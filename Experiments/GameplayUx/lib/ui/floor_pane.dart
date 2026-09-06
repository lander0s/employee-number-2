/// The floor pane. Placeholder by design - no simulation in this experiment.
///
/// It carries the run control, top-right, because that is where the thing being
/// run lives. A consequence worth knowing: the divider can hide the floor
/// entirely, and when it does there is no run button, so a program cannot be
/// started unless the floor is visible enough to reach it. That is intended - see
/// the collapse threshold in gameplay_screen.dart.
///
/// It used to host test scaffolding as well - sample/clear buttons and a shadow
/// toggle, parked inside the placeholder rectangle so they could not be mistaken
/// for design. They are gone: the questions they were there to answer have been
/// answered, and a screenshot of this pane should show the game.
library;

import 'package:flutter/material.dart';

import 'wireframe.dart';

class FloorPane extends StatelessWidget {
  const FloorPane({
    super.key,
    required this.running,
    required this.onToggleRun,
  });

  final bool running;
  final VoidCallback onToggleRun;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: W.paneFloor,
      padding: const EdgeInsets.all(10),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF474747),
          border: Border.all(color: W.line),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRect(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'FLOOR SIMULATION\nGOES HERE',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: W.label.copyWith(
                        color: W.textDim,
                        letterSpacing: 1.2,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Chrome(
                child: RunButton(running: running, onTap: onToggleRun),
              ),
            ),
          ],
        ),
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
