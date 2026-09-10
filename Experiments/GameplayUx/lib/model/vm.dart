/// The machine that actually runs a program.
///
/// Two halves. [compile] flattens the editor's tree into a straight list of
/// instructions with jumps, and [Machine] walks that list. The flattening is
/// what makes everything downstream simple: a program counter is one integer,
/// stepping is one index, and the row to point the caret at is whatever the
/// current instruction remembers it came from.
///
/// It runs to completion up front and hands back a [RunResult] - a trace of
/// what happened, one entry per instruction, each carrying the state of the
/// world at that moment. The screen then replays it on a timer. That split is
/// deliberate: the verdict is known before the first frame of playback, the
/// trace is a value that tests can assert on without a clock, and the animation
/// this is eventually feeding is a replay of exactly the same list.
///
/// Semantics are the ones written down in GameDesign/level-01-briefing.md 5 and
/// level-04-briefing.md 5, including the two orderings that are easy to get
/// backwards and change what the player sees.
library;

import 'commands.dart';
import 'level.dart';
import 'program.dart';

// ---------------------------------------------------------------- compilation

enum Op {
  take,
  ship,
  copyTo,
  copyFrom,
  sum,
  sub,

  /// Skip to [target] unless the held package satisfies the condition. Both
  /// `IF` and `REPEAT WHILE` compile to this; only the back edge differs.
  branchUnless,

  /// The loop back edge. Free, and never traced: a jump is bookkeeping, not
  /// something the robot does.
  jump,
}

class Instr {
  Instr(this.op, this.nodeId, {this.pallet = 0, this.comparator, this.target});

  final Op op;

  /// The row this came from, so the caret has somewhere to point.
  final String nodeId;

  final int pallet;
  final String? comparator;

  /// Where [Op.branchUnless] and [Op.jump] go. Patched after the body is
  /// emitted, which is why it is not final.
  int? target;

  /// Structure is free; work costs one step each. The rule is physical rather
  /// than syntactic - a step is a thing the player watches the robot do, and
  /// deciding has no animation (level-04-briefing 5.1).
  bool get costsStep => switch (op) {
    Op.take || Op.ship || Op.copyTo || Op.copyFrom || Op.sum || Op.sub => true,
    Op.branchUnless || Op.jump => false,
  };
}

/// Flattens the tree. Bodies are emitted inline; blocks become branches.
List<Instr> compile(List<Node> root) {
  final out = <Instr>[];

  void emit(List<Node> nodes) {
    for (final node in nodes) {
      switch (node.commandId) {
        case 'take':
          out.add(Instr(Op.take, node.id));
        case 'ship':
          out.add(Instr(Op.ship, node.id));
        case 'copyTo':
          out.add(Instr(Op.copyTo, node.id, pallet: node.palletArg));
        case 'copyFrom':
          out.add(Instr(Op.copyFrom, node.id, pallet: node.palletArg));
        case 'sum':
          out.add(Instr(Op.sum, node.id, pallet: node.palletArg));
        case 'sub':
          out.add(Instr(Op.sub, node.id, pallet: node.palletArg));

        case 'repeat':
          // No test at the top: the only ways out are an empty TAKE and the
          // end of the program (6.6 - there is no way to ask whether the
          // intake is empty).
          final top = out.length;
          emit(node.children!);
          out.add(Instr(Op.jump, node.id, target: top));

        case 'repeatWhile':
          final top = out.length;
          final test = Instr(
            Op.branchUnless,
            node.id,
            comparator: node.comparator,
          );
          out.add(test);
          emit(node.children!);
          out.add(Instr(Op.jump, node.id, target: top));
          test.target = out.length;

        case 'ifCond':
          final test = Instr(
            Op.branchUnless,
            node.id,
            comparator: node.comparator,
          );
          out.add(test);
          emit(node.children!);
          test.target = out.length;

        default:
          throw StateError('no instruction for ${node.commandId}');
      }
    }
  }

  emit(root);
  return out;
}

/// Whether a held value satisfies one of the six comparisons against zero.
///
/// **Zero is not positive.** Standard, and the level that teaches POSITIVE has
/// a zero in its shipment for exactly that reason.
bool holds(String comparator, int value) => switch (comparator) {
  'ZERO' => value == 0,
  'NOT ZERO' => value != 0,
  'POSITIVE' => value > 0,
  'NOT POSITIVE' => value <= 0,
  'NEGATIVE' => value < 0,
  'NOT NEGATIVE' => value >= 0,
  _ => throw StateError('unknown comparator $comparator'),
};

// ------------------------------------------------------------------- running

enum HaltKind {
  /// The intake ran dry, or the program ran off its end. Either way the shift
  /// is over and the goal gets checked.
  shiftEnded,

  /// The robot was asked to do something impossible. The goal is not checked:
  /// a program that fails, fails, even if outbound happened to be right.
  failed,

  /// Spinning without doing anything. Counted in *instructions*, not steps -
  /// see [Machine.instructionCap].
  stuck,
}

class Halt {
  const Halt(this.kind, this.message);

  final HaltKind kind;
  final String message;
}

/// Where UNIT-02 is standing.
///
/// The machine has to record this because the floor cannot work it out: a tick
/// says a package left the intake, not that the robot walked to the chute to
/// fetch it. It is where the unit *is*, not where it is going, so an
/// instruction that moves nothing - a condition - carries the station of
/// whatever came before it and the robot stays put.
enum StationKind {
  /// Where a shift starts. Nothing is worked on from here.
  home,

  /// The near end of the intake belt.
  chute,

  /// The near end of the outbound belt, which never moves.
  outbound,

  /// One of the numbered floor spots.
  pallet,
}

class Station {
  const Station(this.kind, [this.pallet = 0]);

  static const start = Station(StationKind.home);

  final StationKind kind;

  /// Only meaningful for [StationKind.pallet].
  final int pallet;

  @override
  bool operator ==(Object other) =>
      other is Station && other.kind == kind && other.pallet == pallet;

  @override
  int get hashCode => Object.hash(kind, pallet);
}

/// One instruction's worth of history, with the world as it stood after it.
class Tick {
  const Tick({
    required this.nodeId,
    required this.line,
    required this.intake,
    required this.claws,
    required this.outbound,
    required this.pallets,
    required this.steps,
    required this.station,
    required this.op,
  });

  /// The row that ran, for the caret.
  final String nodeId;

  /// What happened, in words, for the console.
  final String line;

  final List<int> intake;
  final int? claws;
  final List<int> outbound;
  final List<int?> pallets;

  /// SPEED so far.
  final int steps;

  /// Where the unit was standing when this instruction finished.
  final Station station;

  /// Which instruction it was.
  ///
  /// Recorded for the same reason as [station]: the floor cannot work it out.
  /// Some of it is inferable from the state either side - a package leaving the
  /// intake means a TAKE - but `COPY FROM` and `SUB` both just change what is
  /// in the claws, and telling them apart by comparing the new value against
  /// the pallet fails on the shipment where a subtraction happens to land on
  /// it. The machine knows; this is it saying so.
  final Op op;
}

class RunResult {
  const RunResult({
    required this.ticks,
    required this.halt,
    required this.outbound,
    required this.steps,
    required this.passed,
    required this.verdict,
    required this.truncated,
  });

  final List<Tick> ticks;
  final Halt halt;
  final List<int> outbound;
  final int steps;

  /// Whether the shipment was right *and* the shift ended cleanly.
  final bool passed;

  /// What to tell the player, pass or fail.
  final String verdict;

  /// The trace stopped being recorded before the program stopped running. Only
  /// reachable by a program that spins.
  final bool truncated;
}

class Machine {
  Machine(this.program, this.level)
    : _intake = List<int>.of(level.intake),
      _pallets = List<int?>.filled(palletCount, null);

  final List<Instr> program;
  final Level level;

  final List<int> _intake;
  final List<int> _outbound = [];
  final List<int?> _pallets;
  int? _claws;

  int _pc = 0;
  int _steps = 0;
  int _instructions = 0;

  /// Updated by the instructions that send the robot somewhere, and left alone
  /// by the ones that do not.
  Station _station = Station.start;

  /// Generous, and counted in instructions rather than steps.
  ///
  /// This is the one rule here that is a bug rather than a design choice. A
  /// program like `REPEAT { IF POSITIVE { } }` with a package held runs forever
  /// while its *step* count stays frozen, so a guard watching SPEED never
  /// trips, the frame never advances, and the app hangs - on a phone, with no
  /// console, in front of a playtester (level-04-briefing 5.1).
  static const instructionCap = 100000;

  /// The trace stops growing here. A program that spins would otherwise record
  /// a hundred thousand entries to say one thing.
  static const traceCap = 3000;

  final List<Tick> _ticks = [];
  bool _truncated = false;

  RunResult run() {
    Halt halt = const Halt(HaltKind.shiftEnded, 'The shift ended.');

    while (true) {
      if (_instructions++ >= instructionCap) {
        halt = const Halt(HaltKind.stuck, 'UNIT-02 got stuck in a loop.');
        break;
      }
      if (_pc < 0 || _pc >= program.length) break;

      final outcome = _exec(program[_pc]);
      if (outcome != null) {
        halt = outcome;
        break;
      }
    }

    return _finish(halt);
  }

  /// Runs one instruction. Returns a [Halt] if the shift is over.
  Halt? _exec(Instr instr) {
    switch (instr.op) {
      case Op.take:
        // Order matters and is easy to get backwards: an empty intake ends the
        // shift *before* the discard, so the robot finishes still holding what
        // it was rejecting. That image - UNIT-02 waving goodbye with the
        // package it refused - is worth more to the lesson than any wording
        // (level-04-briefing 5).
        if (_intake.isEmpty) {
          // Traced, and charged. The robot still walked to the chute to find
          // out, so it costs a step like any other TAKE - which is why the
          // reference solution's SPEED is `len + 1 + positives` rather than
          // `len + positives` (level-04-briefing 6.3), and why an empty
          // shipment costs 1 rather than 0.
          _station = const Station(StationKind.chute);
          _trace(instr, 'TAKE  (intake empty, shift ends)');
          return const Halt(HaltKind.shiftEnded, 'The intake ran dry.');
        }
        final discarded = _claws;
        _claws = _intake.removeAt(0);
        _station = const Station(StationKind.chute);
        _trace(
          instr,
          discarded == null
              ? 'TAKE $_claws'
              : 'TAKE $_claws  (binned $discarded)',
        );

      case Op.ship:
        if (_claws == null) return _emptyClaws('ship');
        // Emptied *before* the trace. A tick is the world as it stands after
        // the instruction, and this one was recording the claws still holding
        // what had just been shipped - so anything reading the trace saw a
        // package in two places at once. The floor did exactly that, and left
        // the unit standing at the belt holding a box it had put down.
        final shipped = _claws!;
        _outbound.add(shipped);
        _claws = null;
        _station = const Station(StationKind.outbound);
        _trace(instr, 'SHIP $shipped');

      case Op.copyTo:
        if (_claws == null) return _emptyClaws('copy');
        _pallets[instr.pallet] = _claws;
        _station = Station(StationKind.pallet, instr.pallet);
        _trace(instr, 'COPY TO ${palletName(instr.pallet)}  <- ${_claws!}');

      case Op.copyFrom:
        final value = _pallets[instr.pallet];
        if (value == null) return _emptyPallet(instr.pallet);
        // Same discard rule as TAKE: anything that fills full claws bins what
        // was in them (game-design-document 6.3).
        final discarded = _claws;
        _claws = value;
        _station = Station(StationKind.pallet, instr.pallet);
        _trace(
          instr,
          discarded == null
              ? 'COPY FROM ${palletName(instr.pallet)}  -> $value'
              : 'COPY FROM ${palletName(instr.pallet)}  -> $value'
                    '  (binned $discarded)',
        );

      case Op.sum:
      case Op.sub:
        if (_claws == null) return _emptyClaws('add to');
        final operand = _pallets[instr.pallet];
        if (operand == null) return _emptyPallet(instr.pallet);
        final before = _claws!;
        _claws = instr.op == Op.sum ? before + operand : before - operand;
        _station = Station(StationKind.pallet, instr.pallet);
        final sign = instr.op == Op.sum ? '+' : '-';
        _trace(
          instr,
          '${instr.op == Op.sum ? 'SUM' : 'SUB'} '
          '${palletName(instr.pallet)}'
          '  $before $sign $operand = ${_claws!}',
        );

      case Op.branchUnless:
        // A condition asks about the package in the claws. With nothing in them
        // there is no question to answer, so this fails rather than quietly
        // picking a branch and going wrong several seconds later
        // (level-04-briefing 5.2).
        if (_claws == null) {
          return const Halt(
            HaltKind.failed,
            "UNIT-02 checked what it was holding. It wasn't holding anything.",
          );
        }
        final yes = holds(instr.comparator!, _claws!);
        _trace(
          instr,
          '${instr.comparator}? ${_claws!} -> ${yes ? 'yes' : 'no'}',
        );
        if (!yes) {
          _pc = instr.target!;
          return null;
        }

      case Op.jump:
        _pc = instr.target!;
        return null;
    }

    _pc++;
    return null;
  }

  Halt _emptyClaws(String verb) => Halt(
    HaltKind.failed,
    'UNIT-02 tried to $verb, but its claws were empty.',
  );

  Halt _emptyPallet(int pallet) =>
      Halt(HaltKind.failed, 'Pallet ${palletName(pallet)} is empty.');

  void _trace(Instr instr, String line) {
    if (instr.costsStep) _steps++;
    if (_ticks.length >= traceCap) {
      _truncated = true;
      return;
    }
    _ticks.add(
      Tick(
        nodeId: instr.nodeId,
        line: line,
        intake: List.unmodifiable(_intake),
        claws: _claws,
        outbound: List.unmodifiable(_outbound),
        pallets: List.unmodifiable(_pallets),
        steps: _steps,
        station: _station,
        op: instr.op,
      ),
    );
  }

  RunResult _finish(Halt halt) {
    final expected = level.expected;
    var passed = halt.kind == HaltKind.shiftEnded;
    var verdict = halt.message;

    if (halt.kind != HaltKind.shiftEnded) {
      passed = false;
    } else if (_intake.isNotEmpty) {
      passed = false;
      final n = _intake.length;
      verdict =
          'The shift ended with $n package${n == 1 ? '' : 's'} still on intake.';
    } else if (level.requireHandsEmpty && _claws != null) {
      passed = false;
      verdict = 'UNIT-02 finished still holding ${_claws!}.';
    } else if (!_sameOrder(_outbound, expected)) {
      passed = false;
      verdict = _mismatch(_outbound, expected);
    } else {
      verdict = 'Shipment accepted.';
    }

    return RunResult(
      ticks: List.unmodifiable(_ticks),
      halt: halt,
      outbound: List.unmodifiable(_outbound),
      steps: _steps,
      passed: passed,
      verdict: verdict,
      truncated: _truncated,
    );
  }

  static bool _sameOrder(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Names a value wherever it can. The player's whole model of a filter level
  /// is "which numbers went where", and a message that says only "the shipment
  /// was wrong" throws that away (level-04-briefing 7.3).
  static String _mismatch(List<int> got, List<int> want) {
    for (var i = 0; i < want.length; i++) {
      if (i >= got.length) {
        return 'UNIT-02 was supposed to ship ${want[i]}. It did not.';
      }
      if (got[i] != want[i]) {
        return "UNIT-02 shipped ${got[i]} where ${want[i]} was expected.";
      }
    }
    return "UNIT-02 shipped ${got[want.length]}, which Brent did not ask for.";
  }
}
