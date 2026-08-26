/// The program pane: nested block containers, spacers, and block-aware drag
/// reorder.
///
/// Insertion works through **spacers**, not a caret. Every legal insertion point
/// is a visible gap between siblings, as thick as the container's left arm. Tap
/// one and it expands into the shape of the row about to land there; tap
/// anything else and it closes. There is no invisible position to remember and no
/// rule about where a command "goes" - the answer is already on screen.
///
/// That also means a row is just a row again. Tapping one used to move the
/// insertion point somewhere else, which is exactly the indirection this
/// replaces.
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

    return GestureDetector(
      // Everything below the program belongs to the end of the program. The
      // trailing spacer is 18 tall and invisible against the pane, so reaching
      // it was a game of hitting an edge; this makes the whole empty area the
      // same target. Rows and spacers are opaque, so they still win their own
      // taps - this only catches what nothing else claimed.
      behavior: HitTestBehavior.opaque,
      onTap: () => _mutate(() => doc.setCaret(Slot(null, doc.root.length, 0))),
      child: Container(
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

    return GestureDetector(
      // The left arm and the corners are part of *this* block, so a tap there
      // opens this block's trailing gap rather than falling through to the pane
      // and jumping to the end of the whole program.
      behavior: HitTestBehavior.opaque,
      onTap: () => _mutate(
        () => doc.setCaret(Slot(node.id, node.children!.length, depth + 1)),
      ),
      child: Container(
        // No margin. The spacers on either side are the separation, and a margin
        // on top of them would be a second spacing system that means nothing.
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
            // The body's trailing spacer *is* the bottom arm of the "C": it is
            // already the same thickness as the left arm, and the left arm runs
            // down past it, so together they close the bracket. There used to be a
            // separate foot bar here, which meant 36 of bottom edge where 18 was
            // wanted - and half of it was dead space that only closed the gap.
            //
            // An empty body needs no special minimum either: one spacer is the
            // body, and it is exactly the right height already.
            Padding(
              padding: const EdgeInsets.only(left: W.indentPerDepth, right: 4),
              child: body,
            ),
          ],
        ),
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
    onTap: () => _mutate(doc.closeGap),
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

  /// The open gap, or null when none is.
  final Slot? caret;

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
    final isOpen = widget.slot == widget.caret;

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
        final dropColour = onColour ? W.ink : W.dropTarget;

        // A spacer is always there and always the same thickness as the
        // container's left arm, so the program has one structural unit and every
        // gap in it means the same thing: something can go here.
        //
        // Open, it takes the shape of the row about to land in it. It is not a
        // caret: there is nothing to remember and nothing blinking, just a gap
        // that is currently wide.
        final Widget child;
        final double? fixedHeight;
        if (active) {
          child = Container(height: 4, color: dropColour);
          fixedHeight = null;
        } else if (isOpen) {
          child = _OpenGap(colour: markColour);
          fixedHeight = null;
        } else {
          child = const SizedBox.shrink();
          fixedHeight = W.indentPerDepth;
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            height: fixedHeight,
            // Open, it is the size of an instruction row - still a minimum, so
            // it grows with text scale like one.
            constraints: fixedHeight == null
                ? const BoxConstraints(minHeight: W.rowHeight)
                : null,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: child,
          ),
        );
      },
    );
  }
}

/// An expanded spacer: the shape of the instruction about to land in it.
///
/// This replaced a blinking caret. The blink was a text-cursor metaphor, and the
/// whole point of spacers is that the insertion point is a place rather than a
/// cursor - a gap that is currently wide needs no animation to explain itself.
class _OpenGap extends StatelessWidget {
  const _OpenGap({required this.colour});

  final Color colour;

  @override
  Widget build(BuildContext context) {
    return DottedOutline(
      colour: colour,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: W.rowInset - 4, right: 10),
          child: Text(
            'INSERT HERE',
            style: W.row.copyWith(color: colour, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
      ),
    );
  }
}

/// A dashed border in the row's own corner radius, so an open gap reads as a
/// space waiting to be filled rather than as another card.
class DottedOutline extends StatelessWidget {
  const DottedOutline({super.key, required this.colour, required this.child});

  final Color colour;
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DashPainter(colour: colour),
    child: child,
  );
}

class _DashPainter extends CustomPainter {
  const _DashPainter({required this.colour});

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      const Radius.circular(W.rowRadius),
    );

    // Walk the outline, drawing every other segment.
    const dash = 7.0;
    const gap = 5.0;
    for (final metric in (Path()..addRRect(rect)).computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final end = (d + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(d, end), paint);
        d = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.colour != colour;
}

/// What follows the finger during a drag: the real nested shape, so a block
/// visibly carries its body while in the air.
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
        ],
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
            SizedBox(
              height: W.rowHeight,
              width: 220,
              child: const _OpenGap(colour: W.caret),
            ),
            const SizedBox(height: 14),
            Text('Tap a command below to add it here.', style: W.labelDim),
          ],
        ),
      ),
    );
  }
}
