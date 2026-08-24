/// One instruction row.
///
/// Carries the gestures from 7.2: tap to move the caret, swipe left to delete,
/// swipe right to duplicate, long-press to drag. Arguments are edited in place -
/// no modal ever opens for an argument.
///
/// A row reads as a sentence. The fixed command words are the brightest thing on
/// it; every word you can change is a distinctly dimmer grey. That tone *is* the
/// affordance - one visual rule for the whole language, no boxes, no chrome, no
/// stepper buttons.
library;

import 'package:flutter/material.dart';

import '../model/program.dart';
import 'wireframe.dart';

class ProgramRow extends StatelessWidget {
  const ProgramRow({
    super.key,
    required this.row,
    required this.onTap,
    required this.onDelete,
    required this.onDuplicate,
    required this.onCycleArg,
    this.dragging = false,
    this.ghost = false,
  });

  final DisplayRow row;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final ValueChanged<ArgSlot> onCycleArg;

  /// True while this row is the source of an active drag.
  final bool dragging;

  /// True when rendered inside a drag feedback stack (no gestures, no gutter).
  final bool ghost;

  @override
  Widget build(BuildContext context) {
    final node = row.node;
    final height = row.isCloser ? W.closerRowHeight : W.rowHeight;

    final content = Container(
      // A minimum, never a fixed height: 7.3 requires rows to survive OS text
      // scaling to 200% without clipping, so content decides the final height.
      constraints: BoxConstraints(minHeight: height),
      decoration: BoxDecoration(
        color: switch (row.kind) {
          RowKind.blockCloser => W.rowFillCloser,
          RowKind.blockHeader => W.rowFillAlt,
          RowKind.command => W.rowFill,
        },
        border: const Border(
          bottom: BorderSide(color: W.paneProgram, width: 1),
        ),
      ),
      child: Opacity(
        opacity: dragging ? 0.35 : 1,
        child: IntrinsicHeight(
          child: Row(
            // Stretch so the spines span the row whatever height it settles at.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(width: W.rowInset),
              Spines(depth: row.depth),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  // No vertical padding here: the row's 60dp minimum already
                  // provides the breathing room, and adding padding on top of a
                  // cyclable word's own 48dp tap padding made a condition row a
                  // pixel taller than a plain one.
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _Keyword(
                        text: row.isCloser ? 'END' : node.spec.label,
                        dim: row.isCloser,
                      ),
                      if (!row.isCloser)
                        for (final chip in node.chips)
                          _ArgWord(
                            text: chip.text,
                            onTap: ghost ? () {} : () => onCycleArg(chip.slot),
                          ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (ghost) return content;

    // A closer is not independently addressable: it belongs to its header.
    // Tapping one only parks the caret after the block.
    if (row.isCloser) {
      return GestureDetector(onTap: onTap, child: content);
    }

    return GestureDetector(
      onTap: onTap,
      child: Dismissible(
        key: ValueKey('dismiss-${node.id}-${row.kind}'),
        // Both actions are handled here and the row is never actually
        // dismissed, so the list stays the single source of truth.
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.endToStart) {
            onDelete();
          } else {
            onDuplicate();
          }
          return false;
        },
        background: const _SwipeHint(label: 'DUPLICATE', end: false),
        secondaryBackground: const _SwipeHint(label: 'DELETE', end: true),
        child: content,
      ),
    );
  }
}

/// A fixed word: the brightest tone on the row, and not tappable.
class _Keyword extends StatelessWidget {
  const _Keyword({required this.text, this.dim = false});

  final String text;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Text(
        text,
        style: dim ? W.row.copyWith(color: W.textDim, fontSize: 18) : W.row,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
      ),
    );
  }
}

/// A cyclable word: tap to advance to the next value.
///
/// Rendered as a quiet button - soft fill, faint edge, 2px corners. Flat text in
/// a different grey was cleaner but nobody could tell it was tappable, and a row
/// carries up to three of these, so the fill is deliberately much softer than a
/// real button's.
class _ArgWord extends StatelessWidget {
  const _ArgWord({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: '$text, tap to change',
      child: GestureDetector(
        onTap: onTap,
        // Opaque so the whole padded area is tappable, not just the glyphs.
        behavior: HitTestBehavior.opaque,
        // No `alignment` and no `constraints` on this Container. With either
        // set it expands to its incoming width constraint, and inside a Wrap
        // that constraint is the full row - which put every word on its own line
        // and made the IF row four lines tall. Padding alone gets the 48dp
        // target and lets the Container size to its text.
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: W.cyclableFill,
            border: Border.all(color: W.cyclableEdge),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(
            text,
            style: W.row.copyWith(fontWeight: FontWeight.w400),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
      ),
    );
  }
}

/// The vertical guides of the enclosing blocks. One per level of nesting, so a
/// block's header and its closer are visually connected by the guide running
/// down its body.
///
/// Slot rows render this too - otherwise the guide breaks wherever the caret or
/// a drop target sits, and the block looks torn in half.
class Spines extends StatelessWidget {
  const Spines({super.key, required this.depth});
  final int depth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 10 + W.indentPerDepth * depth,
      child: Row(
        // Height comes from the enclosing IntrinsicHeight, so the spines stretch
        // rather than needing an explicit (and clippable) height.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(width: 6),
          for (var d = 0; d < depth; d++) ...[
            Container(width: 2, color: W.spineFor(d)),
            SizedBox(width: W.indentPerDepth - 2),
          ],
        ],
      ),
    );
  }
}

class _SwipeHint extends StatelessWidget {
  const _SwipeHint({required this.label, required this.end});
  final String label;
  final bool end;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: W.chrome,
      alignment: end ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Text(label, style: W.meta.copyWith(color: W.textDim)),
    );
  }
}
