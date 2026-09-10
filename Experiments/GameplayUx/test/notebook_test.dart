// The invariants from GameDesign/program-editor.md §9.
//
// Each one is a bug the first pass actually produced, which is why they are
// tests rather than prose. They are grouped and named after the invariant, so a
// failure says which promise broke rather than which widget moved.
//
// Layout assertions are exact here. There is no tilt in this pass, so a measured
// rect is the thing itself and not a rotated bounding box - the tolerances that
// used to hide 8dp of drift are gone with it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameplay_ux/model/commands.dart';
import 'package:gameplay_ux/model/program.dart';
import 'package:gameplay_ux/model/level.dart';
import 'package:gameplay_ux/ui/gameplay_screen.dart';
import 'package:gameplay_ux/ui/notebook/brief.dart';
import 'package:gameplay_ux/ui/notebook/caret.dart';
import 'package:gameplay_ux/ui/notebook/panel.dart';
import 'package:gameplay_ux/ui/notebook/note.dart';
import 'package:gameplay_ux/ui/notebook/program.dart';
import 'package:gameplay_ux/ui/notebook/slot.dart';
import 'package:gameplay_ux/ui/notebook/tokens.dart';

/// MaterialApp installs its own MediaQuery from the view, so the scale has to be
/// injected via `builder` to reach the widgets under test. Animations are off by
/// default: a gap that animates never settles under `pumpAndSettle`, and the
/// animation itself is tested separately with explicit pumps.
/// The brief is written on the page above the program, so it sets where every
/// row starts. Kept to one short line here: the test font draws every glyph as
/// a full square em, so a realistic brief wraps to six lines and pushes the
/// page tail out of the built area entirely. Tests that care about the brief
/// pass their own.
const testBrief = LevelBrief(task: 'Ship.');

/// The level the harness plays, unless a test hands over its own. Its shipment
/// is the briefing's `s1`, so a run exercises the discard, the zero and the
/// correctly-rejected last package.
Level levelWith(LevelBrief brief) => Level(
  brief: brief,
  intake: const [-4, 7, 0, 3, 9, -1],
  goal: (intake) => intake.where((n) => n > 0).toList(),
);

Widget harness({
  double textScale = 1.0,
  bool animate = false,
  LevelBrief brief = testBrief,
  Level? level,
  ProgramDocument? program,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(textScale),
      disableAnimations: !animate,
    ),
    child: child!,
  ),
  home: GameplayScreen(level: level ?? levelWith(brief), program: program),
);

Future<void> boot(
  WidgetTester tester, {
  double textScale = 1.0,
  LevelBrief brief = testBrief,
  Level? level,
  ProgramDocument? program,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    harness(textScale: textScale, brief: brief, level: level, program: program),
  );
  await tester.pumpAndSettle();
}

/// Command words appear both on the page and on the note, so assertions have to
/// say which surface they mean.
Finder onPage(String text) =>
    find.descendant(of: find.byType(ProgramEditor), matching: find.text(text));

Finder onNote(String text) =>
    find.descendant(of: find.byType(CommandNote), matching: find.text(text));

/// The painted box behind a word.
/// The block a label is drawn in.
///
/// [Panel], not DecoratedBox: a plain fill needs no decoration, so a flat block
/// no longer builds one and this used to resolve to whatever box happened to be
/// further up the tree. Naming the widget says what is meant and cannot drift
/// with how the fill is painted.
Finder boxOf(Finder label) =>
    find.ancestor(of: label, matching: find.byType(Panel)).first;

/// Every gap on the page, in layout order; the tail is the last of them. Scoped
/// to the editor, because the note is a drop target too - that is how deleting
/// works - and it is not a gap.
List<Element> gaps(WidgetTester tester) => find
    .descendant(
      of: find.byType(ProgramEditor),
      matching: find.byType(DragTarget<DragPayload>),
    )
    .evaluate()
    .toList();

double heightOf(WidgetTester tester, Element e) =>
    tester.getRect(find.byWidget(e.widget)).height;

/// Empties the program the way a player can: swipe each root row away, taking
/// its body with it. There used to be a CLEAR button in the floor pane to do
/// this in one tap; it was test scaffolding and it is gone, and a helper that
/// only uses gestures the game actually has is the better trade anyway.
///
/// The wait at the end is load-bearing: the undo toast is laid over the bottom
/// of the screen, exactly where the note is, and a drag started under it would
/// grab the toast instead.
Future<void> clearProgram(WidgetTester tester) async {
  Finder rows() => find.descendant(
    of: find.byType(ProgramEditor),
    matching: find.byType(Dismissible),
  );

  for (var guard = 0; rows().evaluate().isNotEmpty; guard++) {
    expect(guard, lessThan(20), reason: 'a swipe stopped deleting');
    await tester.drag(rows().first, const Offset(400, 0));
    await tester.pumpAndSettle();
  }

  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
  expect(find.text('UNDO'), findsNothing);
}

/// Picks a command off the note and holds it over gap [index] without letting go.
Future<TestGesture> carryFromNote(
  WidgetTester tester,
  String label,
  int index,
) async {
  final gesture = await tester.startGesture(tester.getCenter(onNote(label)));
  await tester.pump(const Duration(milliseconds: 40));
  // Two moves: the first starts the drag, the second lands it on the target.
  await gesture.moveBy(const Offset(0, -30));
  await tester.pump();
  await gesture.moveTo(
    tester.getCenter(find.byWidget(gaps(tester)[index].widget)),
  );
  await tester.pump();
  return gesture;
}

Future<void> dropFromNote(WidgetTester tester, String label, int index) async {
  final gesture = await carryFromNote(tester, label, index);
  await gesture.up();
  await tester.pumpAndSettle();
}

/// Long-presses a placed command and holds it at [to].
Future<TestGesture> liftFromPage(
  WidgetTester tester,
  String label,
  Offset to,
) async {
  final gesture = await tester.startGesture(tester.getCenter(onPage(label)));
  await tester.pump(Paper.liftDelay + const Duration(milliseconds: 60));
  await gesture.moveBy(const Offset(0, -10));
  await tester.pump();
  await gesture.moveTo(to);
  await tester.pump();
  return gesture;
}

void main() {
  group('1. nothing moves when a drop lands', () {
    testWidgets('the rows below a gap hold their position', (tester) async {
      await boot(tester);

      // Gap 1 is inside the REPEAT body, above TAKE.
      final gesture = await carryFromNote(tester, 'SHIP', 1);
      final previewed = tester.getRect(boxOf(onPage('IF')));

      await gesture.up();
      await tester.pumpAndSettle();

      expect(
        tester.getRect(boxOf(onPage('IF'))).top,
        closeTo(previewed.top, 0.5),
        reason: 'the preview already occupied the space the row now takes',
      );
    });

    testWidgets('an open gap is a row plus the gaps that row will have', (
      tester,
    ) async {
      await boot(tester);
      final row = tester.getRect(boxOf(onPage('TAKE')));

      final gesture = await carryFromNote(tester, 'SHIP', 1);

      final gap = tester.getRect(find.byWidget(gaps(tester)[1].widget));
      expect(gap.height, closeTo(row.height + Paper.gap * 2, 0.5));

      // And the outline is inset from its own edge exactly as a word is.
      final outline = tester.getRect(find.byType(DashedOutline));
      final word = tester.getRect(find.text('DROP HERE'));
      expect(
        word.left - outline.left,
        closeTo(tester.getRect(onPage('TAKE')).left - row.left, 0.5),
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('2 and 3. running changes nothing but what can be touched', () {
    Future<void> run(WidgetTester tester) async {
      await tester.tap(find.text('RUN'));
      await tester.pumpAndSettle();
    }

    testWidgets('a run takes the tray height, and gives it back', (
      tester,
    ) async {
      // Pillar 2 said no row moves when a run starts or stops, and that
      // cannot hold now the tray is *above* the program: whatever the tray
      // gives up comes off the top, so every row moves up by its height.
      //
      // What can still be promised is that the move is exactly that and
      // nothing else, and that it is reversible - a program that drifted a
      // little further up on every run would be the real bug this is watching
      // for.
      await boot(tester);
      final tray = tester.getRect(find.byType(CommandNote)).height;
      final before = tester.getRect(boxOf(onPage('TAKE')));

      await run(tester);
      expect(find.byType(CommandNote), findsNothing, reason: 'tray collapsed');
      expect(
        before.top - tester.getRect(boxOf(onPage('TAKE'))).top,
        closeTo(tray, 0.5),
        reason: 'moved up by something other than the tray height',
      );

      await tester.tap(find.text('STOP'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(boxOf(onPage('TAKE'))),
        before,
        reason: 'the program did not come back to where it was',
      );
    });

    testWidgets('the gaps stay, and refuse', (tester) async {
      await boot(tester);
      final count = gaps(tester).length;

      await run(tester);
      expect(gaps(tester), hasLength(count));

      final gap = gaps(tester).first.widget as DragTarget<DragPayload>;
      expect(
        gap.onWillAcceptWithDetails!(
          DragTargetDetails(
            data: const NewCommand('take'),
            offset: Offset.zero,
          ),
        ),
        isFalse,
      );
    });

    testWidgets('and an argument cannot be cycled', (tester) async {
      await boot(tester);
      await run(tester);

      await tester.tap(onPage('POSITIVE'));
      await tester.pumpAndSettle();
      expect(onPage('POSITIVE'), findsOneWidget);
    });
  });

  group('4. gaps everywhere, and the tail owns the rest of the page', () {
    testWidgets('a gap before, between and after every sibling', (
      tester,
    ) async {
      await boot(tester);

      // Root: before REPEAT, and the tail after it. REPEAT's body: before TAKE,
      // between TAKE and IF, after IF. IF's body: before SHIP, after SHIP.
      expect(gaps(tester), hasLength(7));
    });

    testWidgets('the tail runs past the bottom of the page', (tester) async {
      await boot(tester);
      final page = tester.getRect(find.byType(ProgramEditor));
      final tail = tester.getRect(find.byKey(const ValueKey('page-tail')));

      expect(tail.top, lessThan(page.bottom));
      expect(
        tail.height,
        greaterThanOrEqualTo(page.height * Paper.tailSlack - 0.5),
        reason: 'half a page of slack, so a short program can be scrolled',
      );
    });

    testWidgets('a drop far below the program still appends', (tester) async {
      await boot(tester);
      final page = tester.getRect(find.byType(ProgramEditor));

      final gesture = await tester.startGesture(
        tester.getCenter(onNote('SUB')),
      );
      await tester.pump(const Duration(milliseconds: 40));
      // Downwards, off the tray and onto the page: the tray is above the
      // program now, so that is the direction a command travels.
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      // The empty tail, with nothing under it but page.
      await gesture.moveTo(Offset(page.center.dx, page.bottom - 20));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      final dropped = tester.getRect(boxOf(onPage('SUB')));
      final block = tester.getRect(boxOf(onPage('REPEAT')));
      expect(dropped.top, greaterThan(block.top));
      expect(dropped.left, closeTo(block.left, 0.5), reason: 'at the root');
    });

    testWidgets('an empty program is one big drop target', (tester) async {
      await boot(tester);
      await clearProgram(tester);

      expect(find.text('Drag a command down from above.'), findsOneWidget);
      final page = tester.getRect(find.byType(ProgramEditor));

      final gesture = await tester.startGesture(
        tester.getCenter(onNote('TAKE')),
      );
      await tester.pump(const Duration(milliseconds: 40));
      await gesture.moveBy(const Offset(0, -30));
      await tester.pump();
      await gesture.moveTo(page.center);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(onPage('TAKE'), findsOneWidget);
      expect(find.text('Drag a command down from above.'), findsNothing);
    });
  });

  group('5. an empty body reserves a row', () {
    testWidgets('in the shade a child would wear', (tester) async {
      await boot(tester);
      final page = tester.getRect(find.byType(ProgramEditor));

      await clearProgram(tester);

      final gesture = await tester.startGesture(
        tester.getCenter(onNote('REPEAT')),
      );
      await tester.pump(const Duration(milliseconds: 40));
      await gesture.moveBy(const Offset(0, -30));
      await tester.pump();
      await gesture.moveTo(page.center);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      final body = find.byType(EmptyBody);
      expect(body, findsOneWidget);
      expect(
        tester.getRect(body).height,
        closeTo(Paper.openGap, 0.5),
        reason: 'a row, with the gaps a row would have',
      );

      final ghost = tester.widget<DecoratedBox>(
        find.descendant(of: body, matching: find.byType(DecoratedBox)).first,
      );
      expect(
        (ghost.decoration as BoxDecoration).color,
        Paper.fillFor(specFor('repeat').colour, 1),
      );
    });
  });

  group('7. a block is one object', () {
    testWidgets('lifting it carries its body', (tester) async {
      await boot(tester);
      final page = tester.getRect(find.byType(ProgramEditor));

      final before = find.text('SHIP').evaluate().length;
      final gesture = await liftFromPage(tester, 'IF', page.center);

      // One more of each word than before: the block is dimmed in place, and a
      // copy of it is in the air - carrying its body with it.
      expect(find.text('IF').evaluate(), hasLength(greaterThan(2)));
      expect(
        find.text('SHIP').evaluate(),
        hasLength(before + 1),
        reason: 'the body came along',
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('and it cannot be dropped inside itself', (tester) async {
      await boot(tester);

      final editor = tester.state<ProgramEditorState>(
        find.byType(ProgramEditor),
      );
      final repeat = editor.doc.root.first;
      final inner = repeat.children!.firstWhere((n) => n.isBlock);

      expect(editor.doc.move(repeat.id, Slot(inner.id, 0, 2)), isFalse);
    });

    testWidgets('swiping it takes the body with it', (tester) async {
      await boot(tester);

      await tester.drag(onPage('IF'), const Offset(400, 0));
      await tester.pumpAndSettle();

      expect(onPage('IF'), findsNothing);
      expect(onPage('SHIP'), findsNothing);
      expect(onPage('REPEAT'), findsOneWidget);
      expect(find.text('UNDO'), findsOneWidget);
    });
  });

  group('the commands sit centred in their strip', () {
    testWidgets('every command is big enough to get a finger on', (
      tester,
    ) async {
      // [Paper.buttonTarget] was declared and never applied - the buttons were
      // their text plus 2dp, about 19dp, and a drag that has to start inside
      // 19dp is a drag that misses. A guarantee written in a doc comment and
      // implemented nowhere is what this is here to catch.
      await boot(tester);
      for (final spec in commandCatalogue) {
        final box = tester.getRect(boxOf(onNote(spec.trayLabel)));
        expect(
          box.height,
          greaterThanOrEqualTo(Paper.buttonTarget - 0.5),
          reason: '${spec.trayLabel} is ${box.height} tall',
        );
      }
    });

    testWidgets('the same air above the first row as below the last', (
      tester,
    ) async {
      // The two gaps are built out of different things - the white the divider
      // leaves under its handle above, the note's own padding below - so
      // nothing but a measurement can say they agree. They were 21.7dp and
      // 6.0dp, which read as the commands hanging off the splitter rather than
      // sitting in it.
      await boot(tester);
      final handle = tester.getRect(find.byKey(const Key('splitter-handle')));
      final note = tester.getRect(find.byType(CommandNote));
      final firstRow = tester.getRect(boxOf(onNote('TAKE')));
      final lastRow = tester.getRect(boxOf(onNote('SUB')));

      final above = firstRow.top - handle.bottom;
      final below = note.bottom - lastRow.bottom;

      expect(above, closeTo(Paper.trayAir, 0.6), reason: 'above is $above');
      expect(below, closeTo(Paper.trayAir, 0.6), reason: 'below is $below');
      expect(above, closeTo(below, 0.6));
    });
  });

  group('the note is where commands come from and go back to', () {
    testWidgets('it becomes a bin only while a placed command is held', (
      tester,
    ) async {
      await boot(tester);
      expect(find.text('DROP TO REMOVE'), findsNothing);

      // Dragging *from* the note leaves it a note: there is nothing to delete.
      var gesture = await carryFromNote(tester, 'SHIP', 1);
      expect(find.text('DROP TO REMOVE'), findsNothing);
      await gesture.up();
      await tester.pumpAndSettle();

      final page = tester.getRect(find.byType(ProgramEditor));
      gesture = await liftFromPage(tester, 'TAKE', page.center);
      expect(find.text('DROP TO REMOVE'), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('DROP TO REMOVE'), findsNothing);
    });

    testWidgets('dropping a command on it removes the command', (tester) async {
      await boot(tester);
      final note = tester.getRect(find.byType(CommandNote));

      final gesture = await liftFromPage(tester, 'TAKE', note.center);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(onPage('TAKE'), findsNothing);
      expect(find.text('UNDO'), findsOneWidget);
    });

    testWidgets('and the note does not change size when it becomes a bin', (
      tester,
    ) async {
      await boot(tester);
      final before = tester.getRect(find.byType(CommandNote));

      final gesture = await liftFromPage(tester, 'TAKE', before.center);

      // Resizing it would reflow the page mid-drag, which is the one moment the
      // player is tracking a moving object.
      expect(tester.getRect(find.byType(CommandNote)), before);

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('10. the note holds the whole language, without scrolling', () {
    testWidgets('every command, in two rows', (tester) async {
      await boot(tester);

      for (final spec in commandCatalogue) {
        expect(onNote(spec.trayLabel), findsOneWidget, reason: spec.id);
      }

      expect(
        find.descendant(
          of: find.byType(CommandNote),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );

      // The buttons' boxes, not their labels: a long label scales down inside
      // its button, so label tops vary within a row and button tops do not.
      final tops = <double>{};
      for (final spec in commandCatalogue) {
        tops.add(tester.getRect(boxOf(onNote(spec.trayLabel))).top);
      }
      expect(tops, hasLength(2), reason: 'two rows, not one and not three');
    });
  });

  group('11 and 12. where the edges are', () {
    testWidgets('a command ends against its container', (tester) async {
      await boot(tester);
      final page = tester.getRect(find.byType(ProgramEditor));

      // Nothing is laid out wider than the page: the overhang is gone with the
      // "C" it was protecting.
      final block = tester.getRect(boxOf(onPage('REPEAT')));
      expect(block.right, lessThanOrEqualTo(page.right + 0.5));
      expect(block.left - page.left, closeTo(Paper.gutter, 0.5));

      // A command inside a container ends against the container's right arm.
      final take = tester.getRect(boxOf(onPage('TAKE')));
      expect(block.right - take.right, closeTo(Paper.armEnd, 0.5));
    });

    testWidgets('the column has the same air either side', (tester) async {
      await boot(tester);
      final page = tester.getRect(find.byType(ProgramEditor));
      final block = tester.getRect(boxOf(onPage('REPEAT')));

      // The whole point of the inset being [Paper.rootEnd] == [Paper.gutter]:
      // measured rather than assumed, because the two are applied by different
      // widgets at different depths and only meet on screen.
      expect(
        block.left - page.left,
        closeTo(page.right - block.right, 0.5),
        reason:
            'left ${block.left - page.left}, '
            'right ${page.right - block.right}',
      );
    });

    testWidgets('the program starts right of the margin line', (tester) async {
      await boot(tester);
      final page = tester.getRect(find.byType(ProgramEditor));
      final block = tester.getRect(boxOf(onPage('REPEAT')));

      // The margin rule is not drawn any more, but the strip it stood in is
      // still reserved - the caret is what uses it now, and a command written
      // over it would be written over the mark saying which line is running.
      expect(
        block.left - page.left,
        greaterThan(Paper.marginInset),
        reason: 'nothing is written in the caret strip',
      );
    });
  });

  group('the transport says what can be done to a run', () {
    Finder control(String label) => find.bySemanticsLabel(label);

    testWidgets('cold: run it, or step into it', (tester) async {
      await boot(tester);

      expect(find.text('RUN'), findsOneWidget);
      expect(find.text('STOP'), findsNothing, reason: 'nothing to stop yet');
      expect(control('Next instruction'), findsOneWidget);
      // Offered, but disabled: a step with nowhere to go stays put rather than
      // disappearing and shuffling every other control along.
      expect(control('Previous instruction'), findsOneWidget);
    });

    /// Starts a run and leaves it *playing*.
    ///
    /// Never `pumpAndSettle`: that runs the trace out to the verdict, which is
    /// a different state with a different set of controls - and is what the
    /// older tests in this file are unknowingly asserting against when they
    /// reach for STOP.
    Future<void> startPlaying(WidgetTester tester) async {
      await tester.tap(find.text('RUN'));
      await tester.pump();
      // The first instruction is scheduled with no delay, and a bare pump does
      // not advance the clock far enough to fire a zero-duration timer.
      await tester.pump(const Duration(milliseconds: 1));
    }

    testWidgets('playing: pause it, or stop it', (tester) async {
      await boot(tester);
      await startPlaying(tester);

      expect(control('Pause the shift'), findsOneWidget);
      expect(find.text('STOP'), findsOneWidget);
      // The cursor is being moved for you; a step here would race the clock.
      expect(control('Next instruction'), findsNothing);
      expect(control('Previous instruction'), findsNothing);
    });

    testWidgets('paused: step either way, resume, or stop', (tester) async {
      await boot(tester);
      await startPlaying(tester);
      await tester.tap(control('Pause the shift'));
      await tester.pump();

      expect(control('Run the shift'), findsOneWidget, reason: 'resume');
      expect(control('Previous instruction'), findsOneWidget);
      expect(control('Next instruction'), findsOneWidget);
      expect(find.text('STOP'), findsOneWidget);
      expect(control('Pause the shift'), findsNothing);
    });

    testWidgets('a step from cold marks a line without starting the clock', (
      tester,
    ) async {
      await boot(tester);
      expect(find.byType(RunCaret), findsNothing);

      await tester.tap(control('Next instruction'));
      await tester.pump();

      expect(find.byType(RunCaret), findsOneWidget);
      expect(control('Pause the shift'), findsNothing, reason: 'not playing');
      expect(find.text('STOP'), findsOneWidget, reason: 'a run is loaded');
    });
  });

  group('a run says which line it is on', () {
    Future<void> run(WidgetTester tester) async {
      await tester.tap(find.text('RUN'));
      await tester.pumpAndSettle();
    }

    testWidgets('no caret until one starts, and none after it stops', (
      tester,
    ) async {
      await boot(tester);
      expect(find.byType(RunCaret), findsNothing);

      await run(tester);
      expect(find.byType(RunCaret), findsOneWidget);

      await tester.tap(find.text('STOP'));
      await tester.pumpAndSettle();
      expect(find.byType(RunCaret), findsNothing);
    });

    testWidgets('it marks exactly one line', (tester) async {
      await boot(tester);
      await run(tester);

      // The stand-in picks at random, so this cannot assert *which* row - only
      // that whatever it picked is marked once. Loop, because a bug that marks
      // every row or none would otherwise pass whenever the roll was kind.
      for (var i = 0; i < 12; i++) {
        expect(find.byType(RunCaret), findsOneWidget);
        await tester.tap(find.text('STOP'));
        await tester.pumpAndSettle();
        await run(tester);
      }
    });

    testWidgets('the marked command is outlined, and costs no layout', (
      tester,
    ) async {
      await boot(tester);
      const rows = ['REPEAT', 'TAKE', 'IF', 'SHIP'];

      /// Each row's offset *inside the page*, not its position on screen.
      ///
      /// A run collapses the tray above the program, so the page grows upward
      /// and every row on screen moves with it - which has nothing to do with
      /// the outline. Measured against the page, that shift cancels and what
      /// is left is only what the outline itself cost.
      Map<String, double> offsets() {
        final page = tester.getRect(find.byType(ProgramEditor));
        return {
          for (final r in rows)
            r: tester.getRect(boxOf(onPage(r))).top - page.top,
        };
      }

      final before = offsets();

      // Every row, not one of them: an outline that reserved space would only
      // shift the program on the runs that happened to mark a row above the
      // one being watched.
      await run(tester);
      final after = offsets();
      for (final r in rows) {
        expect(after[r], closeTo(before[r]!, 0.5), reason: r);
      }

      final outlined = tester
          .widgetList<Panel>(find.byType(Panel))
          .where((p) => p.outline != null)
          .toList();
      expect(outlined, hasLength(1));
      expect(outlined.single.outline, Paper.caret);
    });

    testWidgets('it sits in the margin, left of the rule', (tester) async {
      await boot(tester);
      await run(tester);

      final caret = tester.getRect(find.byType(RunCaret));
      final page = tester.getRect(find.byType(ProgramEditor));

      // The strip between the page's edge and the margin rule is the caret's
      // alone: it must clear the rule, and it must not hang off the page.
      expect(caret.left - page.left, greaterThanOrEqualTo(0));
      expect(caret.right - page.left, lessThanOrEqualTo(Paper.marginInset));
    });

    testWidgets('level with the line it marks, not the block it opens', (
      tester,
    ) async {
      // A container is as tall as everything it owns, so a mark centred on the
      // marked widget would sit halfway down the body instead of beside the
      // title. Whatever the roll picked, the caret belongs in its first row.
      await boot(tester);
      await run(tester);

      for (var i = 0; i < 8; i++) {
        final caret = tester.getRect(find.byType(RunCaret));
        final marked = tester.getRect(find.byType(CaretGutter));
        expect(
          caret.center.dy - marked.top,
          lessThan(Paper.headerTop + Paper.rowHeight),
          reason: 'the caret drifted below the row it marks',
        );

        // Re-roll rather than re-boot: pumping the screen again reuses its
        // State, so it would still be mid-run and the button would say STOP.
        await tester.tap(find.text('STOP'));
        await tester.pumpAndSettle();
        await run(tester);
      }
    });
  });

  group('a run keeps the line it is on in view', () {
    // A program long enough that the caret has to leave the first screen, run
    // against an intake long enough to reach the bottom of it. Every row is a
    // TAKE, so the machine walks straight down the page one row per tick.
    const rows = 24;

    ProgramDocument longProgram() {
      final doc = ProgramDocument();
      for (var i = 0; i < rows; i++) {
        doc.insertAt('take', Slot(null, i, 0));
      }
      return doc;
    }

    Level longLevel() => Level(
      brief: testBrief,
      intake: List<int>.generate(rows, (i) => i + 1),
      goal: (intake) => const [],
    );

    Rect pageOf(WidgetTester tester) =>
        tester.getRect(find.byType(ProgramEditor));

    /// Starts a run and lets it play for [elapsed], stepping the clock by hand.
    ///
    /// Measured in run *time*, not in instructions. Instructions no longer take
    /// a fixed hold - the animation drives the clock, so one that walks further
    /// takes longer - and counting them from outside would mean knowing the
    /// pacing, which is the thing most likely to change.
    ///
    /// Sliced rather than jumped, so every scheduled instruction actually
    /// fires. And never `pumpAndSettle`: playback reschedules a frame on every
    /// instruction, so settling runs the whole program and tears the caret down
    /// before anything can be measured.
    Future<void> runFor(WidgetTester tester, Duration elapsed) async {
      await tester.tap(find.text('RUN'));
      await tester.pump();
      // The first instruction is scheduled with no delay, and a bare pump does
      // not advance the clock far enough to fire a zero-duration timer.
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();

      const slice = Duration(milliseconds: 100);
      for (var left = elapsed; left > Duration.zero; left -= slice) {
        await tester.pump(slice);
      }
      // One more frame: the scroll is scheduled post-frame, so the instruction
      // that just landed has not been followed yet.
      await tester.pump();
    }

    /// Where the caret is.
    Rect caretOf(WidgetTester tester) =>
        tester.getRect(find.byType(CaretGutter));

    /// The page's scroll offset.
    ///
    /// Read off the position rather than inferred from a row's rect: the rows
    /// are two dozen identical TAKEs, so there is no one of them to measure
    /// against, and this is the number the rule is actually about.
    double offsetOf(WidgetTester tester) => tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(ProgramEditor),
            matching: find.byType(Scrollable),
          ),
        )
        .position
        .pixels;

    /// Drives one instruction, exactly, by hand.
    Future<void> step(WidgetTester tester, String which) async {
      await tester.tap(find.bySemanticsLabel(which));
      await tester.pump();
      // The follow is scheduled post-frame, so the step needs a second frame
      // before the page has had its chance to move.
      await tester.pump();
    }

    testWidgets('it does not move while the line is already showing', (
      tester,
    ) async {
      // This is the case the old centring rule got wrong: it moved the page on
      // every step, including the many where the player could already see the
      // line perfectly well.
      //
      // Measured with the caret parked well clear of both edges, which is what
      // makes it a real test. Doing it near the top of the program proves
      // nothing - the page is already at offset zero there, so centring is
      // clamped to no movement and the old rule passes by accident.
      await boot(tester, level: longLevel(), program: longProgram());
      await runFor(tester, const Duration(seconds: 12));
      await tester.tap(find.bySemanticsLabel('Pause the shift'));
      await tester.pump();

      // Back up the page a few rows, so the next line forward cannot possibly
      // need the page to move.
      for (var i = 0; i < 3; i++) {
        await step(tester, 'Previous instruction');
      }

      final page = pageOf(tester);
      final before = offsetOf(tester);
      final caret = caretOf(tester);
      expect(caret.top, greaterThan(page.top + Paper.rowHeight));
      expect(caret.bottom, lessThan(page.bottom - Paper.rowHeight));

      await step(tester, 'Next instruction');

      expect(
        caretOf(tester).top,
        greaterThan(caret.top),
        reason: 'the caret did not advance, so nothing was tested',
      );
      expect(
        offsetOf(tester),
        before,
        reason: 'the page moved for a line that was already in view',
      );
    });

    testWidgets('it scrolls the minimum once the line reaches the foot', (
      tester,
    ) async {
      // Long enough that the caret would be well off the bottom if nothing had
      // scrolled. Every TAKE here costs one pickup and no walk - the unit
      // never leaves the chute after the first instruction - so this is
      // comfortably mid-program.
      await boot(tester, level: longLevel(), program: longProgram());
      await runFor(tester, const Duration(seconds: 12));

      final page = pageOf(tester);
      final caret = caretOf(tester);

      // On screen, which is the whole requirement...
      expect(caret.top, greaterThanOrEqualTo(page.top - 0.5));
      expect(caret.bottom, lessThanOrEqualTo(page.bottom + 0.5));

      // ...and no further in than it had to come. Walking *down* the program,
      // the minimum move leaves the line near the foot of the page - centring
      // it would mean having scrolled about half a page more than necessary.
      expect(
        caret.center.dy,
        greaterThan(page.center.dy),
        reason: 'the page scrolled further than it needed to',
      );
    });

    testWidgets('and when it does move, it leaves a row of slack', (
      tester,
    ) async {
      // Measured at a movement, not at an arbitrary moment. Slack is what a
      // movement leaves behind so the *following* instruction can land inside
      // it without moving the page again - which means that one step later the
      // line is legitimately flush with the edge. Asserting it every frame
      // would be asserting that the page scrolls every frame.
      await boot(tester, level: longLevel(), program: longProgram());
      await runFor(tester, const Duration(seconds: 12));
      await tester.tap(find.bySemanticsLabel('Pause the shift'));
      await tester.pump();

      var before = offsetOf(tester);
      for (var i = 0; i < rows; i++) {
        await step(tester, 'Next instruction');
        final now = offsetOf(tester);
        if (now != before) {
          expect(
            pageOf(tester).bottom - caretOf(tester).bottom,
            greaterThanOrEqualTo(Paper.caretSlack - 0.5),
            reason: 'the page moved but left the line against the edge',
          );
          return;
        }
        before = now;
      }
      fail('the page never moved, so nothing was measured');
    });

    testWidgets('it comes back up for a line stepped back to', (tester) async {
      // The other direction, which only the debugger reaches: step back far
      // enough and the marked line goes off the *top* of the page.
      await boot(tester, level: longLevel(), program: longProgram());
      await runFor(tester, const Duration(seconds: 12));

      await tester.tap(find.bySemanticsLabel('Pause the shift'));
      await tester.pump();

      final scrolled = pageOf(tester);
      for (var i = 0; i < rows; i++) {
        final prev = find.bySemanticsLabel('Previous instruction');
        if (prev.evaluate().isEmpty) break;
        await tester.tap(prev);
        await tester.pump();
        await tester.pump();

        final caret = find.byType(CaretGutter);
        if (caret.evaluate().isEmpty) break; // stepped back before line one
        expect(
          tester.getRect(caret).top,
          greaterThanOrEqualTo(scrolled.top - 0.5),
          reason: 'the line went off the top after $i steps back',
        );
      }
    });

    testWidgets('and does not fight the top of the page', (tester) async {
      // The first line is already showing, so the right amount of scrolling is
      // none - and there is nothing above it to scroll in even if it wanted to.
      //
      // Measured on the scroll offset, not on where the row lands. A run
      // collapses the tray above the program, which moves every row up by its
      // height without the page having scrolled a pixel, and this test is
      // about the scrolling.
      await boot(tester, level: longLevel(), program: longProgram());
      await runFor(tester, Duration.zero);

      expect(offsetOf(tester), 0, reason: 'the page pulled itself about');
      expect(
        tester.getRect(find.byType(CaretGutter)).center.dy,
        lessThan(pageOf(tester).center.dy),
        reason: 'still up near the top, which is the honest answer here',
      );
    });
  });

  group('the brief is written on the page, not pinned above it', () {
    // Deliberately short: see [testBrief]. Two lines here so the detail is
    // exercised without wrapping in the square test font.
    const brief = LevelBrief(task: 'Ship.', detail: 'Not zero.');

    testWidgets('it is on the page, above the program', (tester) async {
      await boot(tester, brief: brief);

      expect(
        find.text('TASK'),
        findsNothing,
        reason: 'no card above the floor',
      );
      expect(
        find.descendant(
          of: find.byType(ProgramEditor),
          matching: find.byType(Brief),
        ),
        findsOneWidget,
      );
      expect(
        tester.getRect(find.byType(Brief)).bottom,
        lessThanOrEqualTo(tester.getRect(boxOf(onPage('REPEAT'))).top),
      );
    });

    testWidgets('and it scrolls away with the program', (tester) async {
      await boot(tester, brief: brief);
      final before = tester.getRect(find.byType(Brief)).top;

      await tester.drag(find.byType(ProgramEditor), const Offset(0, -120));
      await tester.pumpAndSettle();

      // Not the full 120: touch slop is spent before the scroll starts.
      expect(tester.getRect(find.byType(Brief)).top, lessThan(before - 80));
    });

    testWidgets('it is set as prose, not on the row pitch', (tester) async {
      await boot(tester, brief: brief);

      // It used to be a whole number of 36dp rows, because each line had to
      // fill a ruled row and land on the rule under it. That is what made it
      // airy: a 17pt line in a 36pt box is nearly double-spaced. The ruling is
      // gone and so is the constraint - what is checked now is the opposite,
      // that a line takes the room the text needs and no more.
      final line = Paper.briefSize * Paper.briefLine;
      expect(line, lessThan(Paper.rowHeight));

      final height = tester.getRect(find.byType(Brief)).height;
      final written = height - Paper.briefGap - Paper.briefTop;
      expect(
        written / line,
        closeTo((written / line).roundToDouble(), 0.02),
        reason: 'written block is $written tall, not a whole number of lines',
      );
    });

    testWidgets('it has the same air above it as below it', (tester) async {
      await boot(tester, brief: brief);

      // Measured on screen rather than against the tokens, because the two
      // sides are built by different widgets: above is one box inside the
      // brief, below is the brief's own trailing box *plus* the first gap of
      // the program, which belongs to the editor. They only meet as whitespace.
      final box = tester.getRect(find.byType(Brief));
      final lines = find.descendant(
        of: find.byType(Brief),
        matching: find.byType(Text),
      );
      final above = tester.getRect(lines.first).top - box.top;
      final below =
          tester.getRect(boxOf(onPage('REPEAT'))).top -
          tester.getRect(lines.last).bottom;

      expect(above, closeTo(below, 0.5), reason: 'above $above, below $below');
    });

    testWidgets('it is writing, not a row: nothing can be done to it', (
      tester,
    ) async {
      await boot(tester, brief: brief);
      final written = find.byType(Brief);

      for (final gesture in <Type>[
        Dismissible,
        LongPressDraggable<DragPayload>,
        DragTarget<DragPayload>,
      ]) {
        expect(
          find.ancestor(of: written, matching: find.byType(gesture)),
          findsNothing,
          reason: '$gesture wraps the brief',
        );
      }
    });
  });

  group('text scales to 200% without clipping', () {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('at x$scale', (tester) async {
        await boot(tester, textScale: scale);

        final word = tester.getRect(onPage('TAKE'));
        final row = tester.getRect(boxOf(onPage('TAKE')));

        expect(row.height, greaterThanOrEqualTo(word.height));
        expect(row.top, lessThanOrEqualTo(word.top));
        expect(row.bottom, greaterThanOrEqualTo(word.bottom));
        expect(tester.takeException(), isNull);
      });
    }
  });
}
