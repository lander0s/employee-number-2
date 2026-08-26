/// One instruction row.
///
/// The row itself answers one gesture: tap an argument to cycle it. Arguments
/// are edited in place - no modal ever opens for an argument. Deleting and
/// reordering are owned by the pane, because for a block those gestures act on
/// the whole container rather than on this one row, and insertion is not a row
/// gesture at all: it is a drop into a spacer.
///
/// A row reads as a sentence. The fixed command words are bare, bright and
/// semibold; every word you can change is a quiet button.
///
/// Each command carries a bright colour (see commands.dart), so rows are written
/// in dark ink rather than the near-white used elsewhere. A plain row paints its
/// own colour; a block header paints the fill of the container it belongs to, so
/// the two read as one shape at rest and the header still has a background of
/// its own to carry when it slides.
library;

import 'package:flutter/material.dart';

import '../model/program.dart';
import 'wireframe.dart';

class ProgramRow extends StatelessWidget {
  const ProgramRow({
    super.key,
    required this.row,
    required this.onCycleArg,
    this.dragging = false,
    this.interactive = true,
  });

  final DisplayRow row;
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
      decoration: switch (row.kind) {
        // A plain command is a card of its own.
        RowKind.command => BoxDecoration(
          color: tone,
          borderRadius: BorderRadius.circular(W.rowRadius),
        ),
        // A block header takes the container's fill and the container's rounding
        // at the top, so at rest the two are indistinguishable - one shape, not
        // a card inside a card.
        //
        // It has to paint that itself rather than let the container show
        // through: a swipe or a drag moves the header alone, and a title sliding
        // out from under its own background looked like the letters had come
        // loose from the block.
        RowKind.blockHeader => BoxDecoration(
          color: W.blockFill(tone, row.depth),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(W.blockRadius),
          ),
        ),
        RowKind.blockCloser => null,
      },
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

    return content;
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
