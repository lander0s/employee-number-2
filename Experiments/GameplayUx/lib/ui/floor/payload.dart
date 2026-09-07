/// Where the unit's hands are, per authored keyframe.
///
/// The sprites carry empty `payload` slots that already move with the claws,
/// and Animations/README.md publishes their paths. Reproducing those paths here
/// is what attaches a package to a hand instead of parking it at the sprite's
/// middle and hoping.
///
/// Coordinates are the **Lottie composition's**, 300x240, which is the SVG's
/// with 30 added to x (README, "Coordinate systems"). The tables below are
/// already converted, so nothing downstream has to remember the offset.
///
/// The easing is not decoration. Every segment carries its own cubic-bezier and
/// they differ on purpose - flat dwells, a slow anticipation, then a hard
/// acceleration into the merge's impact. The README is explicit that lerping
/// the table linearly desyncs worst around the smash, which is precisely where
/// it shows.
library;

import 'dart:ui';

/// One slot's authored path.
class Payload {
  const Payload({
    required this.times,
    required this.points,
    required this.splines,
    this.alphas,
  }) : _fixed = null;

  /// A slot that never moves. The two-handed grip, for the poses that just
  /// stand there holding something.
  const Payload.fixed(Offset at)
    : times = const <double>[0, 1],
      points = const [],
      splines = const <List<double>>[
        [0, 0, 1, 1],
      ],
      alphas = null,
      _fixed = at;

  final List<double> times;
  final List<Offset> points;

  /// One `[x1, y1, x2, y2]` per segment, so `splines.length == times.length-1`.
  final List<List<double>> splines;

  /// Opacity per keyframe, where the slot fades. Stepped, not eased - the
  /// authored values only ever hold or switch.
  final List<double>? alphas;

  final Offset? _fixed;

  /// The two-handed grip. Frame 0 of every carrying pose, and where the
  /// one-shots land so they hand off to `holding` without a jump.
  static const grip = Offset(150, 96);

  /// `pickup`, 1.15s. The slot waits at the grab point while the arm reaches,
  /// then rises to the grip. Played backwards this is `putdown`, which is why
  /// there is no second file.
  static const pickup = Payload(
    times: <double>[0, 0.05, 0.46, 0.58, 1],
    points: [
      Offset(150, 195.4),
      Offset(150, 195.4),
      Offset(150, 195.4),
      Offset(150, 195.4),
      grip,
    ],
    splines: <List<double>>[
      [0, 0, 1, 1],
      [0.4, 0, 0.25, 1],
      [0, 0, 1, 1],
      [0.35, 0, 0.2, 1],
    ],
  );

  static const _mergeTimes = <double>[
    0,
    0.06,
    0.3,
    0.42,
    0.56,
    0.68,
    0.79,
    0.88,
    1,
  ];
  static const _mergeSplines = <List<double>>[
    [0, 0, 1, 1],
    [0.4, 0, 0.2, 1],
    [0, 0, 1, 1],
    [0.4, 0, 0.2, 1],
    [0.3, 0, 0.7, 1],
    [0.8, 0, 1, 1],
    [0.1, 0, 0.3, 1],
    [0.4, 0, 0.2, 1],
  ];

  /// `merge`, 2.2s, slot A: what the unit was already holding.
  ///
  /// It starts at the grip rather than in the right claw, which the README
  /// calls deliberate - frame 0 is then identical to the `holding` sprite - and
  /// slides into the claw as the left hand leaves. It disappears at the impact.
  static const mergeA = Payload(
    times: _mergeTimes,
    points: [
      grip,
      grip,
      Offset(161, 100.5),
      Offset(161, 100.5),
      Offset(190.1, 90),
      Offset(202.7, 81.5),
      Offset(161, 99.3),
      Offset(182, 94.3),
      Offset(178.7, 97.5),
    ],
    splines: _mergeSplines,
    alphas: <double>[1, 1, 1, 1, 1, 1, 1, 0, 0],
  );

  /// `merge`, slot `payload` - the result, which appears at the impact and
  /// stays at the grip.
  static const mergeResult = Payload(
    times: _mergeTimes,
    points: [grip, grip, grip, grip, grip, grip, grip, grip, grip],
    splines: _mergeSplines,
    alphas: <double>[0, 0, 0, 0, 0, 0, 0, 1, 1],
  );

  /// Where the slot is, [u] of the way through the animation.
  Offset at(double u) {
    final fixed = _fixed;
    if (fixed != null) return fixed;

    final t = u.clamp(0.0, 1.0);
    for (var i = 1; i < times.length; i++) {
      if (t > times[i] && i != times.length - 1) continue;
      final span = times[i] - times[i - 1];
      final p = span == 0 ? 1.0 : ((t - times[i - 1]) / span).clamp(0.0, 1.0);
      final s = splines[i - 1];
      return Offset.lerp(
        points[i - 1],
        points[i],
        _ease(s[0], s[1], s[2], s[3], p),
      )!;
    }
    return points.last;
  }

  /// Opacity at [u]. Stepped: the authored values hold and then switch, so an
  /// eased blend would invent a fade nobody drew.
  double alphaAt(double u) {
    final a = alphas;
    if (a == null) return 1;
    final t = u.clamp(0.0, 1.0);
    var value = a.first;
    for (var i = 0; i < times.length; i++) {
      if (times[i] <= t) value = a[i];
    }
    return value;
  }
}

/// Solves a cubic-bezier easing: given progress along x, return y.
///
/// Bisected rather than solved analytically - twenty-odd iterations is nothing
/// next to a frame, and a closed form for a cubic is more code to get wrong.
double _ease(double x1, double y1, double x2, double y2, double p) {
  if (p <= 0) return 0;
  if (p >= 1) return 1;

  double bez(double a, double b, double t) {
    final u = 1 - t;
    return 3 * a * u * u * t + 3 * b * u * t * t + t * t * t;
  }

  var lo = 0.0;
  var hi = 1.0;
  var t = p;
  for (var i = 0; i < 24; i++) {
    final err = bez(x1, x2, t) - p;
    if (err.abs() < 1e-5) break;
    if (err > 0) {
      hi = t;
    } else {
      lo = t;
    }
    t = (lo + hi) / 2;
  }
  return bez(y1, y2, t);
}
