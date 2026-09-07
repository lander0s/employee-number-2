/// The floor, seen from above. Wireframe primitives, no art.
///
/// Everything the machine can observe is on it: the intake belt running in from
/// off-screen left, the outbound belt running out off-screen right, five
/// pallets across the bottom, and UNIT-02 between the two holding at most one
/// package.
///
/// Both belts deliberately leave the square. A shipment is not a list of six,
/// it is a queue arriving from the rest of a warehouse the player never sees,
/// and rails that run off the edge of the panel say that where two tidy columns
/// of boxes say the opposite. That is the whole world (game-design-document
/// 6.1), and drawing it as boxes and lines first is the cheapest way to find
/// out whether the *layout* reads before anything is drawn properly.
///
/// It moves. Packages travel between the position they held on the last
/// instruction and the one they hold on this one, which means the floor needs
/// both states and cannot work from a single snapshot - see [FloorStage].
library;

import 'package:flutter/material.dart';

import '../../model/commands.dart';
import '../../model/level.dart';
import '../../model/vm.dart';
import '../run_controller.dart';
import '../wireframe.dart';

/// How long one instruction's movement takes.
///
/// Shorter than the shortest hold in [RunController], so every movement lands
/// and then rests. Continuous motion would read as a conveyor that never stops,
/// which is a different machine from this one: UNIT-02 does one thing at a
/// time, and the stillness between things is how you see what it did.
const _travel = Duration(milliseconds: 280);

/// The instruction is in two phases: the unit walks, then it acts.
///
/// One phase would have the package leave the belt while the robot was still
/// crossing the floor towards it - the box teleporting into claws that had not
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
  });

  FloorState.of(Tick tick)
    : intake = tick.intake,
      claws = tick.claws,
      outbound = tick.outbound,
      pallets = tick.pallets,
      station = tick.station;

  /// The batch as it arrived, before a program has touched it. Also what the
  /// floor shows while the player is still writing: the shipment is the
  /// question, and it should be readable the whole time.
  FloorState.waiting(Level level)
    : intake = level.intake,
      claws = null,
      outbound = const [],
      pallets = const [],
      station = Station.start;

  final List<int> intake;
  final int? claws;
  final List<int> outbound;
  final List<int?> pallets;

  /// Where the unit is standing. The floor walks it between the two states.
  final Station station;
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
                builder: (context, _) => CustomPaint(
                  // Linear, deliberately: a package on a belt is being carried
                  // at the belt's speed. Easing it would be the box deciding
                  // for itself when to set off and when to stop.
                  painter: _Floor(from: from, to: to, t: _anim.value),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Floor extends CustomPainter {
  _Floor({required this.from, required this.to, required this.t});

  final FloorState from;
  final FloorState to;

  /// 0 at the previous instruction, 1 at this one.
  final double t;

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
  /// rail carries on, so neither belt appears to stop at the panel.
  ///
  /// The consequence worth naming: **the unit always drops at the same place.**
  /// The near end of the outbound is the drop point, and by the time the unit
  /// ships again whatever was there has travelled on, so the position never
  /// depends on how much has been shipped.
  static const _chuteEnd = 0.235;
  static const _beltOff = 0.6;

  /// The pallets are pushed to the foot of the square, where they belong: they
  /// are the floor, and everything else happens above them.
  static const _palletTop = 0.805;
  static const _palletSize = 0.135;

  static const _robot = 0.17;

  /// The line the belts run along. The unit no longer stands on it - it stands
  /// *above* whatever it is working on - but everything is still measured from
  /// it, because it is the axis the whole floor is built around.
  static const _beltAt = 0.42;

  /// The two rows the unit works from: above the belts, and above the pallets.
  /// It reaches down into whichever it is standing over, which is why the claws
  /// overlap the belt or the pallet rather than stopping short of it.
  static const _beltRow = 0.245;
  static const _palletRow = 0.705;

  /// How far a binned package falls before it is gone.
  static const _binDrop = 0.13;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final beltW = s * _beltW;
    final mid = s * _beltAt;

    final box = beltW * 0.59;
    final step = box + s * 0.008;

    // The head of each queue stops short of the end of its belt by the same
    // clearance it has along the sides, so a package sits in an even surround
    // instead of pressed against the rail it arrived on.
    final lip = (beltW - box) / 2;

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

    // Slot 0 is the end nearest the unit on both belts; the queues run away
    // from it in opposite directions.
    Rect intakeSlot(int i) => Rect.fromLTWH(
      intakeBelt.right - lip - box - i * step,
      mid - box / 2,
      box,
      box,
    );
    Rect outSlot(int i) =>
        Rect.fromLTWH(outBelt.left + lip + i * step, mid - box / 2, box, box);

    final pad = s * _pad;
    final palletSize = s * _palletSize;
    final palletSpan = s - pad * 2;
    final palletGap = palletCount > 1
        ? (palletSpan - palletSize * palletCount) / (palletCount - 1)
        : 0.0;
    Rect palletSlot(int i) => Rect.fromLTWH(
      pad + i * (palletSize + palletGap),
      s * _palletTop,
      palletSize,
      palletSize,
    );

    /// Where the unit stands to work on something: over it, one body clear.
    Rect stand(Station at) {
      final side = s * _robot;
      final centre = switch (at.kind) {
        // Mid-floor, between the two belts. Only ever the starting position.
        StationKind.home => Offset(s / 2, s * _beltRow),
        StationKind.chute => Offset(intakeSlot(0).center.dx, s * _beltRow),
        StationKind.outbound => Offset(outSlot(0).center.dx, s * _beltRow),
        StationKind.pallet => Offset(
          palletSlot(at.pallet).center.dx,
          s * _palletRow,
        ),
      };
      return Rect.fromCenter(center: centre, width: side, height: side);
    }

    // The walk finishes before the hand-over starts. Everything a package does
    // is measured against [act]; everything the unit does, against [walk].
    final walk = (t / _walkPhase).clamp(0.0, 1.0);
    final act = ((t - _walkPhase) / (1 - _walkPhase)).clamp(0.0, 1.0);

    final robot = Rect.lerp(stand(from.station), stand(to.station), walk)!;
    final held = robot.deflate(s * _robot * 0.22);

    _grid(canvas, s);
    _rail(canvas, intakeBelt, 'INTAKE', intakeSlot(0), s);
    _rail(canvas, outBelt, 'OUTBOUND', outSlot(0), s);
    _pallets(canvas, s, palletSlot);
    _unit(canvas, robot, s);

    // What the instruction did, read off the two states rather than passed in.
    // The machine already recorded the result; asking it to also describe the
    // movement would be two sources for one fact.
    final took = from.intake.length - to.intake.length == 1;
    final shipped = to.outbound.length - from.outbound.length == 1;
    final binned = took && from.claws != null;

    // -------------------------------------------------------------- intake
    //
    // Everything still on the belt slides one slot closer when a package comes
    // off the front, which is what a conveyor does.
    for (var i = 0; i < to.intake.length; i++) {
      final rect = Rect.lerp(
        intakeSlot(i + (took ? 1 : 0)),
        intakeSlot(i),
        act,
      )!;
      if (rect.right < 0) break;
      _package(canvas, rect, to.intake[i], s);
    }

    // ------------------------------------------------------------ outbound
    final added = shipped ? 1 : 0;
    for (var i = 0; i < to.outbound.length; i++) {
      // Drawn head-first from the drop point, and the head is the *newest*:
      // the first thing shipped is furthest away, already off the edge.
      final value = to.outbound[to.outbound.length - 1 - i];
      final rect = i == 0 && shipped
          // Carried in the claws for the whole walk, then set down. `held` is
          // the walked-to position, so it leaves the unit wherever the unit
          // actually got to.
          ? Rect.lerp(held, outSlot(0), act)!
          : Rect.lerp(outSlot(i - added), outSlot(i), act)!;
      if (rect.left > s) break;
      _package(canvas, rect, value, s);
    }

    // --------------------------------------------------------------- claws
    if (to.claws != null) {
      // A package arriving from the chute is lifted once the unit is there;
      // one already in the claws, or one changed in place by arithmetic, just
      // rides along with it.
      _package(
        canvas,
        took ? Rect.lerp(intakeSlot(0), held, act)! : held,
        to.claws!,
        s,
      );
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
        Rect.lerp(held, held.translate(0, s * _binDrop), act)!,
        from.claws!,
        s,
        fade: act,
      );
    }
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
  ///
  /// Geometry comes from the caller because the unit needs it too - it has to
  /// know where pallet 3 is in order to stand over it - and two places working
  /// it out separately is how they end up disagreeing.
  void _pallets(Canvas canvas, double s, Rect Function(int) slot) {
    for (var i = 0; i < palletCount; i++) {
      final rect = slot(i);
      canvas.drawRect(rect, _stroke());
      _label(canvas, '$i', Offset(rect.center.dx, rect.bottom + s * 0.012), s);

      final value = i < to.pallets.length ? to.pallets[i] : null;
      if (value != null) {
        _package(canvas, rect.deflate(rect.width * 0.16), value, s);
      }
    }
  }

  /// UNIT-02. What it is holding is drawn by [paint], because that package may
  /// be in flight rather than in the claws.
  void _unit(Canvas canvas, Rect rect, double s) {
    canvas.drawRect(rect, _stroke(width: 2));

    // Two claws off the bottom edge, pointing at the floor it works over.
    final side = rect.width;
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
  }

  // ------------------------------------------------------------------ pieces

  Paint _stroke({double width = 1.5}) => Paint()
    ..color = W.floorLine
    ..strokeWidth = width
    ..style = PaintingStyle.stroke;

  /// A package: a box with its number in it. That is all a package is.
  void _package(
    Canvas canvas,
    Rect rect,
    int value,
    double s, {
    double fade = 0,
  }) {
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
      old.t != t || old.from != from || old.to != to;
}
