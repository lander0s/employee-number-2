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

import 'package:flutter/material.dart';

import '../model/program.dart';
import 'floor_pane.dart';
import 'program_pane.dart';
import 'tray.dart';
import 'wireframe.dart';

const _programFocused = 0.38;
const _floorFocused = 0.60;
const _minFloor = 0.0;
const _maxFloor = 1.0;

/// Floor heights below this collapse the pane entirely: the run button lives in
/// the floor, and a floor too short to reach it would be a dead strip.
const _minRunnableFloor = RunButton.height + 36;

class GameplayScreen extends StatefulWidget {
  const GameplayScreen({super.key});

  @override
  State<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends State<GameplayScreen> {
  final _doc = ProgramDocument();

  /// The pane answers drags that start in the tray as well as its own, so the
  /// screen holds the handle that lets one talk to the other.
  final _pane = GlobalKey<ProgramPaneState>();
  double _floorFraction = _programFocused;
  bool _draggingDivider = false;

  /// Fake, for the moment: the button flips state so the two labels can be felt.
  /// Nothing executes.
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _doc.loadSample();
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
    return Scaffold(
      backgroundColor: W.page,
      body: SafeArea(
        child: Column(
          children: [
            Chrome(child: const _TaskCard()),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final available = constraints.maxHeight - W.dividerHitHeight;
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
                                running: _running,
                                onToggleRun: () =>
                                    setState(() => _running = !_running),
                                onLoadSample: () {
                                  _doc.loadSample();
                                  _refresh();
                                },
                                onClear: () {
                                  _doc.clear();
                                  _refresh();
                                },
                                rows: _doc.rowCount,
                                depth: _doc.maxDepth,
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
                        child: ProgramPane(
                          key: _pane,
                          doc: _doc,
                          onChanged: _refresh,
                          running: _running,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            // The tray is hidden while running: nothing can be inserted, and
            // the program pane gets the space back to watch the program in.
            if (!_running)
              Chrome(
                child: CommandTray(
                  // A command carried up from the tray scrolls the program when
                  // it reaches an edge, exactly as a row being moved does.
                  onDragUpdate: (position) =>
                      _pane.currentState?.autoScrollTo(position),
                  onDragEnd: () => _pane.currentState?.stopAutoScroll(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _refresh() => setState(() {});
}

const _taskText = 'Ship only the positive numbers.';

/// 7.1's task card: the brief, pinned, display-only, plus `[i]` to re-open it -
/// 5 requires the brief to always be re-openable.
class _TaskCard extends StatelessWidget {
  const _TaskCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: W.chrome,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TASK', style: W.meta),
                const SizedBox(height: 2),
                Text(
                  _taskText,
                  style: W.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Builder(
            builder: (context) => _InfoButton(onTap: () => _showBrief(context)),
          ),
        ],
      ),
    );
  }

  void _showBrief(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: W.chrome,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('THE BRIEF', style: W.meta),
            const SizedBox(height: 8),
            Text(_taskText, style: W.label),
            const SizedBox(height: 12),
            Text(
              'The boss call replays here. Not built in this experiment.',
              style: W.labelDim,
            ),
            const SizedBox(height: 16),
            WButton(
              label: 'Back to work',
              wide: true,
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoButton extends StatelessWidget {
  const _InfoButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: 'Re-open the brief',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: W.minTarget,
          constraints: const BoxConstraints(minHeight: W.minTarget),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: W.button,
            border: Border.all(color: W.line),
          ),
          child: Text('i', style: W.label.copyWith(color: W.text)),
        ),
      ),
    );
  }
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
