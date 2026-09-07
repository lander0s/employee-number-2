/// Plays a [RunResult] back, one tick at a time.
///
/// The machine has already finished by the time this starts: the verdict is
/// known, the trace is a list, and this only decides how fast the player sees
/// it. Keeping the clock out of the VM is what lets the whole language be
/// tested without one, and it is the same shape the floor animation will want -
/// a replay of a list, not a second interpreter.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../model/level.dart';
import '../model/program.dart';
import '../model/vm.dart';

/// How long the verdict sits before the run lets go.
const _verdictFor = Duration(milliseconds: 2500);

class RunController extends ChangeNotifier {
  RunController({required this.level});

  /// How long one instruction is held on screen.
  ///
  /// Deliberately slow: the point of a run right now is to *watch* the unit,
  /// and a gesture you cannot follow is a gesture you cannot judge. A polished
  /// build wants a fast-forward and probably a faster default, at which point
  /// these come down - they are pacing, not physics.
  ///
  /// Long enough for the floor's travel animation to land and then rest, which
  /// is the constraint [FloorStage] is written against. Free instructions - the
  /// branches - go by quicker because nothing moves on the floor for them, only
  /// the caret, but not so quickly that a loop's rhythm disappears.
  ///
  /// Public because the widget tests step the clock by hand, and a test that
  /// copies these numbers quietly stops advancing a full tick the day they
  /// change - which is exactly what happened the last time they moved.
  static const stepHold = Duration(milliseconds: 2800);
  static const freeHold = Duration(milliseconds: 1000);

  final Level level;

  RunResult? _result;

  /// SIZE, captured when the run started. The machine counts steps; rows are a
  /// property of the program, and the program can be edited the moment a run
  /// ends - so this is the size of what actually ran.
  int _size = 0;
  int get size => _size;

  int _cursor = -1;
  Timer? _timer;
  bool _finished = false;

  bool get running => _result != null;

  /// True once the last tick has played and the verdict is up.
  bool get finished => _finished;

  RunResult? get result => _result;

  /// The row the caret points at, or null when nothing is running.
  String? get executing =>
      _cursor >= 0 && _cursor < (_result?.ticks.length ?? 0)
      ? _result!.ticks[_cursor].nodeId
      : null;

  /// Everything that has happened so far, oldest first.
  List<Tick> get log =>
      _result == null ? const [] : _result!.ticks.take(_cursor + 1).toList();

  /// The world as it stands. Null before the first instruction has run, which
  /// is when the floor should show the shipment as it arrived.
  Tick? get now => _at(_cursor);

  /// The world one instruction ago. The floor interpolates between this and
  /// [now], so it needs both - a snapshot on its own cannot say which way a
  /// package was travelling.
  Tick? get previous => _at(_cursor - 1);

  /// Which instruction is on screen. The floor watches this to know when to
  /// start a new travel animation; the number itself means nothing to it.
  int get cursor => _cursor;

  Tick? _at(int index) =>
      index >= 0 && index < (_result?.ticks.length ?? 0)
      ? _result!.ticks[index]
      : null;

  /// Compiles and runs [doc], then starts playing the result back.
  ///
  /// A program that cannot be compiled is not a thing the editor can author -
  /// blocks come with their closers and every argument has a value - so a throw
  /// here is a bug, not a player mistake, and is left to crash loudly.
  void start(ProgramDocument doc) {
    stop();
    _size = doc.size;
    _result = Machine(compile(doc.root), level).run();
    _cursor = -1;
    _finished = false;
    notifyListeners();
    _schedule();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _result = null;
    _cursor = -1;
    _finished = false;
    notifyListeners();
  }

  void _schedule() {
    final ticks = _result!.ticks;
    final next = _cursor + 1;

    if (next >= ticks.length) {
      // Out of trace: hold the verdict up, then let go. An empty program has
      // no ticks at all and lands here immediately, which is right - it failed
      // before the robot moved.
      _finished = true;
      notifyListeners();
      _timer = Timer(_verdictFor, () {
        _timer = null;
        stop();
      });
      return;
    }

    // How long the tick already on screen stays there, not how long the next
    // one will. A branch moved nothing on the floor, so it does not earn the
    // same beat as a package changing hands.
    final delay = _cursor < 0 ? Duration.zero : _hold(_cursor);

    _timer = Timer(delay, () {
      _cursor = next;
      notifyListeners();
      _schedule();
    });
  }

  /// A tick is free when it did not advance SPEED, which is the same question
  /// as "did the robot do anything".
  Duration _hold(int index) {
    final ticks = _result!.ticks;
    final before = index == 0 ? 0 : ticks[index - 1].steps;
    return ticks[index].steps == before ? freeHold : stepHold;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
