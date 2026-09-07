/// Where the robot is up to: a mark in the margin, beside the line running now.
///
/// It goes in the margin rather than on the row for two reasons. The rows are
/// already coloured, shadowed and nested, and a highlight laid over one of them
/// competes with all of that; and the margin is otherwise empty, so a mark there
/// is the only thing moving on the page while a program runs, which is exactly
/// what "you are here" needs to be.
///
/// It is drawn in red pen, picking up the margin rule it sits against. That is
/// also why it is not the ink the program is written in: the program is what the
/// player wrote, and this is somebody else marking it up as they read.
library;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// The mark itself, sized and placed by [CaretGutter].
class RunCaret extends StatelessWidget {
  const RunCaret({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Running this line',
    child: CustomPaint(size: Paper.caretSize, painter: const _Caret()),
  );
}

/// Puts a [RunCaret] in the page's margin, level with [child]'s first row.
///
/// The caret is positioned *outside* its parent, in the strip left of the
/// margin rule, and the stack does not clip so that it paints there. Doing it
/// this way rather than measuring the row and placing a mark over the page is
/// what makes it follow scrolling, reflow and reordering for free: it is part of
/// the row, and the row already knows where it is.
class CaretGutter extends StatelessWidget {
  const CaretGutter({
    super.key,
    required this.header,
    required this.depth,
    required this.child,
  });

  /// True when [child] is a container, whose title sits below its own top pad.
  /// A block is as tall as everything it owns, so without this the mark would
  /// centre itself against the whole body instead of the line being run.
  final bool header;

  /// How deep the row is nested. Every container insets its body by
  /// [Paper.gap], so a row three blocks down starts three gaps right of the
  /// gutter - and the caret has to back out of all of it. The margin is a
  /// property of the page, not of the row, so the mark does not step right as
  /// the program nests.
  final int depth;

  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      child,
      Positioned(
        // Measured from the page's left edge, then back out through the
        // gutter and every container between here and the root.
        left: Paper.caretInset - Paper.gutter - depth * Paper.gap,
        top: header ? Paper.headerTop : 0,
        height: Paper.rowHeight,
        child: const Center(child: RunCaret()),
      ),
    ],
  );
}

class _Caret extends CustomPainter {
  const _Caret();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = Paper.caret
      ..isAntiAlias = true;

    // A solid head, and a short shaft behind it: a bare triangle at this size
    // reads as a bullet point rather than as something pointing.
    canvas.drawPath(
      Path()
        ..moveTo(w, h / 2)
        ..lineTo(w * 0.45, 0)
        ..lineTo(w * 0.45, h)
        ..close(),
      paint,
    );

    canvas.drawRect(Rect.fromLTRB(0, h * 0.34, w * 0.5, h * 0.66), paint);
  }

  @override
  bool shouldRepaint(_Caret old) => false;
}
