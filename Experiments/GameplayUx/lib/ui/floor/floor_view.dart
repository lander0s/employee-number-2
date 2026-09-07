/// The floor, seen from above. Wireframe primitives, no art.
///
/// Everything the machine can observe is on it: the intake belt running in from
/// off-screen left, the outbound belt running out off-screen right, five
/// pallets across the bottom, and UNIT-02 working between them.
///
/// Both belts deliberately leave the square. A shipment is not a list of six,
/// it is a queue arriving from the rest of a warehouse the player never sees,
/// and rails that run off the edge of the panel say that where two tidy columns
/// of boxes say the opposite. That is the whole world (game-design-document
/// 6.1), and drawing it as boxes and lines first is the cheapest way to find
/// out whether the *layout* reads before anything is drawn properly.
///
/// It moves. The unit walks to whatever it is working on and packages travel
/// between the positions they held on either side of an instruction, which
/// means the floor needs both states and cannot work from a single snapshot -
/// see [FloorStage]. Where things are, and the route between them, is
/// [FloorGeometry].
library;

import 'package:flutter/material.dart';

import '../../model/commands.dart';
import '../../model/level.dart';
import '../../model/vm.dart';
import '../run_controller.dart';
import '../wireframe.dart';
import 'floor_geometry.dart';
import 'payload.dart';
import 'unit_sprite.dart';

/// How long one instruction's movement takes.
///
/// Shorter than [RunController.stepHold], so every movement lands and then
/// rests. Continuous motion would read as a conveyor that never stops, which is
/// a different machine from this one: UNIT-02 does one thing at a time, and the
/// stillness between things is how you see what it did.
///
/// It is *longer* than [RunController.freeHold], and that is fine: a branch
/// moves nothing, so there is no movement of its own to cut short.
///
/// Sized so the act phase lands near the pickup animation's own length - 70
/// frames at 60fps, so about 1.2 seconds. Drive a one-shot much faster than it
/// was drawn and the gesture is a blur; the reason to slow the whole run down
/// was to stop that happening.
const _travel = Duration(milliseconds: 2400);

/// The instruction is in two phases: the unit walks, then it acts.
///
/// One phase would have the package leave the belt while the unit was still
/// crossing the floor towards it - a box teleporting into claws that had not
/// arrived. Splitting it means the walk finishes first and the hand-over
/// happens where the unit is standing, which is the order these things happen
/// in. It is also why nothing about a package's position is written down: it is
/// wherever the claws are, and the claws are wherever the walk got to.
const _walkPhase = 0.6;

/// Everything on the floor at one instant.
class FloorState {
  const FloorState({
    required this.intake,
    required this.claws,
    required this.outbound,
    required this.pallets,
    required this.station,
    required this.op,
  });

  FloorState.of(Tick tick)
    : intake = tick.intake,
      claws = tick.claws,
      outbound = tick.outbound,
      pallets = tick.pallets,
      station = tick.station,
      op = tick.op;

  /// The batch as it arrived, before a program has touched it. Also what the
  /// floor shows while the player is still writing: the shipment is the
  /// question, and it should be readable the whole time.
  FloorState.waiting(Level level)
    : intake = level.intake,
      claws = null,
      outbound = const [],
      pallets = const [],
      station = Station.start,
      // Nothing has run, so nothing is being done. A jump is the machine's own
      // bookkeeping and the unit does not act on one, which makes it the right
      // stand-in for "no instruction at all".
      op = Op.jump;

  final List<int> intake;
  final int? claws;
  final List<int> outbound;
  final List<int?> pallets;

  /// Where the unit is standing. The floor walks it between the two states.
  final Station station;

  /// What it is doing. The pose comes from this rather than from comparing the
  /// two states, because `COPY FROM` and `SUB` look identical from outside.
  final Op op;
}

/// Drives the floor's animation off a [RunController].
///
/// The controller advances in steps - one instruction, then a pause - so it
/// cannot drive movement on its own. This restarts a short travel animation
/// whenever the instruction on screen changes, and hands the painter the two
/// states with a position between them.
class FloorStage extends StatefulWidget {
  const FloorStage({super.key, required this.level, required this.run});

  final Level level;
  final RunController run;

  @override
  State<FloorStage> createState() => _FloorStageState();
}

class _FloorStageState extends State<FloorStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: _travel,
  );

  /// The instruction the current animation belongs to.
  int _showing = -1;

  /// The act phase on its own, for driving the grab.
  ///
  /// It stops a thousandth short of the end on purpose: a Lottie layer's out
  /// point is *exclusive*, so driving a 70-frame composition to exactly 1.0
  /// asks for frame 70 - one past the last frame the layer exists on.
  late final Animation<double> _act = Tween<double>(
    begin: 0,
    end: 0.999,
  ).animate(_actPhase);

  /// The same, from the far end: putting a package down is the grab in
  /// reverse, so it is the same composition read backwards.
  late final Animation<double> _actBack = Tween<double>(
    begin: 0.999,
    end: 0,
  ).animate(_actPhase);

  late final Animation<double> _actPhase = CurvedAnimation(
    parent: _anim,
    curve: const Interval(_walkPhase, 1),
  );

  @override
  void initState() {
    super.initState();
    widget.run.addListener(_onRun);
  }

  @override
  void dispose() {
    widget.run.removeListener(_onRun);
    _anim.dispose();
    super.dispose();
  }

  void _onRun() {
    if (!mounted) return;
    final cursor = widget.run.cursor;
    if (cursor != _showing) {
      _showing = cursor;
      // From zero every time rather than continuing: each instruction is its
      // own movement, and one that started late should not finish early.
      _anim.forward(from: 0);
    }
    setState(() {});
  }

  /// Ground, then the unit, then cargo.
  ///
  /// The unit is a widget and everything else is painted, so it has to be a
  /// layer rather than a draw call. Cargo goes on top of it deliberately: a
  /// package carries a number and the number is the game, so it must never end
  /// up behind an arm.
  Widget _layers(FloorGeometry g, FloorState from, FloorState to, double t) {
    // Linear, deliberately: a package on a belt is being carried at the belt's
    // speed, and the unit walks at the unit's. Easing either would be the thing
    // deciding for itself when to set off and when to stop.
    final walk = (t / _walkPhase).clamp(0.0, 1.0);
    final at = g.walkBetween(from.station, to.station, walk);

    final moving = from.station != to.station;
    final took = from.intake.length - to.intake.length == 1;

    // What it is carrying depends on which phase this is, not just on where the
    // instruction ended: during the walk it still has whatever it set off with.
    //
    // That distinction is the whole of it for SHIP. The instruction ends with
    // empty claws, so a single `to.claws` reading walked the unit across the
    // floor empty-handed with a numbered box stuck to it, and then set nothing
    // down. It carries the box over, and puts it down.
    final carrying = (t < _walkPhase ? from.claws : to.claws) != null;

    // Every acting pose is a transient: it plays while the instruction is in
    // flight and gives way to the resting pose the moment it lands. A one-shot's
    // last frame is the end of a movement, not a pose to stand in.
    final settled = t >= 1;
    final resting = carrying ? UnitPose.holding : UnitPose.idle;

    final pose = moving && t < _walkPhase
        ? (carrying ? UnitPose.walkingHolding : UnitPose.walking)
        : settled
        ? resting
        : switch (to.op) {
            // Guarded on the delta: a TAKE that finds the chute empty walks
            // over and finds nothing, so there is no grab to play.
            Op.take when took => UnitPose.pickup,
            Op.copyFrom => UnitPose.pickup,
            Op.ship || Op.copyTo => UnitPose.putdown,
            Op.sum || Op.sub => UnitPose.merge,
            // A condition is the one instruction the unit does not act on.
            Op.take || Op.branchUnless || Op.jump => resting,
          };

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _Floor(from: from, to: to, t: t, layer: _Layer.ground),
          ),
        ),
        UnitOnFloor(
          geometry: g,
          at: at,
          pose: pose,
          driver: pose == UnitPose.putdown ? _actBack : _act,

          // COPY TO leaves the package in the claws as well as on the pallet,
          // so unlike SHIP the reverse-grab must not end empty-handed - which
          // it does not, because `carrying` still reads true afterwards.
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _Floor(from: from, to: to, t: t, layer: _Layer.cargo),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.run.now;
    final before = widget.run.previous;

    final to = now == null
        ? FloorState.waiting(widget.level)
        : FloorState.of(now);

    // Falling back to the waiting state is what makes the very first
    // instruction animate: a TAKE on the first tick travels from the shipment
    // as it arrived, rather than appearing in the claws.
    final from = before != null
        ? FloorState.of(before)
        : (now == null ? to : FloorState.waiting(widget.level));

    return LayoutBuilder(
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
              child: AnimatedBuilder(
                animation: _anim,
                builder: (context, _) =>
                    _layers(FloorGeometry(side), from, to, _anim.value),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Which pass of the floor is being drawn. See [_FloorStageState._layers].
enum _Layer { ground, cargo }

class _Floor extends CustomPainter {
  _Floor({
    required this.from,
    required this.to,
    required this.t,
    required this.layer,
  });

  final FloorState from;
  final FloorState to;
  final _Layer layer;

  /// 0 at the previous instruction, 1 at this one.
  final double t;

  /// How far a binned package falls before it is gone.
  static const _binDrop = 0.13;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final g = FloorGeometry(s);

    // The walk finishes before the hand-over starts. Everything a package does
    // is measured against [act]; everything the unit does, against [walk].
    final walk = (t / _walkPhase).clamp(0.0, 1.0);
    final act = ((t - _walkPhase) / (1 - _walkPhase)).clamp(0.0, 1.0);

    final feet = g.walkBetween(from.station, to.station, walk);

    // Where the unit's hands are, per the authored payload slots. Everything it
    // is carrying hangs off this rather than off the middle of the sprite.
    Offset hand(Payload slot, double u) => g.handAt(feet, slot.at(u));

    final grip = hand(const Payload.fixed(Payload.grip), 0);
    final held = g.packageAt(grip);

    // Every package position below is interpolated as a *centre* and turned
    // into a rect once, at the end. Lerping the rects instead interpolates
    // their size too, and the moment one of the endpoints was a piece of
    // furniture - a pallet square rather than a package on it - a box swelled
    // to the size of the pallet on its way out of it.
    Rect between(Offset a, Offset b, double u) =>
        g.packageAt(Offset.lerp(a, b, u)!);

    if (layer == _Layer.ground) {
      _grid(canvas, s);
      _rail(canvas, g.intakeBelt, 'INTAKE', g.intakeSlot(0), s);
      _rail(canvas, g.outBelt, 'OUTBOUND', g.outSlot(0), s);
      _pallets(canvas, g);
      return;
    }

    // What the instruction did, read off the two states rather than passed in.
    // The machine already recorded the result; asking it to also describe the
    // movement would be two sources for one fact.
    final took = from.intake.length - to.intake.length == 1;
    final shipped = to.outbound.length - from.outbound.length == 1;
    final binned = took && from.claws != null;

    // The hand path this instruction's cargo rides, and how far along it is.
    // `putdown` is the grab read backwards, which is what setting a thing down
    // is - the same slot, the same easing, the other way.
    final (Payload slot, double u) = switch (to.op) {
      Op.take when took => (Payload.pickup, act),
      Op.copyFrom => (Payload.pickup, act),
      Op.ship || Op.copyTo => (Payload.pickup, 1 - act),
      Op.sum || Op.sub => (Payload.mergeA, act),
      _ => (const Payload.fixed(Payload.grip), 0),
    };
    final onHandAt = hand(slot, u);
    final onHand = g.packageAt(onHandAt);

    // -------------------------------------------------------------- intake
    //
    // Everything still on the belt slides one slot closer when a package comes
    // off the front, which is what a conveyor does.
    for (var i = 0; i < to.intake.length; i++) {
      final rect = between(
        g.intakeSlot(i + (took ? 1 : 0)).center,
        g.intakeSlot(i).center,
        act,
      );
      if (rect.right < 0) break;
      _package(canvas, rect, to.intake[i]);
    }

    // ------------------------------------------------------------ outbound
    final added = shipped ? 1 : 0;
    for (var i = 0; i < to.outbound.length; i++) {
      // Drawn head-first from the drop point, and the head is the *newest*:
      // the first thing shipped is furthest away, already off the edge.
      final value = to.outbound[to.outbound.length - 1 - i];
      final rect = i == 0 && shipped
          // Carried in the claws for the whole walk, then lowered by the hand
          // and released onto the belt. The hand only takes it most of the way
          // - the last of it is the box settling into its slot, which the
          // animation has no keyframe for because the belt is not its business.
          ? between(onHandAt, g.outSlot(0).center, _release(act))
          : between(g.outSlot(i - added).center, g.outSlot(i).center, act);
      if (rect.left > s) break;
      _package(canvas, rect, value);
    }

    // --------------------------------------------------------------- claws
    if (to.claws != null) {
      final arriving = took || to.op == Op.copyFrom;
      // The package's own place, not the slot's: a pallet square is bigger
      // than a package, and starting a transfer from it made the box grow.
      final source = took
          ? g.intakeSlot(0).center
          : g.palletSlot(to.station.pallet).center;

      // Arriving cargo starts where it was and meets the claw as it closes;
      // after that it is the hand's. Anything already held just rides.
      //
      // The result of an arithmetic instruction is the exception: it does not
      // exist until the impact, so it appears at the grip on the beat the
      // animation says it does.
      final rect = switch (to.op) {
        Op.sum || Op.sub => held,
        _ when arriving => between(source, onHandAt, _grasp(act)),
        _ => onHand,
      };
      final fade = switch (to.op) {
        Op.sum || Op.sub => 1 - Payload.mergeResult.alphaAt(act),
        _ => 0.0,
      };
      _package(canvas, rect, to.claws!, fade: fade);
    }

    // Arithmetic is the one instruction with two operands, and the merge is the
    // one animation where the hands do different things - so both are on
    // screen, one per claw, and they disappear together on the frame the result
    // appears. Their opacities are authored, not invented.
    if (to.op == Op.sum || to.op == Op.sub) {
      // A: what it was already holding, in the right claw.
      if (from.claws != null) {
        _package(
          canvas,
          onHand,
          from.claws!,
          fade: 1 - Payload.mergeA.alphaAt(act),
        );
      }

      // B: the operand, read off its pallet and lifted by the left claw.
      //
      // The pallet keeps its own copy - SUM and SUB read a pallet, they do not
      // empty it - so [_pallets] still draws it and for a moment the two sit on
      // top of each other. That is the point: the box lifting away from the one
      // left behind is what "read" looks like.
      final operand = to.station.kind == StationKind.pallet
          ? to.pallets.elementAtOrNull(to.station.pallet)
          : null;
      if (operand != null) {
        _package(
          canvas,
          between(
            g.palletSlot(to.station.pallet).center,
            hand(Payload.mergeB, act),
            _grasp(act),
          ),
          operand,
          fade: 1 - Payload.mergeB.alphaAt(act),
        );
      }
    }

    // ----------------------------------------------------------------- bin
    //
    // TAKE with full claws destroys what was held (game-design-document 6.3).
    // The docs are insistent that this must not be silent, and a box dropping
    // out of frame is the least this can do until there is a bin to drop it
    // into and a sound to go with it.
    if (binned) {
      _package(
        canvas,
        between(grip, grip.translate(0, s * _binDrop), act),
        from.claws!,
        fade: act,
      );
    }
  }

  /// How much of the way the cargo has transferred from its source into the
  /// claw. The claw spends the first part of a pickup reaching, so the box
  /// stays put and then goes with it.
  static double _grasp(double act) => (act / 0.5).clamp(0.0, 1.0);

  /// The mirror: the hand carries it down and lets go at the end.
  static double _release(double act) => ((act - 0.5) / 0.5).clamp(0.0, 1.0);

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

  /// A belt: the rail, its rollers, and its label under the near end.
  void _rail(Canvas canvas, Rect belt, String label, Rect head, double s) {
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

    _label(canvas, label, Offset(head.center.dx, belt.bottom + s * 0.037), s);
  }

  /// The numbered spots, and whatever is on them.
  void _pallets(Canvas canvas, FloorGeometry g) {
    for (var i = 0; i < palletCount; i++) {
      final rect = g.palletSlot(i);
      canvas.drawRect(rect, _stroke());
      _label(
        canvas,
        '$i',
        Offset(rect.center.dx, rect.bottom + g.side * 0.012),
        g.side,
      );

      final value = i < to.pallets.length ? to.pallets[i] : null;
      if (value != null) {
        // [FloorGeometry.packageAt], like every other package on the floor.
        // Fitting one to the pallet instead is what made it a different size
        // here than on a belt.
        _package(canvas, g.packageAt(rect.center), value);
      }
    }
  }

  // ------------------------------------------------------------------ pieces

  Paint _stroke({double width = 1.5}) => Paint()
    ..color = W.floorLine
    ..strokeWidth = width
    ..style = PaintingStyle.stroke;

  /// A package: a box with its number in it. That is all a package is.
  void _package(Canvas canvas, Rect rect, int value, {double fade = 0}) {
    final alpha = 1 - fade;
    canvas.drawRect(
      rect,
      Paint()..color = W.floorPackage.withValues(alpha: alpha),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = W.text.withValues(alpha: alpha)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );
    _text(
      canvas,
      '$value',
      rect.center,
      rect.height * 0.62,
      W.text.withValues(alpha: alpha),
    );
  }

  void _label(Canvas canvas, String text, Offset at, double s) =>
      _text(canvas, text, at, s * 0.036, W.floorLabel);

  void _text(Canvas canvas, String text, Offset at, double size, Color colour) {
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

    painter.paint(canvas, at - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(_Floor old) =>
      old.t != t || old.from != from || old.to != to || old.layer != layer;
}
