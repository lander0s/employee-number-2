// The floor's geometry, and the one rule that is easy to break by accident.
//
// The unit must never walk through a conveyor. That was true of the first
// version by luck - it stood in one place - and false the moment it started
// walking, because the direct line from the chute to pallet 0 crosses the
// intake belt. It is geometry rather than drawing, so it can be checked without
// a canvas, which is why lib/ui/floor/floor_geometry.dart exists as its own
// file.

import 'package:flutter_test/flutter_test.dart';
import 'package:gameplay_ux/model/commands.dart';
import 'package:gameplay_ux/model/vm.dart';
import 'package:gameplay_ux/ui/floor/floor_geometry.dart';
import 'package:gameplay_ux/ui/floor/payload.dart';

/// A realistic square: the panel is 448dp wide on the device this is built on.
const g = FloorGeometry(448);

/// Every place the unit can be sent.
List<Station> everywhere() => [
  Station.start,
  const Station(StationKind.chute),
  const Station(StationKind.outbound),
  for (var i = 0; i < palletCount; i++) Station(StationKind.pallet, i),
];

String name(Station s) =>
    s.kind == StationKind.pallet ? 'pallet ${s.pallet}' : s.kind.name;

void main() {
  group('the unit never walks through a belt', () {
    test('on any journey between any two stations', () {
      // Sampled densely rather than at the corners: the corners are the part
      // that is obviously fine, and a route that clipped a belt would do it
      // half way along a leg.
      for (final from in everywhere()) {
        for (final to in everywhere()) {
          for (var i = 0; i <= 200; i++) {
            final at = g.walkBetween(from, to, i / 200);
            final unit = g.sweep(at);
            expect(
              unit.overlaps(g.intakeBelt),
              isFalse,
              reason: '${name(from)} -> ${name(to)} at ${i / 200}: intake',
            );
            expect(
              unit.overlaps(g.outBelt),
              isFalse,
              reason: '${name(from)} -> ${name(to)} at ${i / 200}: outbound',
            );
          }
        }
      }
    });

    test('measured on the art, not just the body', () {
      // These were different when the unit was a box with drawn claws hanging
      // below it: the body cleared the belt and the claws swept the rollers.
      // The sprite is contained in its square so they coincide again, and the
      // check is written against [sweep] so that it survives art that is not.
      final standing = g.stand(const Station(StationKind.chute));
      expect(g.sweep(standing).overlaps(g.intakeBelt), isFalse);
      expect(
        g.sweep(standing).bottom,
        lessThanOrEqualTo(g.intakeBelt.top),
        reason: 'the unit should stop at the belt, not stand on it',
      );
    });
  });

  group('the route', () {
    test('is a straight line when the row does not change', () {
      // Chute to outbound runs along the belt row, which is clear above both
      // belts - so there is nothing to route around and no corner to turn.
      final path = g.route(
        g.stand(const Station(StationKind.chute)),
        g.stand(const Station(StationKind.outbound)),
      );
      expect(path, hasLength(2));
    });

    test('turns two corners when it does', () {
      final path = g.route(
        g.stand(const Station(StationKind.chute)),
        g.stand(const Station(StationKind.pallet, 0)),
      );
      expect(path, hasLength(4));
      // The crossing happens in the corridor between the belt ends, at one x.
      expect(path[1].dx, path[2].dx);
      expect(path[1].dx, greaterThanOrEqualTo(g.corridorLo));
      expect(path[1].dx, lessThanOrEqualTo(g.corridorHi));
    });

    test('drops straight down when it is already over the corridor', () {
      // Home is mid-floor, which is clear of both belts, so the unit should not
      // sidestep before setting off.
      final home = g.stand(Station.start);
      final path = g.route(home, g.stand(const Station(StationKind.pallet, 2)));
      expect(path[1].dx, home.dx, reason: 'no detour was needed');
    });
  });

  group('the sprite sits where the art says it does', () {
    test('its wheels are on the station, not its middle', () {
      // Animations/README.md puts the casters at 81.25% down the comp. The
      // sprite was fitted into a square instead, which letterboxed it and left
      // 18.75% of empty canvas below the wheels - so the unit floated most of a
      // body above whatever it was standing next to, and every published hand
      // coordinate was that far out.
      final feet = g.stand(const Station(StationKind.chute));
      final box = g.body(feet);
      expect(box.bottom, greaterThan(feet.dy), reason: 'canvas below the wheels');
      expect(
        (feet.dy - box.top) / box.height,
        closeTo(FloorGeometry.groundLine, 0.001),
      );
    });

    test('and the box keeps the composition aspect, so nothing letterboxes', () {
      // BoxFit.fill maps 300x240 onto this one-to-one. Any other aspect shifts
      // the art inside its box and puts the payload slots somewhere the floor
      // cannot predict.
      final box = g.body(g.stand(Station.start));
      expect(box.width / box.height, closeTo(FloorGeometry.spriteAspect, 0.001));
    });

    test('the grip is at chest height, above the belt it works', () {
      final feet = g.stand(const Station(StationKind.chute));
      final grip = g.handAt(feet, Payload.grip);
      expect(grip.dx, closeTo(feet.dx, 0.01), reason: 'centred');
      expect(grip.dy, lessThan(g.intakeBelt.top), reason: 'held clear of it');
      expect(grip.dy, lessThan(feet.dy), reason: 'above its own wheels');
    });

    test("the pickup's grab point reaches the ground line", () {
      // Which is what lets a package be met at the belt rather than snatched
      // out of the air: the claw comes down to where the unit is standing.
      final feet = g.stand(const Station(StationKind.chute));
      final grab = g.handAt(feet, Payload.pickup.at(0));
      expect(grab.dy, closeTo(feet.dy, g.side * 0.005));
    });
  });

  group('the payload tracks follow what was authored', () {
    test('pickup waits at the grab point, then rises to the grip', () {
      expect(Payload.pickup.at(0), Payload.pickup.at(0.4));
      expect(Payload.pickup.at(1), Payload.grip);
      // Still down at the end of the dwell, well up by the end.
      expect(Payload.pickup.at(0.58).dy, greaterThan(150));
      expect(Payload.pickup.at(0.9).dy, lessThan(130));
    });

    test('the easing is not linear, which the README insists on', () {
      // Segment 5 to 6 accelerates hard into the merge impact. Sampled at its
      // midpoint, an eased path is nowhere near the linear halfway point - and
      // the README says lerping desyncs worst exactly here.
      final a = Payload.mergeA.at(0.68);
      final b = Payload.mergeA.at(0.79);
      final mid = Payload.mergeA.at((0.68 + 0.79) / 2);
      final linear = Offset.lerp(a, b, 0.5)!;
      expect((mid - linear).distance, greaterThan(4));
    });

    test('the two operands take different paths, one per hand', () {
      // The only state where the hands do different things, which is what
      // makes it the arithmetic gesture: A is already held, B is picked up off
      // the floor, and they meet.
      expect(Payload.mergeA.at(0), Payload.grip, reason: 'A starts held');
      expect(
        Payload.mergeB.at(0).dy,
        greaterThan(180),
        reason: 'B starts on the floor',
      );

      // They are on opposite sides of the unit through the wind-up, and both
      // arrive at the middle for the impact.
      final windA = Payload.mergeA.at(0.68);
      final windB = Payload.mergeB.at(0.68);
      expect(windA.dx, greaterThan(Payload.grip.dx));
      expect(windB.dx, lessThan(Payload.grip.dx));

      final hitA = Payload.mergeA.at(0.79);
      final hitB = Payload.mergeB.at(0.79);
      expect((hitA - hitB).distance, lessThan(30), reason: 'they collide');
    });

    test('and both go on the frame the result arrives', () {
      expect(Payload.mergeA.alphaAt(0.95), 0);
      expect(Payload.mergeB.alphaAt(0.95), 0);
      expect(Payload.mergeResult.alphaAt(0.95), 1);
    });

    test('opacity steps rather than fading', () {
      // A is visible until the impact and gone after it; the result is the
      // other way round. Nobody drew a cross-fade, so nobody should invent one.
      expect(Payload.mergeA.alphaAt(0.5), 1);
      expect(Payload.mergeA.alphaAt(0.95), 0);
      expect(Payload.mergeResult.alphaAt(0.5), 0);
      expect(Payload.mergeResult.alphaAt(0.95), 1);
    });

    test('a fixed slot never moves', () {
      const still = Payload.fixed(Payload.grip);
      expect(still.at(0), Payload.grip);
      expect(still.at(0.5), Payload.grip);
      expect(still.at(1), Payload.grip);
    });
  });

  group('walking is paced by distance', () {
    test('so a short leg does not take as long as a long one', () {
      // A 10-unit sidestep followed by a 100-unit march. Half way *by
      // distance* is 55 along, deep into the second leg. Interpolating per
      // segment would put it at 10 - the corner - having spent half the walk
      // on a tenth of the journey, which is the unit sprinting round the bend.
      final path = [
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(110, 0),
      ];
      expect(FloorGeometry.walked(path, 0.5).dx, closeTo(55, 0.01));
    });

    test('and the ends are exact', () {
      final path = g.route(
        g.stand(const Station(StationKind.outbound)),
        g.stand(const Station(StationKind.pallet, 4)),
      );
      expect(FloorGeometry.walked(path, 0), path.first);
      expect(FloorGeometry.walked(path, 1), path.last);
    });

    test('and standing still is not a journey', () {
      final at = g.stand(const Station(StationKind.chute));
      expect(FloorGeometry.walked([at, at], 0.5), at);
    });
  });

  group('a package changes hands in the right direction', () {
    // Getting this backwards is silent and specific, and it produced two
    // complaints that turned out to be one bug: the package parked on the slot
    // for the near half of the instruction, which reads at once as the value
    // arriving early and as the claw being empty.
    const claw = Offset(200, 100);
    const slot = Offset(200, 300);

    test('picking up: it waits on the slot, then rides the claw', () {
      Offset at(double act) =>
          g.transfer(claw: claw, slot: slot, outward: false, act: act);

      expect(at(0), slot, reason: 'still where it was');
      expect(at(0.25).dy, greaterThan(claw.dy), reason: 'on its way');
      expect(at(0.5), claw, reason: 'in hand by the halfway mark');
      expect(at(1), claw, reason: 'and stays there');
    });

    test('setting down: it rides the claw, then lands on the slot', () {
      Offset at(double act) =>
          g.transfer(claw: claw, slot: slot, outward: true, act: act);

      expect(at(0), claw, reason: 'carried');
      expect(at(0.5), claw, reason: 'still carried at the halfway mark');
      expect(at(0.75).dy, greaterThan(claw.dy), reason: 'being let go');
      expect(at(1), slot, reason: 'down');
    });

    test('the two directions are mirrors', () {
      // Which is the whole point of the parameter. Not at 0.5 though: that is
      // the crossover, where an inward transfer has just arrived in the claw
      // and an outward one has not yet let go, so both have the package in
      // hand. It is the one moment the two directions agree.
      for (final act in [0.1, 0.3, 0.7, 0.9]) {
        final out = g.transfer(
          claw: claw,
          slot: slot,
          outward: true,
          act: act,
        );
        final into = g.transfer(
          claw: claw,
          slot: slot,
          outward: false,
          act: act,
        );
        expect(out, isNot(into), reason: 'act $act');
      }

      expect(
        g.transfer(claw: claw, slot: slot, outward: true, act: 0.5),
        g.transfer(claw: claw, slot: slot, outward: false, act: 0.5),
        reason: 'both hold it at the crossover',
      );
    });
  });

  group('a package is one size, everywhere', () {
    test('on a belt, in the claws, and on a pallet', () {
      // It was not: the pallet was a constant a fifth larger than a belt is
      // thick, and a box drawn to fit it came out a fifth bigger - so a package
      // grew when it was set down and shrank when it was picked up.
      final onBelt = g.intakeSlot(0);
      final onOutbound = g.outSlot(2);
      final inClaws = g.packageAt(
        g.handAt(g.stand(Station.start), Payload.grip),
      );
      final onPallet = g.packageAt(g.palletSlot(3).center);

      for (final it in [onBelt, onOutbound, inClaws, onPallet]) {
        expect(it.width, closeTo(g.boxSize, 0.001));
        expect(it.height, closeTo(g.boxSize, 0.001));
      }
    });

    test('a pallet is furniture and is bigger than what sits on it', () {
      // Which is exactly why a transfer has to interpolate the package's
      // *centre* and build the rect once: lerping the rects instead
      // interpolates their size, and starting from the pallet square swelled
      // the box to the pallet's size on its way out of it.
      expect(g.palletSlot(0).width, greaterThan(g.boxSize));
      expect(
        g.packageAt(g.palletSlot(0).center).width,
        closeTo(g.boxSize, 0.001),
      );
    });

    test('and a pallet gives it the surround a belt does', () {
      // Which is why the pallet is derived from the package rather than the
      // other way round.
      expect(g.palletSide, closeTo(g.side * FloorGeometry.beltThickness, 0.001));
      expect(g.palletSide, greaterThan(g.boxSize));
    });

    test('a package on a pallet sits inside it', () {
      for (var i = 0; i < palletCount; i++) {
        final slot = g.palletSlot(i);
        final box = g.packageAt(slot.center);
        expect(slot.contains(box.topLeft), isTrue, reason: 'pallet $i');
        expect(slot.contains(box.bottomRight), isTrue, reason: 'pallet $i');
      }
    });
  });

  group('the floor is laid out where the unit expects', () {
    test('a station is directly over the thing it works on', () {
      expect(
        g.stand(const Station(StationKind.chute)).dx,
        closeTo(g.intakeSlot(0).center.dx, 0.01),
      );
      expect(
        g.stand(const Station(StationKind.outbound)).dx,
        closeTo(g.outSlot(0).center.dx, 0.01),
      );
      for (var i = 0; i < palletCount; i++) {
        expect(
          g.stand(Station(StationKind.pallet, i)).dx,
          closeTo(g.palletSlot(i).center.dx, 0.01),
          reason: 'pallet $i',
        );
      }
    });

    test('and the pallet row is clear of the unit standing over it', () {
      for (var i = 0; i < palletCount; i++) {
        final standing = g.sweep(g.stand(Station(StationKind.pallet, i)));
        expect(
          standing.bottom,
          lessThanOrEqualTo(g.palletSlot(i).top),
          reason: 'pallet $i',
        );
      }
    });

    test('both belts run off the square', () {
      // Which is the whole reason the corridor is the only crossing: there is
      // no way round either end.
      expect(g.intakeBelt.left, lessThan(0));
      expect(g.outBelt.right, greaterThan(g.side));
    });
  });
}
