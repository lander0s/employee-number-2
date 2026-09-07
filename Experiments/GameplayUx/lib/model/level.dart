/// What a level hands the machine: a brief to read and a batch to work on.
///
/// A real level defines a *set* of shipments and rolls one when it opens, and
/// clearing it means passing all of them headless (game-design-document 8.5).
/// This is the first cut: one shipment, checked on its own. The shape below is
/// the one that grows into it - a goal written as a function of the intake
/// rather than as a literal list is exactly what makes the rest of the set
/// checkable without writing the answer out six times.
library;

/// The note at the top of the page. Actionable only: what the boss said, and
/// why, is the call's job.
class LevelBrief {
  const LevelBrief({required this.task, this.detail});

  /// One line, the thing to do.
  final String task;

  /// The rest of it, for levels whose rule does not fit in one line. Still no
  /// fiction: the conditions, the edge case, what counts as done.
  final String? detail;
}

class Level {
  const Level({
    required this.brief,
    required this.intake,
    required this.goal,
    this.requireHandsEmpty = false,
  });

  final LevelBrief brief;

  /// The packages on the chute, in the order they arrive. A package is a
  /// number and has no other properties, so this is the whole of it.
  final List<int> intake;

  /// What outbound has to hold at the end, derived from the intake rather than
  /// written out. Level 4's is `intake.where((n) => n > 0)`.
  final List<int> Function(List<int> intake) goal;

  /// Whether the shift has to end with the claws empty.
  ///
  /// False by default, and that is not laziness: a filter level whose last
  /// package is rejected correctly ends with the robot still holding it, so a
  /// blanket requirement would fail the reference solution on one shipment in
  /// six (level-04-briefing 5.3).
  final bool requireHandsEmpty;

  List<int> get expected => goal(intake);
}
