/// UNIT-02, drawn properly.
///
/// The first floor drew it as a box with two claws, which was enough to judge
/// the *layout* - where it stands, what it can reach - and is no use at all for
/// judging whether the thing has any character. These are the real sprites,
/// from Animations/, so that question can be looked at now rather than after
/// everything else is finished.
///
/// Which one plays is a function of the two states either side of an
/// instruction: is it moving, is it carrying, is it picking something up. The
/// machine already knows all three, so nothing here decides anything - it only
/// chooses a file.
library;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'floor_geometry.dart';

/// What the unit is doing, as far as the animation is concerned.
enum UnitPose {
  idle,
  holding,
  walking,
  walkingHolding,

  /// The grab. A one-shot, driven by the instruction rather than looping.
  pickup,

  /// Setting a package down: the grab, played backwards. The same file driven
  /// from the far end - which is what putting a thing down *is*, and cheaper
  /// than an animation that would only ever be the reverse of one we have.
  putdown,

  /// Working on what it is holding: SUM and SUB. Named for the merge it was
  /// drawn for, which was the same gesture in an earlier design - two things
  /// becoming one.
  merge,
}

extension on UnitPose {
  String get asset => switch (this) {
    UnitPose.idle => 'assets/animations/delivery-robot-idle.json',
    UnitPose.holding => 'assets/animations/delivery-robot-holding.json',
    UnitPose.walking => 'assets/animations/delivery-robot-walking.json',
    UnitPose.walkingHolding =>
      'assets/animations/delivery-robot-walking-holding.json',
    UnitPose.pickup ||
    UnitPose.putdown => 'assets/animations/delivery-robot-pickup.json',
    UnitPose.merge => 'assets/animations/delivery-robot-merge.json',
  };

  /// The loops run themselves; the grab and its reverse are driven, so that
  /// the moment the box leaves the belt is the moment the claws close on it
  /// rather than whenever the loop happened to be.
  bool get loops => switch (this) {
    UnitPose.pickup || UnitPose.putdown || UnitPose.merge => false,
    UnitPose.idle ||
    UnitPose.holding ||
    UnitPose.walking ||
    UnitPose.walkingHolding => true,
  };
}

/// The unit, drawn at whatever it is doing.
///
/// Never mirrored, in either axis. The unit faces the camera by design - that
/// is what the art is - so a flip would turn it round to show a back that does
/// not exist. Direction of travel is carried by the walk cycle instead.
class UnitSprite extends StatelessWidget {
  const UnitSprite({super.key, required this.pose, this.driver});

  final UnitPose pose;

  /// Progress for the driven poses. Ignored by the looping ones.
  final Animation<double>? driver;

  @override
  Widget build(BuildContext context) {
    // A loop that never ends is a frame that is always scheduled, which is
    // exactly what a reduced-motion setting is asking us not to do - and, less
    // philosophically, what makes `pumpAndSettle` hang forever. Held on its
    // first frame instead, so the unit is still there, just still.
    final still = MediaQuery.disableAnimationsOf(context);
    final loop = pose.loops && !still;

    return Lottie.asset(
      pose.asset,
      controller: pose.loops ? null : driver,
      animate: loop,
      repeat: loop,
      // Contained in the unit's own square, so the art can never reach further
      // than the footprint the collision rule is written against. The sprites
      // are 300x240, so this letterboxes rather than crops - a wider box would
      // let an arm overhang a belt the body is clear of.
      fit: BoxFit.contain,
      // The frame it holds on before the first real frame arrives. Without it
      // the unit blinks out of existence every time the pose changes.
      addRepaintBoundary: true,
    );
  }
}

/// Places a [UnitSprite] on the floor.
///
/// The sprite is a widget and everything else on the floor is painted, so it
/// goes in the middle of a three-layer stack: ground below it, cargo above.
/// Above matters - a package has a number on it, and the number is the game.
class UnitOnFloor extends StatelessWidget {
  const UnitOnFloor({
    super.key,
    required this.geometry,
    required this.at,
    required this.pose,
    this.driver,
  });

  final FloorGeometry geometry;
  final Offset at;
  final UnitPose pose;
  final Animation<double>? driver;

  @override
  Widget build(BuildContext context) {
    final box = geometry.body(at);
    return Positioned(
      left: box.left,
      top: box.top,
      width: box.width,
      height: box.height,
      child: UnitSprite(pose: pose, driver: driver),
    );
  }
}
