/// The program pane: nested block containers, caret, and block-aware drag
/// reorder.
///
/// A block is drawn as a literal container with its body inset, so it reads as a
/// "C" wrapped around the instructions it owns. There are no connector lines: the
/// container's own shape says what belongs to what, which a naive eye reads
/// without being taught. Nesting alternates two background tones, so an inner
/// block always contrasts with the one holding it.
///
/// That means the pane is a recursive widget tree rather than a flat list, and
/// the tree is built eagerly inside a scroll view. Fine at puzzle scale; see the
/// README's known gaps for what that costs.
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
  const ProgramPane({
    super.key,
    required this.doc,
    required this.onChanged,
    required this.running,
  });

  final ProgramDocument doc;
  final VoidCallback onChanged;

  /// While running, the program is read-only: no caret, no drop slots, no
  /// gestures. A program that cannot be edited should not keep offering the
  /// affordances of editing.
  final bool running;

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
    final empty = doc.root.isEmpty && _draggingId == null;

    return Container(
      key: _paneKey,
      color: W.paneProgram,
      child: empty
          ? _EmptyState(
              slot: const Slot(null, 0, 0),
              onTapSlot: (slot) => _mutate(() => doc.setCaret(slot)),
            )
          : LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.only(bottom: 40),
                // Laid out wider than the pane and clipped, so no block ever
                // shows its right edge. The inner scroll view exists only to
                // give the extra width a legitimate home - it never scrolls, and
                // without it Flutter would report the overflow as an error.
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: SizedBox(
                    width: constraints.maxWidth + W.programOverhang,
                    child: _buildList(doc.root, null, 0),
                  ),
                ),
              ),
            ),
    );
  }

  /// One child list: a slot before every node and one after the last, so every
  /// legal insertion point - including an empty block body - is reachable.
  ///
  /// [on] is the colour of the block this list sits inside, or null at the root.
  /// Slots need it: a caret drawn in the dark theme's pale grey is invisible on
  /// a bright yellow block.
  Widget _buildList(
    List<Node> nodes,
    String? parentId,
    int depth, {
    Color? on,
  }) {
    // While running there are no slots at all, so the caret and every drop gap
    // disappear together rather than being individually suppressed.
    if (widget.running) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final node in nodes) _buildNode(node, depth)],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < nodes.length; i++) ...[
          _buildSlot(Slot(parentId, i, depth), on),
          _buildNode(nodes[i], depth),
        ],
        _buildSlot(Slot(parentId, nodes.length, depth), on),
      ],
    );
  }

  Widget _buildNode(Node node, int depth) {
    if (!node.isBlock) {
      return _draggable(
        node,
        _buildRow(DisplayRow(node: node, kind: RowKind.command, depth: depth)),
      );
    }

    final fill = W.blockFill(node.spec.colour, depth);
    final body = _buildList(node.children!, node.id, depth + 1, on: fill);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(W.blockRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Only the header is draggable, as before: a draggable wrapping the
          // whole container would fight its own children for the gesture.
          _draggable(
            node,
            _buildRow(
              DisplayRow(node: node, kind: RowKind.blockHeader, depth: depth),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: W.indentPerDepth, right: 4),
            child: node.children!.isEmpty
                // An empty body still has to show the inset, or the container
                // stops reading as a container.
                ? ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 18),
                    child: body,
                  )
                : body,
          ),
          _BlockFoot(
            onTap: () => _mutate(
              () => doc.setCaret(
                _caretForRow(
                  DisplayRow(
                    node: node,
                    kind: RowKind.blockCloser,
                    depth: depth,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlot(Slot slot, Color? on) => _SlotWidget(
    slot: slot,
    on: on,
    caret: doc.caret,
    dragActive: _draggingId != null,
    accepts: (id) => _accepts(id, slot),
    onTap: () => _mutate(() => doc.setCaret(slot)),
    onAccept: (id) => _mutate(() {
      doc.move(id, slot);
    }),
  );

  /// A block may not be dropped into its own body.
  bool _accepts(String draggedId, Slot slot) {
    if (slot.parentId == null) return true;
    return !doc.contains(draggedId, slot.parentId!);
  }

  Widget _buildRow(DisplayRow row) => ProgramRow(
    row: row,
    interactive: !widget.running,
    dragging: _draggingId == row.node.id,
    onTap: () => _mutate(() => doc.setCaret(_caretForRow(row))),
    onDelete: () => _confirmDelete(row),
    onDuplicate: () => _mutate(() => doc.duplicate(row.node.id)),
    onCycleArg: (slot) => _mutate(() => doc.cycleArg(row.node.id, slot)),
  );

  Widget _draggable(Node node, Widget rowWidget) {
    if (widget.running) return rowWidget;

    return LongPressDraggable<String>(
      data: node.id,
      delay: const Duration(milliseconds: 180),
      onDragStarted: () => setState(() => _draggingId = node.id),
      onDragUpdate: (d) => _startAutoScroll(d.globalPosition),
      onDragEnd: (_) {
        _stopAutoScroll();
        setState(() => _draggingId = null);
      },
      onDraggableCanceled: (_, _) {
        _stopAutoScroll();
        setState(() => _draggingId = null);
      },
      feedback: _DragFeedback(node: node),
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
    required this.on,
    required this.caret,
    required this.dragActive,
    required this.accepts,
    required this.onTap,
    required this.onAccept,
  });

  final Slot slot;

  /// The enclosing block's colour, or null at the root.
  final Color? on;

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

        // On a bright block everything here has to be drawn in ink; on the dark
        // pane it is drawn in the pale theme colours.
        final onColour = widget.on != null;
        final markColour = onColour ? W.ink : W.caret;
        final ruleColour = onColour ? W.inkDim : W.lineSoft;
        final dropColour = onColour ? W.ink : W.dropTarget;

        // The caret's height comes from its own text, not a constant, so it
        // cannot clip when the OS text scale is above 1.0. Everything else here
        // is a bare rule with no text in it, so a fixed height is safe.
        final Widget child;
        final double? fixedHeight;
        if (active) {
          child = Container(height: 4, color: dropColour);
          fixedHeight = 34;
        } else if (widget.dragActive) {
          child = Container(height: 1, color: ruleColour);
          fixedHeight = 16;
        } else if (isCaret) {
          child = _Caret(colour: markColour);
          fixedHeight = null;
        } else {
          // Zero, so rows sit flush against each other and the list reads as one
          // block of text. The slot only needs height when it has something to
          // show - the caret, or a drop target during a drag. It used to keep 6px
          // to stay tappable, but tapping a *row* already places the caret, so
          // the height bought nothing.
          child = const SizedBox.shrink();
          fixedHeight = 0;
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
            // The caret stands in for the row that is about to land here, so it
            // carries the same margin a command row does.
            margin: isCaret ? const EdgeInsets.symmetric(vertical: 2) : null,
            padding: EdgeInsets.only(
              left: W.rowInset,
              right: 10,
              top: isCaret ? 8 : 0,
              bottom: isCaret ? 8 : 0,
            ),
            child: Align(alignment: Alignment.centerLeft, child: child),
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
  const _Caret({required this.colour});

  /// Dark ink on a coloured block, pale on the dark pane.
  final Color colour;

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
          Container(width: 26, height: 3, color: widget.colour),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'INSERT HERE',
              // Same size and weight as an instruction row: a smaller caret read
              // as a different kind of thing.
              style: W.row.copyWith(color: widget.colour),
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
  const _DragFeedback({required this.node});

  final Node node;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.92,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 300,
          decoration: BoxDecoration(
            border: Border.all(color: W.text, width: 2),
          ),
          child: _ghost(node, 0),
        ),
      ),
    );
  }

  /// The same shape the pane draws, minus every gesture. Depth restarts at 0 so
  /// the ghost is tinted as if it were top level.
  Widget _ghost(Node node, int depth) {
    Widget row(RowKind kind) => ProgramRow(
      row: DisplayRow(node: node, kind: kind, depth: depth),
      interactive: false,
      onTap: () {},
      onDelete: () {},
      onDuplicate: () {},
      onCycleArg: (_) {},
    );

    if (!node.isBlock) return row(RowKind.command);

    return Container(
      color: W.blockFill(node.spec.colour, depth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          row(RowKind.blockHeader),
          Padding(
            padding: const EdgeInsets.only(left: W.indentPerDepth, right: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final child in node.children!.take(4))
                  _ghost(child, depth + 1),
                if (node.children!.length > 4)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '+${node.children!.length - 4} more',
                      style: W.meta,
                    ),
                  ),
              ],
            ),
          ),
          const _BlockFoot(),
        ],
      ),
    );
  }
}

/// The bottom arm of a block's "C".
///
/// It used to be a row reading `END`. The word was redundant once the block
/// became a container - the shape already says where it stops - so the foot is
/// now just a bar as thick as the left arm, which makes the bracket symmetrical.
///
/// It stays tappable, because the bottom edge of a block is exactly where you go
/// to add an instruction *after* it. Short (18) but full width, and opaque, so
/// the whole strip answers.
class _BlockFoot extends StatelessWidget {
  const _BlockFoot({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: const SizedBox(height: W.indentPerDepth),
  );
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
            const _Caret(colour: W.caret),
            const SizedBox(height: 14),
            Text('Tap a command below to add it here.', style: W.labelDim),
          ],
        ),
      ),
    );
  }
}
