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
import 'package:gameplay_ux/ui/notebook/fold.dart';
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
    harness(
      textScale: textScale,
      brief: brief,
      level: level,
      program: program,
    ),
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
Finder boxOf(Finder label) =>
    find.ancestor(of: label, matching: find.byType(DecoratedBox)).first;

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

    testWidgets('no row moves when a run starts or stops', (tester) async {
      await boot(tester);
      final before = tester.getRect(boxOf(onPage('TAKE')));

      await run(tester);
      expect(tester.getRect(boxOf(onPage('TAKE'))), before);

      await tester.tap(find.text('STOP'));
      await tester.pumpAndSettle();
      expect(tester.getRect(boxOf(onPage('TAKE'))), before);
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
      final note = tester.getRect(find.byType(CommandNote));

      final gesture = await tester.startGesture(
        tester.getCenter(onNote('SUB')),
      );
      await tester.pump(const Duration(milliseconds: 40));
      await gesture.moveBy(const Offset(0, -30));
      await tester.pump();
      // Above the note: the bottom of the page is behind it.
      await gesture.moveTo(Offset(page.center.dx, note.top - 20));
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

      expect(find.text('Drag a command up from below.'), findsOneWidget);
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
      expect(find.text('Drag a command up from below.'), findsNothing);
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

  group('11 and 12. paper: where the glue is, and where the edges are', () {
    testWidgets('a command ends on the page, a container runs to it', (
      tester,
    ) async {
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

    testWidgets('a container is glued at the top, a command at the left', (
      tester,
    ) async {
      await boot(tester);

      BoxShadow shadowOf(String word) {
        final box = tester.widget<DecoratedBox>(boxOf(onPage(word)));
        return (box.decoration as BoxDecoration).boxShadow!.single;
      }

      // The glued edge casts nothing. That is the whole grammar.
      expect(shadowOf('REPEAT').offset.dx, 0, reason: 'note: falls downwards');
      expect(shadowOf('REPEAT').offset.dy, greaterThan(0));
      expect(shadowOf('TAKE').offset.dx, greaterThan(0), reason: 'tab: right');

      // Negative spread, or the blur bleeds back over the glued edge.
      expect(shadowOf('REPEAT').spreadRadius, lessThan(0));
      expect(shadowOf('TAKE').spreadRadius, lessThan(0));
    });

    testWidgets('the program starts right of the margin line', (tester) async {
      await boot(tester);
      final page = tester.getRect(find.byType(ProgramEditor));
      final block = tester.getRect(boxOf(onPage('REPEAT')));

      expect(
        block.left - page.left,
        greaterThan(Paper.marginInset),
        reason: 'nothing is written over the margin',
      );
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
      final before = {for (final r in rows) r: tester.getRect(boxOf(onPage(r)))};

      // Every row, not one of them: the stand-in marks a random line, and an
      // outline that reserved space would only shift the program on the runs
      // that happened to pick a row above the one being watched.
      await run(tester);
      for (final r in rows) {
        expect(tester.getRect(boxOf(onPage(r))), before[r], reason: r);
      }

      final outlined = tester
          .widgetList<StuckPaper>(find.byType(StuckPaper))
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

    testWidgets('it scrolls the running line to the middle', (tester) async {
      await boot(tester, level: longLevel(), program: longProgram());

      // Long enough to be a dozen or so rows in, where the row would be well
      // off the bottom of the page if nothing had scrolled. Every TAKE here
      // costs one pickup and no walk - the unit never leaves the chute after
      // the first instruction - so this is comfortably mid-program.
      await runFor(tester, const Duration(seconds: 12));

      final page = pageOf(tester);
      final caret = tester.getRect(find.byType(CaretGutter));
      expect(
        caret.center.dy,
        closeTo(page.center.dy, Paper.rowHeight),
        reason: 'the running line drifted off centre',
      );
    });

    testWidgets('and does not fight the top of the page', (tester) async {
      // The first line cannot be centred - there is nothing above it to scroll
      // in - so the page must stay put rather than pulling the program down.
      await boot(tester, level: longLevel(), program: longProgram());
      final before = tester.getRect(boxOf(onPage('TAKE').first));

      await runFor(tester, Duration.zero);

      expect(tester.getRect(boxOf(onPage('TAKE').first)), before);
      expect(
        tester.getRect(find.byType(CaretGutter)).center.dy,
        lessThan(pageOf(tester).center.dy),
        reason: 'clamped above centre, which is the honest answer here',
      );
    });
  });

  group('the brief is written on the page, not pinned above it', () {
    // Deliberately short: see [testBrief]. Two lines here so the detail is
    // exercised without wrapping in the square test font.
    const brief = LevelBrief(task: 'Ship.', detail: 'Not zero.');

    testWidgets('it is on the page, above the program', (tester) async {
      await boot(tester, brief: brief);

      expect(find.text('TASK'), findsNothing, reason: 'no card above the floor');
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

    testWidgets('it takes a whole number of ruled rows', (tester) async {
      await boot(tester, brief: brief);

      // Otherwise the written lines land between the rules instead of on
      // them, which is the tell that a page is a picture of paper rather than
      // paper. Measured on the writing alone: the drop above it and the gap
      // below it are both outside the block that has to stay on the grid.
      final height = tester.getRect(find.byType(Brief)).height;
      final written = height - Paper.handDrop - Paper.briefGap;

      // Distance to the nearest whole number of rows, not the remainder: a
      // block a hair *under* two rows has a remainder of almost a whole row,
      // which reads as maximally wrong when it is as close as floating point
      // gets to right.
      final rows = written / Paper.rowHeight;
      final off = (rows - rows.roundToDouble()).abs() * Paper.rowHeight;
      expect(
        off,
        lessThan(0.5),
        reason: 'written block is $written tall, ${off}px off the grid',
      );
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
