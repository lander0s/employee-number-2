/// Where everything on the floor is, and how the unit gets between them.
///
/// Pulled out of the painter so it can be *checked*. The rule that the unit
/// never walks through a conveyor is geometry, not drawing, and geometry can be
/// asserted about without a canvas - see test/floor_test.dart. It also stopped
/// two places working out where pallet 3 is: the pallet draws itself there and
/// the unit stands over it, and they have to agree.
///
/// Every dimension is a fraction of the square's side, so the floor scales
/// whole and there is not one absolute distance in it.
library;

import 'dart:ui';

import '../../model/commands.dart';
import '../../model/vm.dart';

class FloorGeometry {
  const FloorGeometry(this.side);

  /// The square is as wide as it is tall; this is both.
  final double side;

  // ---------------------------------------------------------------- fractions

  /// The square's own margin, which the pallet row is flush with.
  static const pad = 0.045;

  /// The belts' thickness, and the line they run along.
  static const beltThickness = 0.145;
  static const beltAt = 0.42;

  /// Where each belt meets the floor: the right end of the intake, the left
  /// end of the outbound. Placed so two and a half packages are on screen -
  /// enough to see what is coming and what just left, not enough to plan a
  /// whole shipment by reading it off the floor.
  static const chuteEnd = 0.235;

  /// How far past the edge of the square each rail carries on, so neither belt
  /// appears to stop at the panel.
  static const beltOff = 0.6;

  static const palletTop = 0.805;
  static const palletSize = 0.135;

  static const robot = 0.17;

  /// How far the claws hang below the body. They are part of the unit for
  /// collision purposes: clearing a belt with the body and dragging the claws
  /// through it is still walking through it.
  static const clawReach = robot * 0.22;

  /// The two rows the unit works from: clear above the belts, and clear above
  /// the pallets.
  ///
  /// Both are set so the claws stop at the edge of what they are reaching for
  /// rather than inside it. Body clearance alone was not enough - the claws
  /// hang below it, and they swept the rollers on every walk past.
  static const beltRow = 0.215;
  static const palletRow = 0.675;

  // ------------------------------------------------------------------ absolute

  double get _beltW => side * beltThickness;
  double get _mid => side * beltAt;
  double get robotSide => side * robot;

  /// A package on a belt, and the gap between two of them.
  double get boxSize => _beltW * 0.59;
  double get _step => boxSize + side * 0.008;

  /// The head of each queue stops short of the end of its belt by the same
  /// clearance it has along the sides, so a package sits in an even surround
  /// instead of pressed against the rail it arrived on.
  double get _lip => (_beltW - boxSize) / 2;

  Rect get intakeBelt => Rect.fromLTRB(
    side * -beltOff,
    _mid - _beltW / 2,
    side * chuteEnd,
    _mid + _beltW / 2,
  );

  Rect get outBelt => Rect.fromLTRB(
    side * (1 - chuteEnd),
    _mid - _beltW / 2,
    side * (1 + beltOff),
    _mid + _beltW / 2,
  );

  /// Slot 0 is the end nearest the unit on both belts; the queues run away from
  /// it in opposite directions.
  Rect intakeSlot(int i) => Rect.fromLTWH(
    intakeBelt.right - _lip - boxSize - i * _step,
    _mid - boxSize / 2,
    boxSize,
    boxSize,
  );

  Rect outSlot(int i) => Rect.fromLTWH(
    outBelt.left + _lip + i * _step,
    _mid - boxSize / 2,
    boxSize,
    boxSize,
  );

  Rect palletSlot(int i) {
    final size = side * palletSize;
    final margin = side * pad;
    final span = side - margin * 2;
    // Evenly spaced, ends flush with the margin: the floor should read as one
    // grid rather than as a row of pallets floating under it.
    final gap = palletCount > 1
        ? (span - size * palletCount) / (palletCount - 1)
        : 0.0;
    return Rect.fromLTWH(
      margin + i * (size + gap),
      side * palletTop,
      size,
      size,
    );
  }

  // -------------------------------------------------------------------- the unit

  /// Where the unit stands to work on something: over it, one body clear.
  Offset stand(Station at) => switch (at.kind) {
    // Mid-floor, between the two belts. Only ever the starting position.
    StationKind.home => Offset(side / 2, side * beltRow),
    StationKind.chute => Offset(intakeSlot(0).center.dx, side * beltRow),
    StationKind.outbound => Offset(outSlot(0).center.dx, side * beltRow),
    StationKind.pallet => Offset(
      palletSlot(at.pallet).center.dx,
      side * palletRow,
    ),
  };

  Rect body(Offset centre) =>
      Rect.fromCenter(center: centre, width: robotSide, height: robotSide);

  /// The unit's whole footprint, claws included. This is what must not meet a
  /// belt.
  Rect sweep(Offset centre) {
    final it = body(centre);
    return Rect.fromLTRB(
      it.left,
      it.top,
      it.right,
      it.bottom + side * clawReach,
    );
  }

  /// A hair of daylight between the unit and a belt it is passing.
  ///
  /// Without it the corridor is exactly tangent to the belt ends, and whether
  /// the unit clips one comes down to which way a float rounds - which is how
  /// the collision test first failed, on one sample of one journey.
  static const clearance = 0.012;

  /// The gap between the two belt ends, less half a body and a margin at each
  /// side: the only strip of floor the unit can cross from one row to the other.
  double get corridorLo => side * (chuteEnd + clearance) + robotSide / 2;
  double get corridorHi => side * (1 - chuteEnd - clearance) - robotSide / 2;

  /// The unit's path between two points, as a polyline.
  ///
  /// It must not cross a belt, and it cannot go round one: both belts run off
  /// the square, so the only way between the belt row and the pallet row is the
  /// corridor between their near ends. A change of row is therefore an L -
  /// along the starting row to the corridor, across, then along the target row -
  /// rather than the diagonal it was, which walked over the rollers.
  ///
  /// Moves that stay on one row need no routing: the belt row is clear above
  /// both belts and the pallet row clear below them, by construction.
  List<Offset> route(Offset a, Offset b) {
    if (a.dy == b.dy) return [a, b];
    final x = _crossAt(a.dx, b.dx);
    return [a, Offset(x, a.dy), Offset(x, b.dy), b];
  }

  /// Where to change rows.
  ///
  /// Whichever end is already in the corridor, so the unit drops straight down
  /// when it can and only detours when it must. When neither is - standing over
  /// pallet 4, say, which is under the outbound belt - it takes the near edge,
  /// and every point in the corridor costs the same distance anyway.
  double _crossAt(double ax, double bx) {
    if (ax >= corridorLo && ax <= corridorHi) return ax;
    if (bx >= corridorLo && bx <= corridorHi) return bx;
    return ax < corridorLo ? corridorLo : corridorHi;
  }

  /// A point [u] of the way along a polyline, measured by distance rather than
  /// by segment - otherwise a short leg and a long one would take the same time
  /// and the unit would appear to sprint round the corner.
  static Offset walked(List<Offset> path, double u) {
    var total = 0.0;
    for (var i = 1; i < path.length; i++) {
      total += (path[i] - path[i - 1]).distance;
    }
    if (total == 0) return path.first;

    var left = u.clamp(0.0, 1.0) * total;
    for (var i = 1; i < path.length; i++) {
      final leg = (path[i] - path[i - 1]).distance;
      if (left <= leg || i == path.length - 1) {
        return Offset.lerp(path[i - 1], path[i], leg == 0 ? 1 : left / leg)!;
      }
      left -= leg;
    }
    return path.last;
  }

  /// Where the unit is, [u] of the way from one station to another.
  Offset walkBetween(Station from, Station to, double u) =>
      walked(route(stand(from), stand(to)), u);
}
