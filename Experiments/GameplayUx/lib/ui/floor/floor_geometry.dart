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
  ///
  /// Thinner than it was, which is what makes the packages smaller: a box is
  /// sized from the belt it rides on, so shrinking the rail shrinks the cargo
  /// and keeps the two in proportion. It also frees the height the unit needed
  /// to grow into.
  static const beltThickness = 0.125;
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

  /// The unit's footprint, and the box its sprite is drawn in.
  ///
  /// It has grown twice. The wireframe version was a box with two drawn claws
  /// hanging below it, so the footprint had to allow for the reach; the sprite
  /// is contained in this square instead, which gave that room back. Then the
  /// belts got thinner, which gave more.
  ///
  /// It is the one thing on the floor with a face, so it earns the space: the
  /// belts and the pallets are furniture and read fine small, and the unit is
  /// what the player is actually watching.
  static const robot = 0.31;

  /// The sprite's own canvas, and where its wheels sit inside it.
  ///
  /// From Animations/README.md: the comp is 300x240 and the casters plant on
  /// `y = 195`, which is 81.25% down. That matters more than it sounds. The
  /// sprite was being fitted into a *square*, which letterboxed it and left
  /// 18.75% of empty canvas below the wheels - so the unit floated most of a
  /// body above whatever it was supposedly standing next to, and every
  /// published hand coordinate was that far out.
  static const spriteAspect = 300 / 240;
  static const groundLine = 195 / 240;

  // ------------------------------------------------------------------ absolute

  double get _beltW => side * beltThickness;
  double get _mid => side * beltAt;
  double get spriteWidth => side * robot;
  double get spriteHeight => spriteWidth / spriteAspect;

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

  /// A pallet is a package-sized spot with the same surround a belt gives one.
  ///
  /// Derived, not chosen. It was a constant a fifth larger than this, and a
  /// package drawn to fit it came out a fifth bigger than the same package on a
  /// belt - so a box grew when it was set down and shrank when it was picked
  /// up. A package is one size everywhere; the furniture is what adapts.
  double get palletSide => boxSize + _lip * 2;

  Rect palletSlot(int i) {
    final size = palletSide;
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

  /// Where the unit's wheels plant when it works a belt, and a pallet.
  ///
  /// Derived rather than tuned: just clear of the thing it reaches for. They
  /// were two hand-picked constants, which meant growing the unit silently
  /// stood it on the rollers until the collision test said so.
  double get beltFeet => intakeBelt.top - side * clearance;
  double get palletFeet => palletSlot(0).top - side * clearance;

  /// Where the unit stands to work on something. This is its *ground line* -
  /// where the casters touch - not the middle of its sprite.
  Offset stand(Station at) => switch (at.kind) {
    // Mid-floor, between the two belts. Only ever the starting position.
    StationKind.home => Offset(side / 2, beltFeet),
    StationKind.chute => Offset(intakeSlot(0).center.dx, beltFeet),
    StationKind.outbound => Offset(outSlot(0).center.dx, beltFeet),
    StationKind.pallet => Offset(palletSlot(at.pallet).center.dx, palletFeet),
  };

  /// The sprite's draw rect, given where its wheels are.
  ///
  /// The aspect is the comp's, so `BoxFit.contain` maps the composition onto it
  /// one-to-one with no letterbox - which is what makes [handAt] usable.
  Rect body(Offset feet) => Rect.fromLTWH(
    feet.dx - spriteWidth / 2,
    feet.dy - spriteHeight * groundLine,
    spriteWidth,
    spriteHeight,
  );

  /// A point in the sprite's own coordinates, on the floor.
  ///
  /// The comp is 300 wide however big the sprite is drawn, so this is one scale
  /// factor and an origin. Every hand position in [Payload] comes through here.
  Offset handAt(Offset feet, Offset comp) {
    final box = body(feet);
    final k = spriteWidth / 300;
    return Offset(box.left + comp.dx * k, box.top + comp.dy * k);
  }

  /// A package, wherever it happens to be.
  ///
  /// Always [boxSize], deliberately: a package does not grow when it is picked
  /// up. It was being sized as a fraction of the *unit* instead, which made it
  /// half again as big as a belt package and large enough to cover the sprite.
  Rect packageAt(Offset centre) =>
      Rect.fromCenter(center: centre, width: boxSize, height: boxSize);

  /// The unit's footprint: the art down to its wheels.
  ///
  /// Not the whole sprite box. Below the ground line is empty canvas and a cast
  /// shadow, and treating that as solid would push the unit most of a body off
  /// everything it works on. An arm reaching past the line during a pickup is
  /// fine - the README says it does that on purpose, and in a three-quarter
  /// view a reach passes over a belt rather than through it.
  Rect sweep(Offset feet) {
    final box = body(feet);
    return Rect.fromLTRB(box.left, box.top, box.right, feet.dy);
  }

  /// A hair of daylight between the unit and a belt it is passing.
  ///
  /// Without it the corridor is exactly tangent to the belt ends, and whether
  /// the unit clips one comes down to which way a float rounds - which is how
  /// the collision test first failed, on one sample of one journey.
  static const clearance = 0.012;

  /// The gap between the two belt ends, less half a body and a margin at each
  /// side: the only strip of floor the unit can cross from one row to the other.
  double get corridorLo => side * (chuteEnd + clearance) + spriteWidth / 2;
  double get corridorHi => side * (1 - chuteEnd - clearance) - spriteWidth / 2;

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
