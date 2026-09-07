/// The app's chrome: everything around the page.
///
/// It was grey - deliberately joyless, so that colour could not flatter a
/// layout that had not earned it. The layout has been judged now, and the greys
/// had become the one part of the screen still arguing with the rest: the page
/// is warm cream, the commands are saturated stickers, and the frame holding
/// them was a text editor from 2012.
///
/// So the frame is cardboard. It is the right material for a warehouse, it is
/// the only surface in the fiction the player never has to read *through*, and
/// it puts the paper on top of a box rather than in front of a window. Ink on
/// kraft, not near-white on charcoal - the palette flipped light, which is what
/// the bright commands and their dark ink always wanted.
///
/// Everything the notebook itself needs lives in [Paper] (notebook/tokens.dart),
/// not here. This file is only what the page is sitting on.
library;

import 'package:flutter/material.dart';

abstract final class W {
  // ------------------------------------------------------------------ kraft
  //
  // Darkest to lightest. Every one is the same brown at a different depth of
  // cut, which is what makes a stack of them read as one material rather than
  // as a set of panels that happen to be brownish.

  /// The deepest cut: seen only in the gaps between everything else.
  static const page = Color(0xFF5C4A35);

  /// The floor pane's surround.
  static const paneFloor = Color(0xFF8A6E4C);

  /// The well inside it, where the simulation will go. Recessed rather than
  /// raised: it is a hole cut in the box, not another sheet laid on it.
  static const paneWell = Color(0xFF9E815B);

  /// The working surface: anything the player reads text off.
  static const chrome = Color(0xFFC2A47A);

  /// A raised tab, and the same pressed in.
  static const button = Color(0xFFD9C09A);
  static const buttonPressed = Color(0xFFAE8F65);

  /// Corrugation, seen edge-on. The soft one is a fold rather than a cut.
  static const line = Color(0xFF6B5539);
  static const lineSoft = Color(0xFF8A7150);

  // -------------------------------------------------------------------- ink
  //
  // Dark on light now, in both places: the chrome reads the way the commands
  // already did. Contrast is measured against [chrome], the lightest surface
  // any of these sits on being [button], which only improves it.

  /// 7.16:1 on [chrome], clearing 7.3's floor with nothing to spare - which is
  /// the point of writing the number down. Darken the ink, not the board, if a
  /// surface below ever gets lighter.
  static const text = Color(0xFF241B12);

  /// 4.71:1. For text that is genuinely secondary - never for instructions.
  static const textDim = Color(0xFF4A3826);

  /// 2.98:1, and so decorative only: separators, watermarks, disabled labels.
  static const textFaint = Color(0xFF6A553C);

  // ------------------------------------------------------------- dimensions

  static const minTarget = 48.0;

  /// The visible rule is 2dp; this is what a thumb has to hit.
  static const dividerHitHeight = 34.0;

  /// Chrome text stops scaling here, while program rows keep scaling to 200%
  /// and beyond.
  ///
  /// 7.3 requires the *program* to stay readable at 200%, and on a 393-wide
  /// phone the buttons and labels scaled that far consume the entire screen and
  /// starve the two panes. Clamping the chrome is what keeps the pillar's
  /// promise where it matters: the instructions grow, the furniture does not.
  static const chromeMaxTextScale = 1.3;

  // -------------------------------------------------------------------- type
  //
  // 7.3: nothing functional under 17.

  static const TextStyle label = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: text,
  );

  static const TextStyle labelDim = TextStyle(fontSize: 17, color: textDim);

  /// The floor's readout, while the floor is a console.
  ///
  /// Monospaced, because it is columns of numbers and they have to line up
  /// down the screen, and below the 17pt floor 7.3 sets for game text - which
  /// is allowed precisely because this is not game text. It is the machine's
  /// state printed out while the animation that will show it does not exist
  /// yet, and it goes when that arrives.
  static const TextStyle console = TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: <String>['Consolas', 'Courier New'],
    fontSize: 15,
    height: 1.25,
    color: text,
  );

  /// A failed shift, and text on it. Shared with the page's own delete
  /// backdrop, which is the same idea: this went wrong.
  static const danger = Color(0xFF991B1B);
  static const onDanger = Color(0xFFF2F2F2);
}

/// Caps text scaling for furniture. See [W.chromeMaxTextScale].
class Chrome extends StatelessWidget {
  const Chrome({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: W.chromeMaxTextScale,
    child: child,
  );
}

/// A flat cardboard button. No elevation, no radius, no ink colour.
class WButton extends StatelessWidget {
  const WButton({
    super.key,
    required this.label,
    this.onTap,
    this.wide = false,
    this.emphasised = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onTap;
  final bool wide;
  final bool emphasised;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      enabled: enabled,
      label: label,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: W.minTarget),
          width: wide ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: emphasised ? W.buttonPressed : W.button,
            border: Border.all(color: enabled ? W.line : W.lineSoft),
          ),
          child: Text(
            label,
            style: W.label.copyWith(
              color: enabled ? W.text : W.textFaint,
              fontWeight: emphasised ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
