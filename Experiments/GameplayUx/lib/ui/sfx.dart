/// The sounds the floor makes.
///
/// The catalogue and the playback; which sound an instruction makes, and when,
/// is [Cues] in floor/cues.dart.
///
/// Kept deliberately small: a player per sound, reused. Two *different* sounds
/// overlapping is normal - an action can cue several - and one player each
/// handles that, because it is only a sound overlapping *itself* that would
/// need a pool, and nothing here does.
///
/// Played through the default backend, one call per sound. Low-latency mode
/// looked like the right answer for short effects - SoundPool, source loaded
/// once, replayed by seeking - and it is not usable here: `setSource` never
/// completes in that mode, so every play timed out after thirty seconds. The
/// simple path costs a little latency and works.
library;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// The sounds, and the file each one lives in.
///
/// Ogg Vorbis rather than the WAVs they were authored as. Android's decoders
/// refused the WAVs outright - MediaPlayer with a system error, SoundPool with
/// "unable to load sound" - and one of them was 24-bit extensible, which
/// neither backend handles. Ogg is decoded reliably by both, and the whole set
/// went from 1.3MB to 73KB on the way through.
enum Sound {
  /// Closing the claws on something: TAKE, and COPY FROM.
  pickup('pickup.ogg'),

  /// The moment a package splits in two, leaving a copy behind. Only half of
  /// COPY TO: the copy still has to be set down, which is [putDown].
  copyTo('copy-to.ogg'),

  /// A package landing on a pallet. Wood, not magic.
  putDown('put-down.ogg'),

  /// Arithmetic. Two values becoming one.
  merge('merge.ogg'),

  /// Setting a package on the outbound belt.
  ship('ship.ogg'),

  /// The shift did not go out. Not per-instruction: this is the verdict.
  error('error.ogg');

  const Sound(this.file);

  final String file;

  /// `AssetSource` is relative to the asset prefix, which is `assets/`.
  String get asset => 'sfx/$file';
}

class Sfx {
  final _players = <Sound, AudioPlayer>{};

  /// Set once a play fails, so a device or a test harness without an audio
  /// plugin is asked once rather than on every instruction.
  ///
  /// Silence is the right failure here. A missing plugin should not take a
  /// layout test down with it, and it should not stop a run either.
  bool _mute = false;

  /// Plays [sound] at [volume], a fraction of the sample from 0 to 1.
  ///
  /// Passed per call rather than set on the player, because the player is
  /// reused across cues and the same sound is deliberately not always at the
  /// same level - see Cue.volume in floor/cues.dart.
  Future<void> play(Sound sound, {double volume = 1.0}) async {
    if (_mute) return;
    try {
      final player = _players[sound] ??= AudioPlayer();

      // Stopped first: an instruction can follow closely enough on the last
      // one that the previous play is still going, and restarting reads as one
      // sound per action rather than as a slur.
      await player.stop();
      await player.play(AssetSource(sound.asset), volume: volume);
    } catch (error) {
      _mute = true;
      debugPrint('sfx off: $error');
    }
  }

  void dispose() {
    for (final player in _players.values) {
      player.dispose();
    }
    _players.clear();
  }
}
