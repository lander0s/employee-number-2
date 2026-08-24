// Layout tests. Their whole job is to fail when something clips.
//
// A fixed-height row clips silently and only surfaces if a human happens to look
// at the right pixel, so 7.3's "scales to 200% without clipping" is asserted
// here instead: any RenderFlex/RenderBox overflow throws, and takeException
// turns that into a test failure.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameplay_ux/ui/gameplay_screen.dart';
import 'package:gameplay_ux/ui/floor_pane.dart';
import 'package:gameplay_ux/ui/program_pane.dart';
import 'package:gameplay_ux/ui/tray.dart';
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

  // The reported bug: the caret row was a fixed 20px, so its label clipped
  // vertically. These two tests are the regression guard for it.
  for (final scale in scales) {
    testWidgets('the caret label fits inside the caret row at x$scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: scale));
      await tester.pumpAndSettle();

      final label = find.text('INSERT HERE');
      await reveal(tester, label);

      final labelRect = tester.getRect(label);
      final slotRect = tester.getRect(rowContainerFor(label));

      expect(labelRect.height, greaterThan(0));
      expect(slotRect.height, greaterThanOrEqualTo(labelRect.height));
      expect(slotRect.top, lessThanOrEqualTo(labelRect.top));
      expect(slotRect.bottom, greaterThanOrEqualTo(labelRect.bottom));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the caret row height is driven by its text, not a constant', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Future<double> caretHeight(double scale) async {
      await tester.pumpWidget(harness(textScale: scale));
      await tester.pumpAndSettle();
      final label = find.text('INSERT HERE');
      await reveal(tester, label);
      return tester.getRect(rowContainerFor(label)).height;
    }

    // The caret now shares the instruction row's 60px minimum, so scales inside
    // that are absorbed by it - the same as any row. Past the minimum it must
    // still grow, which is what the old fixed 20px could not do and why the
    // label clipped.
    expect(await caretHeight(1.0), W.rowHeight);
    expect(await caretHeight(2.0), W.rowHeight);
    expect(tester.takeException(), isNull);

    // x3 is past the 200% we support, where the IF row's argument controls stop
    // fitting a 393-wide screen (a known limit, see the README). Only the
    // caret's height is under test here, so that unrelated overflow is
    // discarded rather than asserted away.
    final pastTheMinimum = await caretHeight(3.0);
    tester.takeException();
    expect(pastTheMinimum, greaterThan(W.rowHeight));
  });

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

  group('caret', () {
    double caretOpacity(WidgetTester tester) => tester
        .widget<Opacity>(
          find
              .ancestor(
                of: find.text('INSERT HERE'),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;

    testWidgets('is a full instruction row tall', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();

      final caret = tester.getRect(rowContainerFor(find.text('INSERT HERE')));
      final row = tester.getRect(rowContainerFor(inProgram('TAKE')));

      expect(caret.height, row.height);
    });

    testWidgets('uses the instruction row font size', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();

      final caretText = tester.widget<Text>(find.text('INSERT HERE'));
      final rowText = tester.widget<Text>(inProgram('TAKE'));

      expect(caretText.style?.fontSize, rowText.style?.fontSize);
      expect(caretText.style?.fontWeight, rowText.style?.fontWeight);
    });

    testWidgets('blinks', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // No pumpAndSettle in this test: the blink timer never settles.
      await tester.pumpWidget(harness(textScale: 1.0, animate: true));
      await tester.pump();

      expect(caretOpacity(tester), 1);

      await tester.pump(const Duration(milliseconds: 500));
      expect(caretOpacity(tester), 0);

      await tester.pump(const Duration(milliseconds: 500));
      expect(caretOpacity(tester), 1);
    });

    testWidgets('does not blink under reduced motion', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();

      expect(caretOpacity(tester), 1);
      // Would have toggled twice by now if the timer were running.
      await tester.pump(const Duration(seconds: 1));
      expect(caretOpacity(tester), 1);
    });

    testWidgets('blinking does not change the row height', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: 1.0, animate: true));
      await tester.pump();

      final lit = tester
          .getRect(rowContainerFor(find.text('INSERT HERE')))
          .height;
      await tester.pump(const Duration(milliseconds: 500));
      final dark = tester
          .getRect(rowContainerFor(find.text('INSERT HERE')))
          .height;

      expect(dark, lit);
    });
  });

  group('arguments', () {
    Finder trayButton(String label) => find.descendant(
      of: find.byType(CommandTray),
      matching: find.text(label),
    );

    /// The tray scrolls horizontally, so later commands are off-screen.
    Future<void> tapInTray(WidgetTester tester, String label) async {
      await tester.dragUntilVisible(
        trayButton(label),
        find.descendant(
          of: find.byType(CommandTray),
          matching: find.byType(Scrollable),
        ),
        const Offset(-120, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(trayButton(label));
      await tester.pumpAndSettle();
    }

    testWidgets('a pallet argument cycles on tap, like a type does', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();

      // Clear first: the sample program has no pallet command in it.
      await tester.tap(find.text('CLEAR'));
      await tester.pumpAndSettle();
      await tapInTray(tester, 'PICK FROM');

      expect(inProgram('PALLET 1'), findsOneWidget);

      await tester.tap(inProgram('PALLET 1'));
      await tester.pumpAndSettle();
      expect(inProgram('PALLET 2'), findsOneWidget);
      expect(inProgram('PALLET 1'), findsNothing);
    });

    testWidgets('the type argument still cycles on tap', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();

      expect(inProgram('BLUE'), findsOneWidget);
      await tester.tap(inProgram('BLUE'));
      await tester.pumpAndSettle();
      expect(inProgram('RED'), findsOneWidget);
    });

    testWidgets('a row carries one argument control, not a stepper', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();

      await tester.tap(find.text('CLEAR'));
      await tester.pumpAndSettle();
      await tapInTray(tester, 'MERGE');

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

      final words = ['IF', 'TYPE', 'IS', 'BLUE'];
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

      expect(conditionRow.height, greaterThanOrEqualTo(plainRow.height));
      expect(conditionRow.height, lessThan(plainRow.height * 2));
    });

    testWidgets('every segment cycles from the row', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();

      await tester.tap(inProgram('IS'));
      await tester.pumpAndSettle();
      expect(inProgram('IS NOT'), findsOneWidget);

      await tester.tap(inProgram('TYPE'));
      await tester.pumpAndSettle();
      expect(inProgram('WEIGHT'), findsOneWidget);
      expect(inProgram('ZERO'), findsOneWidget);
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

  group('tray edge fade', () {
    double fadeOpacity(WidgetTester tester, String side) => tester
        .widget<AnimatedOpacity>(
          find.descendant(
            of: find.byKey(ValueKey('tray-fade-$side')),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;

    Finder trayScrollable() => find.descendant(
      of: find.byType(CommandTray),
      matching: find.byType(Scrollable),
    );

    testWidgets('points right when there are commands off-screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();

      // Horizontal scrolling is close to undiscoverable without this.
      expect(fadeOpacity(tester, 'right'), 1);
      expect(fadeOpacity(tester, 'left'), 0);
    });

    testWidgets('swaps sides once scrolled to the end', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();

      await tester.fling(trayScrollable(), const Offset(-2000, 0), 4000);
      await tester.pumpAndSettle();

      expect(fadeOpacity(tester, 'right'), 0);
      expect(fadeOpacity(tester, 'left'), 1);
    });

    testWidgets('does not swallow taps on the button underneath', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();

      await tester.tap(find.text('CLEAR'));
      await tester.pumpAndSettle();

      // Tap the last command in the tray, which sits under the right-hand fade
      // after scrolling to the end.
      await tester.fling(trayScrollable(), const Offset(-2000, 0), 4000);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(CommandTray),
          matching: find.text('CLOCK OUT'),
        ),
      );
      await tester.pumpAndSettle();

      expect(inProgram('CLOCK OUT'), findsOneWidget);
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

    testWidgets('hides the tray and the caret, and brings both back', (
      tester,
    ) async {
      await boot(tester);
      expect(find.byType(CommandTray), findsOneWidget);
      expect(find.text('INSERT HERE'), findsOneWidget);

      await start(tester);
      expect(find.byType(CommandTray), findsNothing);
      expect(find.text('INSERT HERE'), findsNothing);

      await start(tester); // STOP
      expect(find.byType(CommandTray), findsOneWidget);
      expect(find.text('INSERT HERE'), findsOneWidget);
    });

    testWidgets('the program is still readable while running', (tester) async {
      await boot(tester);
      await start(tester);

      expect(inProgram('REPEAT'), findsOneWidget);
      expect(inProgram('IF'), findsOneWidget);
      expect(inProgram('BLUE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an argument cannot be cycled while running', (tester) async {
      await boot(tester);
      await start(tester);

      // The words still render, so they still look like part of the sentence -
      // they just do not answer a tap.
      await tester.tap(inProgram('IS'));
      await tester.pumpAndSettle();
      expect(inProgram('IS'), findsOneWidget);
      expect(inProgram('IS NOT'), findsNothing);
    });

    testWidgets('a row cannot be swipe-deleted while running', (tester) async {
      await boot(tester);
      await start(tester);

      await tester.drag(inProgram('TAKE'), const Offset(-400, 0));
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
}
