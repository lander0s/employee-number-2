/// The shape every command and container is drawn as.
///
/// A flat filled block, and an outline when something is pointing at it. That
/// is all it is now.
///
/// It was a sheet of coloured paper stuck to the page, and the two shapes in the
/// program were told apart by which way the shadow fell - a container glued
/// along its top, a command glued along its left, the glued edge casting
/// nothing and the free corner turning up. It was a nice grammar and it is in
/// git; it is not here, because it was style, and the style is parked until the
/// game is worth dressing.
///
/// Nothing was lost in reading the program for it: the nesting is carried by
/// the container's own arms and by the indent, which are layout rather than
/// decoration, and both survive.
library;

import 'package:flutter/widgets.dart';

import 'tokens.dart';

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.fill,
    required this.child,
    this.outline,
  });

  final Color fill;

  /// Drawn round the block, over it, when something is pointing at it. Costs no
  /// layout: see [Paper.caretBorder].
  final Color? outline;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final block = ColoredBox(color: fill, child: child);
    if (outline == null) return block;

    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.all(color: outline!, width: Paper.caretBorder),
      ),
      child: block,
    );
  }
}
