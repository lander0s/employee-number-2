/// The program on the page.
///
/// Walks the document's tree and draws it as nested notes: a container is a
/// sheet of its own colour wrapping everything it owns, a command is a tab
/// inside it, and between every pair of them is a gap that is also the only
/// place anything can land.
///
/// This widget owns the *interaction* on the page - lifting, dropping, swiping,
/// cycling - and the document owns the structure. It does not own deletion:
/// commands can also be dropped on the note to remove them, so the screen owns
/// that and both routes call the same thing.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../model/level.dart';
import '../../model/program.dart';
import 'brief.dart';
import 'caret.dart';
import 'panel.dart';
import 'lift.dart';
import 'page.dart';
import 'row.dart';
import 'slot.dart';
import 'tokens.dart';

class ProgramEditor extends StatefulWidget {
  const ProgramEditor({
    super.key,
    required this.doc,
    required this.brief,
    required this.controller,
    required this.lift,
    required this.autoScroll,
    required this.onChanged,
    required this.onRemove,
    this.running = false,
    this.executing,
    this.bottomInset = 0,
  });

  final ProgramDocument doc;

  /// Written at the top of the page, above the program, in the player's own
  /// hand. It scrolls with the program because it is on the same sheet - the
  /// brief is not a bar pinned over the top of one.
  final LevelBrief brief;

  final ScrollController controller;
  final LiftState lift;
  final AutoScroller autoScroll;

  final VoidCallback onChanged;

  /// Deleting is shared with the note (drop a command on it to remove it), so
  /// it lives one level up and both routes call it.
  final ValueChanged<Node> onRemove;

  /// While running the program is read-only: no drops, no swipes, no argument
  /// taps. The gaps stay in the layout though - removing them reflowed the
  /// whole program at the exact moment you want to watch it.
  final bool running;

  /// The node the robot is on, while [running]. Marked in the margin rather
  /// than highlighted in place - see [CaretGutter].
  final String? executing;

  /// How much of the page's bottom edge the note covers.
  /// Room kept below the last row, so it can be scrolled clear of whatever
  /// the page cannot draw under - which is now only the system's gesture area.
  /// It used to be the height of the command tray, back when the tray was laid
  /// over the page.
  final double bottomInset;

  @override
  State<ProgramEditor> createState() => ProgramEditorState();
}

class ProgramEditorState extends State<ProgramEditor> {
  ProgramDocument get doc => widget.doc;

  /// The node currently in the air, dimmed in place rather than removed: the
  /// program does not close up behind a command being moved.
  String? _lifted;

  /// Attached to whichever row the caret is on, so the page can be scrolled to
  /// it without measuring anything. Only one row is ever marked, so one key is
  /// enough - it moves down the program as the run does.
  final _marked = GlobalKey();

  @override
  void didUpdateWidget(ProgramEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.executing != oldWidget.executing && widget.executing != null) {
      // After the frame: the key is attached to the row this build is about to
      // create, and asking where it is before that gets the previous one.
      WidgetsBinding.instance.addPostFrameCallback((_) => _follow());
    }
  }

  /// Keeps the running line on screen, and otherwise leaves the page alone.
  ///
  /// It used to centre the line on every instruction, which meant the page
  /// moved under the player on almost every step - including the many where
  /// the line was already sitting in plain view. A run should read like a
  /// debugger following code, not like a teleprompter holding one line against
  /// the middle.
  ///
  /// So the page moves only when it must, and then only as far as it must:
  /// down to the line if the line is above, up to it if below, plus
  /// [Paper.caretSlack]. Already visible is the case that does nothing at all,
  /// and it is the common one.
  void _follow() {
    final context = _marked.currentContext;
    if (!mounted || context == null) return;

    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null || !widget.controller.hasClients) return;
    final position = widget.controller.position;

    // The marked *line*, not the marked object. A container is marked as one
    // block - that is the editor's rule everywhere else, and the right one -
    // but a block can easily be taller than the page, and what has to be on
    // screen is the line the caret is against, which for a block is its
    // header. [Paper.headerTop] is where a header's caret sits; on a plain
    // command those few dp are slack and cost nothing.
    final line = Rect.fromLTWH(
      0,
      0,
      box.size.width,
      Paper.headerTop + Paper.rowHeight,
    );

    // The two offsets that would put the line flush against each edge of the
    // page. Between them the line is already showing, which is the case that
    // must not scroll. `atBottom` is the smaller of the two: showing something
    // at the foot of the page takes less scrolling than showing it at the head.
    final atTop = viewport.getOffsetToReveal(box, 0, rect: line).offset;
    final atBottom = viewport.getOffsetToReveal(box, 1, rect: line).offset;
    final here = position.pixels;

    final double target;
    if (atBottom > atTop) {
      // No offset shows the whole line: the page is shorter than one row, so
      // there is no "minimum" to find. Show its top and let the rest go.
      target = atTop;
    } else if (here > atTop) {
      target = atTop - Paper.caretSlack;
    } else if (here < atBottom) {
      target = atBottom + Paper.caretSlack;
    } else {
      return;
    }

    final to = target.clamp(position.minScrollExtent, position.maxScrollExtent);
    // `animateTo` asserts a non-zero duration, so reduced motion is a jump
    // rather than a zero-length animation.
    if (MediaQuery.disableAnimationsOf(context)) {
      position.jumpTo(to);
    } else {
      position.animateTo(
        to,
        duration: Paper.caretFollow,
        curve: Curves.easeOut,
      );
    }
  }

  void _mutate(void Function() change) {
    setState(change);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return NotebookPage(
      child: LayoutBuilder(
        builder: (context, constraints) => CustomScrollView(
          controller: widget.controller,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                // The column, and the only place its width is decided. It used
                // to be a left inset here and a right one applied per root
                // node, which meant a root *block* got none at all and ran to
                // the edge of the page - deliberate when a container was a
                // sheet of paper laid across it, and lopsided now. One padding
                // round everything cannot come apart that way, and the brief
                // is inside it for free.
                padding: const EdgeInsets.symmetric(horizontal: Paper.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Brief(brief: widget.brief),
                    _list(doc.root, null, 0),
                  ],
                ),
              ),
            ),
            // The root's last gap owns the rest of the page, so a drop past the
            // end of the program always lands. Half a pane at minimum, which is
            // what makes a short program scrollable at all.
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Paper.gutter),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight * Paper.tailSlack,
                  ),
                  child: PageTail(
                    key: const ValueKey('page-tail'),
                    slot: Slot(null, doc.root.length, 0),
                    accepts: (payload) => _accepts(payload, null),
                    onAccept: (payload) =>
                        _drop(payload, Slot(null, doc.root.length, 0)),
                    hint: doc.root.isEmpty
                        ? const Text(
                            'Drag a command up from below.',
                            style: Paper.hint,
                          )
                        : null,
                  ),
                ),
              ),
            ),
            // Scrollable room the height of whatever covers the bottom of the
            // page, so the last row can always be brought clear of it.
            if (widget.bottomInset > 0)
              SliverToBoxAdapter(child: SizedBox(height: widget.bottomInset)),
          ],
        ),
      ),
    );
  }

  /// One list of siblings: a gap, a node, a gap, a node... and a closing gap,
  /// except at the root where the closing gap is the whole rest of the page.
  Widget _list(List<Node> nodes, Node? parent, int depth) {
    final ghost = parent == null
        ? null
        : Paper.fillFor(parent.spec.colour, depth);

    Widget gap(int index) => Gap(
      slot: Slot(parent?.id, index, depth),
      ghost: ghost,
      accepts: (payload) => _accepts(payload, parent?.id),
      onAccept: (payload) => _drop(payload, Slot(parent?.id, index, depth)),
    );

    if (parent != null && nodes.isEmpty) {
      return EmptyBody(
        slot: Slot(parent.id, 0, depth),
        ghost: ghost!,
        accepts: (payload) => _accepts(payload, parent.id),
        onAccept: (payload) => _drop(payload, Slot(parent.id, 0, depth)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < nodes.length; i++) ...[
          gap(i),
          _node(nodes[i], depth),
        ],
        if (parent != null) gap(nodes.length),
      ],
    );
  }

  Widget _node(Node node, int depth) {
    final marked = widget.executing == node.id;

    // No inset of its own at either depth: at the root the column's padding
    // has already set the width, and inside a container it fills the body and
    // ends against the container's own right arm.
    final body = node.isBlock
        ? _block(node, depth, marked: marked)
        : CommandTab(
            node: node,
            dimmed: _lifted == node.id,
            interactive: !widget.running,
            outline: marked ? Paper.caret : null,
            onCycle: (slot) => _mutate(() => doc.cycleArg(node.id, slot)),
          );

    // Wrapped inside the gestures rather than around them: while running they
    // pass the row straight through, but a caret that swallowed them would be a
    // silent trap the day anything marks a line outside a run.
    final pointed = marked
        ? KeyedSubtree(
            key: _marked,
            child: CaretGutter(header: node.isBlock, depth: depth, child: body),
          )
        : body;

    return _swipeable(node, _liftable(node, pointed));
  }

  /// A container: a note of its own colour, wrapping its children on all four
  /// sides. The left arm carries the nesting; the right and bottom arms are
  /// what make it a note rather than a bracket.
  Widget _block(Node node, int depth, {bool marked = false}) {
    final fill = Paper.fillFor(node.spec.colour, depth);

    return Opacity(
      opacity: _lifted == node.id ? 0.35 : 1,
      child: Panel(
        fill: fill,
        // The whole block, not just its title: a container is one object
        // everywhere else in this editor - lifting carries its body, swiping
        // deletes it - and an outline round the header alone would be the only
        // place that says otherwise.
        outline: marked ? Paper.caret : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: Paper.headerTop),
              child: CommandTab(
                node: node,
                header: true,
                interactive: !widget.running,
                onCycle: (slot) => _mutate(() => doc.cycleArg(node.id, slot)),
              ),
            ),
            Padding(
              // The body's own trailing gap is the bottom arm, and it is
              // already the same thickness as the left one.
              padding: const EdgeInsets.only(
                left: Paper.gap,
                right: Paper.armEnd,
              ),
              child: _list(node.children!, node, depth + 1),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ gestures

  /// Long-press to lift. The page scrolls vertically and a row must not fight
  /// it, so holding is the cost of moving a placed command.
  Widget _liftable(Node node, Widget child) {
    if (widget.running) return child;

    return LongPressDraggable<DragPayload>(
      data: MoveNode(node.id),
      delay: Paper.liftDelay,
      onDragStarted: () {
        widget.lift.lift(MoveNode(node.id));
        setState(() => _lifted = node.id);
      },
      onDragUpdate: (d) => widget.autoScroll.update(d.globalPosition),
      onDragEnd: (_) => _released(),
      onDraggableCanceled: (_, _) => _released(),
      feedback: _Ghost(node: node),
      // What it left behind stays where it was, dimmed: the program does not
      // close up behind a command in the air.
      childWhenDragging: child,
      child: child,
    );
  }

  void _released() {
    widget.autoScroll.stop();
    widget.lift.drop();
    if (mounted) setState(() => _lifted = null);
  }

  /// Swipe either way to delete. It does not collide with the lift, because
  /// lifting requires a hold.
  Widget _swipeable(Node node, Widget child) {
    if (widget.running) return child;

    return Dismissible(
      key: ValueKey('dismiss-${node.id}'),
      // Handled here and never actually dismissed, so the tree stays the single
      // source of truth.
      confirmDismiss: (_) async {
        widget.onRemove(node);
        return false;
      },
      background: const _SwipeHint(end: false),
      secondaryBackground: const _SwipeHint(end: true),
      child: child,
    );
  }

  // ---------------------------------------------------------------- dropping

  /// A command from the note fits anywhere. A command already in the program
  /// may not be dropped inside its own body.
  bool _accepts(DragPayload payload, String? parentId) {
    if (widget.running) return false;
    return switch (payload) {
      NewCommand() => true,
      MoveNode(:final id) => parentId == null || !doc.contains(id, parentId),
    };
  }

  void _drop(DragPayload payload, Slot slot) => _mutate(() {
    switch (payload) {
      case NewCommand(:final commandId):
        doc.insertAt(commandId, slot);
      case MoveNode(:final id):
        doc.move(id, slot);
    }
  });
}

/// What follows the finger: the command itself, in the air.
///
/// A block brings its body along - it is one object, and seeing only its title
/// fly would say the opposite. The fold is off: paper in the air is not stuck
/// to anything.
class _Ghost extends StatelessWidget {
  const _Ghost({required this.node});

  final Node node;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: 0.92,
    child: Material(
      color: Colors.transparent,
      child: SizedBox(width: 280, child: _ghostFor(node, 0)),
    ),
  );

  Widget _ghostFor(Node node, int depth) {
    if (!node.isBlock) {
      return Panel(
        fill: node.spec.colour,
        child: CommandTab(node: node, interactive: false, onCycle: (_) {}),
      );
    }

    return Panel(
      fill: Paper.fillFor(node.spec.colour, depth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: Paper.headerTop),
            child: CommandTab(
              node: node,
              header: true,
              interactive: false,
              onCycle: (_) {},
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: Paper.gap,
              right: Paper.armEnd,
              bottom: Paper.gap,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final child in node.children!.take(3)) ...[
                  const SizedBox(height: Paper.gap),
                  _ghostFor(child, depth + 1),
                ],
                if (node.children!.length > 3)
                  const Padding(
                    padding: EdgeInsets.only(top: Paper.gap),
                    child: Text('...', style: Paper.hint),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Revealed behind a row being swiped away.
class _SwipeHint extends StatelessWidget {
  const _SwipeHint({required this.end});

  /// True for the hint a leftward swipe reveals, which sits on the right.
  final bool end;

  @override
  Widget build(BuildContext context) => Container(
    color: Paper.danger,
    alignment: end ? Alignment.centerRight : Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: Text(
      'DELETE',
      style: Paper.command.copyWith(fontSize: 17, color: Paper.onDanger),
    ),
  );
}
