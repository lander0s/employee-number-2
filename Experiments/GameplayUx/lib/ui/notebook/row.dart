/// One instruction: a tab of coloured paper, glued along its left edge.
///
/// Presentational. It answers exactly one gesture of its own - a tap on a
/// cyclable word - because everything else that can happen to a command
/// (lifting it, deleting it) happens to the whole node and belongs to the page.
library;

import 'package:flutter/material.dart';

import '../../model/program.dart';
import 'fold.dart';
import 'tokens.dart';

class CommandTab extends StatelessWidget {
  const CommandTab({
    super.key,
    required this.node,
    required this.onCycle,
    this.header = false,
    this.dimmed = false,
    this.interactive = true,
    this.shadows = true,
  });

  final Node node;
  final ValueChanged<ArgSlot> onCycle;

  /// True when this is the title of a container rather than a command of its
  /// own. A header paints nothing: the note behind it is already its colour,
  /// and the note is what casts the shadow. Two shadows 36dp apart would read
  /// as two objects rather than as one note with a title.
  final bool header;

  /// The row is currently in the air; this is what it left behind.
  final bool dimmed;

  /// False while the program runs, and for the drag ghost: renders identically,
  /// answers nothing.
  final bool interactive;

  final bool shadows;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.only(
        left: Paper.rowInsetLeft,
        right: Paper.rowInsetRight,
      ),
      child: Align(
        alignment: header ? Alignment.topLeft : Alignment.centerLeft,
        // Wrap, so a long condition runs onto a second line rather than
        // overflowing. Rows are height-flexible, so growing is free.
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 5,
          runSpacing: 3,
          children: [
            Text(node.spec.label, style: Paper.command),
            for (final chip in node.chips)
              _Cyclable(
                text: chip.text,
                tone: node.spec.colour,
                onTap: interactive ? () => onCycle(chip.slot) : null,
              ),
          ],
        ),
      ),
    );

    final box = Opacity(
      opacity: dimmed ? 0.35 : 1,
      child: ConstrainedBox(
        // A minimum, never a fixed height: 7.3 requires this to survive 200%
        // text scaling without clipping, so content decides the final height.
        constraints: const BoxConstraints(minHeight: Paper.rowHeight),
        child: content,
      ),
    );

    if (header) return box;

    return StuckPaper(
      fill: node.spec.colour,
      shadow: shadows ? Paper.tabShadow : const [],
      child: box,
    );
  }
}

/// A word you can change: the row's colour taken up a shade, with an edge taken
/// down, so it reads as a thing you touch rather than as text in another grey.
class _Cyclable extends StatelessWidget {
  const _Cyclable({required this.text, required this.tone, this.onTap});

  final String text;
  final Color tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: '$text, tap to change',
      child: GestureDetector(
        onTap: onTap,
        // Opaque, so the whole target answers - not only where the glyphs are.
        behavior: HitTestBehavior.opaque,
        // The painted chip and the target are two different boxes. Padding the
        // chip itself out to a fingertip made a condition look like a row of
        // form fields, so the target is transparent space around a chip that is
        // padded to its word and no further.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Paper.chipTarget),
          child: Center(
            widthFactor: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Paper.chipPadH,
                vertical: Paper.chipPadV,
              ),
              decoration: BoxDecoration(
                color: Paper.chipFill(tone),
                border: Border.all(color: Paper.chipEdge(tone)),
              ),
              child: Text(
                text,
                style: Paper.command.copyWith(fontWeight: FontWeight.w400),
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
