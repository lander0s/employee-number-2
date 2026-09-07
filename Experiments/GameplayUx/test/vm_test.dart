// The machine's semantics, as written down in GameDesign/level-01-briefing.md
// section 5 and level-04-briefing.md sections 5 to 7.
//
// The suite in level-04-briefing 7.1 is the spec for most of this: ten
// adversarial programs, each run against the level, with the verdict and the
// message both pinned. Several of them pass on some shipments and fail on
// others, which is the whole argument for a shipment *set* - so the same
// programs are also run against the briefing's other five.

import 'package:flutter_test/flutter_test.dart';
import 'package:gameplay_ux/model/level.dart';
import 'package:gameplay_ux/model/program.dart';
import 'package:gameplay_ux/model/vm.dart';

// ------------------------------------------------------------------ building

Node cmd(String id, {int pallet = 1}) =>
    Node(commandId: id, palletArg: pallet);

Node block(String id, List<Node> body, {String cond = 'ZERO'}) =>
    Node(commandId: id, comparator: cond, children: body);

Level levelOf(List<int> intake, {bool handsEmpty = false}) => Level(
  brief: const LevelBrief(task: 'Ship only the positive numbers.'),
  intake: intake,
  goal: (i) => i.where((n) => n > 0).toList(),
  requireHandsEmpty: handsEmpty,
);

RunResult exec(List<Node> program, Level level) =>
    Machine(compile(program), level).run();

/// The briefing's six shipments, by role.
const s1 = [-4, 7, 0, 3, 9, -1]; // par: mixed, a zero, ends rejected
const s2 = <int>[]; // empty intake
const s3 = [-5, 0, -2]; // nothing to ship
const s4 = [2, 8, 5]; // nothing to reject
const s5 = [6, -3, 0, 4]; // positive first and last
const s6 = [-7]; // one package, rejected
const shipments = {'s1': s1, 's2': s2, 's3': s3, 's4': s4, 's5': s5, 's6': s6};

/// `REPEAT { TAKE; IF POSITIVE { SHIP } }`
List<Node> reference() => [
  block('repeat', [
    cmd('take'),
    block('ifCond', [cmd('ship')], cond: 'POSITIVE'),
  ]),
];

void main() {
  group('the reference solution', () {
    test('clears every shipment in the set', () {
      for (final entry in shipments.entries) {
        final r = exec(reference(), levelOf(entry.value));
        expect(r.passed, isTrue, reason: entry.key);
        expect(
          r.outbound,
          entry.value.where((n) => n > 0).toList(),
          reason: entry.key,
        );
      }
    });

    test('SPEED is len + 1 + positives', () {
      // One TAKE per package, one final TAKE that ends the shift, one SHIP per
      // positive (level-04-briefing 6.3). The +1 is the empty TAKE: it moves no
      // package, but the robot walked to the chute to find that out, so it
      // costs a step like any other. An empty shipment therefore costs 1, not 0.
      const expected = {'s1': 10, 's2': 1, 's3': 4, 's4': 7, 's5': 7, 's6': 2};
      for (final entry in shipments.entries) {
        final intake = entry.value;
        final positives = intake.where((n) => n > 0).length;
        final steps = exec(reference(), levelOf(intake)).steps;
        expect(steps, intake.length + 1 + positives, reason: entry.key);
        expect(steps, expected[entry.key], reason: '${entry.key} in the table');
      }
    });

    test('s1 ends with the rejected package still in the claws', () {
      // The ordering that is easy to get backwards: TAKE on an empty intake
      // ends the shift *before* the discard, so the robot finishes holding
      // what it refused. Nothing in outbound proves this - only the last tick
      // does.
      final r = exec(reference(), levelOf(s1));
      expect(r.ticks.last.claws, -1);
      expect(r.passed, isTrue);
    });

    test('and would fail its own level if empty hands were required', () {
      // Which is why requireHandsEmpty is a per-level flag and defaults off
      // (level-04-briefing 5.3). Without this the reference solution fails one
      // shipment in six, on a random roll, for no reason the player can see.
      expect(exec(reference(), levelOf(s6, handsEmpty: true)).passed, isFalse);
      expect(exec(reference(), levelOf(s6)).passed, isTrue);
    });
  });

  group('the adversarial suite', () {
    // level-04-briefing 7.1, in order. `passes` lists the shipments each wrong
    // program clears - that overlap is what 7.2 uses to argue the set needs all
    // six members.
    final cases = <String, ({List<Node> Function() program, Set<String> passes})>{
      'ships everything': (
        program: () => [
          block('repeat', [cmd('take'), cmd('ship')]),
        ],
        // s2 as well: with an empty intake the first TAKE ends the shift
        // before SHIP can be reached, so the program never gets the chance to
        // be wrong. The briefing had this row down as a failure.
        passes: {'s2', 's4'},
      ),
      'ships nothing': (
        program: () => [
          block('repeat', [cmd('take')]),
        ],
        passes: {'s2', 's3', 's6'},
      ),
      'no loop': (
        program: () => [
          cmd('take'),
          block('ifCond', [cmd('ship')], cond: 'POSITIVE'),
        ],
        passes: {'s2', 's6'},
      ),
      'condition before take': (
        program: () => [
          block('repeat', [
            block('ifCond', [cmd('ship')], cond: 'POSITIVE'),
            cmd('take'),
          ]),
        ],
        passes: <String>{},
      ),
      'ships the zeros': (
        program: () => [
          block('repeat', [
            cmd('take'),
            block('ifCond', [cmd('ship')], cond: 'NOT NEGATIVE'),
          ]),
        ],
        passes: {'s2', 's4', 's6'},
      ),
      'ships the negatives': (
        program: () => [
          block('repeat', [
            cmd('take'),
            block('ifCond', [cmd('ship')], cond: 'NOT ZERO'),
          ]),
        ],
        passes: {'s2', 's4'},
      ),
      'double ship': (
        program: () => [
          block('repeat', [
            cmd('take'),
            block('ifCond', [cmd('ship')], cond: 'POSITIVE'),
            cmd('ship'),
          ]),
        ],
        // Same reason as "ships everything": s2 never reaches the bad SHIP.
        passes: {'s2'},
      ),
    };

    cases.forEach((name, spec) {
      test('$name clears exactly ${spec.passes}', () {
        for (final entry in shipments.entries) {
          expect(
            exec(spec.program(), levelOf(entry.value)).passed,
            spec.passes.contains(entry.key),
            reason: '$name on ${entry.key}',
          );
        }
      });
    });

    test('only the zeros catch a NOT NEGATIVE filter', () {
      // 7.2: drop the zeros from the set and this wrong program clears the
      // level. This is the test that justifies s1, s3 and s5 carrying one.
      final program = [
        block('repeat', [
          cmd('take'),
          block('ifCond', [cmd('ship')], cond: 'NOT NEGATIVE'),
        ]),
      ];
      for (final entry in shipments.entries) {
        final hasZero = entry.value.contains(0);
        expect(
          exec(program, levelOf(entry.value)).passed,
          !hasZero,
          reason: entry.key,
        );
      }
    });
  });

  group('failures name what went wrong', () {
    test('shipping with empty claws', () {
      final r = exec([cmd('ship')], levelOf(s1));
      expect(r.halt.kind, HaltKind.failed);
      expect(r.verdict, contains('claws were empty'));
    });

    test('a condition with empty claws', () {
      // Not "false": with nothing held there is no question to answer, and
      // guessing produces a wrong shipment several seconds later with nothing
      // to trace it back to (level-04-briefing 5.2).
      final r = exec([
        block('ifCond', [cmd('ship')], cond: 'POSITIVE'),
      ], levelOf(s1));
      expect(r.halt.kind, HaltKind.failed);
      expect(r.verdict, "UNIT-02 checked what it was holding. It wasn't holding anything.");
    });

    test('leaving packages on the intake', () {
      final r = exec([cmd('take'), cmd('ship')], levelOf(s4));
      expect(r.passed, isFalse);
      expect(r.verdict, contains('2 packages still on intake'));
    });

    test('and it says "package" when there is one', () {
      final r = exec([cmd('take'), cmd('ship')], levelOf([1, 2]));
      expect(r.verdict, contains('1 package still on intake'));
    });

    test('the goal is checked at the end, not on the fly', () {
      // Outbound is already correct when the last SHIP runs; the program still
      // fails, because the instruction after it cannot be performed
      // (level-01-briefing 7, case 9).
      final r = exec([
        ...List.generate(3, (_) => cmd('take')).expand((t) => [t, cmd('ship')]),
        cmd('ship'),
      ], levelOf([1, 2, 3]));
      expect(r.outbound, [1, 2, 3]);
      expect(r.passed, isFalse);
      expect(r.halt.kind, HaltKind.failed);
    });
  });

  group('the discard rule', () {
    test('TAKE with full claws bins what was held', () {
      // Silent in the fiction, loud in the trace: the line has to say so, or
      // the only symptom is a missing box several steps later.
      final r = exec([
        cmd('take'),
        cmd('take'),
        cmd('ship'),
      ], levelOf([1, 2]));
      expect(r.outbound, [2]);
      expect(r.ticks[1].line, contains('binned 1'));
    });

    test('COPY FROM with full claws does too', () {
      final r = exec([
        cmd('take'),
        cmd('copyTo', pallet: 1),
        cmd('take'),
        cmd('copyFrom', pallet: 1),
      ], levelOf([1, 2]));
      expect(r.ticks.last.claws, 1);
      expect(r.ticks.last.line, contains('binned 2'));
    });
  });

  group('arithmetic and the floor', () {
    test('SUM and SUB work against a pallet', () {
      final r = exec([
        cmd('take'),
        cmd('copyTo', pallet: 1),
        cmd('take'),
        cmd('sum', pallet: 1),
        cmd('ship'),
      ], levelOf([10, 5]));
      expect(r.outbound, [15]);
    });

    test('SUB is claws minus pallet, not the other way round', () {
      final r = exec([
        cmd('take'),
        cmd('copyTo', pallet: 1),
        cmd('take'),
        cmd('sub', pallet: 1),
        cmd('ship'),
      ], levelOf([10, 4]));
      expect(r.outbound, [-6]);
    });

    test('reading an empty pallet fails', () {
      final r = exec([cmd('copyFrom', pallet: 3)], levelOf(s1));
      expect(r.halt.kind, HaltKind.failed);
      expect(r.verdict, contains('Pallet 3 is empty'));
    });
  });

  group('the loop guard', () {
    test('counts instructions, not steps', () {
      // The one rule here that is a bug rather than a design choice. This
      // program executes forever while SPEED stays frozen, so a guard watching
      // steps never trips and the app hangs (level-04-briefing 5.1, rule 3).
      final r = exec([
        cmd('take'),
        block('repeat', [
          block('ifCond', const [], cond: 'POSITIVE'),
        ]),
      ], levelOf([7]));

      expect(r.halt.kind, HaltKind.stuck);
      expect(r.verdict, 'UNIT-02 got stuck in a loop.');
      expect(r.steps, 1, reason: 'the spin cost no steps at all');
      expect(r.truncated, isTrue, reason: 'the trace stopped growing');
      expect(r.ticks.length, lessThanOrEqualTo(Machine.traceCap));
    });

    test('an empty REPEAT is caught too', () {
      final r = exec([block('repeat', const [])], levelOf(s1));
      expect(r.halt.kind, HaltKind.stuck);
    });
  });

  group('compilation', () {
    test('a block emits a branch around its body, and nothing for the closer', () {
      // Closers are rendered but are not commands: they are free for SIZE, and
      // they compile to nothing at all (level-04-briefing 5.1, rule 1).
      final code = compile([
        block('ifCond', [cmd('ship')], cond: 'POSITIVE'),
      ]);
      expect(code.map((i) => i.op), [Op.branchUnless, Op.ship]);
      expect(code.first.target, 2, reason: 'skips to just past the body');
    });

    test('REPEAT WHILE tests at the top and jumps back to the test', () {
      final code = compile([
        block('repeatWhile', [cmd('take')], cond: 'NOT ZERO'),
      ]);
      expect(code.map((i) => i.op), [Op.branchUnless, Op.take, Op.jump]);
      expect(code.last.target, 0, reason: 'back to the test, not past it');
      expect(code.first.target, 3, reason: 'out of the loop entirely');
    });

    test('every instruction remembers the row it came from', () {
      // Which is the whole basis of the caret: the editor never has to be asked
      // where the program counter is.
      final program = reference();
      final repeat = program.first;
      final take = repeat.children!.first;

      final code = compile(program);
      expect(code.first.nodeId, take.id);
      expect(code.last.nodeId, repeat.id, reason: 'the back edge is the loop');
    });

    test('an empty program is legal and does nothing', () {
      final r = exec(const [], levelOf(s1));
      expect(r.ticks, isEmpty);
      expect(r.halt.kind, HaltKind.shiftEnded);
      expect(r.passed, isFalse, reason: 'six packages are still on intake');
    });
  });
}
