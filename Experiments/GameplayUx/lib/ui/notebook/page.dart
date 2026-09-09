/// The panel the program is written on.
///
/// Nothing but surface. What is written on it is somebody else's problem and
/// arrives as [child].
///
/// It used to be a sheet of ruled paper, and the ruling was scroll-linked so
/// the lines moved with the text written on them - a fixed backdrop slides
/// against the instructions the moment the page moves, which is the one thing
/// paper never does. That is gone with the rest of the style, and with it the
/// need for this to know anything about the scroll position at all.
library;

import 'package:flutter/material.dart';

import 'tokens.dart';

class NotebookPage extends StatelessWidget {
  const NotebookPage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Container(color: Paper.sheet, child: child);
}
