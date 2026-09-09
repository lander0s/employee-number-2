/// The app's chrome: everything around the page.
///
/// Grey, deliberately. It was cardboard for a while, and the cardboard was
/// good - the right material for a warehouse, warm under the bright commands -
/// but it was answering a question the game has not asked yet. The game is not
/// fun on purpose yet, and a screen that looks finished is a screen nobody
/// wants to gut. So the style is parked: this is a wireframe and it is meant to
/// look like one, until the gameplay earns better.
///
/// Every value here is a neutral, which is the whole rule and is what makes the
/// file safe to throw away later: nothing downstream can come to depend on a
/// hue that is not there. Colour that *survives* the wireframe is colour that
/// carries meaning - the command families, a failed shift - and that lives in
/// the command catalogue and [Paper], not here.
///
/// Everything the notebook itself needs lives in [Paper] (notebook/tokens.dart),
/// not here. This file is only what the page is sitting on.
library;

import 'package:flutter/material.dart';

abstract final class W {
  // ----------------------------------------------------------------- greys
  //
  // Darkest to lightest, and nothing but greys. Light rather than charcoal: the
  // chrome this replaced was dark, and a dark frame around a white page reads
  // as a deliberate theme. Flat light grey reads as unfinished, which is
  // accurate and is the point.

  /// Seen only in the gaps between everything else.
  static const page = Color(0xFFB8B8B8);

  /// The floor the simulation is drawn on. It runs edge to edge - there is no
  /// frame around it - so this is the whole top pane.
  ///
  /// A shade darker than the surfaces that carry text, so that a white package
  /// on it separates without its outline having to do all the work.
  static const paneWell = Color(0xFFD6D6D6);

  /// The working surface: anything the player reads text off.
  static const chrome = Color(0xFFE8E8E8);

  /// A raised tab, and the same pressed in.
  static const button = Color(0xFFF2F2F2);
  static const buttonPressed = Color(0xFFCFCFCF);

  /// An edge, and a softer one for something disabled.
  static const line = Color(0xFF6B6B6B);
  static const lineSoft = Color(0xFFA6A6A6);

  // -------------------------------------------------------------------- ink
  //
  // Dark on light, in both places: the chrome reads the way the commands
  // already did. Ratios are measured against [chrome], the darkest surface any
  // of these sits on - [button] is lighter and only improves them.

  /// 14.2:1 on [chrome]. Far past 7.3's floor, where the cardboard it replaced
  /// cleared it by 0.16 - a neutral costs nothing to darken, so there is no
  /// reason to run it close.
  static const text = Color(0xFF1A1A1A);

  /// 6.90:1. For text that is genuinely secondary - never for instructions.
  static const textDim = Color(0xFF4D4D4D);

  /// 4.16:1, and so decorative only: separators, watermarks, disabled labels.
  static const textFaint = Color(0xFF6E6E6E);

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

  // ------------------------------------------------------------------ floor
  //
  // Lines and boxes, no art - the unit's sprite is the one drawn thing out
  // there. These are the floor's whole palette, and it having one at all is
  // what keeps it from borrowing the program's colours: the commands are the
  // language, and the world they act on should not compete with it.

  /// Cell lines and belt rollers: present, never read.
  static const floorGrid = Color(0x331A1A1A);

  /// Belts, pallets and the unit's furniture.
  static const floorLine = Color(0xFF5A5A5A);

  /// INTAKE, OUTBOUND, the pallet numbers.
  static const floorLabel = Color(0xFF7A7A7A);

  /// A package. Lighter than the floor it sits on, because a package is the one
  /// thing out there that moves and the eye should find it first.
  static const floorPackage = Color(0xFFFFFFFF);

  /// A failed shift, and text on it. Shared with the page's own delete
  /// backdrop, which is the same idea: this went wrong.
  ///
  /// One of the few colours that survive the wireframe, because it is not
  /// decoration: a red here means the shift did not go out.
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

/// A flat button. No elevation, no radius, no ink colour.
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
