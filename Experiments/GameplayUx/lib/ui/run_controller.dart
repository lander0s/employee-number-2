/// Plays a [RunResult] back, and lets the player drive it by hand.
///
/// The machine has already finished by the time this starts: the verdict is
/// known, the trace is a list, and this only decides which part of it is on
/// screen. Keeping the clock out of the VM is what lets the whole language be
/// tested without one - and it is what makes stepping *backwards* possible at
/// all. Nothing is recomputed to go back; the trace is a list and this is an
/// index into it.
///
/// Four states, and they are what the controls read:
///
///  - **cold** - no trace. [running] false.
///  - **playing** - the clock is advancing the cursor.
///  - **paused** - a trace, a cursor, and no clock. Stepping lives here.
///  - **finished** - past the last instruction, verdict up.
///
/// [running] means *a trace is loaded*, not *the clock is going*: it is what
/// locks the program for editing, and a paused run has to stay locked or the
/// trace on screen would describe a program that no longer exists.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../model/level.dart';
import '../model/program.dart';
import '../model/vm.dart';
import 'floor/pace.dart';

class RunController extends ChangeNotifier {
  RunController({required this.level, required this.program});

  final Level level;

  /// Where the program comes from when a control needs one.
  ///
  /// A callback rather than the document itself, because a run can now start
  /// from a step as easily as from play, and whichever one starts it has to
  /// compile what is on the page at that moment. The page is edited between
  /// runs; holding a document from construction would pin the wrong version.
  final ProgramDocument Function() program;

  RunResult? _result;

  /// SIZE, captured when the run started. The machine counts steps; rows are a
  /// property of the program, and the program can be edited the moment a run
  /// ends - so this is the size of what actually ran.
  int _size = 0;
  int get size => _size;

  int _cursor = -1;
  Timer? _timer;
  bool _finished = false;

  /// How long the instruction on screen has been up. Measured rather than
  /// assumed so that a pause halfway through an instruction resumes halfway
  /// through it, instead of restarting the movement.
  final _spent = Stopwatch();

  /// A trace is loaded. Not the same as [playing]: this is what says the
  /// program is locked.
  bool get running => _result != null;

  /// The clock is advancing.
  bool get playing => _result != null && _timer != null && !_finished;

  /// Loaded, stopped, and not at the end - the state stepping happens in.
  bool get paused => running && !playing && !_finished;

  /// True once the last instruction has played and the verdict is up.
  bool get finished => _finished;

  RunResult? get result => _result;

  bool get canStepBack => running && (_finished || _cursor >= 0);

  /// Cold counts: the first step compiles the program and shows instruction
  /// one, the same way play does.
  bool get canStepForward => !_finished;

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

  Tick? _at(int index) => index >= 0 && index < (_result?.ticks.length ?? 0)
      ? _result!.ticks[index]
      : null;

  // ----------------------------------------------------------- the controls

  /// Runs, from wherever it is: compiles and starts from cold, or picks the
  /// clock back up after a pause.
  void play() {
    if (playing || _finished) return;
    if (_result == null) _load();
    _spent.start();
    _schedule();
    notifyListeners();
  }

  /// Freezes the clock where it is. The trace stays loaded.
  void pause() {
    if (!playing) return;
    _timer!.cancel();
    _timer = null;
    _spent.stop();
    notifyListeners();
  }

  /// One instruction on, compiling first if nothing is loaded.
  ///
  /// Stepping past the last instruction is what raises the verdict, so the end
  /// of a stepped run reads the same as the end of a played one.
  void stepForward() {
    if (_finished) return;
    if (_result == null) _load();
    _byHand();

    if (_cursor + 1 >= _result!.ticks.length) {
      _finished = true;
    } else {
      _cursor++;
    }
    notifyListeners();
  }

  /// One instruction back.
  ///
  /// Nothing is recomputed - the trace is already a list and this walks it the
  /// other way. From the verdict it steps back onto the last instruction
  /// rather than off the end of the run.
  void stepBack() {
    if (!canStepBack) return;
    _byHand();

    if (_finished) {
      _finished = false;
    } else {
      _cursor--;
    }
    notifyListeners();
  }

  /// Unloads. The program becomes editable again.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _spent
      ..reset()
      ..stop();
    _result = null;
    _cursor = -1;
    _finished = false;
    notifyListeners();
  }

  // ------------------------------------------------------------- the clock

  /// Compiles what is on the page and loads the trace, without showing any of
  /// it yet: the cursor sits before the first instruction, which is the floor
  /// as the shift starts.
  ///
  /// A program that cannot be compiled is not a thing the editor can author -
  /// blocks come with their closers and every argument has a value - so a throw
  /// here is a bug, not a player mistake, and is left to crash loudly.
  void _load() {
    final doc = program();
    _size = doc.size;
    _result = Machine(compile(doc.root), level).run();
    _cursor = -1;
    _finished = false;
    _spent
      ..reset()
      ..stop();
  }

  /// The player took the wheel: stop the clock.
  void _byHand() {
    _timer?.cancel();
    _timer = null;
    _spent
      ..reset()
      ..stop();
  }

  void _schedule() {
    final ticks = _result!.ticks;
    final next = _cursor + 1;

    if (next >= ticks.length) {
      // Out of trace: raise the verdict and stop there. An empty program has
      // no ticks at all and lands here immediately, which is right - it failed
      // before the robot moved.
      //
      // Nothing tidies itself away any more. A run used to hold its verdict
      // for two and a half seconds and then unload itself, which was the
      // right shape while the verdict was a strip along the floor; it is a
      // modal now, and a modal that dismissed itself on a timer would be a
      // modal you could miss.
      _finished = true;
      notifyListeners();
      return;
    }

    // What the instruction already on screen has *left*, not what it was
    // given: resuming from a pause owes only the remainder.
    final full = _cursor < 0 ? Duration.zero : _hold(_cursor);
    final left = full - _spent.elapsed;

    _timer = Timer(left > Duration.zero ? left : Duration.zero, () {
      _cursor = next;
      _spent
        ..reset()
        ..start();
      notifyListeners();
      _schedule();
    });
  }

  /// How long the instruction on screen gets.
  ///
  /// Asked of [Pace], which is also what the floor times its animation by - so
  /// the program advances exactly when the movement finishes. It used to be a
  /// fixed hold with the movement squeezed to fit, which made the unit's speed
  /// depend on how far it happened to be going.
  Duration _hold(int index) =>
      Pace.of(before: _at(index - 1), now: _at(index)!, level: level).total;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
