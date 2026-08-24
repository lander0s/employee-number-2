/// The program pane: rows, caret, and block-aware drag reorder.
///
/// Flutter gives us nothing for the drag here. ReorderableListView moves one row
/// and knows nothing about a REPEAT owning its body, so this is hand-rolled from
/// LongPressDraggable plus explicit DragTarget slots, exactly as
/// game-design-document.md 13.3 predicts it has to be.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../model/program.dart';
import 'program_row.dart';
import 'wireframe.dart';

class ProgramPane extends StatefulWidget {
  const ProgramPane({super.key, required this.doc, required this.onChanged});

  final ProgramDocument doc;
  final VoidCallback onChanged;

  @override
  State<ProgramPane> createState() => ProgramPaneState();
}

class ProgramPaneState extends State<ProgramPane> {
  final _scroll = ScrollController();
  final _paneKey = GlobalKey();
  String? _draggingId;
  Timer? _autoScroll;

  ProgramDocument get doc => widget.doc;

  @override
  void dispose() {
    _autoScroll?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _mutate(void Function() change) {
    setState(change);
    widget.onChanged();
  }

  /// Drag near the top or bottom edge scrolls the list, so a long program can be
  /// reordered without letting go.
  ///
  /// The pane's geometry is resolved here rather than in build: during build the
  /// render box may not be laid out yet, and localToGlobal asserts on it.
  void _startAutoScroll(Offset globalPosition) {
    _autoScroll?.cancel();
    const edge = 90.0;
    const speed = 14.0;

    final box = _paneKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final y = globalPosition.dy - box.localToGlobal(Offset.zero).dy;
    final direction = y < edge
        ? -1.0
        : y > box.size.height - edge
        ? 1.0
        : 0.0;
    if (direction == 0) return;
    _autoScroll = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_scroll.hasClients) return;
      final next = (_scroll.offset + direction * speed).clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      );
      _scroll.jumpTo(next);
    });
  }

  void _stopAutoScroll() {
    _autoScroll?.cancel();
    _autoScroll = null;
  }

  @override
  Widget build(BuildContext context) {
    final items = doc.flattenWithSlots();
    final dragging = _draggingId != null;

    return Container(
      key: _paneKey,
      color: W.paneProgram,
      child: Column(
        children: [
          Expanded(
            child: doc.root.isEmpty && !dragging
                ? _EmptyState(
                    slot: const Slot(null, 0, 0),
                    onTapSlot: (slot) => _mutate(() => doc.setCaret(slot)),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.only(bottom: 40),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final item = items[i];
                      if (item is Slot) {
                        return _SlotWidget(
                          slot: item,
                          caret: doc.caret,
                          dragActive: dragging,
                          accepts: (id) => _accepts(id, item),
                          onTap: () => _mutate(() => doc.setCaret(item)),
                          onAccept: (id) => _mutate(() {
                            doc.move(id, item);
                          }),
                        );
                      }
                      return _buildRow(item as DisplayRow);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// A block may not be dropped into its own body.
  bool _accepts(String draggedId, Slot slot) {
    if (slot.parentId == null) return true;
    return !doc.contains(draggedId, slot.parentId!);
  }

  Widget _buildRow(DisplayRow row) {
    final rowWidget = ProgramRow(
      row: row,
      dragging: _draggingId == row.node.id,
      onTap: () => _mutate(() => doc.setCaret(_caretForRow(row))),
      onDelete: () => _confirmDelete(row),
      onDuplicate: () => _mutate(() => doc.duplicate(row.node.id)),
      onCycleArg: (slot) => _mutate(() => doc.cycleArg(row.node.id, slot)),
    );

    if (!row.isDraggable) return rowWidget;

    return LongPressDraggable<String>(
      data: row.node.id,
      delay: const Duration(milliseconds: 180),
      onDragStarted: () => setState(() => _draggingId = row.node.id),
      onDragUpdate: (d) => _startAutoScroll(d.globalPosition),
      onDragEnd: (_) {
        _stopAutoScroll();
        setState(() => _draggingId = null);
      },
      onDraggableCanceled: (_, _) {
        _stopAutoScroll();
        setState(() => _draggingId = null);
      },
      feedback: _DragFeedback(doc: doc, row: row),
      childWhenDragging: rowWidget,
      child: rowWidget,
    );
  }

  /// Tapping a row parks the caret "below" it - which for a block header means
  /// the first slot inside the block, since that is where a program continues.
  Slot _caretForRow(DisplayRow row) {
    final node = row.node;
    if (row.kind == RowKind.blockHeader) {
      return Slot(node.id, 0, row.depth + 1);
    }
    final located = doc.flattenWithSlots();
    // The slot immediately following this row in render order is the one that
    // means "after this row, in this row's parent".
    final index = located.indexWhere(
      (e) => e is DisplayRow && e.node.id == node.id && e.kind == row.kind,
    );
    for (var i = index + 1; i < located.length; i++) {
      final candidate = located[i];
      if (candidate is Slot) return candidate;
    }
    return Slot(null, doc.root.length, 0);
  }

  Future<void> _confirmDelete(DisplayRow row) async {
    final node = row.node;
    final hasBody = node.isBlock && (node.children?.isNotEmpty ?? false);

    if (!hasBody) {
      _mutate(() => doc.delete(node.id));
      _toast('Deleted ${node.spec.label}', onUndo: () => _mutate(doc.undo));
      return;
    }

    final keep = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: W.chrome,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('DELETE ${node.spec.label}', style: W.label),
            const SizedBox(height: 4),
            Text('This block has instructions inside it.', style: W.labelDim),
            const SizedBox(height: 16),
            WButton(
              label: 'Keep the contents',
              wide: true,
              onTap: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 8),
            WButton(
              label: 'Delete the block and its contents',
              wide: true,
              onTap: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
    if (keep == null) return;
    _mutate(() => doc.delete(node.id, keepContents: keep));
    _toast('Deleted ${node.spec.label}', onUndo: () => _mutate(doc.undo));
  }

  void _toast(String message, {required VoidCallback onUndo}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          backgroundColor: W.chrome,
          duration: const Duration(seconds: 4),
          content: Text(message, style: W.labelDim),
          action: SnackBarAction(
            label: 'UNDO',
            textColor: W.text,
            onPressed: onUndo,
          ),
        ),
      );
  }
}

/// An insertion point. Doubles as the caret when idle and as a drop target
/// during a drag.
class _SlotWidget extends StatefulWidget {
  const _SlotWidget({
    required this.slot,
    required this.caret,
    required this.dragActive,
    required this.accepts,
    required this.onTap,
    required this.onAccept,
  });

  final Slot slot;
  final Slot caret;
  final bool dragActive;
  final bool Function(String) accepts;
  final VoidCallback onTap;
  final ValueChanged<String> onAccept;

  @override
  State<_SlotWidget> createState() => _SlotWidgetState();
}

class _SlotWidgetState extends State<_SlotWidget> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isCaret = widget.slot == widget.caret;

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        final ok = widget.accepts(details.data);
        if (ok) setState(() => _hovering = true);
        return ok;
      },
      onLeave: (_) => setState(() => _hovering = false),
      onAcceptWithDetails: (details) {
        setState(() => _hovering = false);
        widget.onAccept(details.data);
      },
      builder: (context, candidate, rejected) {
        final active = _hovering || candidate.isNotEmpty;

        // The caret's height comes from its own text, not a constant, so it
        // cannot clip when the OS text scale is above 1.0. Everything else here
        // is a bare rule with no text in it, so a fixed height is safe.
        final Widget child;
        final double? fixedHeight;
        if (active) {
          child = Container(height: 4, color: W.dropTarget);
          fixedHeight = 34;
        } else if (widget.dragActive) {
          child = Container(height: 1, color: W.lineSoft);
          fixedHeight = 16;
        } else if (isCaret) {
          child = const _Caret();
          fixedHeight = null;
        } else {
          child = const SizedBox.shrink();
          fixedHeight = 6;
        }

        return GestureDetector(
          onTap: widget.onTap,
          child: Container(
            height: fixedHeight,
            // The caret occupies a full instruction row: it is where the next
            // instruction will land, so it should be the size of one. Still a
            // minimum rather than a fixed height, so it grows with text scale.
            constraints: isCaret
                ? const BoxConstraints(minHeight: W.rowHeight)
                : null,
            padding: EdgeInsets.symmetric(vertical: isCaret ? 8 : 0),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(width: W.rowInset),
                  Spines(depth: widget.slot.depth),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(alignment: Alignment.centerLeft, child: child),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The insertion caret: a full-height row carrying a dash and a label, blinking
/// like a text cursor so it reads as a cursor rather than as an instruction.
///
/// Blinking is suppressed under `disableAnimations` - a blinking element is
/// exactly what that setting exists for - and the timer is cancelled in that
/// case rather than left spinning.
class _Caret extends StatefulWidget {
  const _Caret();

  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret> {
  /// Matches Flutter's own text caret cadence.
  static const _halfPeriod = Duration(milliseconds: 500);

  Timer? _timer;
  bool _on = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _timer?.cancel();
      _timer = null;
      _on = true;
    } else {
      _timer ??= Timer.periodic(_halfPeriod, (_) {
        if (mounted) setState(() => _on = !_on);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Opacity rather than removing the child: the row must not change height
    // between blinks.
    return Opacity(
      opacity: _on ? 1 : 0,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 26, height: 3, color: W.caret),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'INSERT HERE',
              // Same size and weight as an instruction row: a smaller caret read
              // as a different kind of thing.
              style: W.row.copyWith(color: W.textDim),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
        ],
      ),
    );
  }
}

/// What follows the finger during a drag. Renders the whole subtree, so it is
/// visible that a block carries its body.
class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.doc, required this.row});
  final ProgramDocument doc;
  final DisplayRow row;

  @override
  Widget build(BuildContext context) {
    final node = row.node;
    final rows = <DisplayRow>[];

    void walk(node, int depth) {
      rows.add(
        DisplayRow(
          node: node,
          kind: node.isBlock ? RowKind.blockHeader : RowKind.command,
          depth: depth,
        ),
      );
      for (final c in [...?node.children]) {
        walk(c, depth + 1);
      }
      if (node.isBlock) {
        rows.add(
          DisplayRow(node: node, kind: RowKind.blockCloser, depth: depth),
        );
      }
    }

    walk(node, 0);

    return Opacity(
      opacity: 0.92,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 300,
          decoration: BoxDecoration(
            border: Border.all(color: W.text, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final r in rows.take(8))
                ProgramRow(
                  row: r,
                  ghost: true,
                  onTap: () {},
                  onDelete: () {},
                  onDuplicate: () {},
                  onCycleArg: (_) {},
                ),
              if (rows.length > 8)
                Container(
                  height: 24,
                  color: W.chrome,
                  alignment: Alignment.center,
                  child: Text('+${rows.length - 8} more', style: W.meta),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.slot, required this.onTapSlot});
  final Slot slot;
  final ValueChanged<Slot> onTapSlot;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTapSlot(slot),
      child: Container(
        alignment: Alignment.topLeft,
        padding: const EdgeInsets.fromLTRB(44, 18, 18, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Caret(),
            const SizedBox(height: 14),
            Text('Tap a command below to add it here.', style: W.labelDim),
          ],
        ),
      ),
    );
  }
}
