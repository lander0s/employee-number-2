/// The floor: a console, for now.
///
/// The real thing is a warehouse with a robot walking around it, and the state
/// below - intake, claws, outbound, pallets - is what that animation will be
/// animating. Printing it as text first is not a placeholder in the usual
/// sense: it is the machine's whole observable surface, written out, so the
/// semantics can be watched and argued with before a single sprite exists. If
/// a rule reads wrong here it will read wrong with a robot on top of it.
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
import 'run_controller.dart';
import 'wireframe.dart';

class FloorPane extends StatelessWidget {
  const FloorPane({
    super.key,
    required this.level,
    required this.run,
    required this.onToggleRun,
  });

  final Level level;
  final RunController run;
  final VoidCallback onToggleRun;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: W.paneFloor,
      padding: const EdgeInsets.all(10),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: W.paneWell,
          border: Border.all(color: W.line),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              // Clamped like the rest of the furniture: 7.3 asks the *program*
              // to stay readable at 200%, and a readout that grew that far
              // would overflow the well long before it helped anyone.
              child: Chrome(
                child: AnimatedBuilder(
                  animation: run,
                  builder: (context, _) => _Console(level: level, run: run),
                ),
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
      ),
    );
  }
}

class _Console extends StatelessWidget {
  const _Console({required this.level, required this.run});

  final Level level;
  final RunController run;

  @override
  Widget build(BuildContext context) {
    final now = run.now;
    final result = run.result;

    // Before the first instruction the floor shows the batch as it arrived,
    // which is also what it shows while the player is still writing: the
    // shipment is the question, and it should be readable the whole time.
    final intake = now?.intake ?? level.intake;
    final claws = now?.claws;
    final outbound = now?.outbound ?? const <int>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Right inset so the readout never runs under the RUN button.
          Padding(
            padding: const EdgeInsets.only(right: 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Field(label: 'INTAKE', values: intake),
                _Field(
                  label: 'CLAWS',
                  values: claws == null ? const [] : [claws],
                ),
                _Field(label: 'OUTBOUND', values: outbound),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: W.line),
          const SizedBox(height: 6),
          Expanded(child: _Log(run: run)),
          if (result != null && run.finished) ...[
            const SizedBox(height: 6),
            _Verdict(result: result, size: run.size),
          ],
        ],
      ),
    );
  }
}

/// One row of the readout: a label, then the numbers on it.
class _Field extends StatelessWidget {
  const _Field({required this.label, required this.values});

  final String label;
  final List<int> values;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(label, style: W.console.copyWith(color: W.textFaint)),
        ),
        Expanded(
          child: Text(
            values.isEmpty ? '--' : values.map((v) => '$v').join('   '),
            style: W.console,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

/// What has happened, newest at the bottom.
///
/// `reverse: true` rather than a scroll controller chasing the end: the list
/// grows by one line every few hundred milliseconds, and anchoring it to the
/// bottom is a property of the viewport rather than something to animate
/// towards on every tick.
class _Log extends StatelessWidget {
  const _Log({required this.run});

  final RunController run;

  @override
  Widget build(BuildContext context) {
    final lines = run.log;
    if (lines.isEmpty) {
      return Text(
        run.running ? '...' : 'Write a program and press RUN.',
        style: W.console.copyWith(color: W.textFaint),
      );
    }

    final newestFirst = lines.reversed.toList();

    return ListView.builder(
      reverse: true,
      padding: EdgeInsets.zero,
      itemCount: newestFirst.length,
      itemBuilder: (context, i) {
        final tick = newestFirst[i];
        // Only the line that just ran is at full strength. The rest are there
        // to be glanced back at, not read.
        final current = i == 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 34,
                child: Text(
                  '${tick.steps}',
                  style: W.console.copyWith(color: W.textFaint),
                ),
              ),
              Expanded(
                child: Text(
                  tick.line,
                  style: W.console.copyWith(
                    color: current ? W.text : W.textDim,
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
            good
                ? 'SIZE $size   SPEED ${result.steps}'
                : result.verdict,
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
