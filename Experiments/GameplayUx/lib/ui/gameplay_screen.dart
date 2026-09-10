/// The gameplay screen: task card, two stacked panes, draggable divider, tray.
///
/// Snap states per game-design-document.md 7.1 - program-focused at 38/62 and
/// floor-focused at 60/40, one swipe apart, with the divider free to sit
/// anywhere in between.
///
/// Note there are no hardcoded chrome heights here. The task card, tray and
/// bottom bar size themselves from their content, and the two panes split
/// whatever is left. Deriving the split from constants breaks the moment the OS
/// text scale rises, which 7.3 requires us to survive to 200%.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../model/level.dart';
import '../model/program.dart';
import '../model/vm.dart';
import 'floor_pane.dart';
import 'run_controller.dart';
import 'sfx.dart';
import 'notebook/lift.dart';
import 'notebook/note.dart';
import 'notebook/program.dart';
import 'notebook/tokens.dart';
import 'wireframe.dart';

/// How far the floor is pulled out, as a fraction of a square.
///
/// The floor is a square the width of the pane and can never be taller than
/// that (see ui/floor/floor_view.dart), so its whole range is 0 - shut - to 1,
/// fully out. It used to be a fraction of the screen, which let the floor grow
/// into a letterbox and made the two snap states depend on the phone.
///
/// Two snaps. Fully out is where the floor is read; [_snapProgram] is where it
/// is glanced at, and leaves the page most of the panel.
const _snapProgram = 0.55;
const _snapFloor = 1.0;

/// Floor heights below this collapse the pane entirely: the run button lives in
/// the floor, and a floor too short to reach it would be a dead strip.
const _minRunnableFloor = RunControls.height + 36;

class GameplayScreen extends StatefulWidget {
  const GameplayScreen({super.key, required this.level, this.program});

  /// The level being played. Passed in rather than held here: it is content,
  /// and the screen is the frame around it.
  final Level level;

  /// The program to open with. Null means the sample, which is what a fresh
  /// level does here for now; 13.3 wants a half-written program to survive
  /// backgrounding, and this is the seam it comes back through.
  final ProgramDocument? program;

  @override
  State<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends State<GameplayScreen> {
  late final ProgramDocument _doc;

  /// Page and note are siblings, and a drag routinely starts on one and ends on
  /// the other, so the two things they share live here: what is in the air, and
  /// the scrolling it can cause.
  final _lift = LiftState();
  final _scroll = ScrollController();
  late final AutoScroller _autoScroll = AutoScroller(
    controller: _scroll,
    visiblePage: _visiblePage,
  );

  final _pageKey = GlobalKey();

  /// The part of the page a finger can reach, which is now all of it.
  ///
  /// It used to be the page minus the note's height, measured every frame,
  /// because the note lay *over* the page and covered its bottom edge. The note
  /// is a sibling above the page now and covers nothing, so there is nothing to
  /// subtract and nothing to measure.
  Rect _visiblePage() {
    final box = _pageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return Rect.zero;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// One way to delete, whichever gesture asked for it: a swipe on the page, or
  /// a drop on the note.
  void _remove(Node node) {
    final label = node.spec.label;
    setState(() => _doc.delete(node.id));
    _refresh();
    _toast('Deleted $label');
  }

  void _toast(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          backgroundColor: W.chrome,
          duration: _toastLife,
          content: Text(message, style: W.labelDim),
          action: SnackBarAction(
            label: 'UNDO',
            textColor: W.text,
            onPressed: () {
              setState(_doc.undo);
              _refresh();
            },
          ),
        ),
      );

    // Timed here as well as in the SnackBar, because SnackBar's own timer does
    // not run at all while a screen reader is active - it waits to be dismissed
    // by hand, which left the offer sitting there indefinitely.
    _toastTimer?.cancel();
    _toastTimer = Timer(_toastLife, () {
      if (mounted) messenger.hideCurrentSnackBar();
    });
  }

  static const _toastLife = Duration(seconds: 1);
  Timer? _toastTimer;

  @override
  void dispose() {
    _toastTimer?.cancel();
    _run.removeListener(_refresh);
    _run.dispose();
    _sfx.dispose();
    _autoScroll.dispose();
    _lift.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Opens on the square. The floor is the thing that just became worth
  /// looking at, and the page still gets most of a tall phone at this setting.
  double _floorOpen = _snapFloor;
  bool _draggingDivider = false;

  /// The machine, and the playback of what it did.
  ///
  /// The program is compiled and executed the instant RUN is pressed - the
  /// verdict exists before the first frame of playback - and this walks the
  /// trace so the page and the floor can show the same instruction.
  late final RunController _run = RunController(
    level: widget.level,
    // Asked for at the moment a control needs it, not captured now: a run can
    // start from a step as well as from play, and either has to compile what
    // is on the page then.
    program: () => _doc,
  );

  /// Owned here so it is disposed with the screen. The floor decides *when*
  /// each sound plays; this only decides how long the players live.
  final _sfx = Sfx();

  bool get _running => _run.running;

  @override
  void initState() {
    super.initState();
    _doc = widget.program ?? (ProgramDocument()..loadSample());
    // The whole screen rebuilds on every tick. It is a page of text and a
    // dozen boxes at two or three frames a second, and threading a notifier
    // through to the two places that care would buy nothing measurable.
    _run.addListener(_refresh);
  }

  void _snapTo(double target) => setState(() => _floorOpen = target);

  void _toggleSnap() {
    final toFloor =
        (_floorOpen - _snapFloor).abs() > (_floorOpen - _snapProgram).abs();
    _snapTo(toFloor ? _snapFloor : _snapProgram);
  }

  /// On release, settle onto a snap state if we are close to one, otherwise
  /// leave the divider where it was put.
  ///
  /// Shut is a snap too: a splitter pushed almost all the way up should close
  /// rather than leave a two-millimetre sliver of floor nobody asked for.
  void _settle() {
    const threshold = 0.06;
    for (final snap in const [0.0, _snapProgram, _snapFloor]) {
      if ((_floorOpen - snap).abs() < threshold) {
        _snapTo(snap);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // The note's height is only knowable once it has laid out.

    final verdict = _run.finished ? _run.result : null;

    return Scaffold(
      backgroundColor: W.page,
      // No SafeArea: the game runs full screen (see main.dart), so there are no
      // bars to keep clear of, and the insets the platform still reports for
      // them left a band of dead board across the top of the panel.
      body: Stack(
        children: [
          SafeArea(
            top: false,
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Floored at zero before it is used as a clamp bound: on the
                      // first frame the incoming height is 0, which made `available`
                      // negative and `clamp(0, available)` throw. No room means no
                      // floor, not an error.
                      final available =
                          (constraints.maxHeight - W.dividerHitHeight).clamp(
                            0.0,
                            double.infinity,
                          );

                      // The hard limit: a square. The floor is as wide as the panel
                      // and the simulation is seen from above, so a floor taller
                      // than it is wide would be a world stretched in one axis -
                      // and pulling the splitter past that point would give the
                      // player empty board rather than more warehouse.
                      //
                      // On a phone short enough that a square will not fit, the
                      // screen wins and the square is clipped from the top.
                      final square = constraints.maxWidth;
                      final maxFloor = square < available ? square : available;
                      final floorHeight = (maxFloor * _floorOpen).clamp(
                        0.0,
                        maxFloor,
                      );

                      // The floor is either tall enough to hold the run button or
                      // hidden outright - never a sliver too thin to start a program
                      // from. Dragging the divider to the top is a legitimate way to
                      // say "I am editing, not running".
                      final floorVisible = floorHeight > _minRunnableFloor;

                      return Column(
                        children: [
                          SizedBox(
                            height: floorHeight,
                            child: floorVisible
                                ? FloorPane(
                                    level: widget.level,
                                    run: _run,
                                    sfx: _sfx,
                                  )
                                : const SizedBox.shrink(),
                          ),
                          _Divider(
                            active: _draggingDivider,
                            onDragStart: () =>
                                setState(() => _draggingDivider = true),
                            onDragUpdate: (dy) {
                              if (maxFloor <= 0) return;
                              setState(() {
                                // Against the square, not the screen: a drag moves
                                // the drawer, and the drawer is only ever one
                                // square deep. Past the end it simply stops.
                                _floorOpen = (_floorOpen + dy / maxFloor).clamp(
                                  0.0,
                                  1.0,
                                );
                              });
                            },
                            onDragEnd: () {
                              setState(() => _draggingDivider = false);
                              _settle();
                            },
                            onDoubleTap: _toggleSnap,
                          ),
                          Expanded(
                            // The tray sits above the page, not over it: fixed
                            // under the divider, and the program scrolls beneath.
                            // It reads as the bottom lip of the splitter rather
                            // than as something floating on the page - it moves
                            // with the divider and the scrollable region starts
                            // below it.
                            //
                            // It was laid over the page, and the page no longer
                            // shows through it. That is the only thing given up:
                            // the tray keeps its place during a run rather than
                            // disappearing, so the program is never resized under
                            // the player. Design pillar 2 - a run changes what can
                            // be touched and nothing else - and the moment a run
                            // starts is exactly when a row must not move.
                            child: Column(
                              children: [
                                // Gone while running, not merely hidden: the
                                // program takes the height back and shows more of
                                // itself for the run.
                                //
                                // This is knowingly against pillar 2 as it was
                                // written - a run changes what can be touched and
                                // nothing else - because the tray is above the
                                // program now. Anything the tray gives up comes
                                // off the top, so every row moves up by its height
                                // at the moment a run starts. There is no scroll
                                // offset that hides it either: compensating would
                                // mean scrolling *back* by that height, and at the
                                // top of a program there is nothing to scroll back
                                // into.
                                if (!_running)
                                  ColoredBox(
                                    color: Paper.sheet,
                                    child: Chrome(
                                      child: CommandNote(
                                        lift: _lift,
                                        autoScroll: _autoScroll,
                                        onTrash: (id) {
                                          final node = _doc.nodeById(id);
                                          if (node != null) _remove(node);
                                        },
                                      ),
                                    ),
                                  ),
                                Expanded(
                                  child: ProgramEditor(
                                    doc: _doc,
                                    brief: widget.level.brief,
                                    controller: _scroll,
                                    lift: _lift,
                                    autoScroll: _autoScroll,
                                    onChanged: _refresh,
                                    onRemove: _remove,
                                    running: _running,
                                    executing: _run.executing,
                                    // The system's gesture area, which the note
                                    // used to absorb by sitting on it. Nothing is
                                    // down there now but the program, so the
                                    // program owes it the room.
                                    bottomInset: MediaQuery.viewPaddingOf(
                                      context,
                                    ).bottom,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Over the lot, including the floor: the verdict is the app talking
          // about the whole shift, not a thing that happened on the warehouse
          // floor. It used to be drawn inside the floor pane, which put it
          // under the bloom - the one thing the player was waiting for,
          // arriving at 40% brightness.
          if (verdict != null)
            _Verdict(result: verdict, size: _run.size, onDismiss: _run.stop),
        ],
      ),
    );
  }

  void _refresh() => setState(() {});
}

/// The end of a shift, as a modal.
///
/// A wireframe has no elevation to lean on - no shadow, no radius, no
/// material - so the only thing that can say "in front" is the scrim behind
/// it. That is also what makes it modal in fact and not just in look: the
/// scrim eats the taps, so the program underneath cannot be edited while a
/// verdict about a different program is on screen.
class _Verdict extends StatelessWidget {
  const _Verdict({
    required this.result,
    required this.size,
    required this.onDismiss,
  });

  final RunResult result;

  /// Command rows. Closers are free, so this is not the number of lines on the
  /// page (level-04-briefing 5.1, rule 1).
  final int size;

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final good = result.passed;

    return Positioned.fill(
      child: Semantics(
        container: true,
        // Announced as one thing: a screen reader should read the outcome and
        // its reason together, not offer them as two labels to hunt through.
        label: good
            ? 'Shift complete. Size $size, speed ${result.steps}.'
            : 'Shift failed. ${result.verdict}',
        child: GestureDetector(
          // Absorbs everything, and does *not* dismiss. Tapping a scrim by
          // accident is how you lose a message you had not read yet, and this
          // one is the whole point of having pressed run.
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: ColoredBox(
            color: W.scrim,
            child: Center(
              child: Chrome(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: W.chrome,
                    border: Border.all(
                      // The one bit of colour: red means the shift did not go
                      // out, which is meaning rather than decoration and so
                      // survives the wireframe.
                      color: good ? W.line : W.danger,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        good ? 'SHIFT COMPLETE' : 'SHIFT FAILED',
                        style: W.label.copyWith(
                          fontWeight: FontWeight.w700,
                          color: good ? W.text : W.danger,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        good
                            ? 'SIZE $size   SPEED ${result.steps}'
                            : result.verdict,
                        style: W.console.copyWith(color: W.textDim),
                      ),
                      const SizedBox(height: 20),
                      WButton(
                        // Keyed so a test can end a run without knowing which
                        // of the two words this is wearing.
                        key: const Key('verdict-dismiss'),
                        label: good ? 'CARRY ON' : 'BACK TO THE PROGRAM',
                        wide: true,
                        emphasised: true,
                        onTap: onDismiss,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The draggable divider: a short bar, and nothing else.
///
/// It was a full-width rule with a bordered 52x26 grip and a pair of arrows
/// painted in it, on the reasoning that a bare line reads as decoration and the
/// affordance had to announce itself. The box was the heavy part of that, and a
/// centred handle is the one shape a person already reads as "drag me" - so the
/// announcement can be made much more quietly.
///
/// It sits on the same surface as the tray below it, deliberately. The tray is
/// the bottom lip of the splitter: they move together, so they should look like
/// one thing being moved rather than a bar with a panel stuck under it. That
/// also takes a stripe of grey out of the middle of the screen, which is most
/// of what made this read as thick.
///
/// The *hit* area stays [W.dividerHitHeight] regardless of how thin the bar
/// looks. What is easy to see and what is easy to hit are different questions,
/// and only the first one was asked.
class _Divider extends StatelessWidget {
  const _Divider({
    required this.active,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDoubleTap,
  });

  final bool active;
  final VoidCallback onDragStart;
  final ValueChanged<double> onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Resize panes',
      hint: 'Drag up or down to change the split. Double tap to snap.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: (_) => onDragStart(),
        onVerticalDragUpdate: (d) => onDragUpdate(d.delta.dy),
        onVerticalDragEnd: (_) => onDragEnd(),
        onDoubleTap: onDoubleTap,
        child: Container(
          height: W.dividerHitHeight,
          color: Paper.sheet,
          alignment: Alignment.center,
          child: Container(
            // Keyed so a test can measure the air under it: that gap is one
            // half of the tray's symmetry and nothing else can find it.
            key: const Key('splitter-handle'),
            width: 40,
            height: active ? 4 : 3,
            color: active ? W.text : W.lineSoft,
          ),
        ),
      ),
    );
  }
}
