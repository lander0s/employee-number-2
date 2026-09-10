/// The level brief, at the top of the page.
///
/// It replaces the task card that used to be pinned above the floor. That card
/// was chrome: a strip of app furniture, a label, and a button to re-open a
/// sheet nobody opened twice. This is the same information written where the
/// work is.
///
/// Two consequences fall out of it and both are the point. The brief costs no
/// screen height of its own, because it scrolls away with the program once you
/// are past reading it. And there is nothing to tap to get it back: it is still
/// up there, where you wrote it.
library;

import 'package:flutter/material.dart';

import '../../model/level.dart';
import 'tokens.dart';

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Above the writing, matching the air under it: the brief is a note
          // with room round it, not a caption stuck to the top of the pane.
          const SizedBox(height: Paper.briefTop),
          // No label in front of it. The brief is the only prose on the page
          // and it sits at the top of it, so a word announcing that this is
          // the task was saying what its position already said.
          //
          // The screen reader still hears it: [Semantics] above names this
          // block, because a listener has no position to read it from.
          Text(brief.task, style: Paper.brief),
          if (detail != null) Text(detail, style: Paper.brief),
          // Air between the brief and the work rather than a line drawn across.
          const SizedBox(height: Paper.briefGap),
        ],
      ),
    );
  }
}
