// Colour tests.
//
// Each command wears a bright colour pulled back a little from full saturation.
// Two contracts matter, and both are asserted here:
//
//  1. No two commands look alike. An earlier dark, desaturated palette put nine
//     tones so close together that TAKE and SHIP read as the same colour, so the
//     floor here is a perceptual one (CIE76 deltaE), not a "these are different
//     hex values" one.
//  2. Every colour stays legible in dark ink under 7.3's 7:1 floor - which is
//     what leaves room to push saturation *up* for the executing line later,
//     rather than having to swap in a different colour.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameplay_ux/model/commands.dart';
import 'package:gameplay_ux/ui/notebook/tokens.dart';

double _linear(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _linear(c.r) + 0.7152 * _linear(c.g) + 0.0722 * _linear(c.b);

/// WCAG contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// CIE76 colour difference. Rough, but enough to catch two tones a player would
/// read as the same colour.
double deltaE(Color a, Color b) {
  List<double> lab(Color c) {
    double f(double t) =>
        t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;

    final r = _linear(c.r);
    final g = _linear(c.g);
    final b = _linear(c.b);
    final x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047;
    final y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    final z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883;
    final fx = f(x);
    final fy = f(y);
    final fz = f(z);
    return [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
  }

  final la = lab(a);
  final lb = lab(b);
  var sum = 0.0;
  for (var i = 0; i < 3; i++) {
    sum += math.pow(la[i] - lb[i], 2);
  }
  return math.sqrt(sum);
}

void main() {
  /// Commands that share a colour, by id. Colour names the family, not the
  /// command: movement in and out of the building, the floor, the loop, the
  /// branch, arithmetic.
  const families = <String, List<String>>{
    'movement': ['take', 'ship'],
    'storage': ['copyFrom', 'copyTo'],
    'loop': ['repeat', 'repeatWhile'],
    'branch': ['ifCond'],
    'arithmetic': ['sum', 'sub'],
  };

  test('the catalogue is exactly these five families', () {
    final listed = families.values.expand((ids) => ids).toSet();
    final actual = commandCatalogue.map((c) => c.id).toSet();
    expect(actual, listed, reason: 'a new command needs a family');
  });

  test('a family shares one colour', () {
    for (final entry in families.entries) {
      final colours = entry.value.map((id) => specFor(id).colour).toSet();
      expect(
        colours,
        hasLength(1),
        reason: '${entry.key} should be one colour, not ${colours.length}',
      );
    }
  });

  test('no two families look alike', () {
    // The complaint that produced this palette: TAKE and SHIP were about ten
    // degrees of hue apart and read as one colour. 20 is comfortably past "these
    // are different". Within a family that is now the point - TAKE and SHIP are
    // deliberately identical, and the word tells them apart - so the check is
    // between families.
    final names = families.keys.toList();
    for (var i = 0; i < names.length; i++) {
      for (var j = i + 1; j < names.length; j++) {
        final a = specFor(families[names[i]]!.first).colour;
        final b = specFor(families[names[j]]!.first).colour;
        expect(
          deltaE(a, b),
          greaterThan(20),
          reason: '${names[i]} and ${names[j]} are too close to tell apart',
        );
      }
    }
  });

  test('row ink clears 7:1 on every command colour', () {
    for (final spec in commandCatalogue) {
      expect(
        contrast(Paper.ink, spec.colour),
        greaterThanOrEqualTo(7),
        reason: '${spec.id} (${spec.colour}) is too dark for its ink',
      );
    }
  });

  test('row ink clears 7:1 on every argument chip', () {
    // Chips are cut out of the row a shade lighter, so against dark ink they can
    // only improve on the row's own ratio - but assert it rather than assume it.
    for (final spec in commandCatalogue.where((c) => c.takesArg)) {
      expect(
        contrast(Paper.ink, Paper.chipFill(spec.colour)),
        greaterThanOrEqualTo(7),
        reason: '${spec.id} chip is too dark for its ink',
      );
    }
  });

  test('the depth step is visible but does not change the colour', () {
    for (final spec in commandCatalogue.where((c) => c.isBlock)) {
      final flat = Paper.fillFor(spec.colour, 0);
      final stepped = Paper.fillFor(spec.colour, 1);

      expect(flat, isNot(stepped), reason: '${spec.id} nested in itself');
      // A step, not a repaint: still clearly the same colour.
      expect(deltaE(flat, stepped), lessThan(16));
      // And still legible.
      expect(contrast(Paper.ink, stepped), greaterThanOrEqualTo(7));
    }
  });

  test('the palette is saturated, and what that costs', () {
    // The colours were desaturated a little so the executing row could be shown
    // by *saturating* it: same colour, more of it. At full saturation that
    // headroom is gone, and nothing in the other direction replaces it - a
    // lightness step big enough to read (deltaE >= 8 on every command) drops the
    // purple's ink contrast to about 4.1, and a step gentle enough to stay
    // readable leaves the cyan-ish ones invisible.
    //
    // So the executing row needs a mechanism that is not the fill: an outline, a
    // shadow, a nudge in position. This test records the constraint rather than
    // pretending the fill can still carry it.
    const movement = ['take', 'ship'];
    for (final spec in commandCatalogue.where(
      (c) => !movement.contains(c.id),
    )) {
      final hsl = HSLColor.fromColor(spec.colour);
      expect(
        hsl.saturation,
        closeTo(1, 0.01),
        reason: '${spec.id} is not at full saturation',
      );
    }

    // The movement family is held back. At full saturation its green was the one
    // colour that hurt to look at - a green at that lightness is the brightest
    // thing the screen can make - and TAKE and SHIP together are most of what is
    // on screen in any program, so it was doing the most damage.
    for (final id in movement) {
      final green = HSLColor.fromColor(specFor(id).colour);
      expect(green.saturation, lessThan(0.7), reason: id);
      expect(green.saturation, greaterThan(0.4), reason: id);
    }
  });

  test('the paper is legible, and the commands still sit on it', () {
    // The program surface went from a dark pane to a light sheet, which changes
    // what has to be checked: ink on paper for the pane's own text, and the
    // command colours no longer disappearing into their background.
    expect(contrast(Paper.ink, Paper.sheet), greaterThanOrEqualTo(7));

    for (final spec in commandCatalogue) {
      expect(
        deltaE(Paper.sheet, spec.colour),
        greaterThan(20),
        reason: '${spec.id} is too close to the paper to read as a card on it',
      );
    }

    // The rules are a hint, not a grid to read: faint against the sheet, and
    // never competing with a word written over them. Measured composited, since
    // they are painted at low alpha - the raw colour is a strong blue and says
    // nothing about what lands on the page.
    expect(
      contrast(Paper.sheet, Color.alphaBlend(Paper.rule, Paper.sheet)),
      lessThan(2),
    );
    expect(
      contrast(Paper.sheet, Color.alphaBlend(Paper.margin, Paper.sheet)),
      lessThan(3),
    );
  });

  test('the delete backdrop reads as an alert, not as a command', () {
    // Near-white on it. This used to be asserted against `W.text`, which was
    // near-white when the chrome was grey and is dark ink now that it is
    // cardboard - so the assertion was passing on a token the swipe hint does
    // not actually use. It uses [Paper.onDanger], which is what is checked.
    expect(contrast(Paper.onDanger, Paper.danger), greaterThanOrEqualTo(7));

    // And it must not be mistaken for the storage family, which wears a red.
    for (final spec in commandCatalogue) {
      expect(
        deltaE(Paper.danger, spec.colour),
        greaterThan(12),
        reason: '${spec.id} is too close to the delete backdrop',
      );
    }
  });

  test('the caret is legible on every block colour', () {
    // The caret is drawn in ink when it sits inside a block, because the dark
    // theme's pale grey vanished on a bright yellow one.
    for (final spec in commandCatalogue.where((c) => c.isBlock)) {
      for (final depth in [0, 1]) {
        expect(
          contrast(Paper.ink, Paper.fillFor(spec.colour, depth)),
          greaterThanOrEqualTo(7),
          reason: 'caret on ${spec.id} at depth $depth',
        );
      }
    }
  });
}
