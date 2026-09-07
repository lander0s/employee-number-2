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
import 'floor_pane.dart';
import 'run_controller.dart';
import 'notebook/lift.dart';
import 'notebook/note.dart';
import 'notebook/program.dart';
import 'wireframe.dart';

const _programFocused = 0.38;
const _floorFocused = 0.60;
const _minFloor = 0.0;
const _maxFloor = 1.0;

/// Floor heights below this collapse the pane entirely: the run button lives in
/// the floor, and a floor too short to reach it would be a dead strip.
const _minRunnableFloor = RunButton.height + 36;

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

  /// The note lies *over* the page, so the page has to know how much of its
  /// bottom edge is covered. Measured rather than computed: the note's height
  /// follows the OS text scale, so there is no constant to use.
  final _pageKey = GlobalKey();
  final _noteKey = GlobalKey();
  double _noteHeight = 0;

  void _measureNote() {
    final box = _noteKey.currentContext?.findRenderObject() as RenderBox?;
    final height = _running ? 0.0 : (box?.size.height ?? 0);
    if (mounted && height != _noteHeight) {
      setState(() => _noteHeight = height);
    }
  }

  /// The part of the page a finger can actually reach: the note covers the rest.
  Rect _visiblePage() {
    final box = _pageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return Rect.zero;
    final origin = box.localToGlobal(Offset.zero);
    return origin & Size(box.size.width, box.size.height - _noteHeight);
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
    _autoScroll.dispose();
    _lift.dispose();
    _scroll.dispose();
    super.dispose();
  }

  double _floorFraction = _programFocused;
  bool _draggingDivider = false;

  /// The machine, and the playback of what it did.
  ///
  /// The program is compiled and executed the instant RUN is pressed - the
  /// verdict exists before the first frame of playback - and this walks the
  /// trace so the page and the floor can show the same instruction.
  late final RunController _run = RunController(level: widget.level);

  bool get _running => _run.running;

  void _toggleRun() {
    if (_run.running) {
      _run.stop();
    } else {
      _run.start(_doc);
    }
  }

  @override
  void initState() {
    super.initState();
    _doc = widget.program ?? (ProgramDocument()..loadSample());
    // The whole screen rebuilds on every tick. It is a page of text and a
    // dozen boxes at two or three frames a second, and threading a notifier
    // through to the two places that care would buy nothing measurable.
    _run.addListener(_refresh);
  }

  void _snapTo(double target) => setState(() => _floorFraction = target);

  void _toggleSnap() {
    final toFloor =
        (_floorFraction - _floorFocused).abs() >
        (_floorFraction - _programFocused).abs();
    _snapTo(toFloor ? _floorFocused : _programFocused);
  }

  /// On release, settle onto a snap state if we are close to one, otherwise
  /// leave the divider where it was put.
  void _settle() {
    const threshold = 0.05;
    for (final snap in const [_programFocused, _floorFocused]) {
      if ((_floorFraction - snap).abs() < threshold) {
        _snapTo(snap);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // The note's height is only knowable once it has laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureNote());

    return Scaffold(
      backgroundColor: W.page,
      // No SafeArea: the game runs full screen (see main.dart), so there are no
      // bars to keep clear of, and the insets the platform still reports for
      // them left a band of dead board across the top of the panel.
      body: SafeArea(
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
                  final available = (constraints.maxHeight - W.dividerHitHeight)
                      .clamp(0.0, double.infinity);
                  final floorHeight = (available * _floorFraction).clamp(
                    0.0,
                    available,
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
                                onToggleRun: _toggleRun,
                              )
                            : const SizedBox.shrink(),
                      ),
                      _Divider(
                        active: _draggingDivider,
                        onDragStart: () =>
                            setState(() => _draggingDivider = true),
                        onDragUpdate: (dy) {
                          if (available <= 0) return;
                          setState(() {
                            _floorFraction = (_floorFraction + dy / available)
                                .clamp(_minFloor, _maxFloor);
                          });
                        },
                        onDragEnd: () {
                          setState(() => _draggingDivider = false);
                          _settle();
                        },
                        onDoubleTap: _toggleSnap,
                      ),
                      Expanded(
                        // The tray is laid over the page rather than beside it.
                        // Two things fall out of that, and both are the point:
                        // the ruled sheet shows through the tray's translucency,
                        // and pressing RUN does not resize the program - the
                        // pane was already the full height, so the tray simply
                        // stops covering part of it. It used to shrink the pane,
                        // which meant every row jumped the moment a run started,
                        // at exactly the moment you want to be watching them.
                        child: Stack(
                          children: [
                            Positioned.fill(
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
                                bottomInset: _noteHeight,
                              ),
                            ),
                            if (!_running)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Chrome(
                                  child: CommandNote(
                                    key: _noteKey,
                                    lift: _lift,
                                    autoScroll: _autoScroll,
                                    onTrash: (id) {
                                      final node = _doc.nodeById(id);
                                      if (node != null) _remove(node);
                                    },
                                  ),
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
    );
  }

  void _refresh() => setState(() {});
}

/// The draggable divider. Its hit area is 34 tall even though the visible rule
/// is 2, because a 2px drag target is unusable with a thumb. No text in it, so a
/// fixed height is safe here.
///
/// The grip carries a small up and down arrow: a bare line reads as decoration,
/// and nothing else on this screen moves vertically, so the affordance has to say
/// so rather than waiting to be discovered.
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
        child: SizedBox(
          height: W.dividerHitHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The rule, running the full width behind the grip.
              Container(
                height: active ? 3 : 2,
                color: active ? W.text : W.lineSoft,
              ),
              Container(
                width: 52,
                height: 26,
                decoration: BoxDecoration(
                  color: W.chrome,
                  border: Border.all(color: active ? W.text : W.line),
                ),
                child: CustomPaint(
                  painter: _GripArrows(color: active ? W.text : W.textDim),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two small triangles, up and down, painted rather than drawn with an icon
/// font: at this size a glyph's built-in padding makes the pair too tall for the
/// grip, and painting keeps them crisp on every platform.
class _GripArrows extends CustomPainter {
  const _GripArrows({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const width = 11.0;
    const height = 6.0;
    const gap = 6.0;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final cx = size.width / 2;
    final cy = size.height / 2;

    canvas.drawPath(
      Path()
        ..moveTo(cx, cy - gap / 2 - height)
        ..lineTo(cx - width / 2, cy - gap / 2)
        ..lineTo(cx + width / 2, cy - gap / 2)
        ..close(),
      paint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(cx, cy + gap / 2 + height)
        ..lineTo(cx - width / 2, cy + gap / 2)
        ..lineTo(cx + width / 2, cy + gap / 2)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(_GripArrows oldDelegate) => oldDelegate.color != color;
}
