/// The floor pane. Placeholder by design - no simulation in this experiment.
///
/// It carries the run control, top-right, because that is where the thing being
/// run lives. A consequence worth knowing: the divider can hide the floor
/// entirely, and when it does there is no run button, so a program cannot be
/// started unless the floor is visible enough to reach it. That is intended - see
/// the collapse threshold in gameplay_screen.dart.
///
/// It also hosts the test scaffolding. Those controls and readouts are not part
/// of the game: parked in the chrome they read as design decisions and mislead
/// anyone looking at a screenshot, so they live inside the placeholder rectangle
/// where nothing is real yet.
library;

import 'package:flutter/material.dart';

import 'wireframe.dart';

class FloorPane extends StatelessWidget {
  const FloorPane({
    super.key,
    required this.running,
    required this.onToggleRun,
    required this.onLoadSample,
    required this.onClear,
    required this.rows,
    required this.depth,
  });

  final bool running;
  final VoidCallback onToggleRun;
  final VoidCallback onLoadSample;
  final VoidCallback onClear;
  final int rows;
  final int depth;

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The scaffolding is the first thing to go when the floor is dragged
            // small: it is the least important content on screen.
            final showScaffolding = constraints.maxHeight >= 190;

            return Stack(
              children: [
                Positioned.fill(
                  child: Column(
                    children: [
                      Expanded(
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
                      if (showScaffolding)
                        Chrome(
                          child: _Scaffolding(
                            onLoadSample: onLoadSample,
                            onClear: onClear,
                            rows: rows,
                            depth: depth,
                          ),
                        ),
                    ],
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
            );
          },
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

class _Scaffolding extends StatelessWidget {
  const _Scaffolding({
    required this.onLoadSample,
    required this.onClear,
    required this.rows,
    required this.depth,
  });

  final VoidCallback onLoadSample;
  final VoidCallback onClear;
  final int rows;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(100) / 100;

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF3C3C3C),
        border: Border.all(color: W.lineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'TEST SCAFFOLDING · NOT PART OF THE DESIGN',
            style: W.meta.copyWith(color: W.textFaint),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          // Wrap, not Row: these are diagnostics and must never be the thing
          // that overflows a narrow screen or a large text scale.
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _MiniButton(label: 'SAMPLE', onTap: onLoadSample),
              _MiniButton(label: 'CLEAR', onTap: onClear),
              Text(
                'ROWS $rows   DEPTH $depth   TEXT x${scale.toStringAsFixed(2)}',
                style: W.meta.copyWith(color: W.textDim),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        // No `alignment` here: a Container with alignment expands to its
        // incoming width constraint, and inside a Wrap that constraint is the
        // full row - which stretched these buttons edge to edge. Without it the
        // Container sizes to its child.
        child: Container(
          constraints: const BoxConstraints(minHeight: 30),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: W.button,
            border: Border.all(color: W.lineSoft),
          ),
          child: Text(label, style: W.meta.copyWith(color: W.text)),
        ),
      ),
    );
  }
}
