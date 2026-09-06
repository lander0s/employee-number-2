/// The notebook's own design tokens.
///
/// Separate from `W`, which holds the app's chrome - the task card, the divider,
/// the floor pane, the run button. Those are dark furniture around the game.
/// This is the sheet of paper the program is written on, and it is a different
/// world: light, warm, and written in ink rather than in near-white.
///
/// See GameDesign/program-editor.md. Every number here is specified there, with
/// the reasoning; this file is the reasoning made executable.
library;

import 'package:flutter/material.dart';

abstract final class Paper {
  // ------------------------------------------------------------------ surface

  /// The sheet. Warm rather than white: paper, not a document window.
  static const sheet = Color(0xFFF6F1E4);

  /// Faint blue rules at exactly [rowHeight], so instructions sit *on* the
  /// lines, and a red margin down the left like every school notebook.
  static const rule = Color(0x332F6FA8);
  static const margin = Color(0x4DD2504A);
  static const marginInset = 26.0;

  /// Where writing starts: clear of the margin line, the way it does on paper.
  static const gutter = 34.0;

  // --------------------------------------------------------------------- ink

  /// Commands are bright, so their text is dark. The whole palette flipped when
  /// the pane became paper, and this is what it flipped to.
  static const ink = Color(0xFF1B1B1B);
  static const inkFaint = Color(0x991B1B1B);

  // ------------------------------------------------------------------ metrics

  /// A row hugs its text. 36 is under the usual 48 target and deliberately so:
  /// a row is not a tap target - its gestures are a swipe and a long-press -
  /// and the one thing on it that *is* tapped carries its own target below.
  static const rowHeight = 36.0;
  static const rowInsetLeft = 10.0;
  static const rowInsetRight = 6.0;

  /// The only spacing in the program. Closed it is the gap between siblings and
  /// the thickness of a container's arms; open it is the shape of the row about
  /// to land in it.
  static const gap = 12.0;
  static const openGap = rowHeight + gap * 2;

  /// A container wraps its children on all four sides: this much left, [armEnd]
  /// right, [gap] below. The left arm carries the nesting; the right and bottom
  /// arms are what make it a note rather than a bracket.
  static const armEnd = 8.0;

  /// A command at the root has no container to end against, so it stops this far
  /// inside the page - its lifted end needs somewhere to fall.
  static const rootEnd = 16.0;

  /// Cyclable words: padded to the word, with the target carried by transparent
  /// space around them.
  static const chipPadH = 8.0;
  static const chipPadV = 2.0;
  static const chipTarget = 36.0;

  /// The tray's buttons are tapped and dragged from cold, so they keep the full
  /// target.
  static const buttonTarget = 48.0;

  /// How much empty page is kept below the last row, as a fraction of the pane.
  /// It is what makes a short program scrollable at all.
  static const tailSlack = 0.5;

  // ------------------------------------------------------------------- paper

  /// Where the glue is. A container is glued along its top and lifts at the
  /// bottom; a single command is glued along its left and lifts at its right
  /// end. The negative spread is load-bearing: without it the blur bleeds back
  /// over the glued edge and the note stops being stuck to anything.
  static const noteShadow = <BoxShadow>[
    BoxShadow(
      color: Color(0x40000000),
      offset: Offset(0, 4),
      blurRadius: 6,
      spreadRadius: -3,
    ),
  ];

  static const tabShadow = <BoxShadow>[
    BoxShadow(
      color: Color(0x40000000),
      offset: Offset(4, 2),
      blurRadius: 6,
      spreadRadius: -3,
    ),
  ];

  /// The note lies over the page and lets it through: the ruling is visible
  /// under it, which is what makes the note read as something resting on the
  /// program rather than a strip of frame bolted to the bottom of the screen.
  static const scrim = Color(0x661C1C1C);

  /// Revealed behind a row being swiped away. Deep rather than bright: it is
  /// read in near-white like the app's own furniture, and it has to stay clear
  /// of the red the storage family wears so a delete never reads as a command.
  static const danger = Color(0xFF991B1B);
  static const onDanger = Color(0xFFF2F2F2);

  /// The note in its bin state, and the same lit up with something over it.
  static const binIdle = Color(0xFFBFC3C7);
  static const binArmed = Color(0xFFFF8275);

  /// The free corner is turned up a little. Small enough to register as
  /// physical rather than as a graphic.
  static const fold = 10.0;

  /// The underside of the paper, seen in the fold.
  static Color underside(Color fill) => Color.lerp(fill, Colors.black, 0.16)!;

  /// A block nested inside another of the same colour steps one shade, so the
  /// inset arms stay visible. It *lightens*, because the ink is dark.
  static Color fillFor(Color base, int depth) =>
      depth.isEven ? base : Color.lerp(base, Colors.white, 0.14)!;

  /// A cyclable word sits in a well cut out of its own row: the row's colour
  /// taken up, with an edge taken down.
  static Color chipFill(Color base) => Color.lerp(base, Colors.white, 0.24)!;
  static Color chipEdge(Color base) => Color.lerp(base, Colors.black, 0.30)!;

  // ---------------------------------------------------------------- movement

  /// A gap opens and closes under a held command. Linear: it is following a
  /// finger, not performing.
  static const gapGrow = Duration(milliseconds: 120);

  /// How long a press has to last before a placed command lifts. Long enough
  /// not to fire while the page is being scrolled, short enough not to feel
  /// like a wait.
  static const liftDelay = Duration(milliseconds: 180);

  /// Holding a lifted command near an edge scrolls the page, at a speed that
  /// ramps with how far into the zone the finger is. A constant speed reads as
  /// a switch tripped by accident; a ramp reads as pressure.
  static const edgeZone = 90.0;
  static const edgeSlow = 2.0;
  static const edgeFast = 16.0;

  // ------------------------------------------------------------------- type

  static const family = 'Sniglet';
  static const fallback = <String>['Consolas', 'Courier New', 'monospace'];

  /// `leadingDistribution: even` is doing real work: the labels are all caps,
  /// and by default the leftover line height is split the way the font declares
  /// it - most of it below the caps, in descender space nothing here ever uses.
  static const TextStyle command = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    leadingDistribution: TextLeadingDistribution.even,
    height: 1,
    color: ink,
  );

  static const TextStyle hint = TextStyle(fontSize: 17, color: inkFaint);

  // ------------------------------------------------------------- handwriting

  /// The brief is not chrome. It is written at the top of the same page the
  /// program is written on, in the player's own hand, because that is what a
  /// person actually does with a notebook: write down what they were asked for,
  /// then work underneath it.
  static const handFamily = 'Schoolbell';

  /// A shade darker than [ink]. The brief is the only writing on the page with
  /// no coloured note under it to lift it off the sheet, so it has to do that
  /// with weight alone.
  static const handInk = Color(0xFF111111);
  static const handInkFaint = Color(0xB3111111);

  /// `height` is not a ratio anyone chose: it is [rowHeight] over the size, so
  /// every written line lands on a printed rule. Handwriting that floats
  /// between the lines is the tell that a page is a picture of paper.
  /// Sized to the face, not carried over from the last one: Schoolbell sets a
  /// good deal wider than the hand it replaced, so the 31 that fit there wraps
  /// here - spending a whole ruled row on the word "numbers." 26 is the size
  /// that puts the sample brief's first line back on one row.
  ///
  /// Where any given brief breaks is a property of its own text, so this is a
  /// nudge away from a cliff rather than a law. Re-check it when the face
  /// changes; it is the first thing a new one invalidates.
  static const handSize = 26.0;

  /// Schoolbell ships one face, so [FontWeight.w700] has nothing to select.
  /// It asks the engine to embolden the outlines it has, which it does - by a
  /// fraction of a pixel, and by however much the platform feels like.
  ///
  /// Use [handAt] rather than this directly: it adds the rest of the weight in
  /// a way that does not depend on who is rendering.
  static const TextStyle hand = TextStyle(
    fontFamily: handFamily,
    fontFamilyFallback: fallback,
    fontSize: handSize,
    fontWeight: FontWeight.w700,
    height: rowHeight / handSize,
    leadingDistribution: TextLeadingDistribution.even,
    color: handInk,
  );

  /// The hand, in [colour], pressed harder.
  ///
  /// The extra weight is the same glyph drawn four more times a hair off
  /// centre, behind itself. It thickens every stroke by a known amount instead
  /// of a platform-dependent one, and it thickens the curves as much as the
  /// stems - which is what a pen does and what a real bold face does not.
  static TextStyle handAt(Color colour) => hand.copyWith(
    color: colour,
    shadows: [
      for (final offset in const [
        Offset(handPress, 0),
        Offset(-handPress, 0),
        Offset(0, handPress),
        Offset(0, -handPress),
      ])
        Shadow(color: colour, offset: offset),
    ],
  );

  /// How far off centre those copies sit. Half a pixel reads as anti-aliasing;
  /// much past one and the counters inside `a`, `e` and `o` start to fill in.
  ///
  /// Lower than it was for the previous face. Schoolbell's strokes are already
  /// heavy, so most of the weight is in the font now and this only has to
  /// finish the job - at 0.7 it closed the counters and read as a blot.
  static const handPress = 0.4;

  /// How far the whole written block is pushed down so its first baseline sits
  /// on the first rule rather than above it. One number, tuned once: every line
  /// below it is a whole [rowHeight] further down and keeps the same relation.
  static const handDrop = 6.0;

}
