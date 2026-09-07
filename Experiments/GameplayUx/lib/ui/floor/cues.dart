/// Which sounds an action makes, and when.
///
/// **This is the file to tweak.** One row per instruction, each row a list of
/// sounds with an offset. Everything else about audio is plumbing: [Sfx] owns
/// the players, `FloorStage` owns the clock, and neither has an opinion about
/// what anything sounds like.
///
/// An action gets a list rather than one sound because a gesture is not one
/// event. The merge animation is the case that forced it: the unit closes a
/// claw on one package and then smashes two together, a second apart, and COPY
/// TO plays the same composition backwards to split one in two and set half
/// down. Cueing either as a single sample would mean baking the gap into the
/// file, where it cannot be moved without an editor.
library;

import '../../model/vm.dart';
import '../sfx.dart';

/// A sound, when it plays, and how loud.
class Cue {
  const Cue(this.sound, {this.delay = Duration.zero, this.volume = 1.0})
    : assert(
        volume >= 0 && volume <= 1,
        'volume is a fraction of the sample, 0 to 1',
      );

  final Sound sound;

  /// Measured from the moment the *gesture* starts - the frame the walk ends
  /// and the animation's act phase begins - not from the start of the
  /// instruction.
  ///
  /// That anchor is the point. An instruction's length varies with how far the
  /// unit had to walk, so an offset from its start would drift across the floor
  /// and land the noise somewhere different every time. The gestures are fixed
  /// lengths, so an offset from one of those means the same thing on every run.
  ///
  /// It is spent against the animation clock, not a timer, so a cue cannot
  /// arrive at a moment the picture is not at.
  final Duration delay;

  /// A fraction of the sample, 0 to 1. Set per cue rather than per sound,
  /// because the same noise does not want the same level in every place it is
  /// used - the grab under a SUB is one beat of a two-part gesture and can sit
  /// under it, where the same grab is the whole of a TAKE.
  ///
  /// Only ever down. There is no headroom above 1 to ask for: the platforms
  /// disagree about what they do with a larger number, and a sample that is too
  /// quiet at full volume wants normalising in an editor, where it can be done
  /// once and heard while it happens.
  ///
  /// The bound is checked in a const constructor, so a value outside it fails
  /// to compile rather than at the moment it would have played.
  final double volume;
}

/// The table.
abstract final class Cues {
  /// The sounds [op] makes.
  ///
  /// [acts] is false for an instruction that walks over and does nothing - a
  /// TAKE that finds the chute empty - which has no gesture to hang a sound on.
  static List<Cue> of(Op op, {required bool acts}) => switch (op) {
    Op.take => acts ? _grab : const [],
    Op.copyFrom => _grab,
    Op.ship => const [Cue(Sound.putDown)],

    // The two-sound cases. Both play Payload's merge composition - COPY TO
    // backwards, SUM and SUB forwards - so their offsets are the same two
    // authored keyframes seen from opposite ends, and they mirror: each pair
    // adds up to the 2200ms the animation runs for.
    //
    //   frame 0.42   the operand leaves the floor: the claw has closed
    //   frame 0.88   the impact: two packages become one
    //
    // They are where the picture is, not where they sounded best - so nudge
    // them by ear from here, but that is the ledge they start from.

    // Backwards: one package becomes two, and one of them goes down on the
    // pallet. Magic, then wood.
    Op.copyTo => const [
      Cue(Sound.copyTo, delay: Duration(milliseconds: 264)), // 1 - 0.88
      Cue(Sound.putDown, delay: Duration(milliseconds: 1276)), // 1 - 0.42
    ],

    // Forwards: the unit closes a claw on the second operand and smashes the
    // two together. The grab, then the impact - and it keeps the result, so
    // there is nothing to set down after.
    Op.sum || Op.sub => const [
      Cue(Sound.pickup, delay: Duration(milliseconds: 924)), // 0.42
      Cue(Sound.merge, delay: Duration(milliseconds: 1936)), // 0.88
    ],

    // Conditions and jumps move nothing.
    Op.branchUnless || Op.jump => const [],
  };

  /// The shift's verdict, when it goes badly.
  ///
  /// Not an action: it is cued from the run's result rather than from an
  /// instruction, so there is no gesture for a [Cue.delay] to be measured from
  /// and that field is ignored here. It lives in this file anyway, so that
  /// every level in the game is set in one place.
  static const failed = Cue(Sound.error);

  static const _grab = [Cue(Sound.pickup, delay: Duration(milliseconds: 600))];
}
