/// One instruction row.
///
/// Carries the gestures from 7.2: tap to move the caret, swipe left to delete,
/// swipe right to duplicate, long-press to drag. Arguments are edited in place -
/// no modal ever opens for an argument.
///
/// A row reads as a sentence. The fixed command words are bare, bright and
/// semibold; every word you can change is a quiet button.
///
/// Each command carries a bright colour (see commands.dart), so rows are written
/// in dark ink rather than the near-white used elsewhere. A plain row paints its
/// colour; a block header and its `END` do not, because the block container
/// behind them already has it - painting twice would double the tone.
library;

import 'package:flutter/material.dart';

import '../model/program.dart';
import 'wireframe.dart';

class ProgramRow extends StatelessWidget {
  const ProgramRow({
    super.key,
    required this.row,
    required this.onDelete,
    required this.onCycleArg,
    this.dragging = false,
    this.interactive = true,
  });

  final DisplayRow row;
  final VoidCallback onDelete;
  final ValueChanged<ArgSlot> onCycleArg;

  /// True while this row is the source of an active drag.
  final bool dragging;

  /// False for the drag ghost and for every row while a program is running: the
  /// row renders identically but answers no gestures.
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final node = row.node;
    final tone = node.spec.colour;

    // A block header is a title on the container, not a card. It hugs its own
    // content and sits at the top of the block, so the only space between the
    // title and the first child is the spacer - which is the thing that reacts
    // to a tap. A centred 60dp header put ~19dp of dead height under the title
    // before the spacer even started.
    final isHeader = row.kind == RowKind.blockHeader;

    final content = Container(
      // A minimum, never a fixed height: 7.3 requires rows to survive OS text
      // scaling to 200% without clipping, so content decides the final height.
      constraints: isHeader
          ? null
          : const BoxConstraints(minHeight: W.rowHeight),
      // No margin: the gap between two siblings is a spacer, and a spacer is the
      // only spacing mechanism in the program. A card margin on top of it would
      // be a second one that means nothing.
      //
      // Only a plain command is a card of its own. A block header is part of the
      // container behind it, so it takes neither the fill nor the rounding - a
      // rounded header inside a rounded block would read as two shapes where
      // there is one.
      decoration: row.kind == RowKind.command
          ? BoxDecoration(
              color: tone,
              borderRadius: BorderRadius.circular(W.rowRadius),
            )
          : null,
      padding: EdgeInsets.only(
        left: W.rowInset,
        right: 8,
        top: isHeader ? W.headerTopPad : 0,
      ),
      child: Opacity(
        opacity: dragging ? 0.35 : 1,
        child: Align(
          alignment: isHeader ? Alignment.topLeft : Alignment.centerLeft,
          // Wrap, so a long condition runs onto a second line instead of
          // overflowing a narrow screen. Rows are height-flexible, so growing
          // is free.
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
                    tone: tone,
                    onTap: interactive ? () => onCycleArg(chip.slot) : () {},
                  ),
            ],
          ),
        ),
      ),
    );

    if (!interactive) return content;

    // Nothing to tap on a row any more: insertion is a drop into a spacer, so a
    // row's only gestures are the ones that act on the row itself.
    return Dismissible(
      key: ValueKey('dismiss-${node.id}-${row.kind}'),
      // One gesture, either direction. There used to be a second one - swipe
      // the other way to duplicate - which meant committing to a direction
      // before knowing which was which. Deleting is the one thing a row needs to
      // be able to do to itself, so both ways do it and there is nothing to aim
      // at: whichever way the thumb happens to fall is right.
      // Handled here and the row is never actually dismissed, so the tree stays
      // the single source of truth.
      confirmDismiss: (direction) async {
        onDelete();
        return false;
      },
      background: const _SwipeHint(label: 'DELETE', end: false),
      secondaryBackground: const _SwipeHint(label: 'DELETE', end: true),
      child: content,
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
        style: dim
            ? W.row.copyWith(color: W.inkDim, fontSize: 18)
            : W.row.copyWith(color: W.ink),
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
  const _ArgWord({required this.text, required this.tone, required this.onTap});

  final String text;

  /// The row's colour: the chip is cut out of it rather than sitting on top in
  /// a neutral grey, which would fight every hue it landed on.
  final Color tone;

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
            color: W.chipFill(tone),
            border: Border.all(color: W.chipEdge(tone)),
            borderRadius: BorderRadius.circular(W.chipRadius),
          ),
          child: Text(
            text,
            style: W.row.copyWith(color: W.ink, fontWeight: FontWeight.w400),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
      ),
    );
  }
}

class _SwipeHint extends StatelessWidget {
  const _SwipeHint({required this.label, required this.end});
  final String label;

  /// True for the hint revealed by a leftward swipe, which sits on the right.
  final bool end;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: W.chrome,
      alignment: end ? Alignment.centerRight : Alignment.centerLeft,
      // The row runs past the right edge of the screen, so the right-hand hint
      // has to be pulled back by the overhang or it lands where nobody can see
      // it.
      padding: EdgeInsets.only(
        left: 18,
        right: end ? 18 + W.programOverhang : 18,
      ),
      child: Text(label, style: W.meta.copyWith(color: W.textDim)),
    );
  }
}
