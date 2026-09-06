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

  /// The clip holding the page down. Steel needs a dark side and a light side;
  /// one flat grey reads as a drawing of a clip rather than a clip.
  static const clipMetal = Color(0xFFB4B8BD);
  static const clipShade = Color(0xFF6B7075);
  static const clipSize = Size(22, 58);

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
}
