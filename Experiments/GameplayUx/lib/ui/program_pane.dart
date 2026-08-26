/// The program pane: nested block containers, spacers, and block-aware drag
/// reorder.
///
/// Insertion works by **dragging a command out of the tray and dropping it into
/// a spacer**. Every legal insertion point is a visible gap between siblings, as
/// thick as the container's left arm; the one under the finger expands into the
/// shape of the row about to land there.
///
/// Nothing is expanded when nothing is being dragged. An expanded gap only means
/// "this is where the thing you are holding will go", so it has no meaning
/// without something in hand - and a drop that is not over a spacer does
/// nothing.
///
/// There is no insertion point stored anywhere. A drop names its own place, so
/// there is no state to keep in sync and no rule about where a command "goes".
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

  /// While running, the program is read-only: no spacers, no drop targets, no
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
    return Container(
      key: _paneKey,
      color: W.paneProgram,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth + W.programOverhang;

          return CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverToBoxAdapter(
                child: _overhang(width, _buildList(doc.root, null, 0)),
              ),
              // The last spacer at the root owns everything below the program.
              // As an 18-tall strip it was an invisible edge you had to hit
              // exactly, and on an empty program there was nothing to hit at
              // all - the pane rendered a hint and no drop target whatsoever.
              //
              // SliverFillRemaining grows it into the leftover viewport and
              // shrinks it back to a normal spacer once the program is long
              // enough to scroll.
              if (!widget.running)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _overhang(
                    width,
                    _buildSlot(
                      Slot(null, doc.root.length, 0),
                      null,
                      key: const ValueKey('program-tail'),
                      fill: true,
                      hint: doc.root.isEmpty
                          ? Text(
                              'Drag a command up from below.',
                              style: W.labelDim,
                            )
                          : null,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Laid out wider than the pane and clipped, so no block ever shows its right
  /// edge. The inner scroll view exists only to give the extra width a
  /// legitimate home - it never scrolls, and without it Flutter would report the
  /// overflow as an error.
  Widget _overhang(double width, Widget child) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    physics: const NeverScrollableScrollPhysics(),
    child: SizedBox(width: width, child: child),
  );

  /// One child list: a slot before every node and one after the last, so every
  /// legal insertion point - including an empty block body - is reachable.
  ///
  /// [on] is the colour of the block this list sits inside, or null at the root.
  /// Spacers need it: an expanded gap drawn in the dark theme pale grey is
  /// invisible on a bright yellow block.
  Widget _buildList(
    List<Node> nodes,
    String? parentId,
    int depth, {
    Color? on,
  }) {
    // While running there are no slots at all, so no drop target exists on a
    // program that cannot be edited.
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
        // The root's trailing slot is not here: it is the sliver that fills the
        // rest of the pane, so that dropping below the program always works.
        if (parentId != null)
          _buildSlot(
            Slot(parentId, nodes.length, depth),
            on,
            // An empty block's body is this one slot and nothing else, so it is
            // the only thing that can say "something goes in here".
            wide: nodes.isEmpty,
          ),
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
      // No margin. The spacers on either side are the separation, and a margin
      // on top of them would be a second spacing system that means nothing.
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(W.blockRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Only the header is draggable: a draggable wrapping the whole
          // container would fight its own children for the gesture.
          _draggable(
            node,
            _buildRow(
              DisplayRow(node: node, kind: RowKind.blockHeader, depth: depth),
            ),
          ),
          // The body's trailing spacer *is* the bottom arm of the "C": it is
          // already the same thickness as the left arm, and the left arm runs
          // down past it, so together they close the bracket.
          //
          // An empty body needs no special minimum either: one spacer is the
          // body, and it is exactly the right height already.
          Padding(
            padding: const EdgeInsets.only(left: W.indentPerDepth, right: 4),
            child: body,
          ),
        ],
      ),
    );
  }

  Widget _buildSlot(
    Slot slot,
    Color? on, {
    Key? key,
    bool fill = false,
    bool wide = false,
    Widget? hint,
  }) => _SlotWidget(
    key: key,
    slot: slot,
    on: on,
    fill: fill,
    wide: wide,
    hint: hint,
    accepts: (payload) => _accepts(payload, slot),
    onAccept: (payload) => _mutate(() {
      switch (payload) {
        case NewCommand(:final commandId):
          doc.insertAt(commandId, slot);
        case MoveNode(:final id):
          doc.move(id, slot);
      }
    }),
  );

  /// A command from the tray fits anywhere. A node already in the program may
  /// not be dropped into its own body.
  bool _accepts(DragPayload payload, Slot slot) => switch (payload) {
    NewCommand() => true,
    MoveNode(:final id) =>
      slot.parentId == null || !doc.contains(id, slot.parentId!),
  };

  Widget _buildRow(DisplayRow row) => ProgramRow(
    row: row,
    interactive: !widget.running,
    dragging: _draggingId == row.node.id,
    onDelete: () => _confirmDelete(row),
    onDuplicate: () => _mutate(() => doc.duplicate(row.node.id)),
    onCycleArg: (slot) => _mutate(() => doc.cycleArg(row.node.id, slot)),
  );

  Widget _draggable(Node node, Widget rowWidget) {
    if (widget.running) return rowWidget;

    return LongPressDraggable<DragPayload>(
      data: MoveNode(node.id),
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
    super.key,
    required this.slot,
    required this.on,
    required this.accepts,
    required this.onAccept,
    this.fill = false,
    this.wide = false,
    this.hint,
  });

  final Slot slot;

  /// The enclosing block's colour, or null at the root.
  final Color? on;

  final bool Function(DragPayload) accepts;
  final ValueChanged<DragPayload> onAccept;

  /// True for the trailing root spacer, which grows to fill the pane. Its drop
  /// area stays one row tall at the top; the rest is reach.
  final bool fill;

  /// True for the lone spacer in an empty block body, which is drawn thicker so
  /// the gap reads as a container waiting for something.
  final bool wide;

  /// Shown in place of the drop outline when the program is empty.
  final Widget? hint;

  @override
  State<_SlotWidget> createState() => _SlotWidgetState();
}

class _SlotWidgetState extends State<_SlotWidget> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return DragTarget<DragPayload>(
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
        // Expanded only while something is held over it.
        final open = _hovering || candidate.isNotEmpty;

        // On a bright block this is drawn in ink; on the dark pane, in the pale
        // theme colour.
        final markColour = widget.on != null ? W.ink : W.caret;

        if (widget.fill) {
          return Container(
            constraints: const BoxConstraints(minHeight: W.indentPerDepth),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            alignment: Alignment.topLeft,
            child: open
                ? SizedBox(
                    height: W.rowHeight,
                    child: _OpenGap(colour: markColour),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 8, 0),
                    child: widget.hint,
                  ),
          );
        }

        // An empty body keeps the same height whether or not something is held
        // over it: the shape that lands there is already reserved. The bottom
        // padding is the gap a real command would have below it, so the dashed
        // outline sits exactly where the row will sit.
        if (widget.wide) {
          return Container(
            constraints: const BoxConstraints(minHeight: W.emptyBodyHeight),
            padding: const EdgeInsets.fromLTRB(4, 2, 4, W.indentPerDepth + 2),
            child: open
                ? _OpenGap(colour: markColour)
                : const SizedBox.shrink(),
          );
        }

        return Container(
          height: open ? null : W.indentPerDepth,
          // Open, it is the size of an instruction row - still a minimum, so it
          // grows with text scale like one.
          constraints: open
              ? const BoxConstraints(minHeight: W.rowHeight)
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: open ? _OpenGap(colour: markColour) : const SizedBox.shrink(),
        );
      },
    );
  }
}

/// A spacer with something held over it: the shape of the instruction about to
/// land in it.
///
/// It only ever appears mid-drag, so it needs no label explaining what it is for
/// - the thing it is for is under the player's finger.
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
            'DROP HERE',
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
