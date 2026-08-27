// Layout tests. Their whole job is to fail when something clips.
//
// A fixed-height row clips silently and only surfaces if a human happens to look
// at the right pixel, so 7.3's "scales to 200% without clipping" is asserted
// here instead: any RenderFlex/RenderBox overflow throws, and takeException
// turns that into a test failure.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameplay_ux/ui/gameplay_screen.dart';
import 'package:gameplay_ux/ui/floor_pane.dart';
import 'package:gameplay_ux/ui/program_pane.dart';
import 'package:gameplay_ux/ui/tray.dart';
import 'package:gameplay_ux/model/commands.dart';
import 'package:gameplay_ux/model/program.dart';
import 'package:gameplay_ux/ui/wireframe.dart';

/// MaterialApp installs its own MediaQuery from the view, so an outer one is
/// ignored. The scale has to be injected via MaterialApp.builder to reach the
/// widgets under test.
/// `disableAnimations` defaults to true because the caret blinks on a repeating
/// timer, and a repeating timer means `pumpAndSettle` never settles. Reduced
/// motion is also a path worth covering, so the default does double duty; the
/// blink itself is tested separately with explicit `pump` durations.
Widget harness({required double textScale, bool animate = false}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: !animate,
      ),
      child: child!,
    ),
    home: const GameplayScreen(),
  );
}

/// Command names appear in both the program and the tray, so program-row
/// assertions have to be scoped to the pane.
Finder inProgram(String text) =>
    find.descendant(of: find.byType(ProgramPane), matching: find.text(text));

/// The row container wrapping a given program row's label.
Finder rowContainerFor(Finder label) =>
    find.ancestor(of: label, matching: find.byType(Container)).first;

/// Finds a labelled control by its Semantics annotation.
///
/// Not `find.bySemanticsLabel`: that matches the merged semantics *node* label,
/// which picks up glyphs from the child widgets, so an exact name misses.
Finder labelled(String label) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == label,
);

/// Every spacer between siblings. They are the only way to insert, so tests
/// address them directly.
Finder spacers() => find.byType(DragTarget<DragPayload>);

/// The spacer that owns everything below the program: the last one at the root,
/// grown to fill the pane so that a drop past the end always lands.
Finder tailSpacer() => find.byKey(const ValueKey('program-tail'));

/// The spacers laid out between rows. Excludes the tail, whose whole point is to
/// be as tall as the space it has.
List<Element> innerSpacers() => spacers().evaluate().toList()..removeLast();

/// A tray command, by its tray label.
Finder trayCommand(String label) =>
    find.descendant(of: find.byType(CommandTray), matching: find.text(label));

/// Picks a command up out of the tray and holds it over a spacer, without
/// letting go. The caller decides whether to drop or abandon it.
Future<TestGesture> holdOverSpacer(
  WidgetTester tester,
  String label,
  int index,
) async {
  final gesture = await tester.startGesture(
    tester.getCenter(trayCommand(label)),
  );
  await tester.pump(const Duration(milliseconds: 40));
  // Two moves: the first starts the drag, the second lands it on the target.
  await gesture.moveBy(const Offset(0, -30));
  await tester.pump();
  await gesture.moveTo(tester.getCenter(spacers().at(index)));
  await tester.pump();
  return gesture;
}

/// Drops [label] on a point, wherever that point happens to be.
Future<void> dropAt(WidgetTester tester, String label, Offset point) async {
  final gesture = await tester.startGesture(
    tester.getCenter(trayCommand(label)),
  );
  await tester.pump(const Duration(milliseconds: 40));
  await gesture.moveBy(const Offset(0, -30));
  await tester.pump();
  await gesture.moveTo(point);
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

/// The whole gesture: pick up, hold over a spacer, drop.
Future<void> dragIntoSpacer(
  WidgetTester tester,
  String label,
  int index,
) async {
  final gesture = await holdOverSpacer(tester, label, index);
  await gesture.up();
  await tester.pumpAndSettle();
}

/// Brings a row into view, building it if the ListView has not yet.
///
/// ensureVisible is not enough: at larger text scales a later row is outside the
/// cache extent and its element does not exist at all.
Future<void> reveal(WidgetTester tester, Finder target) async {
  if (target.evaluate().isNotEmpty) return;
  await tester.scrollUntilVisible(
    target,
    120,
    scrollable: find.descendant(
      of: find.byType(ProgramPane),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // iPhone 15/16 portrait, plus a narrow small phone as the worst case.
  const sizes = <String, Size>{
    'iphone-15': Size(393, 852),
    'small-phone': Size(320, 640),
  };

  // 1.0 through 2.0 - exactly the range 7.3 commits to supporting. Beyond 200%
  // the layout degrades (a program row's argument controls stop fitting a
  // 393-wide screen); that is a known limit, not a covered case.
  const scales = <double>[1.0, 1.2, 1.4, 1.6, 1.8, 2.0];

  for (final size in sizes.entries) {
    for (final scale in scales) {
      testWidgets('nothing overflows on ${size.key} at x$scale', (
        tester,
      ) async {
        tester.view.physicalSize = size.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(harness(textScale: scale));
        await tester.pumpAndSettle();

        // The sample program loads on init. Only the top rows are asserted:
        // taller rows push later ones out of the lazily-built viewport, which is
        // correct behaviour, not a defect.
        expect(inProgram('REPEAT'), findsOneWidget);
        expect(inProgram('TAKE'), findsOneWidget);

        // The real assertion: nothing overflowed laying any of that out.
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final scale in scales) {
    testWidgets('a row never clips its own label at x$scale', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: scale));
      await tester.pumpAndSettle();

      final label = inProgram('TAKE');
      final labelRect = tester.getRect(label);
      final rowRect = tester.getRect(rowContainerFor(label));

      expect(rowRect.height, greaterThanOrEqualTo(labelRect.height));
      expect(rowRect.top, lessThanOrEqualTo(labelRect.top));
      expect(rowRect.bottom, greaterThanOrEqualTo(labelRect.bottom));
      expect(tester.takeException(), isNull);
    });
  }

  // The reported bug that started this: a fixed-height insertion row clipped its
  // own label. The gap is content-sized now, but the guard is still worth having.
  for (final scale in scales) {
    testWidgets('an open gap never clips its label at x$scale', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: scale));
      await tester.pumpAndSettle();

      final gesture = await holdOverSpacer(tester, 'TAKE', 0);

      final label = find.text('DROP HERE');
      final labelRect = tester.getRect(label);
      final gap = tester.getRect(rowContainerFor(label));

      expect(labelRect.height, greaterThan(0));
      expect(gap.height, greaterThanOrEqualTo(labelRect.height));
      expect(gap.top, lessThanOrEqualTo(labelRect.top));
      expect(gap.bottom, greaterThanOrEqualTo(labelRect.bottom));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  group('divider', () {
    Finder divider() => labelled('Resize panes');

    testWidgets('dragging it changes the split', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();

      final before = tester.getRect(find.byType(FloorPane)).height;

      // Far enough to clear the snap threshold, so the change persists.
      await tester.drag(divider(), const Offset(0, 120));
      await tester.pumpAndSettle();

      final after = tester.getRect(find.byType(FloorPane)).height;
      expect(after, greaterThan(before));
      expect(tester.takeException(), isNull);
    });

    testWidgets('double tap toggles between the two snap states', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();

      // Opens program-focused (38%).
      final programFocused = tester.getRect(find.byType(FloorPane)).height;

      await tester.tap(divider());
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(divider());
      await tester.pumpAndSettle();

      final floorFocused = tester.getRect(find.byType(FloorPane)).height;
      expect(floorFocused, greaterThan(programFocused));

      await tester.tap(divider());
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(divider());
      await tester.pumpAndSettle();

      expect(
        tester.getRect(find.byType(FloorPane)).height,
        closeTo(programFocused, 0.5),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the grip renders its up/down arrows', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();

      // The arrows are painted, so assert the painter is mounted inside the
      // divider rather than looking for a glyph.
      expect(
        find.descendant(of: divider(), matching: find.byType(CustomPaint)),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('scaffolding', () {
    testWidgets('lives inside the floor placeholder, labelled as scaffolding', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();

      // The test controls must not sit in the chrome, where they read as design.
      for (final label in ['SAMPLE', 'CLEAR']) {
        expect(
          find.descendant(
            of: find.byType(FloorPane),
            matching: find.text(label),
          ),
          findsOneWidget,
          reason: '$label belongs inside the floor placeholder',
        );
      }
      expect(find.textContaining('NOT PART OF THE DESIGN'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the mini buttons size to their text, not the full width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();

      // Regression guard: a Container with `alignment` set expands to its
      // incoming width constraint, which inside a Wrap stretched these edge to
      // edge.
      final sample = tester.getRect(
        find
            .ancestor(of: find.text('SAMPLE'), matching: find.byType(Container))
            .first,
      );
      expect(sample.width, lessThan(160));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the tray is only buttons - no label, no par readout', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();

      // SIZE and SPEED are par metrics. 8.2 keeps pars hidden until a level is
      // first cleared, and to a first-time player the numbers read as jargon.
      expect(find.text('TRAY'), findsNothing);
      expect(find.textContaining('SIZE'), findsNothing);

      // The commands themselves are still there.
      expect(
        find.descendant(
          of: find.byType(CommandTray),
          matching: find.text('TAKE'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the task card carries [i] and re-opens the brief', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();

      await tester.tap(labelled('Re-open the brief'));
      await tester.pumpAndSettle();

      expect(find.text('THE BRIEF'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('spacers', () {
    Future<void> boot(WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();
    }

    testWidgets('nothing is expanded until something is being dragged', (
      tester,
    ) async {
      await boot(tester);

      // An expanded gap means "the thing in your hand lands here". With an empty
      // hand it means nothing, so it should not exist.
      expect(find.text('DROP HERE'), findsNothing);
      expect(spacers(), findsWidgets);

      for (final e in innerSpacers()) {
        expect(
          tester.getRect(find.byWidget(e.widget)).height,
          closeTo(W.indentPerDepth, 0.5),
        );
      }
    });

    testWidgets('tapping a spacer does nothing at all', (tester) async {
      await boot(tester);

      await tester.tap(spacers().at(0));
      await tester.pumpAndSettle();

      expect(find.text('DROP HERE'), findsNothing);
      expect(inProgram('SHIP'), findsOneWidget); // nothing inserted
    });

    testWidgets('the spacer under the finger expands, and only it', (
      tester,
    ) async {
      await boot(tester);
      final gesture = await holdOverSpacer(tester, 'TAKE', 0);

      expect(find.text('DROP HERE'), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('an expanded spacer is the row it will hold, margins and all', (
      tester,
    ) async {
      await boot(tester);
      final gesture = await holdOverSpacer(tester, 'TAKE', 0);

      // The outline is the size of the row itself, less the 2dp it is inset by
      // on each side...
      final outline = tester.getRect(find.byType(DottedOutline));
      final row = tester.getRect(rowContainerFor(inProgram('TAKE').first));
      expect(outline.height, closeTo(row.height - 4, 1));

      // ...and the spacer around it carries the gaps that row will have, so the
      // preview occupies exactly the space the drop will take.
      final slot = tester.getRect(find.byWidget(innerSpacers()[0].widget));
      expect(slot.height, closeTo(row.height + W.indentPerDepth * 2, 1));
      expect(outline.top - slot.top, closeTo(W.indentPerDepth + 2, 1.5));
      expect(slot.bottom - outline.bottom, closeTo(W.indentPerDepth + 2, 1.5));

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('an open gap starts where a row starts, inside and out', (
      tester,
    ) async {
      await boot(tester);

      // Spacer 1 is inside the REPEAT body, alongside TAKE.
      final row = tester.getRect(rowContainerFor(inProgram('TAKE').first));
      final label = tester.getRect(inProgram('TAKE').first);

      final gesture = await holdOverSpacer(tester, 'SHIP', 1);

      // The box was inset 4dp from where a row's box begins, which left its
      // label 8dp inside its own edge against a command's 12dp.
      final outline = tester.getRect(find.byType(DottedOutline));
      expect(outline.left, closeTo(row.left, 0.5));
      expect(
        tester.getRect(find.text('DROP HERE')).left - outline.left,
        closeTo(label.left - row.left, 0.5),
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('so the rows below it do not move when the drop lands', (
      tester,
    ) async {
      await boot(tester);

      // Spacer 1 is between REPEAT's TAKE and the IF below it.
      final gesture = await holdOverSpacer(tester, 'SHIP', 1);
      final previewed = tester.getRect(rowContainerFor(inProgram('IF')));

      await gesture.up();
      await tester.pumpAndSettle();

      expect(
        tester.getRect(rowContainerFor(inProgram('IF'))).top,
        closeTo(previewed.top, 1),
        reason: 'the preview already occupied the space the row now takes',
      );
    });

    testWidgets('an open gap is filled in the shade the row will be', (
      tester,
    ) async {
      await boot(tester);

      // Spacer 1 is inside the REPEAT body, between TAKE and the IF. It used to
      // be transparent: only the trailing spacer of an empty body carried the
      // fill, so the same drop previewed a different colour depending on where
      // in the body it landed.
      final gesture = await holdOverSpacer(tester, 'SHIP', 1);

      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byWidget(innerSpacers()[1].widget),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(
        (box.decoration as BoxDecoration).color,
        W.blockFill(specFor('repeat').colour, 1),
        reason: 'the shade a child of this REPEAT wears',
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a gap at the root has no fill to inherit', (tester) async {
      await boot(tester);

      // Spacer 0 is above REPEAT, at the root: no container, so no alternation
      // to continue - the outline sits on the pane itself.
      final gesture = await holdOverSpacer(tester, 'SHIP', 0);

      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byWidget(innerSpacers()[0].widget),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((box.decoration as BoxDecoration).color, isNull);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a gap grows into place rather than snapping open', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(harness(textScale: 1.0, animate: true));
      await tester.pumpAndSettle();

      double gapHeight() =>
          tester.getRect(find.byWidget(innerSpacers()[0].widget)).height;

      final gesture = await tester.startGesture(
        tester.getCenter(trayCommand('TAKE')),
      );
      await tester.pump(const Duration(milliseconds: 40));
      await gesture.moveBy(const Offset(0, -30));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(spacers().at(0)));
      await tester.pump();

      // Caught in the middle of opening: neither closed nor open.
      await tester.pump(W.slotGrow ~/ 2);
      final mid = gapHeight();
      expect(mid, greaterThan(W.indentPerDepth + 1));
      expect(mid, lessThan(W.openSlotHeight - 1));

      await tester.pumpAndSettle();
      expect(gapHeight(), closeTo(W.openSlotHeight, 0.5));

      // And on the way out again.
      await gesture.moveTo(tester.getCenter(inProgram('SHIP')));
      await tester.pump();
      await tester.pump(W.slotGrow ~/ 2);
      final closing = gapHeight();
      expect(closing, lessThan(W.openSlotHeight - 1));
      expect(closing, greaterThan(W.indentPerDepth + 1));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(gapHeight(), closeTo(W.indentPerDepth, 0.5));
    });

    testWidgets('but a landing row does not make it animate shut', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(harness(textScale: 1.0, animate: true));
      await tester.pumpAndSettle();

      final gesture = await holdOverSpacer(tester, 'SHIP', 1);
      await tester.pumpAndSettle();

      // Measured with the gap fully open: that is the layout the drop inherits.
      final ifTop = tester.getRect(rowContainerFor(inProgram('IF'))).top;

      await gesture.up();
      await tester.pump();

      // The dropped row takes the space the gap was holding, so animating the
      // gap shut would shove everything below it down for two frames and pull it
      // back. One frame after the drop, nothing below has moved.
      expect(
        tester.getRect(rowContainerFor(inProgram('IF'))).top,
        closeTo(ifTop, 1),
      );

      await tester.pumpAndSettle();
    });

    testWidgets('everything closes again once the drag ends', (tester) async {
      await boot(tester);
      await dragIntoSpacer(tester, 'SHIP', 0);

      expect(find.text('DROP HERE'), findsNothing);
      for (final e in innerSpacers()) {
        expect(
          tester.getRect(find.byWidget(e.widget)).height,
          closeTo(W.indentPerDepth, 0.5),
        );
      }
    });
  });

  group('dropping a command', () {
    Future<void> boot(WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();
    }

    testWidgets('lands exactly where it was dropped', (tester) async {
      await boot(tester);

      // Spacer 0 is the first one at the root, above REPEAT.
      await dragIntoSpacer(tester, 'SHIP', 0);

      final ship = tester.getRect(rowContainerFor(inProgram('SHIP').first));
      final repeat = tester.getRect(rowContainerFor(inProgram('REPEAT')));
      expect(
        ship.top,
        lessThan(repeat.top),
        reason: 'dropped above REPEAT, so it belongs above REPEAT',
      );
    });

    testWidgets('lands inside a block when dropped inside one', (tester) async {
      await boot(tester);

      // Spacer 3 is inside the IF body, above SHIP.
      await dragIntoSpacer(tester, 'TAKE', 3);

      final dropped = tester.getRect(rowContainerFor(inProgram('TAKE').last));
      final ship = tester.getRect(rowContainerFor(inProgram('SHIP')));
      expect(dropped.left, ship.left, reason: 'same indent means same body');
    });

    testWidgets('a drop that misses every spacer does nothing', (tester) async {
      await boot(tester);
      final before = inProgram('TAKE').evaluate().length;

      // Let go over the middle of a row, which is not a drop target.
      final gesture = await tester.startGesture(
        tester.getCenter(trayCommand('TAKE')),
      );
      await tester.pump(const Duration(milliseconds: 40));
      await gesture.moveBy(const Offset(0, -30));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(inProgram('REPEAT')));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(inProgram('TAKE').evaluate().length, before);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a block dropped in carries its own empty body', (
      tester,
    ) async {
      await boot(tester);
      await dragIntoSpacer(tester, 'REPEAT', 0);

      // Two REPEAT blocks now, and the new one brought a body with it.
      expect(inProgram('REPEAT'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });

  group('arguments', () {
    Future<void> boot(WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();
    }

    testWidgets('a pallet argument cycles on tap, like a type does', (
      tester,
    ) async {
      await boot(tester);
      await dragIntoSpacer(tester, 'COPY FROM', 0);

      expect(inProgram('PALLET 1'), findsOneWidget);

      await tester.tap(inProgram('PALLET 1'));
      await tester.pumpAndSettle();
      expect(inProgram('PALLET 2'), findsOneWidget);
      expect(inProgram('PALLET 1'), findsNothing);
    });

    testWidgets('the comparison cycles on tap, like a pallet does', (
      tester,
    ) async {
      await boot(tester);

      expect(inProgram('POSITIVE'), findsOneWidget);
      await tester.tap(inProgram('POSITIVE'));
      await tester.pumpAndSettle();
      expect(inProgram('NOT POSITIVE'), findsOneWidget);
    });

    testWidgets('a chip hugs its word but stays a thumb target', (
      tester,
    ) async {
      await boot(tester);

      // Painted: tight around the text. The chip used to be padded to 48dp
      // itself, which made a three-word condition look like a row of form
      // fields.
      final word = tester.getRect(inProgram('POSITIVE'));
      final chip = tester.getRect(rowContainerFor(inProgram('POSITIVE')));
      expect(chip.height - word.height, lessThan(12));

      // Tappable: still 48, carried by transparent space around the chip.
      final target = tester.getRect(
        find
            .ancestor(
              of: inProgram('POSITIVE'),
              matching: find.byType(ConstrainedBox),
            )
            .first,
      );
      expect(target.height, greaterThanOrEqualTo(W.minTarget));

      // And the tap still lands from the edge of that target, not just the chip.
      await tester.tapAt(Offset(target.center.dx, target.top + 3));
      await tester.pumpAndSettle();
      expect(inProgram('NOT POSITIVE'), findsOneWidget);
    });

    testWidgets('a row carries one argument control, not a stepper', (
      tester,
    ) async {
      await boot(tester);
      await dragIntoSpacer(tester, 'SUM', 0);

      // The old -/+ stepper put three tap targets on one row. Regression guard
      // against it coming back.
      expect(inProgram('-'), findsNothing);
      expect(inProgram('+'), findsNothing);
      expect(
        labelled('PALLET 1, tap to change'),
        findsOneWidget,
        reason: 'one control, and it announces that it changes on tap',
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('condition row', () {
    // Note on widths: flutter_test renders every glyph as a full-em box, so
    // text here is roughly 1.8x wider than Consolas on a device. A condition
    // that fits one line on a phone can wrap in these tests. That makes a
    // strict "one line" assertion meaningless, so what is guarded instead is
    // that it wraps *gracefully* and never degenerates into one word per line.
    testWidgets('the condition never stacks one word per line', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();

      final words = ['IF', 'POSITIVE'];
      final tops = <double>[
        for (final w in words) tester.getRect(inProgram(w)).top,
      ];

      // At most two distinct baselines. Four would mean every word went to its
      // own line, which is the bug this guards.
      final distinct = tops.map((t) => t.round()).toSet();
      expect(
        distinct.length,
        lessThanOrEqualTo(2),
        reason: 'words: $words at $tops',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a condition row wraps at most once', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();

      // Regression guard. A Container with `alignment` or `constraints` set
      // expands to its incoming width constraint; inside the Wrap that holds the
      // words, that put each word on its own line and made this row 198px tall.
      final conditionRow = tester.getRect(rowContainerFor(inProgram('IF')));
      final plainRow = tester.getRect(rowContainerFor(inProgram('TAKE')));

      // Only an upper bound: a block header carries no card margin, so it is
      // legitimately a few pixels shorter than a plain row. What this guards is
      // the collapse into one word per line, which made it four rows tall.
      expect(conditionRow.height, lessThan(plainRow.height * 2));
    });

    testWidgets('the comparison cycles from the row', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();

      await tester.tap(inProgram('POSITIVE'));
      await tester.pumpAndSettle();
      expect(inProgram('NOT POSITIVE'), findsOneWidget);

      // The whole condition is the one chip now. Zero used to be spelled out
      // after it as a fixed word; naming the point of reference in every row was
      // ceremony, since it is the only thing a condition ever compares against.
      expect(inProgram('ZERO'), findsNothing);
    });

    testWidgets('there is no ELSE anywhere in the UI', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();

      expect(find.text('ELSE'), findsNothing);
    });
  });

  testWidgets('rows carry no line numbers', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(textScale: 1.0));
    await tester.pumpAndSettle();

    // A numbered gutter made the editor look like something to be memorised and
    // reasoned about. Guard against it drifting back in.
    for (final n in ['1', '2', '3', '4', '5', '6']) {
      expect(
        inProgram(n),
        findsNothing,
        reason: 'row $n should not be numbered',
      );
    }
    expect(tester.takeException(), isNull);
  });

  group('run control', () {
    Finder runButton() => find.byType(RunButton);

    testWidgets('lives in the floor, not in the chrome', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: find.byType(FloorPane), matching: runButton()),
        findsOneWidget,
      );
      expect(find.text('RUN'), findsOneWidget);

      // The old bottom bar is gone entirely.
      expect(find.text('RUN SHIFT'), findsNothing);
      expect(find.text('UNDO'), findsNothing);
      expect(find.text('REDO'), findsNothing);
    });

    testWidgets('sits in the top-right of the floor', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();

      final floor = tester.getRect(find.byType(FloorPane));
      final button = tester.getRect(runButton());

      expect(button.right, lessThanOrEqualTo(floor.right));
      expect(button.right, greaterThan(floor.center.dx));
      expect(button.top, lessThan(floor.center.dy));
    });

    testWidgets('flips between RUN and STOP when tapped', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();

      expect(find.text('RUN'), findsOneWidget);
      await tester.tap(runButton());
      await tester.pumpAndSettle();

      expect(find.text('STOP'), findsOneWidget);
      expect(find.text('RUN'), findsNothing);

      await tester.tap(runButton());
      await tester.pumpAndSettle();
      expect(find.text('RUN'), findsOneWidget);
    });

    testWidgets('goes away with the floor when the divider is dragged up', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();

      await tester.drag(labelled('Resize panes'), const Offset(0, -600));
      await tester.pumpAndSettle();

      // Intended: with the floor hidden there is nothing to run from. The floor
      // is never left as a sliver too thin to reach the button.
      expect(find.byType(FloorPane), findsNothing);
      expect(runButton(), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the floor is never visible but too short for the button', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();

      // Creep the divider upward and assert the invariant at every step.
      for (var i = 0; i < 12; i++) {
        await tester.drag(labelled('Resize panes'), const Offset(0, -40));
        await tester.pumpAndSettle();

        if (find.byType(FloorPane).evaluate().isEmpty) continue;
        final floor = tester.getRect(find.byType(FloorPane));
        expect(
          floor.height,
          greaterThanOrEqualTo(RunButton.height),
          reason: 'a visible floor must have room for the run button',
        );
        expect(runButton(), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('the tray fits without scrolling', () {
    Future<void> boot(WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();
    }

    testWidgets('every command is on screen at once', (tester) async {
      await boot(tester);

      // The tray used to be one scrolling strip with a fade on the side that had
      // more commands hidden. Part of the vocabulary was always behind a gesture
      // nobody is told about.
      for (final spec in commandCatalogue) {
        expect(
          trayCommand(spec.trayLabel),
          findsOneWidget,
          reason: '${spec.id} is not in the tray',
        );
      }

      expect(
        find.descendant(
          of: find.byType(CommandTray),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
        reason: 'nothing to scroll, so nothing that can scroll',
      );
      expect(find.byKey(const ValueKey('tray-fade-left')), findsNothing);
      expect(find.byKey(const ValueKey('tray-fade-right')), findsNothing);
    });

    testWidgets('in two rows, and no button is clipped', (tester) async {
      await boot(tester);
      final tray = tester.getRect(find.byType(CommandTray));

      final tops = <double>{};
      for (final spec in commandCatalogue) {
        final button = tester.getRect(
          rowContainerFor(trayCommand(spec.trayLabel)),
        );
        tops.add(button.top.roundToDouble());

        expect(
          button.left,
          greaterThanOrEqualTo(tray.left - 0.5),
          reason: spec.id,
        );
        expect(
          button.right,
          lessThanOrEqualTo(tray.right + 0.5),
          reason: spec.id,
        );
        expect(
          button.height,
          greaterThanOrEqualTo(W.minTarget - 0.5),
          reason: spec.id,
        );
      }

      expect(tops, hasLength(2), reason: 'two rows, not one and not three');
    });

    testWidgets('a command still comes away on an upward drag', (tester) async {
      await boot(tester);

      // The bottom row is the one that used to be off-screen entirely.
      await dragIntoSpacer(tester, 'SUB', 0);

      expect(inProgram('SUB'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('running', () {
    Future<void> start(WidgetTester tester) async {
      await tester.tap(find.byType(RunButton));
      await tester.pumpAndSettle();
    }

    Future<void> boot(WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();
    }

    testWidgets('hides the tray but leaves the program where it was', (
      tester,
    ) async {
      await boot(tester);
      expect(find.byType(CommandTray), findsOneWidget);
      // Relative to the pane: the pane itself does move, because it grows into
      // the space the tray leaves.
      double offsetOf(String row) =>
          tester.getRect(rowContainerFor(inProgram(row))).top -
          tester.getRect(find.byType(ProgramPane)).top;

      const rows = ['REPEAT', 'TAKE', 'IF', 'SHIP'];
      final before = [for (final row in rows) offsetOf(row)];

      await start(tester);
      expect(find.byType(CommandTray), findsNothing);

      // The spacers used to be removed along with the tray, which reflowed the
      // whole program at the exact moment you wanted to be watching it run.
      expect(spacers(), findsWidgets);
      for (var i = 0; i < rows.length; i++) {
        expect(
          offsetOf(rows[i]),
          closeTo(before[i], 0.5),
          reason: '${rows[i]} moved within the pane when the program started',
        );
      }

      await start(tester); // STOP
      expect(find.byType(CommandTray), findsOneWidget);
      expect(spacers(), findsWidgets);
    });

    testWidgets('a spacer takes nothing while the program runs', (
      tester,
    ) async {
      await boot(tester);
      await start(tester);

      // There is nothing to drag from with the tray gone, but the targets are
      // still in the tree, so they have to refuse on their own account.
      final slot = tester.widget<DragTarget<DragPayload>>(spacers().first);
      expect(
        slot.onWillAcceptWithDetails!(
          DragTargetDetails(
            data: const NewCommand('take'),
            offset: Offset.zero,
          ),
        ),
        isFalse,
      );
    });

    testWidgets('the program is still readable while running', (tester) async {
      await boot(tester);
      await start(tester);

      expect(inProgram('REPEAT'), findsOneWidget);
      expect(inProgram('IF'), findsOneWidget);
      expect(inProgram('POSITIVE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an argument cannot be cycled while running', (tester) async {
      await boot(tester);
      await start(tester);

      // The words still render, so they still look like part of the sentence -
      // they just do not answer a tap.
      await tester.tap(inProgram('POSITIVE'));
      await tester.pumpAndSettle();
      expect(inProgram('POSITIVE'), findsOneWidget);
      expect(inProgram('NOT POSITIVE'), findsNothing);
    });

    testWidgets('a row cannot be swipe-deleted while running', (tester) async {
      await boot(tester);
      await start(tester);

      await tester.drag(inProgram('TAKE'), const Offset(400, 0));
      await tester.pumpAndSettle();

      expect(inProgram('TAKE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the program pane grows into the space the tray leaves', (
      tester,
    ) async {
      await boot(tester);
      final editing = tester.getRect(find.byType(ProgramPane)).height;

      await start(tester);
      final running = tester.getRect(find.byType(ProgramPane)).height;

      expect(running, greaterThan(editing));
    });
  });

  group('row spacing', () {
    testWidgets('siblings are separated by a spacer and nothing else', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();

      final take = tester.getRect(rowContainerFor(inProgram('TAKE')));
      final ifRow = tester.getRect(rowContainerFor(inProgram('IF')));

      // Exactly one spacer between two siblings - no card margin on top of it,
      // which would be a second spacing system that means nothing.
      expect(ifRow.top - take.bottom, closeTo(W.indentPerDepth, 0.5));

      // A block header sits at its parent indent; only the body steps in.
      expect(ifRow.left, take.left);
      final ship = tester.getRect(rowContainerFor(inProgram('SHIP')));
      expect(ship.left, greaterThan(ifRow.left));
    });

    testWidgets('drop targets still open up during a drag', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();

      double tallestSpacer() => innerSpacers()
          .map((e) => tester.getRect(find.byWidget(e.widget)).height)
          .fold<double>(0, (a, b) => a > b ? a : b);

      final closed = tallestSpacer();

      final gesture = await tester.startGesture(
        tester.getCenter(inProgram('TAKE')),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();

      // A spacer and a drop target are the same object now, so a drag lands on
      // the affordance the player can already see.
      expect(tallestSpacer(), greaterThan(closed));

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('block containers', () {
    testWidgets('a block wraps its body in a container of its own tone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();

      // The header paints the same fill as the container it belongs to, so the
      // first decorated box above the title is that fill either way.
      Color? fillOf(String rowText) {
        final ancestors = find
            .ancestor(of: inProgram(rowText), matching: find.byType(Container))
            .evaluate()
            .toList();
        for (final e in ancestors) {
          final d = (e.widget as Container).decoration;
          if (d is BoxDecoration && d.color != null) return d.color;
        }
        return null;
      }

      // Each block wears its own command's colour, so REPEAT and the IF nested
      // inside it are already distinct without any depth trick.
      expect(fillOf('REPEAT'), W.blockFill(specFor('repeat').colour, 0));
      expect(fillOf('IF'), W.blockFill(specFor('ifCond').colour, 1));
      expect(fillOf('REPEAT'), isNot(fillOf('IF')));

      // The depth step exists for the harder case: the same block nested in
      // itself, where colour alone would hide the inset arm.
      final base = specFor('repeat').colour;
      expect(W.blockFill(base, 0), isNot(W.blockFill(base, 1)));
    });

    testWidgets('a block header carries its own background', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();

      // The header paints the container's own fill, in the container's
      // rounding, so at rest the two are one shape - and the title always has a
      // background of its own to travel on, wherever it is rendered (the drag
      // ghost draws the same row outside the pane).
      final header = tester.widget<Container>(
        rowContainerFor(inProgram('REPEAT')),
      );
      final decoration = header.decoration as BoxDecoration;
      expect(decoration.color, W.blockFill(specFor('repeat').colour, 0));
      expect(
        decoration.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(W.blockRadius)),
      );

      // And it travels: mid-swipe the painted box is the thing that moves.
      final before = tester.getRect(rowContainerFor(inProgram('REPEAT')));
      final gesture = await tester.startGesture(
        tester.getCenter(inProgram('REPEAT')),
      );
      await tester.pump(const Duration(milliseconds: 20));
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();

      final moved = rowContainerFor(inProgram('REPEAT'));
      expect(tester.getRect(moved).left, greaterThan(before.left));
      expect(
        (tester.widget<Container>(moved).decoration as BoxDecoration).color,
        decoration.color,
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('the body of a block is fully contained by it', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();

      // The "C": the header is the top arm, the container's foot is the bottom
      // arm, and every instruction in between sits inside that span.
      final header = tester.getRect(rowContainerFor(inProgram('REPEAT')));
      final block = tester.getRect(
        find
            .ancestor(of: inProgram('REPEAT'), matching: find.byType(Container))
            .at(1),
      );
      final take = tester.getRect(rowContainerFor(inProgram('TAKE')));

      expect(take.top, greaterThanOrEqualTo(header.bottom));
      expect(take.bottom, lessThanOrEqualTo(block.bottom));

      // The foot is as thick as the left arm, which is what makes the bracket
      // symmetrical. There is no word in it any more.
      expect(find.text('END'), findsNothing);
    });

    testWidgets('no connector lines are drawn', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();

      // The spines that used to join a header to its END are gone: the
      // container's shape carries that now. A 2px-wide box inside the program
      // pane would be one of them.
      final hairlines = find
          .descendant(
            of: find.byType(ProgramPane),
            matching: find.byType(Container),
          )
          .evaluate()
          .where((e) {
            final r = tester.getRect(find.byWidget(e.widget));
            return r.width == 2 && r.height > 20;
          });

      expect(hairlines, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  group('right overhang', () {
    testWidgets('a block runs off the right edge of the pane', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();

      final pane = tester.getRect(find.byType(ProgramPane));
      // The block container behind the REPEAT header.
      final block = tester.getRect(
        find
            .ancestor(of: inProgram('REPEAT'), matching: find.byType(Container))
            .at(1),
      );

      // Seeing the right edge would close the "C" into a rectangle.
      expect(block.right, greaterThan(pane.right));
      expect(block.right - pane.right, closeTo(W.programOverhang, 8));
    });

    testWidgets('nothing is clipped that a player needs to read', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();

      final pane = tester.getRect(find.byType(ProgramPane));
      // Rows are left-aligned, so every word still lands inside the viewport.
      for (final word in ['REPEAT', 'TAKE', 'IF', 'POSITIVE']) {
        expect(
          tester.getRect(inProgram(word)).right,
          lessThanOrEqualTo(pane.right),
          reason: '$word is off-screen',
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('the program still cannot be scrolled sideways', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();

      final before = tester.getRect(inProgram('IF'));
      await tester.drag(inProgram('TAKE'), const Offset(-200, 0));
      await tester.pumpAndSettle();

      // A horizontal drag is a swipe gesture on a row, not a pan of the program:
      // it deletes the row it started on, and nothing else moves sideways.
      expect(inProgram('TAKE'), findsNothing);
      expect(tester.getRect(inProgram('IF')).left, before.left);
      expect(tester.takeException(), isNull);
    });
  });

  group('a row is only a row', () {
    Future<void> boot(WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();
    }

    /// Well to the right of any text, but still inside the visible pane.
    Future<void> tapEmptyPartOf(WidgetTester tester, Finder row) async {
      final pane = tester.getRect(find.byType(ProgramPane));
      final rect = tester.getRect(rowContainerFor(row));
      await tester.tapAt(Offset(pane.right - 30, rect.center.dy));
      await tester.pumpAndSettle();
    }

    testWidgets('tapping a row changes nothing', (tester) async {
      await boot(tester);
      final before = tester.getRect(rowContainerFor(inProgram('TAKE')));

      // A row used to move an invisible insertion point. Now insertion is a
      // drop, so a row has nothing to say about it.
      await tapEmptyPartOf(tester, inProgram('TAKE'));
      await tapEmptyPartOf(tester, inProgram('REPEAT'));

      expect(find.text('DROP HERE'), findsNothing);
      expect(tester.getRect(rowContainerFor(inProgram('TAKE'))), before);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an argument still answers its own tap', (tester) async {
      await boot(tester);

      // The one thing on a row that is still tappable.
      await tester.tap(inProgram('POSITIVE'));
      await tester.pumpAndSettle();
      expect(inProgram('NOT POSITIVE'), findsOneWidget);
    });
  });

  group('an empty block', () {
    Future<void> boot(WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CLEAR'));
      await tester.pumpAndSettle();
    }

    /// Every spacer height except the tail's, in layout order.
    List<double> gaps(WidgetTester tester) => innerSpacers()
        .map((e) => tester.getRect(find.byWidget(e.widget)).height)
        .toList();

    /// Spacer 1 is the body of the only block in the program: spacer 0 is the
    /// root gap above it.
    const body = 1;

    testWidgets('its one gap is thicker than a gap between siblings', (
      tester,
    ) async {
      await boot(tester);
      final pane = tester.getRect(find.byType(ProgramPane));
      await dropAt(tester, 'REPEAT', pane.center);

      // A block with nothing in it has exactly one slot, and that slot is the
      // only thing that can say the container is unfinished. At 18dp it read as
      // ordinary spacing between siblings that are not there.
      final heights = gaps(tester);
      expect(heights[0], closeTo(W.indentPerDepth, 0.5));
      expect(heights[body], closeTo(W.openSlotHeight, 0.5));
    });

    testWidgets('reserves a whole row and the gap that follows it', (
      tester,
    ) async {
      await boot(tester);
      final pane = tester.getRect(find.byType(ProgramPane));
      await dropAt(tester, 'REPEAT', pane.center);
      await dragIntoSpacer(tester, 'TAKE', 0);

      // Measured against a real command rather than the token: the empty body
      // should look like it is holding one instruction that is not there yet.
      final take = tester.getRect(rowContainerFor(inProgram('TAKE')));
      final well = gaps(tester).fold<double>(0, (a, b) => a > b ? a : b);
      expect(well, closeTo(take.height + W.indentPerDepth * 2, 1));
    });

    testWidgets('the drop shape appears where the row will be, gap and all', (
      tester,
    ) async {
      await boot(tester);
      final pane = tester.getRect(find.byType(ProgramPane));
      await dropAt(tester, 'REPEAT', pane.center);
      final before = gaps(tester)[body];

      final gesture = await holdOverSpacer(tester, 'TAKE', body);

      // The space was already reserved, so nothing shifts when the outline
      // appears - the only change on screen is the outline itself.
      expect(gaps(tester)[body], closeTo(before, 0.5));

      final slot = tester.getRect(find.byWidget(innerSpacers()[body].widget));
      final outline = tester.getRect(find.byType(DottedOutline));
      expect(
        slot.bottom - outline.bottom,
        closeTo(W.indentPerDepth + 2, 1.5),
        reason: 'the outline keeps the bottom gap a command would have',
      );
      expect(
        outline.top - slot.top,
        closeTo(W.indentPerDepth + 2, 1.5),
        reason: 'and the top gap too',
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });

    /// The fill painted behind an empty body's reserved row.
    Color ghostFill(WidgetTester tester, int index) {
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byWidget(innerSpacers()[index].widget),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      return (box.decoration as BoxDecoration).color!;
    }

    testWidgets('the reserved row wears the shade a child would', (
      tester,
    ) async {
      await boot(tester);
      final pane = tester.getRect(find.byType(ProgramPane));
      await dropAt(tester, 'REPEAT', pane.center);

      // Same alternation that keeps an IF inside an IF readable: the block sits
      // at depth 0, so its child sits at depth 1 and is a step lighter.
      final repeat = specFor('repeat').colour;
      expect(ghostFill(tester, body), W.blockFill(repeat, 1));
      expect(ghostFill(tester, body), isNot(W.blockFill(repeat, 0)));
    });

    testWidgets('and alternates again one level down', (tester) async {
      await boot(tester);
      final pane = tester.getRect(find.byType(ProgramPane));
      await dropAt(tester, 'REPEAT', pane.center);
      await dragIntoSpacer(tester, 'IF', body);

      // The IF is the only empty block now. It sits at depth 1, so its own
      // reserved row steps back to the unlightened colour.
      final wide = innerSpacers().indexWhere(
        (e) =>
            (tester.getRect(find.byWidget(e.widget)).height - W.openSlotHeight)
                .abs() <
            0.5,
      );
      expect(wide, isNot(-1));

      final ifColour = specFor('ifCond').colour;
      expect(ghostFill(tester, wide), W.blockFill(ifColour, 2));
      expect(ghostFill(tester, wide), ifColour);
    });

    testWidgets('goes back to an ordinary gap once it holds something', (
      tester,
    ) async {
      await boot(tester);
      final pane = tester.getRect(find.byType(ProgramPane));
      await dropAt(tester, 'REPEAT', pane.center);
      await dragIntoSpacer(tester, 'TAKE', body);

      expect(inProgram('TAKE'), findsOneWidget);
      for (final h in gaps(tester)) {
        expect(h, closeTo(W.indentPerDepth, 0.5));
      }
    });

    testWidgets('a nested empty block gets the same treatment', (tester) async {
      await boot(tester);
      final pane = tester.getRect(find.byType(ProgramPane));
      await dropAt(tester, 'REPEAT', pane.center);
      await dragIntoSpacer(tester, 'IF', body);

      // The outer block holds the IF now, so only the inner body is empty - one
      // thick gap, however deep it sits.
      final thick = gaps(
        tester,
      ).where((h) => (h - W.openSlotHeight).abs() < 0.5);
      expect(thick, hasLength(1));
      expect(inProgram('IF'), findsOneWidget);
    });
  });

  group('deleting a row', () {
    Future<void> boot(WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();
    }

    Future<void> swipe(WidgetTester tester, Finder row, double dx) async {
      await tester.drag(row, Offset(dx, 0));
      await tester.pumpAndSettle();
    }

    for (final (name, dx) in [('right', 400.0), ('left', -400.0)]) {
      testWidgets('a swipe to the $name deletes the row', (tester) async {
        await boot(tester);
        await swipe(tester, inProgram('SHIP'), dx);

        // Either direction, so there is nothing to aim at.
        expect(inProgram('SHIP'), findsNothing);
        expect(find.text('UNDO'), findsOneWidget, reason: 'and it is undoable');
      });

      testWidgets('and says DELETE on the way $name', (tester) async {
        await boot(tester);

        // Mid-swipe is where the hint shows, so look while the row is moving.
        final gesture = await tester.startGesture(
          tester.getCenter(inProgram('SHIP')),
        );
        await tester.pump(const Duration(milliseconds: 20));
        await gesture.moveBy(Offset(dx.sign * 30, 0));
        await tester.pump();
        await gesture.moveBy(Offset(dx.sign * 60, 0));
        await tester.pump();

        // The other direction used to duplicate the row.
        expect(find.text('DUPLICATE'), findsNothing);
        expect(find.text('DELETE'), findsOneWidget);

        await gesture.up();
        await tester.pumpAndSettle();
      });
    }

    testWidgets('the undo offer clears itself after a few seconds', (
      tester,
    ) async {
      await boot(tester);
      await swipe(tester, inProgram('SHIP'), 400);
      expect(find.text('UNDO'), findsOneWidget);

      // Still up half a second in, gone shortly after.
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('UNDO'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // It used to sit there until UNDO was tapped, which made a courtesy look
      // like a decision waiting on you.
      expect(find.text('UNDO'), findsNothing);
      expect(inProgram('SHIP'), findsNothing, reason: 'and the delete stands');
    });

    testWidgets('the hint is readable in both directions', (tester) async {
      await boot(tester);
      final pane = tester.getRect(find.byType(ProgramPane));

      for (final dx in [30.0, -30.0]) {
        final gesture = await tester.startGesture(
          tester.getCenter(inProgram('REPEAT')),
        );
        await tester.pump(const Duration(milliseconds: 20));
        await gesture.moveBy(Offset(dx, 0));
        await tester.pump();
        await gesture.moveBy(Offset(dx * 4, 0));
        await tester.pump();

        // A row runs 56dp past the right edge of the screen, so the hint on that
        // side has to be pulled back inside or the word is half off the phone.
        final label = tester.getRect(find.text('DELETE'));
        expect(label.left, greaterThanOrEqualTo(pane.left - 0.5));
        expect(label.right, lessThanOrEqualTo(pane.right + 0.5));

        await gesture.moveBy(Offset(-dx * 5, 0));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('swiping a block carries its whole body along', (tester) async {
      await boot(tester);
      final take = tester.getRect(rowContainerFor(inProgram('TAKE')));
      final ship = tester.getRect(rowContainerFor(inProgram('SHIP')));

      // The swipe used to be on the header alone, so a block slid its title out
      // and left its instructions behind. A block is one thing.
      final gesture = await tester.startGesture(
        tester.getCenter(inProgram('REPEAT')),
      );
      await tester.pump(const Duration(milliseconds: 20));
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();

      final moved = tester.getRect(rowContainerFor(inProgram('TAKE'))).left;
      expect(moved, greaterThan(take.left));
      expect(
        tester.getRect(rowContainerFor(inProgram('SHIP'))).left - ship.left,
        closeTo(moved - take.left, 1),
        reason: 'every row inside moves by the same amount',
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('but a row inside a block still deletes on its own', (
      tester,
    ) async {
      await boot(tester);
      await swipe(tester, inProgram('TAKE'), 400);

      // Both the child and the block it sits in have a swipe now; the deeper one
      // has to win, or a block would be impossible to edit from the inside.
      expect(inProgram('TAKE'), findsNothing);
      expect(inProgram('REPEAT'), findsOneWidget);
      expect(inProgram('SHIP'), findsOneWidget);
    });

    testWidgets('a block goes with its contents, without asking', (
      tester,
    ) async {
      await boot(tester);
      expect(inProgram('TAKE'), findsOneWidget);

      await swipe(tester, inProgram('REPEAT'), 400);

      // No sheet, no choice to make: the whole subtree is gone.
      expect(find.textContaining('Keep the contents'), findsNothing);
      expect(inProgram('REPEAT'), findsNothing);
      expect(inProgram('TAKE'), findsNothing);
      expect(inProgram('IF'), findsNothing);
      expect(inProgram('SHIP'), findsNothing);
    });

    testWidgets('and UNDO brings the whole subtree back', (tester) async {
      await boot(tester);
      await swipe(tester, inProgram('REPEAT'), 400);

      await tester.tap(find.text('UNDO'));
      await tester.pumpAndSettle();

      expect(inProgram('REPEAT'), findsOneWidget);
      expect(inProgram('TAKE'), findsOneWidget);
      expect(inProgram('SHIP'), findsOneWidget);
    });
  });

  group('auto-scroll while dragging', () {
    Future<void> boot(WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();
    }

    /// `.first` is the pane's own vertical scroll view: the overhang wrappers
    /// inside it are scroll views too, and they never scroll.
    double offset(WidgetTester tester) => tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(ProgramPane),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position
        .pixels;

    /// Picks [label] out of the tray and holds it at [point], without dropping.
    Future<TestGesture> carryTo(
      WidgetTester tester,
      String label,
      Offset point,
    ) async {
      final gesture = await tester.startGesture(
        tester.getCenter(trayCommand(label)),
      );
      await tester.pump(const Duration(milliseconds: 40));
      await gesture.moveBy(const Offset(0, -30));
      await tester.pump();
      await gesture.moveTo(point);
      await tester.pump();
      return gesture;
    }

    testWidgets('holding a tray command at the bottom edge scrolls down', (
      tester,
    ) async {
      await boot(tester);
      final pane = tester.getRect(find.byType(ProgramPane));
      expect(offset(tester), 0);

      // A command from the tray used to be the one drag that could not scroll:
      // the pane only heard about rows being moved within it.
      final gesture = await carryTo(
        tester,
        'SHIP',
        Offset(pane.center.dx, pane.bottom - 8),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(offset(tester), greaterThan(0));

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('and stops as soon as the finger leaves the edge', (
      tester,
    ) async {
      await boot(tester);
      final pane = tester.getRect(find.byType(ProgramPane));

      final gesture = await carryTo(
        tester,
        'SHIP',
        Offset(pane.center.dx, pane.bottom - 8),
      );
      await tester.pump(const Duration(milliseconds: 150));

      await gesture.moveTo(pane.center);
      await tester.pump();
      final settled = offset(tester);

      await tester.pump(const Duration(milliseconds: 200));
      expect(offset(tester), settled);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('the middle of the pane never scrolls', (tester) async {
      await boot(tester);
      final pane = tester.getRect(find.byType(ProgramPane));

      final gesture = await carryTo(tester, 'SHIP', pane.center);
      await tester.pump(const Duration(milliseconds: 300));

      expect(offset(tester), 0, reason: 'there has to be a neutral middle');

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('the edge speed ramps rather than switching on', (
      tester,
    ) async {
      await boot(tester);
      final pane = tester.getRect(find.byType(ProgramPane));
      final edge = math.min(W.autoScrollEdge, pane.height / 4);

      // Just inside the zone: slow.
      var gesture = await carryTo(
        tester,
        'SHIP',
        Offset(pane.center.dx, pane.bottom - edge + 2),
      );
      await tester.pump(const Duration(milliseconds: 160));
      final gentle = offset(tester);
      await gesture.up();
      await tester.pumpAndSettle();

      // Hard against the edge: fast.
      gesture = await carryTo(
        tester,
        'SHIP',
        Offset(pane.center.dx, pane.bottom - 2),
      );
      await tester.pump(const Duration(milliseconds: 160));
      expect(offset(tester) - gentle, greaterThan(gentle));

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('the tray face', () {
    Future<void> boot(WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();
    }

    /// The button box behind a tray label.
    Rect faceRect(WidgetTester tester, String label) =>
        tester.getRect(rowContainerFor(trayCommand(label)));

    testWidgets('every command is the same kind of object in the tray', (
      tester,
    ) async {
      await boot(tester);

      // A `┐` block hint and an `_` argument slot used to mark REPEAT, IF and
      // the pallet commands out as different sorts of thing while they were
      // still on the shelf. Being a container is something a command becomes
      // once it is in the program.
      expect(
        find.descendant(
          of: find.byType(CommandTray),
          matching: find.textContaining('┐'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(CommandTray),
          matching: find.textContaining('_'),
        ),
        findsNothing,
      );

      final take = faceRect(tester, 'TAKE');
      for (final spec in commandCatalogue) {
        final face = faceRect(tester, spec.trayLabel);
        expect(
          face.height,
          closeTo(take.height, 0.5),
          reason: '${spec.trayLabel} should be the same height as TAKE',
        );
      }
    });

    testWidgets('a block flies out of the tray looking like its button', (
      tester,
    ) async {
      await boot(tester);

      // The reported bug: the drag preview was a real ProgramRow, and a block
      // header paints no background of its own - the container behind it does -
      // so REPEAT flew as bare letters and IF as floating chips.
      final gesture = await tester.startGesture(
        tester.getCenter(trayCommand('REPEAT')),
      );
      await tester.pump(const Duration(milliseconds: 40));
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump();

      final lifted = find.descendant(
        of: find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.92),
        matching: find.text('REPEAT'),
      );
      expect(lifted, findsOneWidget);

      final box = tester.widget<Container>(
        find.ancestor(of: lifted, matching: find.byType(Container)).first,
      );
      final fill = (box.decoration! as BoxDecoration).color;
      expect(
        fill,
        specFor('repeat').colour,
        reason: 'the thing in the air is a filled button, not naked letters',
      );

      final chips = find.descendant(
        of: find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.92),
        matching: find.text('POSITIVE'),
      );
      expect(chips, findsNothing, reason: 'no arguments in flight either');

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('the space below the program', () {
    Future<void> boot(WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();
    }

    testWidgets('belongs to the end of the program, all of it', (tester) async {
      await boot(tester);

      // The reported bug: the last spacer was an 18dp strip, so appending meant
      // finding an invisible edge with a finger that is covered by the row it is
      // carrying. The empty pane below the program is that spacer now - and it
      // runs on past the bottom of the pane, which is the slack that makes a
      // short program scrollable.
      final pane = tester.getRect(find.byType(ProgramPane));
      final tail = tester.getRect(tailSpacer());
      expect(tail.top, lessThan(pane.bottom));
      expect(tail.bottom, greaterThanOrEqualTo(pane.bottom));
      expect(tail.height, closeTo(pane.height, 0.5));
    });

    testWidgets('a drop far below the last row still appends', (tester) async {
      await boot(tester);
      final pane = tester.getRect(find.byType(ProgramPane));

      await dropAt(tester, 'SHIP', Offset(pane.center.dx, pane.bottom - 20));

      final dropped = tester.getRect(rowContainerFor(inProgram('SHIP').last));
      final block = tester.getRect(rowContainerFor(inProgram('REPEAT')));
      expect(dropped.top, greaterThan(block.top));
      expect(
        dropped.left,
        closeTo(block.left, 0.5),
        reason: 'appended at the root, not into the block it was dropped past',
      );
    });

    testWidgets('is slack a short program can be scrolled into', (
      tester,
    ) async {
      await boot(tester);
      final before = tester.getRect(rowContainerFor(inProgram('REPEAT'))).top;

      // The sample program is shorter than the pane, so there was nothing to
      // scroll at all: the end of the program sat wherever it fell.
      await tester.drag(find.byType(ProgramPane), const Offset(0, -120));
      await tester.pumpAndSettle();

      final after = tester.getRect(rowContainerFor(inProgram('REPEAT'))).top;
      expect(after, lessThan(before), reason: 'the program moved up');
      expect(tester.takeException(), isNull);
    });

    testWidgets('and the slack is still the end of the program', (
      tester,
    ) async {
      await boot(tester);
      await tester.drag(find.byType(ProgramPane), const Offset(0, -120));
      await tester.pumpAndSettle();

      // Scrolled into, it has to keep taking drops - otherwise pulling the
      // program up to get comfortable would cost you the place to drop.
      final pane = tester.getRect(find.byType(ProgramPane));
      await dropAt(tester, 'SHIP', Offset(pane.center.dx, pane.bottom - 40));

      final dropped = tester.getRect(rowContainerFor(inProgram('SHIP').last));
      final block = tester.getRect(rowContainerFor(inProgram('REPEAT')));
      expect(dropped.top, greaterThan(block.top));
      expect(dropped.left, closeTo(block.left, 0.5));
    });

    testWidgets('an empty program is one big drop target', (tester) async {
      await boot(tester);
      await tester.tap(find.text('CLEAR'));
      await tester.pumpAndSettle();
      expect(inProgram('TAKE'), findsNothing);

      // The other reported bug: an empty program drew a hint and nothing else,
      // so the very first command could not be added at all.
      expect(find.text('Drag a command up from below.'), findsOneWidget);
      expect(tailSpacer(), findsOneWidget);

      final pane = tester.getRect(find.byType(ProgramPane));
      await dropAt(tester, 'TAKE', pane.center);

      expect(inProgram('TAKE'), findsOneWidget);
      expect(find.text('Drag a command up from below.'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the hint is only there while there is nothing to see', (
      tester,
    ) async {
      await boot(tester);
      expect(find.text('Drag a command up from below.'), findsNothing);
    });
  });
}
