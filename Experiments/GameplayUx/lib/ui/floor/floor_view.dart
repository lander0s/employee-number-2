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

/// How long one instruction's movement takes.
///
/// Shorter than the shortest hold in [RunController], so every movement lands
/// and then rests. Continuous motion would read as a conveyor that never stops,
/// which is a different machine from this one: UNIT-02 does one thing at a
/// time, and the stillness between things is how you see what it did.
const _travel = Duration(milliseconds: 280);

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
                  // at the belt's speed, and the unit walks at the unit's. Easing
                  // either would be the thing deciding for itself when to set
                  // off and when to stop.
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

    final unit = g.body(g.walkBetween(from.station, to.station, walk));
    final held = unit.deflate(g.robotSide * 0.22);

    _grid(canvas, s);
    _rail(canvas, g.intakeBelt, 'INTAKE', g.intakeSlot(0), s);
    _rail(canvas, g.outBelt, 'OUTBOUND', g.outSlot(0), s);
    _pallets(canvas, g);
    _unit(canvas, unit, s);

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
        g.intakeSlot(i + (took ? 1 : 0)),
        g.intakeSlot(i),
        act,
      )!;
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
          // Carried in the claws for the whole walk, then set down. `held` is
          // the walked-to position, so it leaves the unit wherever the unit
          // actually got to.
          ? Rect.lerp(held, g.outSlot(0), act)!
          : Rect.lerp(g.outSlot(i - added), g.outSlot(i), act)!;
      if (rect.left > s) break;
      _package(canvas, rect, value);
    }

    // --------------------------------------------------------------- claws
    if (to.claws != null) {
      // A package arriving from the chute is lifted once the unit is there;
      // one already in the claws, or one changed in place by arithmetic, just
      // rides along with it.
      _package(
        canvas,
        took ? Rect.lerp(g.intakeSlot(0), held, act)! : held,
        to.claws!,
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
        _package(canvas, rect.deflate(rect.width * 0.16), value);
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
      old.t != t || old.from != from || old.to != to;
}
