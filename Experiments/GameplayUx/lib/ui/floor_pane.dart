/// The floor pane: the simulation, and the controls that drive it.
///
/// Nothing else. The verdict used to be drawn along the bottom of this pane and
/// is a modal on the screen now - see `_Verdict` in gameplay_screen.dart.
///
/// It carries the run controls, top-right, because that is where the thing
/// being run lives. A consequence worth knowing: the divider can hide the floor
/// entirely, and when it does there are no controls, so a program cannot be
/// started unless the floor is visible enough to reach them. That is intended -
/// see the collapse threshold in gameplay_screen.dart.
///
/// The control sits *beside* the bloom rather than inside it. Both are in this
/// pane, and only one of them is part of the world.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../model/level.dart';
import 'bloom.dart';
import 'floor/floor_view.dart';
import 'run_controller.dart';
import 'sfx.dart';
import 'wireframe.dart';

class FloorPane extends StatelessWidget {
  const FloorPane({
    super.key,
    required this.level,
    required this.run,
    required this.sfx,
  });

  final Level level;
  final RunController run;
  final Sfx sfx;

  @override
  Widget build(BuildContext context) {
    // No margin and no border. Both existed to set the well apart from a
    // frame of board around it, and with the simulation running edge to edge
    // there is no frame left to set it apart from - the floor *is* the pane.
    // It also buys the square the width the margin was holding: 20dp on a
    // 448dp panel is a package and a half.
    // The bloom wraps the simulation and stops there. It grades its whole
    // subtree down so the light has something to be bright against, and the
    // run control was in that subtree - dimmed along with the warehouse, and
    // feeding the glow's backdrop besides. It is the app talking, not a thing
    // on the floor for light to fall on, so it is a sibling painted over the
    // top instead.
    //
    // `expand` rather than the default: the pane is handed a tight box by the
    // splitter, and passing that straight down is what the [Container] was
    // doing before as the root. Loose constraints would collapse a stack whose
    // only other child is positioned.
    return Stack(
      fit: StackFit.expand,
      children: [
        BloomLayer(
          child: Container(
            color: W.paneWell,
            // [FloorStage] listens to the controller itself, so there is
            // nothing here to rebuild on its behalf. There was, when the
            // verdict was drawn along the bottom of this pane - and being in
            // here is exactly why it moved out. The bloom grades its whole
            // subtree, so the one thing the player had been waiting for was
            // arriving at 40% brightness.
            child: FloorStage(level: level, run: run, sfx: sfx),
          ),
        ),
        Positioned(
          // Clear of whatever the device keeps for itself up there - a notch,
          // a camera, a status bar. `viewPadding` rather than `padding`,
          // because the game runs full screen: that zeroes `padding` for bars
          // it has hidden, but a camera is still a camera.
          //
          // Worth saying what this is *not* for: the outbound belt was never
          // crowding these. There were 108dp of clear floor between them
          // before it moved down, and there are more now.
          top: 8 + MediaQuery.viewPaddingOf(context).top,
          right: 8,
          child: Chrome(
            child: AnimatedBuilder(
              animation: run,
              builder: (context, _) => RunControls(run: run),
            ),
          ),
        ),
      ],
    );
  }
}

/// The transport: everything the player can do to a run.
///
/// Three controls, always all three, in one order: back, play, forward. They
/// enable and disable; they never come and go, and the row never changes width,
/// so a control cannot move out from under the thumb reaching for it.
///
/// The middle one is a toggle. Nothing loaded, it is play; a run loaded, it is
/// stop. One button, because those two are the same question - *is a run
/// happening* - and a person who wants to start one and a person who wants to
/// be rid of one are both reaching for the middle.
///
/// **There is no pause, and that costs something.** Stepping is how a run gets
/// held: a step takes the wheel, stops the clock and advances one instruction.
/// What is gone is *resuming* - once a run has been stepped, the middle button
/// says stop rather than play, so the way on is another step or a fresh run.
/// The alternative was a middle button that showed play whenever the clock was
/// idle, which reads better right up until you are parked at the verdict with
/// no way back to editing.
///
/// Icons, no words. Three of these shapes are the most over-learned set in
/// software - a tape deck from 1975 has the same row.
class RunControls extends StatelessWidget {
  const RunControls({super.key, required this.run});

  /// One control, square. [gameplay_screen] measures the collapse threshold
  /// against it: a floor too short to show this is a floor a program cannot be
  /// started from.
  static const height = 44.0;

  /// Between two controls. Small - they read as one instrument, not three
  /// buttons - but not nothing, or a thumb cannot tell where one ends.
  static const gap = 6.0;

  final RunController run;

  @override
  Widget build(BuildContext context) {
    final loaded = run.running;

    final controls = <(_Glyph, String, VoidCallback?)>[
      (
        _Glyph.prev,
        'Previous instruction',
        run.canStepBack ? run.stepBack : null,
      ),
      if (loaded)
        (_Glyph.stop, 'Stop the shift', run.stop)
      else
        (_Glyph.play, 'Run the shift', run.play),
      (
        _Glyph.next,
        'Next instruction',
        run.canStepForward ? run.stepForward : null,
      ),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (glyph, semantics, onTap) in controls) ...[
          if (glyph != controls.first.$1) const SizedBox(width: gap),
          _Control(glyph: glyph, semantics: semantics, onTap: onTap),
        ],
      ],
    );
  }
}

/// One control: a square, a glyph, and whether it does anything.
class _Control extends StatelessWidget {
  const _Control({
    required this.glyph,
    required this.semantics,
    required this.onTap,
  });

  final _Glyph glyph;
  final String semantics;

  /// Null disables it. Drawn faint and inert rather than removed - see
  /// [RunControls].
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;

    // Colour says what the control *does*; the border says whether it does
    // anything. Keeping those on separate features is what stops a disabled
    // stop button from reading as a quieter shade of red - it goes grey
    // outright, and grey is the one thing here that means nothing.
    final ink = on ? glyph.ink : W.lineSoft;
    final edge = on ? W.line : W.lineSoft;

    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      enabled: on,
      label: semantics,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: RunControls.height,
          height: RunControls.height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: W.button,
            border: Border.all(color: edge),
          ),
          // Painted rather than set as a glyph, for the same reason as the
          // splitter's handle: at this size an icon font's built-in padding
          // fights the layout.
          child: CustomPaint(
            size: Size.square(RunControls.height * glyph.box),
            painter: _RunGlyph(glyph: glyph, color: ink),
          ),
        ),
      ),
    );
  }
}

enum _Glyph { play, pause, stop, prev, next }

extension on _Glyph {
  /// How much of the control this glyph's box takes.
  ///
  /// Not one number for all five. The tape-deck shapes are solid and square -
  /// they use their box in both directions, and at much more than half the
  /// button a filled triangle starts to look like a warning sign. The curved
  /// arrows are wide and flat: they use their box in one direction, so a box
  /// that gives them the same visual weight has to be bigger.
  double get box => switch (this) {
    _Glyph.prev || _Glyph.next => 0.86,
    _Glyph.play || _Glyph.pause || _Glyph.stop => 0.58,
  };

  /// What this control does, in the colour a programmer already reads it in.
  Color get ink => switch (this) {
    _Glyph.play => W.runGo,
    _Glyph.stop => W.runStop,
    // Blue with the steps rather than green with play: pausing does not start
    // anything, it moves you about inside a run, which is what blue is for
    // here.
    _Glyph.pause || _Glyph.prev || _Glyph.next => W.runStep,
  };
}

/// The transport symbols, drawn rather than typed.
class _RunGlyph extends CustomPainter {
  const _RunGlyph({required this.glyph, required this.color});

  final _Glyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    switch (glyph) {
      case _Glyph.play:
        canvas.drawPath(
          Path()
            ..moveTo(1, 0)
            ..lineTo(w - 1, h / 2)
            ..lineTo(1, h)
            ..close(),
          paint,
        );

      case _Glyph.pause:
        // Two bars with a gap of the same weight: any thinner and at 14px they
        // merge into one at the first fractional device pixel.
        const bar = 4.0;
        canvas.drawRect(Rect.fromLTWH(1.5, 0, bar, h), paint);
        canvas.drawRect(Rect.fromLTWH(w - 1.5 - bar, 0, bar, h), paint);

      case _Glyph.stop:
        canvas.drawRect(Rect.fromLTWH(1, 1, w - 2, h - 2), paint);

      // Curved, like undo and redo, not the tape deck's skip-to-track. A
      // program is a document being read back and forth, and a step is far
      // closer to undo than to jumping a track: it moves *one* instruction,
      // reversibly, and the trace it walks is a history. The two skip arrows
      // said "go to the end", which is the one thing they do not do.
      case _Glyph.prev:
        _turn(canvas, size, paint, back: true);

      case _Glyph.next:
        _turn(canvas, size, paint, back: false);
    }
  }

  /// A shallow bow with a head on one end: undo and redo, mirrored.
  ///
  /// It was the top *half* of a circle, which is a small loop wherever you put
  /// it - a half turn spends all its length on height, and height is the axis
  /// with the least of it. [_sweep] spends the length on width instead.
  ///
  /// The tail is deliberately short of what the arc could be, and shorter than
  /// looks right in isolation. A long tail is the part of an arrow that
  /// carries no meaning - the head says which way - and it costs twice: the
  /// head cannot have those dp, and because the glyph is centred on its own
  /// ink, a tail trailing off one side pushes the head out to the other. The
  /// head is now the larger half of the arrow and sits near the middle of the
  /// button rather than against its edge.
  ///
  /// The cost of a flat arc is that the curve alone no longer says "back" - at
  /// this angle it reads as a line with a bend - which is the other reason the
  /// head is this size, and why it is set along the tangent rather than square
  /// to the world.
  static const _sweep = 45 * math.pi / 180;

  static void _turn(
    Canvas canvas,
    Size size,
    Paint fill, {
    required bool back,
  }) {
    final s = size.width;
    const half = _sweep / 2;

    final chord = s * 0.32;
    final r = chord / 2 / math.sin(half);
    final stroke = s * 0.15;

    // Anywhere; the whole thing is re-centred on its own ink below, so these
    // only have to be right relative to each other.
    final centre = Offset(s / 2, s / 2 + r * math.cos(half));
    final from = -math.pi / 2 - half;
    final arc = Path()
      ..addArc(Rect.fromCircle(center: centre, radius: r), from, _sweep);

    // The head sits at the end the arrow travels *to*, pointing along the
    // tangent there - reversed, because it is arriving rather than leaving.
    final at = back ? from : from + _sweep;
    final tip = centre + Offset(math.cos(at), math.sin(at)) * r;
    final along = back
        ? Offset(math.sin(at), -math.cos(at))
        : Offset(-math.sin(at), math.cos(at));
    final across = Offset(-along.dy, along.dx);

    final length = s * 0.46;
    final width = s * 0.24;
    final head = Path()
      ..moveTo(tip.dx + along.dx * length, tip.dy + along.dy * length)
      ..lineTo(tip.dx + across.dx * width, tip.dy + across.dy * width)
      ..lineTo(tip.dx - across.dx * width, tip.dy - across.dy * width)
      ..close();

    // Centred on what is actually drawn, not on the arc's geometry. The head
    // hangs off one end only, so the ink is lopsided by most of a head length
    // - which is exactly the amount the glyph used to sit off to one side, and
    // is unfixable by choosing better angles. Inflated by half the stroke,
    // since a path's bounds are its centreline.
    final ink = arc
        .getBounds()
        .inflate(stroke / 2)
        .expandToInclude(head.getBounds());

    canvas.save();
    canvas.translate(s / 2 - ink.center.dx, size.height / 2 - ink.center.dy);
    canvas.drawPath(
      arc,
      Paint()
        ..color = fill.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );
    canvas.drawPath(head, fill);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RunGlyph old) => old.glyph != glyph || old.color != color;
}
