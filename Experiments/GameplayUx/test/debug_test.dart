// Driving a run by hand.
//
// A run used to be something you watched: start it, watch it, or abandon it.
// It is a list, though - the machine finishes before the first frame is drawn -
// and these are the tests that say so out loud. Stepping back recomputes
// nothing; it walks the same list the other way, and the tick it lands on is
// the identical object it showed on the way past.

import 'package:flutter_test/flutter_test.dart';
import 'package:gameplay_ux/model/level.dart';
import 'package:gameplay_ux/model/levels.dart';
import 'package:gameplay_ux/model/program.dart';
import 'package:gameplay_ux/ui/floor/pace.dart';
import 'package:gameplay_ux/ui/run_controller.dart';

/// Long enough for the slowest single instruction to have certainly advanced.
///
/// Derived, not guessed: an instruction takes as long as its movement, and the
/// longest walk on the floor plus a merge is most of six seconds. A test that
/// picked a number here would quietly stop advancing the day the unit slowed
/// down.
final aWhile = Pace.longestInstruction + const Duration(seconds: 1);

/// A program long enough to have a middle to be in.
ProgramDocument program() => referenceSolution();

RunController controllerFor([Level? level]) {
  final doc = program();
  return RunController(level: level ?? noNegatives, program: () => doc);
}

void main() {
  group('a run is a list, and it can be walked', () {
    test('nothing is loaded until a control asks for it', () {
      final run = controllerFor();
      expect(run.running, isFalse);
      expect(run.now, isNull);
      expect(run.result, isNull);

      // Forward is offered from cold - the first step is what compiles.
      expect(run.canStepForward, isTrue);
      expect(run.canStepBack, isFalse, reason: 'nothing to go back to');
    });

    test('the first step compiles and shows instruction one', () {
      final run = controllerFor();
      run.stepForward();

      expect(run.running, isTrue, reason: 'a trace is loaded');
      expect(run.playing, isFalse, reason: 'a step does not start the clock');
      expect(run.cursor, 0);
      expect(run.now, isNotNull);
      expect(run.executing, isNotNull);
    });

    test('stepping back lands on the identical tick, not a new one', () {
      final run = controllerFor();
      for (var i = 0; i < 6; i++) {
        run.stepForward();
      }
      final atFive = run.now;
      final atFour = run.previous;

      run.stepBack();
      expect(run.cursor, 4);
      // Identity, not equality: going back must not re-run anything. If this
      // ever fails it means a second machine ran, which is the whole thing the
      // trace-replay shape exists to avoid.
      expect(identical(run.now, atFour), isTrue);

      run.stepForward();
      expect(identical(run.now, atFive), isTrue);
    });

    test('back from the first instruction is the floor before the shift', () {
      final run = controllerFor();
      run.stepForward();
      expect(run.cursor, 0);

      run.stepBack();
      expect(run.cursor, -1);
      expect(run.now, isNull, reason: 'the shipment as it arrived');
      expect(run.executing, isNull, reason: 'no line is running');
      expect(run.running, isTrue, reason: 'the trace is still loaded');
      expect(run.canStepBack, isFalse);
    });

    test(
      'stepping off the end raises the verdict, and back off it returns',
      () {
        final run = controllerFor();
        final total = _walkToEnd(run);

        expect(run.finished, isTrue);
        expect(run.result, isNotNull);
        expect(run.canStepForward, isFalse, reason: 'the shift is over');

        run.stepBack();
        expect(run.finished, isFalse);
        expect(run.cursor, total - 1, reason: 'back onto the last instruction');
        expect(run.canStepForward, isTrue);
      },
    );

    test('a loaded run stays loaded however it is being driven', () {
      // [running] is what locks the program for editing. A paused run has to
      // keep it: the trace on screen describes the program as it was compiled,
      // and an edit would leave the two describing different things.
      final run = controllerFor();
      run.stepForward();
      expect(run.running, isTrue);
      expect(run.paused, isTrue);

      run.stop();
      expect(run.running, isFalse);
      expect(run.paused, isFalse);
      expect(run.cursor, -1);
      expect(run.result, isNull);
    });

    test('SIZE is the program that ran, captured when it loaded', () {
      final run = controllerFor();
      run.stepForward();
      expect(run.size, program().size);
    });
  });

  group('the clock, and taking it back', () {
    testWidgets('play advances, pause holds, play carries on', (tester) async {
      final run = controllerFor();
      addTearDown(run.dispose);

      run.play();
      expect(run.playing, isTrue);

      // The first instruction is scheduled with no delay.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(run.cursor, 0);

      await tester.pump(aWhile);
      final reached = run.cursor;
      expect(reached, greaterThan(0), reason: 'the clock moved it along');

      run.pause();
      expect(run.playing, isFalse);
      expect(run.paused, isTrue);

      // Held: time passing does nothing at all while paused.
      await tester.pump(aWhile);
      expect(run.cursor, reached);

      run.play();
      expect(run.playing, isTrue);
      await tester.pump(aWhile);
      expect(run.cursor, greaterThan(reached));

      run.stop();
    });

    testWidgets('a step stops the clock rather than racing it', (tester) async {
      final run = controllerFor();
      addTearDown(run.dispose);

      run.play();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(run.playing, isTrue);

      run.stepForward();
      expect(run.playing, isFalse, reason: 'stepping takes the wheel');

      final at = run.cursor;
      await tester.pump(aWhile);
      expect(run.cursor, at, reason: 'no timer left running underneath');

      run.stop();
    });

    testWidgets('a run that was driven waits to be read', (tester) async {
      // Watching a run end and being able to edit again is the flow worth
      // keeping. Reading one is not the same thing: having the trace vanish
      // out from under a player who paused to look at it would be hostile, so
      // the first deliberate control turns the release off.
      final driven = controllerFor();
      addTearDown(driven.dispose);
      _walkToEnd(driven);
      expect(driven.finished, isTrue);

      await tester.pump(aWhile * 4);
      expect(driven.running, isTrue, reason: 'still there to be read');
      driven.stop();
    });
  });
}

/// Steps until the verdict is up, and returns how many instructions there were.
///
/// Bounded: a step that stopped advancing would otherwise hang the suite
/// rather than fail it.
int _walkToEnd(RunController run) {
  for (var i = 0; i < 5000; i++) {
    if (run.finished) return run.result!.ticks.length;
    run.stepForward();
  }
  fail('stepping never reached the end of the trace');
}
