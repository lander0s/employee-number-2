/// The program surface's own design tokens.
///
/// Separate from `W`, which holds the app's chrome - the divider, the floor
/// pane, the run button. That is the furniture around the game; this is the
/// surface the program is written on.
///
/// It was a sheet of paper: cream, ruled, with a red margin and every command a
/// sticker casting its own shadow. That is parked with the rest of the style
/// while the gameplay is settled, so what is left here is a flat white panel.
/// The *layout* it implied is not parked - rows still stand off a gutter and
/// the caret still has its strip down the left - because that geometry is being
/// played against, and only the surface under it was decoration.
///
/// See GameDesign/program-editor.md. Every number here is specified there, with
/// the reasoning; this file is the reasoning made executable.
library;

import 'package:flutter/material.dart';

abstract final class Paper {
  // ------------------------------------------------------------------ surface

  /// The panel the program is written on. Flat white while the style is
  /// parked - it was a warm cream sheet, and the warmth was the first thing
  /// that read as a decision rather than a placeholder.
  static const sheet = Color(0xFFFFFFFF);

  /// The strip down the left that no command may be written over.
  ///
  /// It was a red margin rule drawn on paper, and it is now nothing at all -
  /// but the reservation outlives the line, because the caret is what actually
  /// uses it. A run marks the executing line out here, clear of the program, so
  /// the strip has to stay whether or not anything is drawn down it.
  static const marginInset = 26.0;

  /// Where writing starts: clear of [marginInset], with air after it.
  static const gutter = 34.0;

  // --------------------------------------------------------------------- ink

  /// Commands are bright, so their text is dark. This is the one part of the
  /// old palette the wireframe does not touch: the commands keep their family
  /// colours, so the ink that has to stay legible on them is unchanged.
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

  /// Where the column stops, measured in from the right edge.
  ///
  /// Gone as a number: it is [gutter], applied to both sides of the program at
  /// once, because the two are the same thing seen from opposite ends. It was
  /// 16 against a gutter of 34 and only ever reached root-level *commands* -
  /// a root block ran to the edge of the page. That was the sticky-note
  /// grammar, where a container was a sheet laid across the paper and a command
  /// a tab stuck on it. Nothing is stuck to anything now, so the column is just
  /// a column.
  ///
  /// The left is not symmetric *while a run is on*: the caret is drawn out in
  /// the gutter. That is the gutter being used for what it is for, not the
  /// column being off centre.

  /// A container's only vertical padding, above its title. There is none below:
  /// the gap between the title and the first child does that job, and unlike
  /// padding it answers a drop.
  static const headerTop = 7.0;

  /// Cyclable words: padded to the word, with the target carried by transparent
  /// space around them.
  static const chipPadH = 8.0;
  static const chipPadV = 2.0;
  static const chipTarget = 36.0;

  /// The tray's buttons are tapped and dragged from cold, so they keep the full
  /// target.
  static const buttonTarget = 48.0;

  /// The note's own margin, and extra below it.
  ///
  /// The bottom row of commands is the last thing before the edge of the panel,
  /// and on a phone with rounded corners the two commands at its ends are
  /// exactly what the curve eats. Android reports the bars and the cutout and
  /// that inset is added on top of this - but it does not report a corner
  /// radius, so this is the part that has to be generous on its own.
  ///
  /// The sides carry more than the top for the same reason: a corner curve
  /// comes in diagonally, so it takes width as well as height.
  static const notePad = 6.0;
  static const noteSidePad = 10.0;
  static const noteFoot = 18.0;

  /// How much empty page is kept below the last row, as a fraction of the pane.
  /// It is what makes a short program scrollable at all.
  static const tailSlack = 0.5;

  // ------------------------------------------------------------------ blocks

  /// The note lies over the page and lets it through: the ruling is visible
  /// under it, which is what makes the note read as something resting on the
  /// program rather than a strip of frame bolted to the bottom of the screen.
  ///
  /// What separates the tray from the page.
  ///
  /// They are the same colour now - the tray is the same surface the program is
  /// written on, raised - so an edge is the only thing left to tell them apart,
  /// and it has to be a cast shadow rather than a line. A line would read as a
  /// third thing between two surfaces; a shadow reads as one of them being on
  /// top of the other, which is what is true.
  ///
  /// Drawn by the *page*, at its top, not by the tray. A [Column] paints its
  /// children in order, so a shadow the tray tried to cast downward would be
  /// painted over by the page a moment later. The surface it falls on draws it.
  static const surfaceShadow = Color(0x30000000);
  static const surfaceShadowDepth = 9.0;

  /// Revealed behind a row being swiped away. Deep rather than bright: it is
  /// read in near-white like the app's own furniture, and it has to stay clear
  /// of the red the storage family wears so a delete never reads as a command.
  static const danger = Color(0xFF991B1B);
  static const onDanger = Color(0xFFF2F2F2);

  /// The note in its bin state, and the same lit up with something over it.
  /// Idle is the darkest neutral on screen; armed keeps its red, because armed
  /// means something is about to be destroyed.
  static const binIdle = Color(0xFF3E3E3E);
  static const binArmed = Color(0xFFFF8275);

  // ------------------------------------------------------------------- run

  /// The mark in the margin beside the line being run.
  ///
  /// Red, and deliberately not [ink]: the program is what the player wrote,
  /// and this is somebody else reading it back to them. It used to pick up the
  /// margin rule it stood against; that rule is gone, and the caret is now the
  /// only thing out in the strip - which is a better reason for it to be the
  /// one coloured mark there, not a worse one.
  static const caret = Color(0xFFC2453F);
  static const caretSize = Size(14, 16);

  /// From the page's left edge. It has the strip between there and [marginInset]
  /// to itself, and stops clear of the rule rather than touching it.
  static const caretInset = 6.0;

  /// How long the page takes to bring the running line back into view.
  ///
  /// Shorter than the fastest instruction holds for, so the page has settled
  /// before the next line is marked. Any longer and a fast stretch of program
  /// leaves the scroll permanently chasing a caret it never catches.
  static const caretFollow = Duration(milliseconds: 180);

  /// How much page is kept past the running line when the page does have to
  /// move.
  ///
  /// One row's pitch, which buys exactly one instruction: bringing the line
  /// flush with the edge would put the *next* one off screen again and scroll
  /// on every single step, and a row of slack makes it every second step. It
  /// also stops the marked line reading as half cut off by the edge it was
  /// pushed against.
  ///
  /// More would buy more stillness at the cost of a larger jump each time, and
  /// far enough down that road is the centring this replaced. One row is the
  /// least that fixes the every-step case.
  static const caretSlack = rowHeight + gap;

  /// The marked command is also outlined, in the caret's own colour, so the
  /// mark and the thing it marks are obviously one statement rather than an
  /// arrow near a row.
  ///
  /// Drawn as a foreground decoration, which paints over the paper inside the
  /// box it already occupies. A real border would be layout: every marked row
  /// would grow by 4dp and shove the rest of the program down the page at the
  /// exact moment the player is trying to follow it.
  static const caretBorder = 2.0;

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

  // There were two bought faces - a rounded display face on the commands, a
  // handwriting face on the brief - and both were saying the same thing:
  // sticky note, notebook. There is no notebook now, so they were saying it
  // about nothing.
  //
  // The brief is set in the platform's own face: no `fontFamily` at all rather
  // than a named default, because the system face is whatever the platform
  // ships and naming one would pick a loser everywhere else.

  /// The instructions, in the machine's own face.
  ///
  /// Monospace is not a placeholder even though everything around it is: these
  /// are statements in a language, and a fixed advance is what a language looks
  /// like written down.
  ///
  /// It steadies a cycling argument only so far - PALLET A and PALLET E are the
  /// same width, so cycling between them moves nothing, but NEGATIVE to ZERO
  /// is four characters shorter and its chip resizes whatever the face.
  ///
  /// Named by generic family with real fallbacks, the way `W.console` does:
  /// `monospace` is what Android resolves, and Windows needs to be told.
  ///
  /// `leadingDistribution: even` is doing real work: the labels are all caps,
  /// and by default the leftover line height is split the way the font declares
  /// it - most of it below the caps, in descender space nothing here ever uses.
  static const TextStyle command = TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: <String>['Consolas', 'Courier New'],
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    leadingDistribution: TextLeadingDistribution.even,
    height: 1,
    color: ink,
  );

  static const TextStyle hint = TextStyle(fontSize: 17, color: inkFaint);

  // ------------------------------------------------------------------ brief

  /// Smaller than [command], because the brief is what you were asked for and
  /// the program is the work.
  ///
  /// This is the floor, not a preference: 7.3 puts nothing functional under 17,
  /// and the brief is the level's instructions. It cannot go smaller without
  /// giving that up, so if it still reads large the size is not the thing to
  /// change - shorten the brief.
  static const briefSize = 17.0;

  /// A paragraph's line height, and nothing to do with [rowHeight].
  ///
  /// It used to be `rowHeight / briefSize`, which is about 1.9 - enormous for
  /// running text, and not chosen as a typographic measure at all. It was there
  /// because a written line had to fill exactly one ruled row and land on the
  /// rule at the bottom of it. There is no ruling now, so the brief is free to
  /// be set like the prose it is.
  ///
  /// 1.35 rather than the usual 1.4-1.5: this is two or three lines read once,
  /// not a page of body copy, and it sits directly above the program it
  /// describes. Tight keeps it reading as one note.
  static const briefLine = 1.35;

  /// Nothing sets the first line down from the top any more. The face used to
  /// need it - its baseline sat high in the box, by a measured amount that
  /// changed with the size - and an even leading distribution puts a system
  /// face where it should be on its own.
  static const TextStyle brief = TextStyle(
    fontSize: briefSize,
    height: briefLine,
    leadingDistribution: TextLeadingDistribution.even,
    color: ink,
  );

  /// The air between the last written line and the first command.
  ///
  /// Small on purpose: the program's own first gap adds [gap] under this one,
  /// so what a player sees is the sum of the two. At half a row it came to 30
  /// and read as a blank line left in the page; 6 puts the total at [gap] and
  /// a half, still enough to say the note and the work are two things.
  static const briefGap = 6.0;

  /// The air above the brief.
  ///
  /// Written as the sum it has to match rather than as the 18 it comes to: the
  /// space below the brief is [briefGap] *plus* the program's own first [gap],
  /// and a player sees one distance, not two widgets. Stating it this way is
  /// what stops the two drifting apart the next time either is tuned.
  static const briefTop = briefGap + gap;
}
