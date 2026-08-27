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
          boxShadow: W.plastic(tone),
        ),
        // A block header takes the container's fill and the container's rounding
        // at the top, so at rest the two are indistinguishable - one shape, not
        // a card inside a card.
        //
        // It has to paint that itself rather than let the container show
        // through: a swipe or a drag moves the header alone, and a title sliding
        // out from under its own background looked like the letters had come
        // loose from the block.
        // No lip on a header: the block it belongs to casts that, and two
        // moulded edges 44dp apart read as two objects.
        RowKind.blockHeader => BoxDecoration(
          color: W.blockFill(tone, row.depth),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(W.blockRadius),
          ),
        ),
        RowKind.blockCloser => null,
      },
      child: _Glossed(
        radius: isHeader
            ? const BorderRadius.vertical(top: Radius.circular(W.blockRadius))
            : BorderRadius.circular(W.rowRadius),
        child: Padding(
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
                  if (!row.isCloser) ...[
                    for (final chip in node.chips)
                      _ArgWord(
                        text: chip.text,
                        tone: tone,
                        onTap: interactive
                            ? () => onCycleArg(chip.slot)
                            : () {},
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return content;
  }
}

/// Puts a short band of light across the top of whatever it wraps.
///
/// Behind the content, never over it: a gloss painted on top would wash out the
/// words and the argument chips along with the fill.
class _Glossed extends StatelessWidget {
  const _Glossed({required this.radius, required this.child});

  final BorderRadius radius;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    // Passthrough, or the stack shrink-wraps the label and the row loses the
    // minimum height that centres it.
    fit: StackFit.passthrough,
    children: [
      // Fixed height rather than a fraction: the highlight is where the light
      // hits the moulded edge, so it is the same on a one-line row and on a
      // block header, not proportional to how tall the thing happens to be.
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: W.glossHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: W.gloss, borderRadius: radius),
        ),
      ),
      child,
    ],
  );
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
        // The touch target and the painted chip are two different boxes. 7.3
        // wants 48dp under a thumb, and padding the chip itself to that height
        // made a three-word condition look like a row of form fields. So the
        // 48dp lives in transparent space around the chip, which is padded to
        // its word and no further.
        //
        // The minimum goes on the outer box only. Given `alignment` or
        // `constraints`, the *inner* Container would expand to its incoming
        // width - and inside a Wrap that is the whole row, which once put every
        // word on its own line and made the IF row four lines tall.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: W.minTarget),
          child: Center(
            widthFactor: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: W.chipPadH,
                vertical: W.chipPadV,
              ),
              decoration: BoxDecoration(
                color: W.chipFill(tone),
                border: Border.all(color: W.chipEdge(tone)),
                borderRadius: BorderRadius.circular(W.chipRadius),
              ),
              child: Text(
                text,
                style: W.row.copyWith(
                  color: W.ink,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
