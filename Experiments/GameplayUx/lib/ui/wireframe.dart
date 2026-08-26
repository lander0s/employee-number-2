/// Deliberately joyless. Greys only, plain text, no rounded delight.
///
/// The point of the experiment is to judge layout, legibility and interaction.
/// Colour and character would flatter the design and hide problems, so the only
/// values here are greys, and every dimension traces to a spec in
/// GameDesign/game-design-document.md 7.3.
library;

import 'package:flutter/material.dart';

abstract final class W {
  // Greys, light to dark.
  static const page = Color(0xFF2B2B2B);
  static const paneFloor = Color(0xFF3A3A3A);
  static const paneProgram = Color(0xFF232323);
  static const chrome = Color(0xFF1C1C1C);
  static const line = Color(0xFF505050);
  static const lineSoft = Color(0xFF3F3F3F);
  static const button = Color(0xFF454545);
  static const buttonPressed = Color(0xFF5A5A5A);
  static const text = Color(0xFFF2F2F2);
  static const textDim = Color(0xFF9A9A9A);
  static const textFaint = Color(0xFF6E6E6E);
  static const caret = Color(0xFFBFBFBF);

  /// Cyclable words sit on a soft fill with a faint edge, so they read as things
  /// you touch rather than as text that happens to be a different grey.
  ///
  /// Tone alone was tried and rejected: dimming the word was legible in the code
  /// and invisible on a real screen. A fill is the affordance; the word itself
  /// stays at full brightness, because dim text on a lighter fill drops to about
  /// 5:1 and 7.3 puts a 7:1 floor on all instruction text. Regular weight against
  /// the keyword's semibold carries the rest of the distinction.
  static const cyclableFill = Color(0xFF4A4A4A);
  static const cyclableEdge = Color(0xFF606060);
  static const dropTarget = Color(0xFF6E6E6E);

  /// Revealed behind a row being swiped away. It was the same grey as the rest
  /// of the chrome, which said "something is behind this row" and nothing about
  /// what. Deep rather than bright: this one is read in near-white like the
  /// app's own furniture, not in the dark ink the coloured rows use, and it has
  /// to stay clear of SHIP's salmon so a delete never reads as a command.
  static const danger = Color(0xFF991B1B);

  /// A block is a literal container with its body inset, so it reads as a "C"
  /// wrapped around the instructions it owns. Its colour is the command's own,
  /// stepped very slightly by depth so that a block nested inside another of the
  /// *same* command still shows its inset arm.
  /// The dark ink every coloured row is written in.
  ///
  /// Command colours are bright, so the text on them is dark rather than the
  /// near-white used on the app's own chrome. That flip also inverts every
  /// derived tone below: on a dark fill, darkening improves contrast; on a
  /// bright one, lightening does.
  static const ink = Color(0xFF1B1B1B);
  static const inkDim = Color(0x991B1B1B);

  /// The step *lightens*, because the ink is dark. (It darkened when the
  /// palette was dark and the ink near-white - the same reasoning, inverted.)
  static Color blockFill(Color base, int depth) =>
      depth.isEven ? base : Color.lerp(base, Colors.white, 0.14)!;

  /// A cyclable word sits in a well cut into its own row: the row's colour taken
  /// up, with an edge taken down. Deriving both from the row keeps the chip
  /// legible on every hue, and lighter-than-the-row can only improve the ink
  /// contrast the row already passes.
  static Color chipFill(Color base) => Color.lerp(base, Colors.white, 0.24)!;
  static Color chipEdge(Color base) => Color.lerp(base, Colors.black, 0.30)!;

  /// Hairline between two adjacent rows. Invisible where colours differ, and
  /// just enough where two of the same command sit together.
  static Color rowEdge(Color base) => Color.lerp(base, Colors.black, 0.18)!;

  // Dimensions. 7.3: rows 56-64, targets >= 48, indent must be legible.
  static const rowHeight = 60.0;
  static const closerRowHeight = 44.0;
  static const indentPerDepth = 18.0;

  /// A spacer standing in for a row: a command's worth of space with the gap a
  /// real row has above and below it.
  ///
  /// Two places need it. A spacer with something held over it, because that
  /// state is a preview of where the row will land - margins included, so
  /// nothing shifts when it does. And the lone spacer in an empty block, which
  /// reads as one invisible instruction rather than as spacing between siblings
  /// that are not there.
  static const openSlotHeight = rowHeight + indentPerDepth * 2;
  static const minTarget = 48.0;

  /// Left inset for every row and slot, replacing the old line-number gutter.
  static const rowInset = 12.0;

  /// A block header's only vertical padding, above the title. There is none
  /// below it: the spacer between the title and the first child does that job,
  /// and unlike padding it answers a tap.
  static const headerTopPad = 12.0;

  /// Corner radii. Rows and tray buttons share one so a command looks the same
  /// wherever it is; a block is a touch rounder because it is the bigger shape.
  static const rowRadius = 8.0;
  static const blockRadius = 12.0;
  static const chipRadius = 5.0;

  /// How far the program is laid out past the right edge of its pane.
  ///
  /// A block is meant to read as a "C" wrapped around its body. Seeing its right
  /// edge closes the shape into a rectangle and the bracket reading disappears,
  /// so the whole program runs off the screen and is clipped.
  static const programOverhang = 56.0;
  static const dividerHitHeight = 34.0;

  /// Chrome text stops scaling here, while program rows keep scaling to 200%
  /// and beyond.
  ///
  /// 7.3 requires the *program* to stay readable at 200%, and on a 393-wide
  /// phone the task card, tray and buttons scaled that far consume the entire
  /// screen and starve the two panes. Clamping the chrome is what keeps the
  /// pillar's promise where it matters: the instructions grow, the furniture
  /// does not.
  static const chromeMaxTextScale = 1.3;

  // Type. 7.3: instruction rows 20 semibold, nothing functional under 17.
  static const rowFamily = 'Consolas';
  static const rowFallback = <String>['Courier New', 'monospace'];

  /// Command words are extra bold. They are the fixed part of every sentence,
  /// and the weight is half of what separates them from the cyclable values,
  /// which stay at regular.
  static const TextStyle row = TextStyle(
    fontFamily: rowFamily,
    fontFamilyFallback: rowFallback,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: text,
    height: 1.1,
  );

  static const TextStyle rowArg = TextStyle(
    fontFamily: rowFamily,
    fontFamilyFallback: rowFallback,
    fontSize: 20,
    fontWeight: FontWeight.w400,
    color: textDim,
    height: 1.1,
  );

  static const TextStyle label = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: text,
  );

  static const TextStyle labelDim = TextStyle(fontSize: 17, color: textDim);

  /// Below the 17pt functional floor on purpose: this is scaffolding for the
  /// experiment (readouts, hints to the person testing), not game UI.
  static const TextStyle meta = TextStyle(
    fontSize: 13,
    color: textFaint,
    letterSpacing: 0.4,
  );
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

/// A flat grey button. No elevation, no radius beyond 2, no ink colour.
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
