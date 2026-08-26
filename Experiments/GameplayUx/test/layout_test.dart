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
import 'package:gameplay_ux/model/commands.dart';
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
Finder spacers() => find.byType(DragTarget<String>);

Future<void> openSpacer(WidgetTester tester, int index) async {
  await tester.tap(spacers().at(index));
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
      await openSpacer(tester, 0);

      final label = find.text('INSERT HERE');
      final labelRect = tester.getRect(label);
      final gap = tester.getRect(rowContainerFor(label));

      expect(labelRect.height, greaterThan(0));
      expect(gap.height, greaterThanOrEqualTo(labelRect.height));
      expect(gap.top, lessThanOrEqualTo(labelRect.top));
      expect(gap.bottom, greaterThanOrEqualTo(labelRect.bottom));
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

    Future<void> tapTray(WidgetTester tester, String label) async {
      await tester.tap(
        find.descendant(
          of: find.byType(CommandTray),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the program starts with every gap closed', (tester) async {
      await boot(tester);

      // Nothing is half-open when a level loads: the program reads as a program.
      expect(find.text('INSERT HERE'), findsNothing);
      expect(spacers(), findsWidgets);
    });

    testWidgets('a closed spacer is as thick as the container left arm', (
      tester,
    ) async {
      await boot(tester);

      // One structural unit for the whole program: the bracket arms and the gaps
      // between siblings are the same weight.
      for (final e in spacers().evaluate()) {
        expect(
          tester.getRect(find.byWidget(e.widget)).height,
          closeTo(W.indentPerDepth, 0.5),
        );
      }
    });

    testWidgets('tapping a spacer opens it, and only it', (tester) async {
      await boot(tester);
      await openSpacer(tester, 0);
      expect(find.text('INSERT HERE'), findsOneWidget);

      // Opening a second closes the first: at most one gap is ever open.
      await openSpacer(tester, 2);
      expect(find.text('INSERT HERE'), findsOneWidget);
    });

    testWidgets('an open gap is the size of the row about to land in it', (
      tester,
    ) async {
      await boot(tester);
      await openSpacer(tester, 0);

      final gap = tester.getRect(rowContainerFor(find.text('INSERT HERE')));
      final row = tester.getRect(rowContainerFor(inProgram('TAKE')));

      expect(gap.height, closeTo(row.height, 1));
    });

    testWidgets('an insertion lands in the open gap', (tester) async {
      await boot(tester);

      // The first spacer sits above REPEAT, at the root.
      await openSpacer(tester, 0);
      await tapTray(tester, 'SHIP');

      final ship = tester.getRect(rowContainerFor(inProgram('SHIP').first));
      final repeat = tester.getRect(rowContainerFor(inProgram('REPEAT')));
      expect(
        ship.top,
        lessThan(repeat.top),
        reason: 'it should have landed in the gap that was open',
      );
    });

    testWidgets('with no gap open an insertion goes to the end', (
      tester,
    ) async {
      await boot(tester);
      expect(find.text('INSERT HERE'), findsNothing);

      await tapTray(tester, 'SHIP');

      // The end of the program is the only place a player can mean when nothing
      // is open.
      final ship = tester.getRect(rowContainerFor(inProgram('SHIP').last));
      final repeat = tester.getRect(rowContainerFor(inProgram('REPEAT')));
      expect(ship.top, greaterThan(repeat.top));
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

      // Only an upper bound: a block header carries no card margin, so it is
      // legitimately a few pixels shorter than a plain row. What this guards is
      // the collapse into one word per line, which made it four rows tall.
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
      await openSpacer(tester, 0);
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

      double tallestSpacer() => spacers()
          .evaluate()
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

      // A block header paints nothing itself, so the first decorated ancestor
      // above it is the block container. (A plain command row *does* paint, so
      // this only works from a header.)
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
      for (final word in ['REPEAT', 'TAKE', 'IF', 'TYPE', 'IS', 'BLUE']) {
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

      final before = tester.getRect(inProgram('REPEAT'));
      await tester.drag(inProgram('REPEAT'), const Offset(-200, 0));
      await tester.pumpAndSettle();

      // A horizontal drag is a swipe gesture on a row, not a pan of the program.
      expect(tester.getRect(inProgram('REPEAT')).left, before.left);
      expect(tester.takeException(), isNull);
    });
  });

  group('tapping outside a spacer', () {
    Future<void> boot(WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();
      await openSpacer(tester, 0);
      expect(find.text('INSERT HERE'), findsOneWidget);
    }

    /// Well to the right of any text, but still inside the visible pane.
    Future<void> tapEmptyPartOf(WidgetTester tester, Finder row) async {
      final pane = tester.getRect(find.byType(ProgramPane));
      final rect = tester.getRect(rowContainerFor(row));
      await tester.tapAt(Offset(pane.right - 30, rect.center.dy));
      await tester.pumpAndSettle();
    }

    testWidgets('a plain row closes the open gap', (tester) async {
      await boot(tester);
      await tapEmptyPartOf(tester, inProgram('TAKE'));
      expect(find.text('INSERT HERE'), findsNothing);
    });

    testWidgets('a block header closes the open gap', (tester) async {
      await boot(tester);
      await tapEmptyPartOf(tester, inProgram('REPEAT'));
      expect(find.text('INSERT HERE'), findsNothing);
    });

    testWidgets('the bottom arm of a block opens a gap inside it', (
      tester,
    ) async {
      await boot(tester);

      // There is no foot bar any more: the body's trailing spacer is the bottom
      // arm, so the bottom edge of a block inserts at the end of that block
      // rather than doing nothing useful.
      final block = tester.getRect(
        find
            .ancestor(of: inProgram('REPEAT'), matching: find.byType(Container))
            .at(1),
      );
      final pane = tester.getRect(find.byType(ProgramPane));
      await tester.tapAt(
        Offset(pane.right - 30, block.bottom - W.indentPerDepth / 2),
      );
      await tester.pumpAndSettle();

      final gap = tester.getRect(rowContainerFor(find.text('INSERT HERE')));
      final ifRow = tester.getRect(rowContainerFor(inProgram('IF')));

      expect(find.text('INSERT HERE'), findsOneWidget);
      expect(
        gap.top,
        greaterThan(ifRow.top),
        reason: 'it should open at the end of the block, after the IF',
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('the empty space below the program', () {
    Future<void> boot(WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(harness(textScale: 1.0));
      await tester.pumpAndSettle();
    }

    testWidgets('opens the gap at the end of the program', (tester) async {
      await boot(tester);

      // The trailing spacer is 18 tall and invisible against the pane, so
      // reaching the end of the program used to mean hitting an edge.
      final pane = tester.getRect(find.byType(ProgramPane));
      await tester.tapAt(Offset(pane.center.dx, pane.bottom - 40));
      await tester.pumpAndSettle();

      expect(find.text('INSERT HERE'), findsOneWidget);

      final gap = tester.getRect(rowContainerFor(find.text('INSERT HERE')));
      final repeat = tester.getRect(rowContainerFor(inProgram('REPEAT')));
      expect(gap.top, greaterThan(repeat.bottom));

      // At the root, not tucked inside the block.
      expect(gap.left, lessThan(repeat.left + W.indentPerDepth));
    });

    testWidgets('an insertion then lands at the end', (tester) async {
      await boot(tester);

      final pane = tester.getRect(find.byType(ProgramPane));
      await tester.tapAt(Offset(pane.center.dx, pane.bottom - 40));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(CommandTray),
          matching: find.text('SHIP'),
        ),
      );
      await tester.pumpAndSettle();

      final ship = tester.getRect(rowContainerFor(inProgram('SHIP').last));
      final repeat = tester.getRect(rowContainerFor(inProgram('REPEAT')));
      expect(ship.top, greaterThan(repeat.bottom));
    });

    testWidgets('a block arm opens that block, not the end of the program', (
      tester,
    ) async {
      await boot(tester);

      // The left arm belongs to its own block. Falling through to the pane here
      // would jump the insertion point to the end of the whole program, which is
      // nowhere near where the finger landed.
      final ship = tester.getRect(rowContainerFor(inProgram('SHIP')));
      await tester.tapAt(
        Offset(ship.left - W.indentPerDepth / 2, ship.center.dy),
      );
      await tester.pumpAndSettle();

      final gap = tester.getRect(rowContainerFor(find.text('INSERT HERE')));
      final ifRow = tester.getRect(rowContainerFor(inProgram('IF')));

      expect(gap.top, greaterThan(ifRow.top));
      expect(
        gap.left,
        greaterThan(ifRow.left),
        reason: 'the gap should be inside the IF, at its indent',
      );
    });
  });
}
