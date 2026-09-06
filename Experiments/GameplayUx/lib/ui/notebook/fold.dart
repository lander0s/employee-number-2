/// A sheet of coloured paper stuck to the page.
///
/// Both shapes in the program are one of these - a container is a note glued
/// along its top, a command is a tab glued along its left - and the only
/// difference between them is which way the shadow falls. That is the whole
/// visual grammar: **the glued edge casts nothing, the free edge lifts.**
library;

import 'package:flutter/widgets.dart';

import 'tokens.dart';

class StuckPaper extends StatelessWidget {
  const StuckPaper({
    super.key,
    required this.fill,
    required this.shadow,
    required this.child,
    this.folded = true,
  });

  final Color fill;

  /// [Paper.noteShadow] for something glued at the top, [Paper.tabShadow] for
  /// something glued at the left.
  final List<BoxShadow> shadow;

  /// The free corner turns up. Off for the drag ghost, where the paper is in
  /// the air and not stuck to anything.
  final bool folded;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: fill, boxShadow: shadow),
      child: folded
          ? Stack(
              children: [
                child,
                // Bottom-right, on both shapes: it is the corner furthest from
                // the glue either way, so it is the corner that lifts.
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: CustomPaint(
                      size: const Size(Paper.fold, Paper.fold),
                      painter: _Fold(Paper.underside(fill)),
                    ),
                  ),
                ),
              ],
            )
          : child,
    );
  }
}

/// The turned-up corner: a triangle of the paper's underside.
///
/// Painted rather than clipped. Cutting the corner out would show the page
/// through it, which is what a *torn* corner looks like; a fold shows the back
/// of the same sheet, so it is the same colour a shade darker.
class _Fold extends CustomPainter {
  const _Fold(this.underside);

  final Color underside;

  @override
  void paint(Canvas canvas, Size size) {
    final corner = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(corner, Paint()..color = underside);
  }

  @override
  bool shouldRepaint(_Fold old) => old.underside != underside;
}
