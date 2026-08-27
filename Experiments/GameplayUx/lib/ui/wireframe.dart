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

  /// The program is written on a sheet of paper. It was a dark grey pane, which
  /// was honest about being a text editor and said nothing about what the game
  /// is: the fiction is a person writing instructions for a machine on the job,
  /// and a ruled notebook says that before a word of dialogue does. It also
  /// flips the whole surface to light, which is what the bright command colours
  /// and their dark ink were always designed for.
  static const paneProgram = paper;

  static const paper = Color(0xFFF6F1E4);

  /// Faint blue rules at exactly [rowHeight], so instructions sit on the lines
  /// rather than floating between them, and a red margin down the left like
  /// every school notebook.
  static const paperRule = Color(0x332F6FA8);
  static const paperMargin = Color(0x4DD2504A);
  static const paperMarginInset = 26.0;

  /// Where the program starts: to the right of the margin line, the way writing
  /// in a real notebook does. The rules and the margin are the page and run the
  /// full width; only what is written on it respects the margin.
  static const paperGutter = 34.0;

  /// Commands are tilted a fraction of a degree, like stickers pressed onto the
  /// page by hand. Deterministic per command, never random: a fresh angle on
  /// every rebuild would make the whole program twitch every time anything
  /// changed.
  ///
  /// Tiny on purpose. A row is ~400dp wide, so even this lifts its far corner
  /// about 2dp - enough to read as placed rather than printed, small enough that
  /// nothing looks broken.
  static const stickerTilt = 0.0075;

  /// A stable angle in [-stickerTilt, stickerTilt] for a given seed.
  ///
  /// Seeded on the *command*, not on the instance. Per-instance angles looked
  /// marginally more hand-made and were a menace: node ids are generated, so
  /// every command drew a different angle on every run, which made the geometry
  /// of the whole program unreproducible - layout tests passed or failed
  /// depending on how many nodes had been created before them. Per command it is
  /// stable across runs, stable across edits, and reads as a sticker sheet where
  /// every TAKE was cut the same way.
  static double tiltFor(String seed) =>
      ((seed.hashCode % 1000) / 500 - 1) * stickerTilt;

  /// How much empty page the program keeps below its last row, as a fraction of
  /// the pane. It is what makes a short program scrollable at all - without it
  /// the content ends exactly at the viewport, so the end of the program is
  /// stuck wherever it happens to fall, often right above the tray.
  ///
  /// A whole pane was too much: it let the program scroll almost entirely off
  /// the top, and the page looked abandoned. Half brings the last row to the
  /// middle of the screen, which is as far as anyone needs to pull it to be
  /// comfortable adding to the end.
  static const tailSlack = 0.5;
  static const chrome = Color(0xFF1C1C1C);

  /// The tray lies over the page rather than beside it, and lets it through:
  /// the ruled sheet is visible under the note, which is what makes the tray
  /// read as something resting on the program instead of a strip of app frame
  /// bolted to the bottom of the screen.
  ///
  /// Dark enough that the dark ink on the buttons still has a surface to sit
  /// against, light enough that the rules read through the gaps between them.
  static const trayScrim = Color(0x661C1C1C);
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

  /// A soft shadow under every command, and nothing else.
  ///
  /// There was a whole plastic treatment here - a hard lip in a darker shade of
  /// the row's own colour for the moulded edge, and a band of gloss across the
  /// top. Both are gone. The shadow stays because it does something the others
  /// did not: it separates a row from whatever it is sitting on, which on nested
  /// blocks of similar colour is the difference between reading the structure
  /// and squinting at it. The rest was decoration on a screen that already has
  /// nine colours and four depths of nesting to communicate.
  /// Empty when off, so the toggle costs nothing to paint.
  static List<BoxShadow> shadowIf(bool on) => on ? shadow : const [];

  static const shadow = <BoxShadow>[
    BoxShadow(color: Color(0x59000000), offset: Offset(0, 5), blurRadius: 9),
  ];

  /// Hairline between two adjacent rows. Invisible where colours differ, and
  /// just enough where two of the same command sit together.
  static Color rowEdge(Color base) => Color.lerp(base, Colors.black, 0.18)!;

  // Dimensions. 7.3: rows 56-64, targets >= 48, indent must be legible.
  // Tightened once the language settled. The text stays at 20pt - it is the one
  // thing 7.3 will not trade - and everything around it came in.
  //
  // 36 is under the 48dp target guidance, deliberately. A 20pt word is about
  // 14dp of actual capital, so a 48dp row wrapped it in 34dp of air, and a
  // program is mostly rows: that air was the single biggest consumer of a screen
  // whose whole argument (7.1) is how much program you can see at once.
  //
  // What makes it affordable is that a row is not a tap target. Its gestures are
  // a horizontal swipe and a long-press drag, neither of which needs a
  // fingertip-sized box to acquire. The one thing on a row you actually tap - a
  // cyclable word - keeps its own target ([chipTarget]), and it is wide as well
  // as tall, which is where the accuracy really comes from.
  static const rowHeight = 36.0;
  static const closerRowHeight = 44.0;
  static const indentPerDepth = 12.0;

  /// A spacer standing in for a row: a command's worth of space with the gap a
  /// real row has above and below it.
  ///
  /// Two places need it. A spacer with something held over it, because that
  /// state is a preview of where the row will land - margins included, so
  /// nothing shifts when it does. And the lone spacer in an empty block, which
  /// reads as one invisible instruction rather than as spacing between siblings
  /// that are not there.
  static const openSlotHeight = rowHeight + indentPerDepth * 2;

  /// How long a spacer takes to open under a held command, and to close again
  /// when it leaves. Linear: the gap is following the finger, not performing.
  static const slotGrow = Duration(milliseconds: 120);

  /// Hold a dragged command near the top or bottom of the program and it
  /// scrolls, because that is what holding something at the edge of a list
  /// means. The zone is capped at a quarter of the pane: on a short pane a fixed
  /// 90 would leave no neutral middle, so every drag would scroll.
  ///
  /// The speed ramps from [autoScrollSlow] at the inner boundary to
  /// [autoScrollFast] at the very edge. A constant speed makes the zone feel
  /// like a switch you trip by accident; a ramp makes it feel like pressure.
  static const autoScrollEdge = 90.0;
  static const autoScrollSlow = 2.0;
  static const autoScrollFast = 16.0;
  static const minTarget = 48.0;

  /// A chip hugs its word. The target it needs is carried by transparent space
  /// around it - see _ArgWord - so the padding here can be the least that still
  /// reads as a button.
  static const chipPadH = 8.0;
  static const chipPadV = 2.0;

  /// The tappable box around a cyclable word. Smaller than [minTarget], which
  /// stays 48 for the tray buttons: a chip is also 60-120dp wide, and a target
  /// that wide is easy to hit at 36 tall. If playtesting shows mis-taps this is
  /// the first number to put back.
  static const chipTarget = 36.0;

  /// Left inset for every row and slot, replacing the old line-number gutter.
  static const rowInset = 10.0;

  /// A block header's only vertical padding, above the title. There is none
  /// below it: the spacer between the title and the first child does that job,
  /// and unlike padding it answers a tap.
  static const headerTopPad = 7.0;

  /// Corner radii. Rows and tray buttons share one so a command looks the same
  /// wherever it is; a block is a touch rounder because it is the bigger shape.
  /// Sharp. Rounded corners were tried and dropped: on a screen this dense -
  /// blocks inside blocks, chips inside rows, a gloss band on every one - each
  /// radius was another soft edge competing with the nesting for attention, and
  /// the "C" of a container reads harder when its arms are curved. Kept as
  /// tokens rather than deleted so the whole language can be re-rounded from one
  /// place.
  static const rowRadius = 0.0;
  static const blockRadius = 0.0;
  static const chipRadius = 0.0;

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
  /// Instructions are set in Sniglet Regular, vendored in assets/fonts. It is
  /// the one place in the app with any character - the chrome around it stays
  /// plain.
  ///
  /// Only the one face is shipped, so weight cannot separate a keyword from an
  /// argument the way it did with the monospace this replaced. The argument
  /// chips carry that distinction on their own, with a fill and an edge.
  static const rowFamily = 'Sniglet';
  static const rowFallback = <String>['Consolas', 'Courier New', 'monospace'];

  /// A little air between letters, so each one can be read on its own.
  static const rowLetterSpacing = 0.8;

  /// Bold, and one weight for every word on a row: what separates a fixed
  /// command word from a value you can change is the chip around the value, not
  /// the weight of the letters.
  /// `leadingDistribution: even` is doing real work here. The labels are all
  /// caps, and by default the leftover line height is split the way the font
  /// declares it - most of it below the caps, in descender space nothing here
  /// ever uses. That reads as a chunk of padding under every word, worst inside
  /// the argument chips where the box is tight to begin with. Even splits it
  /// top and bottom, so a word sits in the middle of whatever holds it.
  static const TextStyle row = TextStyle(
    fontFamily: rowFamily,
    fontFamilyFallback: rowFallback,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: rowLetterSpacing,
    leadingDistribution: TextLeadingDistribution.even,
    color: text,
    height: 1.0,
  );

  static const TextStyle rowArg = TextStyle(
    fontFamily: rowFamily,
    fontFamilyFallback: rowFallback,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: rowLetterSpacing,
    leadingDistribution: TextLeadingDistribution.even,
    color: textDim,
    height: 1.0,
  );

  static const TextStyle label = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: text,
  );

  static const TextStyle labelDim = TextStyle(fontSize: 17, color: textDim);

  /// The same, for text sitting on the paper rather than on the app's chrome.
  static const TextStyle onPaperDim = TextStyle(fontSize: 17, color: inkDim);

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
