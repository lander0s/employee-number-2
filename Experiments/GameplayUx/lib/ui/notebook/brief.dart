/// The level brief, written at the top of the page in the player's own hand.
///
/// It replaces the task card that used to be pinned above the floor. That card
/// was chrome: a strip of app furniture, a label, and a button to re-open a
/// sheet nobody opened twice. This is the same information as a note somebody
/// wrote down before starting work - which is what the rest of this pane has
/// been pretending to be since it became paper.
///
/// Two consequences fall out of it and both are the point. The brief costs no
/// screen height of its own, because it scrolls away with the program once you
/// are past reading it. And there is nothing to tap to get it back: it is still
/// up there, where you wrote it.
library;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// What the player was asked for. Actionable only - the story lives in the
/// call, and a note written to yourself does not repeat the boss's small talk.
class LevelBrief {
  const LevelBrief({required this.task, this.detail});

  /// One line, the thing to do.
  final String task;

  /// The rest of it, for levels whose rule does not fit in one line. Still no
  /// fiction: the conditions, the edge case, what counts as done.
  final String? detail;
}

class Brief extends StatelessWidget {
  const Brief({super.key, required this.brief});

  final LevelBrief brief;

  @override
  Widget build(BuildContext context) {
    final detail = brief.detail;

    return Semantics(
      container: true,
      label: 'Task. ${brief.task}${detail == null ? '' : '. $detail'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(top: Paper.handDrop),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  // Written first and underlined by the stroke below, the way a
                  // person labels a note to themselves.
                  TextSpan(
                    text: 'Task: ',
                    style: Paper.handAt(Paper.handInkFaint),
                  ),
                  TextSpan(text: brief.task),
                ],
              ),
              style: Paper.handAt(Paper.handInk),
            ),
            if (detail != null)
              Text(detail, style: Paper.handAt(Paper.handInk)),
            // A blank line between the note and the work. One ruled row, so the
            // program below still starts on a line - and left empty rather than
            // ruled off, because a person separates the two by skipping a line,
            // not by drawing across the page.
            const SizedBox(height: Paper.rowHeight),
          ],
        ),
      ),
    );
  }
}
