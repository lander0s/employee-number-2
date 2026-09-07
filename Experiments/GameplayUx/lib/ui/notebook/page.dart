/// The sheet the program is written on.
///
/// Nothing but surface: ruling and margin. What is written on it is somebody
/// else's problem, and arrives as [child].
library;

import 'package:flutter/material.dart';

import 'tokens.dart';

class NotebookPage extends StatelessWidget {
  const NotebookPage({
    super.key,
    required this.controller,
    required this.child,
  });

  /// The program's scroll position: the ruling moves with the text written on
  /// it. A fixed backdrop would slide against the instructions the moment the
  /// page moved, which is the one thing paper never does.
  final ScrollController controller;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Paper.sheet,
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, _) => CustomPaint(
                  painter: _Ruling(
                    offset: controller.hasClients ? controller.offset : 0,
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Horizontal rules at a row's pitch, and a margin down the left.
///
/// Only the phase changes as the page scrolls - the lines are identical, so the
/// remainder is all that matters and the paper is endless.
class _Ruling extends CustomPainter {
  const _Ruling({required this.offset});

  final double offset;

  @override
  void paint(Canvas canvas, Size size) {
    final rule = Paint()
      ..color = Paper.rule
      ..strokeWidth = 1;

    for (
      var y = Paper.rowHeight - offset % Paper.rowHeight;
      y < size.height;
      y += Paper.rowHeight
    ) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rule);
    }

    canvas.drawLine(
      const Offset(Paper.marginInset, 0),
      Offset(Paper.marginInset, size.height),
      Paint()
        ..color = Paper.margin
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_Ruling old) => old.offset != offset;
}
