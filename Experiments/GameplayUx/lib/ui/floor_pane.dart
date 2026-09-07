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
/// It carries the run control, top-right, because that is where the thing being
/// run lives. A consequence worth knowing: the divider can hide the floor
/// entirely, and when it does there is no run button, so a program cannot be
/// started unless the floor is visible enough to reach it. That is intended -
/// see the collapse threshold in gameplay_screen.dart.
library;

import 'package:flutter/material.dart';

import '../model/level.dart';
import '../model/vm.dart';
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
    required this.onToggleRun,
  });

  final Level level;
  final RunController run;
  final Sfx sfx;
  final VoidCallback onToggleRun;

  @override
  Widget build(BuildContext context) {
    // No margin and no border. Both existed to set the well apart from a
    // frame of board around it, and with the simulation running edge to edge
    // there is no frame left to set it apart from - the floor *is* the pane.
    // It also buys the square the width the margin was holding: 20dp on a
    // 448dp panel is a package and a half.
    return Container(
      color: W.paneWell,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: run,
              builder: (context, _) => _Floor(level: level, run: run, sfx: sfx),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Chrome(
              child: AnimatedBuilder(
                animation: run,
                builder: (context, _) =>
                    RunButton(running: run.running, onTap: onToggleRun),
              ),
            ),
          ),
        ],
      ),
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

/// The only execution control the game needs: one button that becomes STOP while
/// a program is running. A separate stop button would be a second target that is
/// dead most of the time.
class RunButton extends StatelessWidget {
  const RunButton({super.key, required this.running, required this.onTap});

  static const height = 44.0;

  final bool running;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: running ? 'Stop the shift' : 'Run the shift',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: height),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: running ? W.buttonPressed : W.button,
            border: Border.all(color: W.text),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                // Painted rather than set as a glyph, for the same reason as the
                // divider arrows: at this size an icon font's built-in padding
                // fights the layout.
                child: CustomPaint(
                  painter: _RunGlyph(running: running, color: W.text),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                running ? 'STOP' : 'RUN',
                style: W.label.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A play triangle, or a stop square while running.
class _RunGlyph extends CustomPainter {
  const _RunGlyph({required this.running, required this.color});

  final bool running;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    if (running) {
      canvas.drawRect(
        Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
        paint,
      );
      return;
    }

    canvas.drawPath(
      Path()
        ..moveTo(1, 0)
        ..lineTo(size.width - 1, size.height / 2)
        ..lineTo(1, size.height)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(_RunGlyph old) =>
      old.running != running || old.color != color;
}
