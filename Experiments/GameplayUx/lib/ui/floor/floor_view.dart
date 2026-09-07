/// The floor, seen from above. Wireframe primitives, no art.
///
/// Everything the machine can observe is on it: the intake belt down the left,
/// the outbound belt down the right, five pallets across the bottom, and
/// UNIT-02 in the middle holding at most one package. That is the whole world
/// (game-design-document 6.1), and drawing it as boxes and lines first is the
/// cheapest way to find out whether the *layout* reads before anything is
/// animated - which way packages flow, where the robot has to reach, whether
/// five pallets across the bottom is legible at a thumb's distance.
///
/// It is a square, always. See [FloorSquare] for why, and for what happens when
/// the divider leaves it less room than that.
library;

import 'package:flutter/material.dart';

import '../../model/commands.dart';
import '../wireframe.dart';

/// A square window onto the floor, anchored at the bottom.
///
/// The floor is a fixed square the width of the pane, and the pane clips it
/// rather than squashing it: pushing the divider up slides the square away like
/// a drawer instead of distorting a world the player is trying to read. It is
/// anchored at the *bottom* because that is where the pallets are - the drawer
/// gives up empty air at the top first, and the last thing to go is the row of
/// spots the program addresses by number.
class FloorSquare extends StatelessWidget {
  const FloorSquare({
    super.key,
    required this.intake,
    required this.claws,
    required this.outbound,
    required this.pallets,
  });

  final List<int> intake;
  final int? claws;
  final List<int> outbound;
  final List<int?> pallets;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final side = constraints.maxWidth;
      return ClipRect(
        child: OverflowBox(
          alignment: Alignment.bottomCenter,
          minHeight: side,
          maxHeight: side,
          child: SizedBox(
            width: side,
            height: side,
            child: CustomPaint(
              painter: _Floor(
                intake: intake,
                claws: claws,
                outbound: outbound,
                pallets: pallets,
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _Floor extends CustomPainter {
  _Floor({
    required this.intake,
    required this.claws,
    required this.outbound,
    required this.pallets,
  });

  final List<int> intake;
  final int? claws;
  final List<int> outbound;
  final List<int?> pallets;

  // Everything below is a fraction of the side, so the whole floor scales with
  // the square and there is not a single hardcoded distance in it.
  static const _pad = 0.045;
  static const _beltW = 0.145;

  /// The belts run from the top of the square to just above the pallets, and
  /// their labels sit at the *foot* of each belt rather than the head.
  ///
  /// Labelling the heads was the obvious way round and it collided with the RUN
  /// button, which lives in the top-right corner and landed square on the word
  /// OUTBOUND. Moving the labels down also let the belts start at the top edge,
  /// which is what makes room for six packages - the longest shipment the
  /// briefing's set contains. Past six a belt shows a `+n` rather than
  /// shrinking the boxes until nobody can read a number.
  static const _beltTop = 0.05;
  static const _beltEnd = 0.72;

  /// The pallets are pushed to the foot of the square, where they belong: they
  /// are the floor, and everything else happens above them. It also gives the
  /// belts and the unit the whole middle of the square instead of two thirds
  /// of it, which is what the room freed by dropping the narration was for.
  static const _palletTop = 0.805;
  static const _palletSize = 0.135;

  /// Centred in the open floor between the top of the belts and the pallets.
  static const _robot = 0.17;
  static const _robotAt = 0.42;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final pad = s * _pad;
    final beltW = s * _beltW;

    _grid(canvas, s);

    final intakeBelt = Rect.fromLTRB(
      pad,
      s * _beltTop,
      pad + beltW,
      s * _beltEnd,
    );
    final outBelt = Rect.fromLTRB(
      s - pad - beltW,
      s * _beltTop,
      s - pad,
      s * _beltEnd,
    );

    // Packages queue at the *bottom* of the intake belt: that end is the chute,
    // the one TAKE reaches into, so the next package to arrive is the one
    // nearest the robot rather than the one furthest from it.
    _belt(canvas, intakeBelt, 'INTAKE', intake, fromBottom: true, s: s);
    _belt(canvas, outBelt, 'OUTBOUND', outbound, fromBottom: true, s: s);

    _pallets(canvas, s);
    _unit(canvas, s);
  }

  void _grid(Canvas canvas, double s) {
    final paint = Paint()
      ..color = W.floorGrid
      ..strokeWidth = 1;
    const cells = 8;
    for (var i = 1; i < cells; i++) {
      final at = s * i / cells;
      canvas.drawLine(Offset(at, 0), Offset(at, s), paint);
      canvas.drawLine(Offset(0, at), Offset(s, at), paint);
    }
  }

  /// A belt, its label, and the packages on it.
  void _belt(
    Canvas canvas,
    Rect belt,
    String label,
    List<int> packages, {
    required bool fromBottom,
    required double s,
  }) {
    canvas.drawRect(belt, _stroke());

    // Rollers, so a belt reads as a belt and not as an empty column.
    final rollers = Paint()
      ..color = W.floorGrid
      ..strokeWidth = 1;
    final pitch = s * 0.05;
    for (var y = belt.top + pitch; y < belt.bottom; y += pitch) {
      canvas.drawLine(Offset(belt.left, y), Offset(belt.right, y), rollers);
    }

    _label(canvas, label, Offset(belt.center.dx, belt.bottom + s * 0.037), s);

    final box = belt.width * 0.59;
    final step = box + s * 0.008;
    final room = (belt.height / step).floor();
    final shown = packages.length < room ? packages.length : room;

    for (var i = 0; i < shown; i++) {
      final y = fromBottom
          ? belt.bottom - box - i * step
          : belt.top + i * step;
      _package(
        canvas,
        Rect.fromLTWH(belt.center.dx - box / 2, y, box, box),
        packages[i],
        s,
      );
    }

    if (packages.length > shown) {
      _label(
        canvas,
        '+${packages.length - shown}',
        Offset(belt.center.dx, belt.top + s * 0.01),
        s,
      );
    }
  }

  void _pallets(Canvas canvas, double s) {
    final pad = s * _pad;
    final size = s * _palletSize;
    final top = s * _palletTop;
    final span = s - pad * 2;
    // Evenly spaced, ends flush with the belts above them: the floor should
    // read as one grid rather than as a row of pallets floating under it.
    final gap = palletCount > 1
        ? (span - size * palletCount) / (palletCount - 1)
        : 0.0;

    for (var i = 0; i < palletCount; i++) {
      final rect = Rect.fromLTWH(pad + i * (size + gap), top, size, size);
      canvas.drawRect(rect, _stroke());
      _label(
        canvas,
        '$i',
        Offset(rect.center.dx, rect.bottom + s * 0.012),
        s,
      );

      final value = i < pallets.length ? pallets[i] : null;
      if (value != null) {
        final inset = size * 0.16;
        _package(canvas, rect.deflate(inset), value, s);
      }
    }
  }

  /// UNIT-02, and whatever is in its claws.
  void _unit(Canvas canvas, double s) {
    final side = s * _robot;
    final rect = Rect.fromCenter(
      center: Offset(s / 2, s * _robotAt),
      width: side,
      height: side,
    );

    canvas.drawRect(rect, _stroke(width: 2));

    // Two claws off the bottom edge, pointing at the floor it works over.
    final claw = Paint()
      ..color = W.text
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final x in [rect.left + side * 0.25, rect.right - side * 0.25]) {
      canvas.drawLine(
        Offset(x, rect.bottom),
        Offset(x, rect.bottom + side * 0.22),
        claw,
      );
    }

    _label(canvas, 'UNIT-02', Offset(rect.center.dx, rect.top - s * 0.03), s);

    if (claws != null) {
      _package(canvas, rect.deflate(side * 0.22), claws!, s);
    }
  }

  // ------------------------------------------------------------------ pieces

  Paint _stroke({double width = 1.5}) => Paint()
    ..color = W.floorLine
    ..strokeWidth = width
    ..style = PaintingStyle.stroke;

  /// A package: a box with its number in it. That is all a package is.
  void _package(Canvas canvas, Rect rect, int value, double s) {
    canvas.drawRect(rect, Paint()..color = W.floorPackage);
    canvas.drawRect(
      rect,
      Paint()
        ..color = W.text
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );
    _text(
      canvas,
      '$value',
      rect.center,
      rect.height * 0.62,
      W.text,
      centred: true,
    );
  }

  void _label(Canvas canvas, String text, Offset at, double s) =>
      _text(canvas, text, at, s * 0.036, W.floorLabel, centred: true);

  void _text(
    Canvas canvas,
    String text,
    Offset at,
    double size,
    Color colour, {
    bool centred = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontFamilyFallback: const ['Consolas', 'Courier New'],
          fontSize: size,
          height: 1,
          color: colour,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(
      canvas,
      centred
          ? at - Offset(painter.width / 2, painter.height / 2)
          : at - Offset(painter.width / 2, 0),
    );
  }

  @override
  bool shouldRepaint(_Floor old) =>
      old.claws != claws ||
      !_same(old.intake, intake) ||
      !_same(old.outbound, outbound) ||
      !_same(old.pallets, pallets);

  static bool _same(List<Object?> a, List<Object?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
