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

  /// The line each belt runs along. They are not the same line any more.
  ///
  /// The outbound belt sits lower, which opens up the top-right of the floor -
  /// the corner the run controls live in. It also costs the floor its
  /// symmetry, and costs the routing its simplest case: [route] treats two
  /// stations on one line as a straight walk, and the chute and the outbound
  /// belt are no longer on one line, so that journey is now an L through the
  /// corridor like any other change of row. Which is correct rather than
  /// merely acceptable - a straight line between them would drag the unit's
  /// footprint across the end of the intake belt.
  static const intakeAt = 0.42;

  /// Below the middle of the floor, which took untangling: the belt's depth was
  /// bounded by the *pallet* row, of all things.
  ///
  /// The unit standing at pallet 4 is 152dp wide, and its right shoulder used
  /// to reach under the outbound belt's left end - so the belt had to stop
  /// above the unit's head, and could not come down without the pallets coming
  /// down with it. Trading depth for the pallets' bottom margin ran out almost
  /// at once: reaching the middle of the floor that way left the rack 5dp off
  /// the bottom edge.
  ///
  /// What freed it was moving the rack far enough left that the unit never
  /// gets under the belt at all - see [palletLeft]. Horizontally clear, the
  /// two stop constraining each other and this number is free.
  static const outAt = 0.58;

  /// Where each belt meets the floor: the right end of the intake, the left
  /// end of the outbound. Placed so two and a half packages are on screen -
  /// enough to see what is coming and what just left, not enough to plan a
  /// whole shipment by reading it off the floor.
  static const chuteEnd = 0.235;

  /// How far past the edge of the square each rail carries on, so neither belt
  /// appears to stop at the panel.
  static const beltOff = 0.6;

  /// A package, and the pallet it sits on, as fractions of the side.
  ///
  /// The pallet is the package, the air above and left of it, and the corner
  /// its letter needs. One of each, not two: the package is tucked into the
  /// top-left rather than centred, so the two things sharing the square each
  /// get a corner instead of the letter having to clear a box in the middle.
  ///
  /// That is worth most of a centimetre. Centred, the same clearance had to
  /// exist on all four sides whether anything used it or not, and the square
  /// came to 51dp; this is 45dp. It has been 56 (the belt's whole thickness,
  /// which read as a crate the box sat *inside*) and 38 (a bare lip, with
  /// nowhere for a letter to go). Each of those was a number someone chose.
  /// This one is what the contents add up to.
  static const box = beltThickness * 0.59;
  static const pallet =
      box +
      palletPad +
      palletLabelGap +
      palletLabelPad +
      palletLabel * palletLabelAdvance;

  /// The air above and to the left of a package on a pallet.
  ///
  /// Small on purpose. It is not there to centre anything - the letter's
  /// corner does the balancing - it is there so the box does not sit on the
  /// lines of the square it stands in.
  static const palletPad = 0.006;

  /// Where the rack starts, measured from the left of the square.
  ///
  /// Its own number rather than the square's [pad], and currently a hair over
  /// it - which is not where it wants to be.
  ///
  /// It was twice the margin, so the rack read as standing on the floor rather
  /// than shoved against the wall. That is the nicer look and it is not what
  /// this is for any more: the ceiling here is whatever keeps the unit at
  /// pallet 4 clear of the outbound belt's left end, because the moment its
  /// shoulder reaches under that belt, the belt's depth is chained to the
  /// pallets' bottom margin and [outAt] cannot reach the middle of the floor.
  /// 0.048 is that ceiling; the belt being where it is costs 19dp here.
  ///
  /// Buying the look back means buying room on the right: a narrower rack, a
  /// narrower unit, or an outbound belt that starts further over - and the
  /// last of those drags the drop point off the edge of the square with it.
  ///
  /// Only the group moves. The spacing inside it is [palletGap] and is
  /// untouched by this.
  static const palletLeft = 0.048;

  /// Between one pallet and the next.
  ///
  /// Enough to see the two squares as two, and no more: they are a rack, and a
  /// rack is read as a group. Anything much wider and they stop being a group
  /// and become five things that happen to be in a line.
  static const palletGap = 0.014;

  /// The air between the package and its letter.
  ///
  /// A term of its own, because without one there is none: every other
  /// quantity in [pallet] is claimed by either the box or the letter, so the
  /// two ended up sharing an edge - not overlapping, which is what was checked,
  /// but touching, which looks like a mistake.
  static const palletLabelGap = 0.006;

  /// A pallet's letter: its size, how far it is tucked in from the corner, and
  /// how wide one character of it is.
  ///
  /// Smaller than a belt's [labelSize]: a belt label hangs in open floor, and
  /// this one has to share a square with a package.
  ///
  /// The advance is monospace's, which is what makes the reservation safe: a
  /// fixed-pitch face sets every glyph in 0.6 of its em, so the letter the
  /// painter measures is no wider than the cell reserved for it here. It is
  /// the one number in this file that is a fact about a font rather than about
  /// the floor, and [pallet] is sized from it - so a proportional face here
  /// would silently overrun the corner.
  static const palletLabel = 0.024;
  static const palletLabelPad = 0.006;
  static const palletLabelAdvance = 0.6;

  /// The air left under the pallet row, before the edge of the square.
  ///
  /// Much more than [pad], the margin the square keeps at its other three
  /// edges. This edge is different: the splitter is immediately below it, a
  /// couple of dp away, so anything close to the bottom reads as though it
  /// were printed on the divider rather than standing on the floor.
  ///
  /// The number grew when the letters moved *inside* the squares, because the
  /// air below the row did not change: it used to be this margin plus a
  /// label's height and its gap, and now the whole of it is margin.
  ///
  /// Then it shrank, to let the outbound belt down while the two were still
  /// tied together. They are not any more - see [outAt] - so this is free to
  /// grow again; it stays at 40dp because the low belt wants the pallets low
  /// with it, and 40 is still twice the margin the square keeps at its other
  /// three edges.
  static const palletFoot = 0.09;

  /// Where the pallet row sits.
  ///
  /// Derived from the foot rather than set by eye, so it cannot drift when the
  /// pallet changes size - which is exactly what happened last time it was
  /// touched. It was 0.805, and by then whatever was under the row had been
  /// squeezed to 7dp without anything noticing.
  static const palletTop = 1 - palletFoot - pallet;

  /// The unit's footprint, and the box its sprite is drawn in.
  ///
  /// It has grown three times. The wireframe version was a box with two drawn
  /// claws hanging below it, so the footprint had to allow for the reach; the
  /// sprite is contained in this square instead, which gave that room back.
  /// Then the belts got thinner, which gave more.
  ///
  /// It is the one thing on the floor with a face, so it earns the space: the
  /// belts and the pallets are furniture and read fine small, and the unit is
  /// what the player is actually watching.
  ///
  /// Two things bound it, and neither is close yet. Standing at a pallet the
  /// sprite reaches up toward the outbound belt and must not touch it, which
  /// leaves 0.09 of the floor spare here; and the corridor between the belt
  /// ends has to stay wide enough to walk through, which shuts at about 0.5.
  /// The collision test in test/floor_test.dart is what actually says so - it
  /// samples every journey, so it fails before a screenshot would show it.
  static const robot = 0.34;

  /// A label under a piece of furniture - INTAKE, OUTBOUND, a pallet letter -
  /// and the air between the two.
  static const labelSize = 0.036;
  static const labelGap = 0.018;

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

  double get labelHeight => side * labelSize;

  /// Where the *centre* of a label hanging under [bottom] goes.
  ///
  /// Derived from the label's own height, which is the whole point of it being
  /// here. Text is painted centred on the point it is given, so an offset
  /// smaller than half a label draws it *inside* the thing it labels - and at
  /// 0.012 against a 0.036 label, the pallet letters were sitting 0.006 up
  /// inside their own square, on the bottom stroke. Every belt label was fine
  /// on a hand-picked number that happened to be big enough, which is exactly
  /// the kind of luck that runs out when a size changes.

  double get _beltW => side * beltThickness;
  double get _intakeMid => side * intakeAt;
  double get _outMid => side * outAt;
  double get spriteWidth => side * robot;
  double get spriteHeight => spriteWidth / spriteAspect;

  /// A package on a belt, and the gap between two of them.
  double get boxSize => side * box;
  double get _step => boxSize + side * 0.008;

  /// The head of each queue stops short of the end of its belt by the same
  /// clearance it has along the sides, so a package sits in an even surround
  /// instead of pressed against the rail it arrived on.
  double get _lip => (_beltW - boxSize) / 2;

  double labelCentreUnder(double bottom) =>
      bottom + labelHeight / 2 + side * labelGap;

  double get palletLabelHeight => side * palletLabel;

  /// The cell kept for a pallet's letter: inside its own square, bottom-right,
  /// inset by [palletLabelPad].
  ///
  /// A reservation, not a measurement. Only the painter knows a glyph's real
  /// width, and it hangs the text off this cell's bottom-right corner - so a
  /// letter narrower than the reservation sits inside it, and the two cannot
  /// disagree about the inset. This is also what [pallet] is sized against,
  /// which is what keeps the letter off the package.
  Rect palletLabelSlot(int i) {
    final square = palletSlot(i);
    final inset = side * palletLabelPad;
    final height = palletLabelHeight;
    final width = height * palletLabelAdvance;
    return Rect.fromLTWH(
      square.right - inset - width,
      square.bottom - inset - height,
      width,
      height,
    );
  }

  Offset palletLabelAnchor(int i) => palletLabelSlot(i).bottomRight;

  /// Where a package sits on a pallet: tucked into the top-left, not centred.
  ///
  /// Every package on the floor is [boxSize]; this only decides where. Off
  /// centre because the square has two tenants - a box and a letter - and
  /// giving each a corner costs less room than centring one and making the
  /// other clear it.
  ///
  /// Every drawing of a package on a pallet goes through here, the still ones
  /// and the animated ones both. A transfer that used the square's centre
  /// while the resting box used this would land the box and then jump it.
  Rect palletPackage(int i) {
    final square = palletSlot(i);
    final inset = side * palletPad;
    return Rect.fromLTWH(
      square.left + inset,
      square.top + inset,
      boxSize,
      boxSize,
    );
  }

  Rect get intakeBelt => Rect.fromLTRB(
    side * -beltOff,
    _intakeMid - _beltW / 2,
    side * chuteEnd,
    _intakeMid + _beltW / 2,
  );

  Rect get outBelt => Rect.fromLTRB(
    side * (1 - chuteEnd),
    _outMid - _beltW / 2,
    side * (1 + beltOff),
    _outMid + _beltW / 2,
  );

  /// Slot 0 is the end nearest the unit on both belts; the queues run away from
  /// it in opposite directions.
  Rect intakeSlot(int i) => Rect.fromLTWH(
    intakeBelt.right - _lip - boxSize - i * _step,
    _intakeMid - boxSize / 2,
    boxSize,
    boxSize,
  );

  Rect outSlot(int i) => Rect.fromLTWH(
    outBelt.left + _lip + i * _step,
    _outMid - boxSize / 2,
    boxSize,
    boxSize,
  );

  /// A pallet is a package with a lip round it. See [pallet].
  ///
  /// Derived from the package, not chosen. It was once a constant of its own,
  /// and a package drawn to fit it came out a fifth bigger than the same
  /// package on a belt - so a box grew when it was set down and shrank when it
  /// was picked up. A package is one size everywhere; the furniture adapts.
  double get palletSide => side * pallet;

  /// A row of pallets packed together at [palletLeft], a [palletGap] apart.
  ///
  /// They used to be spread across the whole width with their ends flush to
  /// the margins, on the idea that the floor should read as one grid. It read
  /// as five separate places instead: the gaps came out wider than the pallets
  /// themselves, so nothing said the five belonged together.
  ///
  /// Packed, they are one rack. The empty floor that leaves on the right is
  /// not waste - it is the room the unit crosses to reach the outbound belt,
  /// and a rack the player can take in at a glance is worth more than a row
  /// that fills the width.
  Rect palletSlot(int i) {
    final size = palletSide;
    return Rect.fromLTWH(
      side * palletLeft + i * (size + side * palletGap),
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
  double get chuteFeet => intakeBelt.top - side * clearance;
  double get outFeet => outBelt.top - side * clearance;
  double get palletFeet => palletSlot(0).top - side * clearance;

  /// Where the unit stands to work on something. This is its *ground line* -
  /// where the casters touch - not the middle of its sprite.
  Offset stand(Station at) => switch (at.kind) {
    // Mid-floor, between the two belts. Only ever the starting position.
    // Home is on the intake's line: it is only ever where a shift starts, and
    // the first thing any shift does is TAKE.
    StationKind.home => Offset(side / 2, chuteFeet),
    StationKind.chute => Offset(intakeSlot(0).center.dx, chuteFeet),
    StationKind.outbound => Offset(outSlot(0).center.dx, outFeet),
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

  /// A package changing hands between a claw and a place on the floor.
  ///
  /// [outward] is the direction: true when the unit is setting the package
  /// down, false when it is picking one up. It is a named parameter rather than
  /// an argument order because getting it backwards is silent and specific -
  /// the package parks on the slot for the near half of the instruction, which
  /// reads at once as the value arriving early *and* as an empty claw. Both
  /// halves of the same swap.
  ///
  /// The claw spends the near half of an instruction reaching, so the package
  /// holds still and then travels with it. Setting down is the mirror: carried
  /// the whole way, released at the end. Neither animation has a keyframe for
  /// the last of it, because a belt slot is not the sprite's business.
  Offset transfer({
    required Offset claw,
    required Offset slot,
    required bool outward,
    required double act,
  }) {
    final u = outward
        ? ((act - 0.5) / 0.5).clamp(0.0, 1.0)
        : (act / 0.5).clamp(0.0, 1.0);
    return outward ? Offset.lerp(claw, slot, u)! : Offset.lerp(slot, claw, u)!;
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

  /// How far the unit walks between two stations, along the route it takes.
  ///
  /// In side-units, so it is the same number on every screen - which is what
  /// lets a walking speed be stated once and mean the same thing on a phone and
  /// on a tablet.
  double routeLength(Station from, Station to) {
    final path = route(stand(from), stand(to));
    var total = 0.0;
    for (var i = 1; i < path.length; i++) {
      total += (path[i] - path[i - 1]).distance;
    }
    return total;
  }

  /// Where the unit is, [u] of the way from one station to another.
  Offset walkBetween(Station from, Station to, double u) =>
      walked(route(stand(from), stand(to)), u);
}
