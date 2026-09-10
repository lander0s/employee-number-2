/// The floor pane: the simulation, and the control that starts it.
///
/// The simulation itself is [FloorSquare] - a wireframe seen from above. This
/// wraps it in the pane, adds the line of narration along the top, and puts the
/// verdict over it when a shift ends.
///
/// The narration is what is left of the console this pane used to be. The floor
/// now shows the *state*, which is most of what the text was for, but not the
/// *reason*: "POSITIVE? 0 -> no" is the one thing a picture of a warehouse
/// cannot say, and it is exactly the thing a player gets wrong.
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

import 'package:flutter/material.dart';

import '../model/level.dart';
import '../model/vm.dart';
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
            child: AnimatedBuilder(
              animation: run,
              builder: (context, _) => _Floor(level: level, run: run, sfx: sfx),
            ),
          ),
        ),
        Positioned(
          top: 8,
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

class _Floor extends StatelessWidget {
  const _Floor({required this.level, required this.run, required this.sfx});

  final Level level;
  final RunController run;
  final Sfx sfx;

  @override
  Widget build(BuildContext context) {
    final result = run.result;

    // Before the first instruction the floor shows the batch as it arrived,
    // which is also what it shows while the player is still writing: the
    // shipment is the question, and it should be readable the whole time.
    return Stack(
      children: [
        // The floor drives its own animation off the controller: it needs the
        // instruction before this one to know which way anything is moving,
        // and one rebuild per tick is not enough frames to move on.
        Positioned.fill(
          child: FloorStage(level: level, run: run, sfx: sfx),
        ),
        if (result != null && run.finished)
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Chrome(
              child: _Verdict(result: result, size: run.size),
            ),
          ),
      ],
    );
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({required this.result, required this.size});

  final RunResult result;

  /// Command rows. Closers are free, so this is not the number of lines on the
  /// page (level-04-briefing 5.1, rule 1).
  final int size;

  @override
  Widget build(BuildContext context) {
    final good = result.passed;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: good ? W.button : W.danger,
        border: Border.all(color: good ? W.line : W.danger),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            good ? 'SHIFT COMPLETE' : 'SHIFT FAILED',
            style: W.console.copyWith(
              fontWeight: FontWeight.w700,
              color: good ? W.text : W.onDanger,
            ),
          ),
          Text(
            good ? 'SIZE $size   SPEED ${result.steps}' : result.verdict,
            style: W.console.copyWith(color: good ? W.textDim : W.onDanger),
          ),
        ],
      ),
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
    final ink = on ? W.text : W.lineSoft;

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
            border: Border.all(color: ink),
          ),
          // Painted rather than set as a glyph, for the same reason as the
          // splitter's handle: at this size an icon font's built-in padding
          // fights the layout.
          child: CustomPaint(
            size: const Size(16, 16),
            painter: _RunGlyph(glyph: glyph, color: ink),
          ),
        ),
      ),
    );
  }
}

enum _Glyph { play, pause, stop, prev, next }

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

    // The bar on a step control, and the width left for its triangle.
    const barW = 2.5;
    const gap = 1.5;

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

      case _Glyph.prev:
        canvas.drawRect(Rect.fromLTWH(1, 0, barW, h), paint);
        canvas.drawPath(
          Path()
            ..moveTo(w - 1, 0)
            ..lineTo(1 + barW + gap, h / 2)
            ..lineTo(w - 1, h)
            ..close(),
          paint,
        );

      case _Glyph.next:
        canvas.drawRect(Rect.fromLTWH(w - 1 - barW, 0, barW, h), paint);
        canvas.drawPath(
          Path()
            ..moveTo(1, 0)
            ..lineTo(w - 1 - barW - gap, h / 2)
            ..lineTo(1, h)
            ..close(),
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(_RunGlyph old) => old.glyph != glyph || old.color != color;
}
