/// The levels the experiment can open.
///
/// One, for now. The app boots straight into it - there is no level select, no
/// call, no progression, and deliberately so: this experiment is about the
/// gameplay screen, and everything around it would be scaffolding to maintain.
///
/// The content is Act 1's filter level, from GameDesign/level-04-briefing.md.
/// It is the smallest level that exercises everything the machine can do wrong:
/// a loop, a condition, the discard rule, a zero that is not positive, and a
/// last package that is correctly rejected - so the shift ends with the robot
/// still holding something.
library;

import 'level.dart';

/// Shipment `s1` from the briefing: the par shipment, and the longest.
///
/// Mixed signs, a zero in the middle, and it ends on a rejected package. The
/// zero is the level's sharpest edge - a player who reads "positive" as "not
/// negative" ships it, and finds out here rather than in Act 3.
const _s1 = [-4, 7, 0, 3, 9, -1];

final positivesOnly = Level(
  brief: const LevelBrief(
    task: 'Ship only the positive numbers.',
    detail: 'Zero is not positive. Everything else goes in the bin.',
  ),
  intake: _s1,
  goal: (intake) => intake.where((n) => n > 0).toList(),
  // s1 correctly ends with -1 still in the claws: the robot takes it, declines
  // to ship it, loops, and finds the intake empty. Requiring empty hands would
  // fail the reference solution on its own level (level-04-briefing 5.3).
  requireHandsEmpty: false,
);

final levels = <Level>[positivesOnly];
