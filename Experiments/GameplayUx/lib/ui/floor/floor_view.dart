/// The floor, seen from above. Wireframe primitives, no art.
///
/// Everything the machine can observe is on it: the intake belt running in from
/// off-screen left, the outbound belt down the right, five pallets across the
/// bottom, and UNIT-02 in the middle holding at most one package.
///
/// The intake deliberately leaves the square. A shipment is not a list of six,
/// it is a queue arriving from the rest of a warehouse the player never sees,
/// and a belt that runs off the edge of the panel says that where a tidy column
/// of boxes says the opposite. That is the whole world
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

  /// Both belts run horizontally at the unit's own height, so intake, unit and
  /// outbound are one straight line across the square and the reach at either
  /// end is a movement the player can see.
  ///
  /// They are the same belt mirrored. [_chuteEnd] is where each one meets the
  /// floor - the right end of the intake, the left end of the outbound - and it
  /// sits where two and a half packages are on screen: enough to see what is
  /// coming and what just left, not enough to plan a whole shipment by reading
  /// it off the floor. [_beltOff] is how far past the edge of the square the
  /// rail carries on, so neither belt ever appears to stop at the panel.
  ///
  /// The consequence worth naming: **the unit always drops at the same place.**
  /// The near end of the outbound is the drop point, and whatever was there has
  /// already travelled on, so the position never depends on how much has been
  /// shipped. Nothing moves yet, but the layout is built for it to.
  static const _chuteEnd = 0.235;
  static const _beltOff = 0.6;

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
    final beltW = s * _beltW;

    _grid(canvas, s);

    final mid = s * _robotAt;
    final intakeBelt = Rect.fromLTRB(
      s * -_beltOff,
      mid - beltW / 2,
      s * _chuteEnd,
      mid + beltW / 2,
    );
    final outBelt = Rect.fromLTRB(
      s * (1 - _chuteEnd),
      mid - beltW / 2,
      s * (1 + _beltOff),
      mid + beltW / 2,
    );

    // Both queues are drawn head-first from the end nearest the unit, and the
    // heads mean opposite things: on the intake it is the next package to be
    // taken, on the outbound the one most recently shipped. Which is why the
    // outbound list is walked backwards - the newest is the one at the drop
    // point, and the first thing shipped is furthest away.
    _belt(canvas, intakeBelt, 'INTAKE', intake, headAtFar: true, s: s);
    _belt(
      canvas,
      outBelt,
      'OUTBOUND',
      outbound.reversed.toList(),
      headAtFar: false,
      s: s,
    );

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

  /// A belt, its label, and the queue on it, head first.
  ///
  /// Horizontal only. Both belts run off the square now, so there is no end for
  /// a queue to fill up against and no `+n` to draw: what is off screen is off
  /// screen, and that is the fiction rather than a limitation. The vertical
  /// case this used to carry went with the last belt that needed it.
  void _belt(
    Canvas canvas,
    Rect belt,
    String label,
    List<int> queue, {
    /// True when the head sits at the belt's right end and the queue runs left
    /// (the intake), false for the mirror of that (the outbound).
    required bool headAtFar,
    required double s,
  }) {
    canvas.drawRect(belt, _stroke());

    // Rollers, across the direction of travel, which is what a roller is.
    // Without them a belt reads as an empty channel.
    final rollers = Paint()
      ..color = W.floorGrid
      ..strokeWidth = 1;
    final pitch = s * 0.05;
    for (var x = belt.left + pitch; x < belt.right; x += pitch) {
      canvas.drawLine(Offset(x, belt.top), Offset(x, belt.bottom), rollers);
    }

    final box = belt.height * 0.59;
    final step = box + s * 0.008;

    // The head stops short of the end of the belt by the same clearance it
    // already has along the sides, so a package sits in an even surround
    // instead of pressed against the rail it arrived on.
    final lip = (belt.height - box) / 2;
    final head = headAtFar ? belt.right - lip - box : belt.left + lip;

    for (var i = 0; i < queue.length; i++) {
      final x = headAtFar ? head - i * step : head + i * step;
      // Past the edge it is clipped anyway, and painting a long shipment off
      // into nowhere is work for nobody.
      if (x + box < 0 || x > s) break;
      _package(
        canvas,
        Rect.fromLTWH(x, belt.center.dy - box / 2, box, box),
        queue[i],
        s,
      );
    }

    _label(
      canvas,
      label,
      Offset(head + box / 2, belt.bottom + s * 0.037),
      s,
    );
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
