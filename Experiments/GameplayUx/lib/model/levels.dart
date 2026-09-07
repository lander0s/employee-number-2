/// The levels the experiment can open.
///
/// One, for now. The app boots straight into it - there is no level select, no
/// call, no progression, and deliberately so: this experiment is about the
/// gameplay screen, and everything around it would be scaffolding to maintain.
library;

import 'level.dart';
import 'program.dart';

/// Ship everything, but never a negative.
///
/// This replaced the filter level, and the reason is the floor. A filter needs
/// a loop and a condition and nothing else, so the unit only ever walked
/// between the two belts - the pallets sat there unused and the whole cross-
/// floor routing was exercised by tests and by nothing a player could watch.
///
/// Negation needs a pallet, and there is no `NEGATE`: the only way to turn `-4`
/// into `4` is to put it on the floor and subtract it from itself twice.
///
///     COPY TO 0     pallet 0 = -4, claws = -4
///     SUB 0         claws = -4 - -4 = 0
///     SUB 0         claws =  0 - -4 = 4
///
/// That is the arithmetic the language was given `SUM` and `SUB` for, and it is
/// the first level here where the unit has a reason to leave the belt line.
final noNegatives = Level(
  brief: const LevelBrief(
    task: 'Ship every number, as a positive.',
    detail: 'Flip the negatives on the way out. Zero is fine as it is.',
  ),

  // Starts negative, so the interesting path is the first thing that happens.
  // Ends negative, so the shift finishes straight after a flip rather than on
  // an easy one. A positive and a zero in the middle prove the flip has to be
  // conditional - a program that negates everything fails on `7`.
  //
  // Four packages rather than six: every negative costs three extra
  // instructions, and a run has to stay short enough to watch twice.
  intake: const [-4, 7, 0, -9],

  goal: (intake) => intake.map((n) => n.abs()).toList(),

  // Every package is shipped here, so the claws really should be empty at the
  // end - unlike the filter level, where the last rejected package is still
  // held and requiring empty hands would fail the reference solution.
  requireHandsEmpty: true,
);

/// `REPEAT { TAKE; IF NEGATIVE { COPY TO 0; SUB 0; SUB 0 }; SHIP }`
///
/// SIZE 7, and SPEED `2 x len + 1 + 3 x negatives` - 15 on this shipment.
///
/// Loaded on launch as a convenience: the point of the experiment is to watch a
/// program run, and starting from an empty page means drawing a program by hand
/// before anything happens. A real level starts empty (§5).
ProgramDocument referenceSolution() => ProgramDocument()
  ..root = [
    Node(
      commandId: 'repeat',
      children: [
        Node(commandId: 'take'),
        Node(
          commandId: 'ifCond',
          comparator: 'NEGATIVE',
          children: [
            Node(commandId: 'copyTo', palletArg: 0),
            Node(commandId: 'sub', palletArg: 0),
            Node(commandId: 'sub', palletArg: 0),
          ],
        ),
        Node(commandId: 'ship'),
      ],
    ),
  ];

final levels = <Level>[noNegatives];
