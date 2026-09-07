/// How long an instruction takes, and why.
///
/// The animation used to be fitted into the clock: every instruction was held
/// for the same fixed time and the movement was squeezed to fit. That made the
/// unit's speed a function of how far it happened to be going - it sprinted
/// across the floor to a pallet and shuffled between two neighbouring belt
/// slots, in the same number of milliseconds.
///
/// Now the clock is fitted to the animation. The unit walks at one speed, each
/// gesture runs at the length it was drawn at, and the program advances when
/// they are done. An instruction that has further to walk simply takes longer,
/// which is what it looks like it should do.
///
/// Both the playback clock and the floor's own animation read their timing from
/// here, so they cannot disagree about how long the instruction on screen is.
library;

import '../../model/commands.dart';
import '../../model/level.dart';
import '../../model/vm.dart';
import 'floor_geometry.dart';

/// One instruction's movement, split into the two phases it happens in.
class Pace {
  const Pace({required this.walk, required this.act});

  /// An instruction the unit does not act on: a condition. It moves nothing, so
  /// there is no movement to time it by, but the caret still has to be readable
  /// on the line - so this is the one duration that is a judgement rather than
  /// a consequence.
  const Pace.thinking() : walk = Duration.zero, act = _thinking;

  /// Getting there, and doing the thing.
  final Duration walk;
  final Duration act;

  Duration get total => walk + act;

  /// Where the walk ends and the act begins, as a fraction of [total]. The
  /// floor splits its animation here.
  ///
  /// Clamped short of 1: a walk with no act at the end - a TAKE that finds the
  /// chute empty - would otherwise ask for an empty interval.
  double get walkFraction {
    final all = total.inMicroseconds;
    if (all == 0) return 0;
    return (walk.inMicroseconds / all).clamp(0.0, 0.999);
  }

  // ------------------------------------------------------------------ speeds

  /// Fractions of the floor per second.
  ///
  /// Stated as a fraction rather than in dp so the unit crosses the warehouse
  /// in the same time on every screen. Slow on purpose: the run is there to be
  /// watched, and a polished build gets a fast-forward rather than a brisker
  /// default.
  static const walkSpeed = 0.32;

  /// The lengths the one-shots were drawn at, from Animations/README.md. Played
  /// at anything else the gesture reads as a blur or a mime.
  static const _pickup = Duration(milliseconds: 1150);
  static const _merge = Duration(milliseconds: 2200);
  static const _thinking = Duration(milliseconds: 700);

  static Duration _actFor(Op op, {required bool took}) => switch (op) {
    // A TAKE that finds nothing walks over and comes away empty. Nothing to
    // play, so nothing to wait for.
    Op.take => took ? _pickup : Duration.zero,
    Op.copyFrom || Op.ship => _pickup,
    Op.copyTo || Op.sum || Op.sub => _merge,
    Op.branchUnless || Op.jump => Duration.zero,
  };

  /// How long the instruction that produced [now] should take.
  ///
  /// [before] is the instruction it follows, or null for the first one - in
  /// which case the unit starts from [Station.start] and the shipment is
  /// untouched, which is what the floor shows before a run begins.
  static Pace of({Tick? before, required Tick now, required Level level}) {
    final from = before?.station ?? Station.start;
    final wasOnIntake = before?.intake.length ?? level.intake.length;
    final took = wasOnIntake - now.intake.length == 1;

    final distance = const FloorGeometry(1).routeLength(from, now.station);
    final walk = Duration(
      microseconds: (distance / walkSpeed * Duration.microsecondsPerSecond)
          .round(),
    );
    final act = _actFor(now.op, took: took);

    if (walk == Duration.zero && act == Duration.zero) {
      return const Pace.thinking();
    }
    return Pace(walk: walk, act: act);
  }

  /// The longest any single instruction can take.
  ///
  /// Derived rather than guessed, because the only thing that wants it is a
  /// test stepping the clock by hand - and a test that guesses this number
  /// silently stops advancing a full instruction the day the speed changes.
  static Duration get longestInstruction {
    const g = FloorGeometry(1);
    var furthest = 0.0;
    for (final a in _everywhere) {
      for (final b in _everywhere) {
        final d = g.routeLength(a, b);
        if (d > furthest) furthest = d;
      }
    }
    return Duration(
          microseconds: (furthest / walkSpeed * Duration.microsecondsPerSecond)
              .round(),
        ) +
        _merge;
  }

  /// The corners are the only stations that can be furthest apart, so the
  /// search does not need the middle pallets.
  static final _everywhere = [
    Station.start,
    const Station(StationKind.chute),
    const Station(StationKind.outbound),
    const Station(StationKind.pallet, 0),
    Station(StationKind.pallet, palletCount - 1),
  ];
}
