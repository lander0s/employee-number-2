/// The sheet the program is written on.
///
/// Nothing but surface: ruling, margin, and the clip holding it down. What is
/// written on it is somebody else's problem, and arrives as [child].
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
          // Over everything on the page: a clip sits on top of the sheet and of
          // whatever is written on it. Fixed rather than scrolled - it holds the
          // page down, it is not written on it.
          const Positioned(
            top: 4,
            right: 10,
            child: IgnorePointer(child: PaperClip()),
          ),
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

/// One length of wire, folded three times.
///
/// Drawn rather than shipped as an asset: it is a few arcs, and a path scales
/// to any density without a set of PNGs.
class PaperClip extends StatelessWidget {
  const PaperClip({super.key});

  @override
  Widget build(BuildContext context) => Transform.rotate(
    // Clipped on at an angle, the way anybody actually does it.
    angle: 0.42,
    child: CustomPaint(size: Paper.clipSize, painter: _Clip()),
  );
}

class _Clip extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final outer = w / 2;
    final inner = w * 0.3;

    final wire = Path()
      ..moveTo(0, h * 0.72)
      ..lineTo(0, outer)
      ..arcToPoint(Offset(w, outer), radius: Radius.circular(outer))
      ..lineTo(w, h - inner)
      ..arcToPoint(
        Offset(w * 0.35, h - inner),
        radius: Radius.circular(inner),
        clockwise: false,
      )
      ..lineTo(w * 0.35, h * 0.28)
      ..arcToPoint(
        Offset(w * 0.68, h * 0.28),
        radius: Radius.circular(inner * 0.55),
      )
      ..lineTo(w * 0.68, h * 0.58);

    // The shaded side first, offset by a pixel, so the wire reads as round.
    canvas.drawPath(
      wire.shift(const Offset(1.2, 1.2)),
      Paint()
        ..color = Paper.clipShade
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      wire,
      Paint()
        ..color = Paper.clipMetal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_Clip old) => false;
}
