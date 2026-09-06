/// The gaps between instructions, which are also the only places a command can
/// land.
///
/// Three named things rather than one widget with four flags:
///
/// - [Gap] - between two siblings. 12dp closed; a reserved row when something
///   is held over it.
/// - [EmptyBody] - the single gap inside a container with nothing in it. Always
///   in the reserved shape, so the container reads as missing its first
///   instruction rather than as squashed.
/// - [PageTail] - the last gap at the root. Owns all the page below the
///   program, which is what makes dropping past the end always work.
///
/// **The invariant they exist for:** an open gap is the size of the row that
/// will land in it *plus the gaps that row will have above and below it*. So
/// when the drop lands, nothing moves - the row replaces the preview in space
/// already reserved for it.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../model/program.dart';
import 'tokens.dart';

/// A gap between two siblings.
class Gap extends StatelessWidget {
  const Gap({
    super.key,
    required this.slot,
    required this.accepts,
    required this.onAccept,
    this.ghost,
  });

  final Slot slot;
  final bool Function(DragPayload) accepts;
  final ValueChanged<DragPayload> onAccept;

  /// The fill a child of this container would wear. Only the reserved states
  /// paint it; a gap at the root has no container above it and so has none.
  final Color? ghost;

  @override
  Widget build(BuildContext context) => DropArea(
    accepts: accepts,
    onAccept: onAccept,
    builder: (open, dropped) => _Reserve(
      reserved: open,
      instant: dropped,
      ghost: ghost,
      child: open ? const OpenGap() : null,
    ),
  );
}

/// The one gap inside an empty container: permanently row-shaped.
class EmptyBody extends StatelessWidget {
  const EmptyBody({
    super.key,
    required this.slot,
    required this.accepts,
    required this.onAccept,
    required this.ghost,
  });

  final Slot slot;
  final bool Function(DragPayload) accepts;
  final ValueChanged<DragPayload> onAccept;

  /// Painted, not implied: the reserved row wears the shade a real child would,
  /// so an empty body reads as one invisible instruction.
  final Color ghost;

  @override
  Widget build(BuildContext context) => DropArea(
    accepts: accepts,
    onAccept: onAccept,
    builder: (open, _) => _Reserve(
      reserved: true,
      instant: true,
      ghost: ghost,
      child: open ? const OpenGap() : null,
    ),
  );
}

/// The rest of the page, below the program.
class PageTail extends StatelessWidget {
  const PageTail({
    super.key,
    required this.slot,
    required this.accepts,
    required this.onAccept,
    this.hint,
  });

  final Slot slot;
  final bool Function(DragPayload) accepts;
  final ValueChanged<DragPayload> onAccept;

  /// Shown when the program is empty and the page is otherwise blank.
  final Widget? hint;

  @override
  Widget build(BuildContext context) => DropArea(
    accepts: accepts,
    onAccept: onAccept,
    builder: (open, _) => Container(
      constraints: const BoxConstraints(minHeight: Paper.gap),
      alignment: Alignment.topLeft,
      child: open
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: Paper.gap),
              child: SizedBox(height: Paper.rowHeight, child: OpenGap()),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(0, 20, 8, 0),
              child: hint,
            ),
    ),
  );
}

/// A row's worth of space, with the gaps a row would have above and below it.
class _Reserve extends StatelessWidget {
  const _Reserve({
    required this.reserved,
    required this.instant,
    this.ghost,
    this.child,
  });

  final bool reserved;
  final bool instant;
  final Color? ghost;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final box = reserved
        ? Container(
            constraints: const BoxConstraints(minHeight: Paper.openGap),
            padding: const EdgeInsets.symmetric(vertical: Paper.gap),
            child: DecoratedBox(
              decoration: BoxDecoration(color: ghost),
              child: child ?? const SizedBox.shrink(),
            ),
          )
        : const SizedBox(height: Paper.gap);

    // Instant means *no* AnimatedSize rather than a zero duration: given one,
    // AnimatedSize finishes inside its own layout pass and asserts.
    if (instant || MediaQuery.disableAnimationsOf(context)) return box;

    return AnimatedSize(
      duration: Paper.gapGrow,
      curve: Curves.linear,
      // Top-anchored: the gap opens downwards, so the row above holds still.
      alignment: Alignment.topCenter,
      child: box,
    );
  }
}

/// What a gap looks like with something held over it.
class OpenGap extends StatelessWidget {
  const OpenGap({super.key});

  @override
  Widget build(BuildContext context) => DashedOutline(
    child: Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        // The same inset a command's first word has, measured from the same
        // edge: this box is the row that is about to be here.
        padding: const EdgeInsets.only(left: Paper.rowInsetLeft, right: 10),
        child: Text(
          'DROP HERE',
          style: Paper.command.copyWith(fontWeight: FontWeight.w400),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
      ),
    ),
  );
}

/// A dashed border, so an open gap reads as a space waiting to be filled rather
/// than as another card.
class DashedOutline extends StatelessWidget {
  const DashedOutline({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _Dashes(), child: child);
}

class _Dashes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Paper.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const dash = 7.0;
    const skip = 5.0;

    void run(Offset from, Offset to) {
      final total = (to - from).distance;
      final step = (to - from) / total;
      var at = 0.0;
      while (at < total) {
        final end = math.min(at + dash, total);
        canvas.drawLine(from + step * at, from + step * end, paint);
        at = end + skip;
      }
    }

    final r = Offset.zero & size;
    run(r.topLeft, r.topRight);
    run(r.bottomLeft, r.bottomRight);
    run(r.topLeft, r.bottomLeft);
    run(r.topRight, r.bottomRight);
  }

  @override
  bool shouldRepaint(_Dashes old) => false;
}

/// The drop-target plumbing every gap shares.
///
/// Hands its builder two things: whether something acceptable is over it, and
/// whether a drop *just* landed here - because closing after a drop has to be
/// instant. The row that lands takes exactly the space the open gap was
/// holding, so animating it shut would shove the page down and pull it back.
class DropArea extends StatefulWidget {
  const DropArea({
    super.key,
    required this.accepts,
    required this.onAccept,
    required this.builder,
  });

  final bool Function(DragPayload) accepts;
  final ValueChanged<DragPayload> onAccept;
  final Widget Function(bool open, bool justDropped) builder;

  @override
  State<DropArea> createState() => _DropAreaState();
}

class _DropAreaState extends State<DropArea> {
  bool _over = false;
  bool _dropped = false;

  @override
  Widget build(BuildContext context) {
    return DragTarget<DragPayload>(
      onWillAcceptWithDetails: (details) {
        final ok = widget.accepts(details.data);
        if (ok) setState(() => _over = true);
        return ok;
      },
      onLeave: (_) => setState(() => _over = false),
      onAcceptWithDetails: (details) {
        _dropped = true;
        setState(() => _over = false);
        widget.onAccept(details.data);
      },
      builder: (context, candidate, rejected) {
        final open = _over || candidate.isNotEmpty;
        if (_dropped) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _dropped = false);
        }
        return widget.builder(open, _dropped);
      },
    );
  }
}
