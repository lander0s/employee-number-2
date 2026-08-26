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
import 'package:gameplay_ux/ui/wireframe.dart';

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
  test('every command has its own colour', () {
    final colours = commandCatalogue.map((c) => c.colour).toSet();
    expect(colours.length, commandCatalogue.length);
  });

  test('no two commands look alike', () {
    // The complaint that produced this palette: TAKE and SHIP were about ten
    // degrees of hue apart and read as one colour. 20 is comfortably past "these
    // are different"; the palette currently sits around 24.
    for (var i = 0; i < commandCatalogue.length; i++) {
      for (var j = i + 1; j < commandCatalogue.length; j++) {
        final a = commandCatalogue[i];
        final b = commandCatalogue[j];
        expect(
          deltaE(a.colour, b.colour),
          greaterThan(20),
          reason: '${a.id} and ${b.id} are too close to tell apart',
        );
      }
    }
  });

  test('row ink clears 7:1 on every command colour', () {
    for (final spec in commandCatalogue) {
      expect(
        contrast(W.ink, spec.colour),
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
        contrast(W.ink, W.chipFill(spec.colour)),
        greaterThanOrEqualTo(7),
        reason: '${spec.id} chip is too dark for its ink',
      );
    }
  });

  test('the depth step is visible but does not change the colour', () {
    for (final spec in commandCatalogue.where((c) => c.isBlock)) {
      final flat = W.blockFill(spec.colour, 0);
      final stepped = W.blockFill(spec.colour, 1);

      expect(flat, isNot(stepped), reason: '${spec.id} nested in itself');
      // A step, not a repaint: still clearly the same colour.
      expect(deltaE(flat, stepped), lessThan(16));
      // And still legible.
      expect(contrast(W.ink, stepped), greaterThanOrEqualTo(7));
    }
  });

  test('there is headroom to saturate for the executing row', () {
    // CLOCK OUT is deliberately a near-grey, so it has no hue to intensify; it
    // will need a different highlight treatment.
    for (final spec in commandCatalogue.where((c) => c.id != 'clockOut')) {
      final hsl = HSLColor.fromColor(spec.colour);

      expect(
        hsl.saturation,
        lessThan(0.8),
        reason: '${spec.id} has no room left to brighten',
      );

      final lit = hsl.withSaturation(0.95).toColor();

      // The highlight is the same colour, more of it - not a different one.
      expect(HSLColor.fromColor(lit).hue, closeTo(hsl.hue, 0.5));
      expect(
        deltaE(spec.colour, lit),
        greaterThan(8),
        reason: '${spec.id} would not visibly change when executing',
      );
      // And an executing row still has to be readable.
      expect(contrast(W.ink, lit), greaterThanOrEqualTo(4.5));
    }
  });

  test('the delete backdrop reads as an alert, not as a command', () {
    // Near-white on it, like the rest of the app's furniture - the dark ink is
    // for coloured rows.
    expect(contrast(W.text, W.danger), greaterThanOrEqualTo(7));

    // And it must not be mistaken for SHIP, the one command wearing a red.
    for (final spec in commandCatalogue) {
      expect(
        deltaE(W.danger, spec.colour),
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
          contrast(W.ink, W.blockFill(spec.colour, depth)),
          greaterThanOrEqualTo(7),
          reason: 'caret on ${spec.id} at depth $depth',
        );
      }
    }
  });
}
