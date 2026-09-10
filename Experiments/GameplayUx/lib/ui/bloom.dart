/// Bloom: light, added to a subtree after it is drawn.
///
/// The rule is that a [keyColours] colour shines and everything else goes dark.
/// It is a rule about the game, not about any one sprite: paint something in a
/// key colour and it emits light, paint it in anything else and it is a surface
/// that light falls on.
///
/// Three layers, bottom to top:
///
///  1. The grade - darkens the child, so the light has something to be bright
///     against.
///  2. The core - what looks like a key colour, added back in that colour and
///     unblurred, undoing the grade on the lit pixels.
///  3. The glow - the same mask, blurred. The light in the air around them.
///
/// Both light layers read the *graded* pixels, which is what makes them light
/// rather than tint: the exposure divides out of the measurement but never out
/// of what is added back.
///
/// [BloomLayer] is the whole API - wrap the app or one pane. It brings its own
/// tuning panel, off unless [_enableTuner] says otherwise and never in release.
library;

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Whether the tuning panel is wanted. Flipped by hand, and put back.
///
/// Only half the gate: even set true the panel is still barred from a release
/// build, so leaving it on by accident cannot ship a debug control.
const _enableTuner = false;

/// The colours that count as light. Each glows in its own colour.
///
/// Add one here and it lights up with no other change, subject to two things:
///
///  - **Distance.** Keys are scored on hue, normalised to 1.0 for a key against
///    itself and exactly 0 for any grey. What matters is the score of the
///    *other* keys and of the palette: the cyan works because its nearest
///    rival, the blue command family, only reaches 0.771, leaving room for the
///    threshold. A key close in hue to another closes that gap, and this list
///    is the first place to look when something glows that should not.
///  - **Cost.** Each key adds two backdrop passes - the threshold is a clamp,
///    and a clamp cannot be folded into a shared matrix.
///
/// Values must be exact. Lottie stores colours as floats, so grepping the
/// project for the hex will not find them.
const keyColours = <Color>[Color(0xFF5CF2DF)];

/// The live tuning, shared by every [BloomLayer] in the tree. A global because
/// the layers can be anywhere and the widgets in between have no business
/// knowing a tuning knob exists.
final bloom = BloomTuning();

class BloomTuning extends ChangeNotifier {
  // ----------------------------------------------------------- the settings
  //
  // The look, not a starting point for one: the app opens lit. These are the
  // one place the numbers live - fields start here, [reset] returns here, and
  // `copy settings` prints them in this exact shape to be pasted back.
  //
  // The two that are not obvious:
  //
  //  - threshold 0.85, because the cyan's nearest rival scores 0.771 and the
  //    margin has to cover the antialiased pixels in between.
  //  - core 2.1, small on purpose. Added light clamps per channel, so a key
  //    pushed past full does not brighten, it whitens - the largest channel
  //    pins while the rest climb. The ceiling here is key x 1.054, and the
  //    core need not reach it alone: a Gaussian peaks on its own source, so
  //    the glow already puts key x 0.29 back on the lit pixels. 0.4 base +
  //    2.1 x 0.15 + 0.29 = key x 1.006, the authored colour, nothing clipped.
  //    That 0.29 is for a source a few pixels across; a larger one keeps more
  //    of the glow's peak and clips again, so for any size the bound is
  //    `core + glow <= (1/largest channel - exposure) / (1 - threshold)`.
  //  - glow and radius, 12 and 6. The amount looks absurd until you count
  //    pixels, and it is sized for the smallest thing expected to glow rather
  //    than for the screen. A Gaussian conserves light, so blurring a source
  //    only a handful of pixels across by a comparable sigma drops its peak to
  //    a few percent of what it was - measured, a source about seven logical
  //    pixels wide kept about 4% of its peak at radius 12. Small sources need
  //    a tight radius *and* a large amount, and the two have to move together:
  //    double the radius and a glow that size all but disappears. Anything
  //    much larger will want them both lower.
  static const defaultDarken = 0.6;
  static const defaultCore = 2.1;
  static const defaultGlow = 12.0;
  static const defaultThreshold = 0.85;
  static const defaultRadius = 6.0;

  /// How far down the child is pulled. 0 is untouched, 1 is black.
  double darken = defaultDarken;

  /// The mask added straight back, unblurred: the lit pixels themselves, each
  /// in its own key colour. Enough to reach the colour as authored, not past
  /// it - see the ceiling above.
  double core = defaultCore;

  /// The same mask, blurred: the light in the air around them. 0 is off, and
  /// also the cheap path - no glow means no backdrop pass.
  double glow = defaultGlow;

  /// Where the mask starts: 1 is the key colour itself, 0 is any grey. Shared
  /// by every key and both passes - differing between core and glow would show
  /// as a seam where the glow stopped agreeing with its source.
  double threshold = defaultThreshold;

  /// Blur sigma, in logical pixels: small is a rim, large is a haze.
  double radius = defaultRadius;

  /// Held down to see the subtree unfiltered without losing the settings.
  bool bypassed = false;

  /// What the grade multiplies brightness by. Floored above 0 because
  /// [maskFilter] divides by it.
  double get exposure => (1 - darken).clamp(0.02, 1.0);

  bool get gradeIsActive => !bypassed && darken != 0;
  bool get coreIsActive => !bypassed && core > 0 && keyColours.isNotEmpty;
  bool get glowIsActive =>
      !bypassed && glow > 0 && radius > 0 && keyColours.isNotEmpty;
  bool get isLit => coreIsActive || glowIsActive;
  bool get isActive => gradeIsActive || isLit;

  void set(void Function() change) {
    change();
    notifyListeners();
  }

  /// Back to the shipped look - undo the fiddling, not switch the effect off.
  void reset() {
    darken = defaultDarken;
    core = defaultCore;
    glow = defaultGlow;
    threshold = defaultThreshold;
    radius = defaultRadius;
    notifyListeners();
  }

  /// Everything off, leaving the app exactly as it is drawn.
  void off() {
    darken = 0;
    core = 0;
    glow = 0;
    notifyListeners();
  }

  /// The settings as Dart, shaped like the constants above so a session of
  /// tuning can be pasted straight back over them.
  String get asDartSource =>
      'static const defaultDarken = ${darken.toStringAsFixed(2)};\n'
      'static const defaultCore = ${core.toStringAsFixed(2)};\n'
      'static const defaultGlow = ${glow.toStringAsFixed(2)};\n'
      'static const defaultThreshold = ${threshold.toStringAsFixed(2)};\n'
      'static const defaultRadius = ${radius.toStringAsFixed(1)};';

  // ------------------------------------------------------------------ stages

  /// The grade: a straight scale on brightness, alpha left alone.
  ColorFilter get gradeFilter => ColorFilter.matrix(<double>[
    exposure, 0, 0, 0, 0, //
    0, exposure, 0, 0, 0, //
    0, 0, exposure, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  /// The mask for one [key]: what that key lights, everything else black. One
  /// key per call, because the threshold is the pipeline's clamp at zero and a
  /// nonlinearity cannot be folded into a shared matrix.
  ///
  /// A matrix is a *linear* map, so it cannot express a distance in colour
  /// space. It projects onto the key's chroma direction instead - hence greys
  /// scoring exactly zero however bright, and hence the blue command family
  /// still reaching 0.771 against the cyan, pointing the same way round the
  /// wheel but further. Two keys close in hue is what would break this, and
  /// the day it wants to be a fragment shader.
  ColorFilter maskFilter(Color key, double gain) {
    final w = _keyWeights(key);

    // Divides the *measurement* only, so the threshold means the same thing
    // however dark the screen has been pulled - and so neither pass takes the
    // darkening that the rest of the subtree took.
    final k = exposure;
    final t = threshold;

    // Every channel is the same scalar intensity times the key colour, so all
    // three cross zero together and the pipeline's clamp at 0 does the
    // thresholding for free.
    List<double> row(double c) => <double>[
      c * gain * w[0] / k,
      c * gain * w[1] / k,
      c * gain * w[2] / k,
      0,
      -c * gain * t * 255,
    ];

    return ColorFilter.matrix(<double>[
      ...row(key.r),
      ...row(key.g),
      ...row(key.b),
      0, 0, 0, 1, 0, // alpha through, so the add below stays opaque
    ]);
  }
}

/// Weights that score a pixel by *hue* alone: 1 for [key], 0 for any grey.
///
/// The key's direction with its own average subtracted off - chroma, with the
/// brightness taken out. The weights sum to zero, so every grey scores 0 no
/// matter how bright. Normalised so the key itself scores 1.
List<double> _keyWeights(Color key) {
  final n = math.sqrt(key.r * key.r + key.g * key.g + key.b * key.b);
  final unit = <double>[key.r / n, key.g / n, key.b / n];
  final mean = (unit[0] + unit[1] + unit[2]) / 3;
  final w = <double>[unit[0] - mean, unit[1] - mean, unit[2] - mean];
  final self = w[0] * key.r + w[1] * key.g + w[2] * key.b;
  return <double>[w[0] / self, w[1] / self, w[2] / self];
}

/// Applies [bloom] to everything below it.
///
/// Wrap the whole app or one pane; scoping it down is just moving where it
/// sits, and the light stays inside whatever it wraps.
///
/// The tuning panel comes with it, but only when [_enableTuner] is on and only
/// in a debug build - by default there is nothing on screen but the effect.
class BloomLayer extends StatelessWidget {
  const BloomLayer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final lit = _build(context);
    // Both halves are compile-time constants, so with either false the panel
    // is never built and the tuner can be shaken out entirely.
    return _enableTuner && kDebugMode ? _Tuner(child: lit) : lit;
  }

  Widget _build(BuildContext context) {
    return AnimatedBuilder(
      animation: bloom,
      // Passed through rather than rebuilt: moving a slider must not rebuild
      // the subtree, which can be the whole game.
      child: child,
      builder: (context, child) {
        // Nothing on means nothing wrapped - no filter at all, not an identity
        // one, so the child renders as if this widget were absent.
        var out = child!;
        if (bloom.gradeIsActive) {
          out = ColorFiltered(colorFilter: bloom.gradeFilter, child: out);
        }
        if (!bloom.isLit) return out;

        // The glow sits above the core deliberately, so it reads a backdrop
        // where the lit pixels are already bright - a halo comes from the lamp
        // being bright, not from what it would have been. The two amounts are
        // therefore not independent: raising the core also feeds the glow.
        // The clip is what keeps the promise that this only affects its own
        // subtree: a backdrop filter has no bounds of its own, and with no
        // enclosing clip it filters the entire screen however small the widget
        // wrapping it.
        return ClipRect(
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              out,
              // Every core before any glow, not each key's pair together:
              // passes read what the ones below left, so this way no key's
              // halo depends on where its colour sits in the list.
              if (bloom.coreIsActive)
                for (final key in keyColours)
                  _pass(bloom.maskFilter(key, bloom.core)),
              if (bloom.glowIsActive)
                for (final key in keyColours)
                  _pass(
                    ImageFilter.compose(
                      outer: ImageFilter.blur(
                        sigmaX: bloom.radius,
                        sigmaY: bloom.radius,
                        // decal, so the blur does not smear the edge pixels
                        // outward and hang a bright rim on the boundary.
                        tileMode: TileMode.decal,
                      ),
                      inner: bloom.maskFilter(key, bloom.glow),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  /// One pass of added light. Additive, so the black everywhere the mask did
  /// not fire leaves the picture alone instead of veiling it; the empty box is
  /// only something for the filter to hang on.
  static Widget _pass(ImageFilter filter) => Positioned.fill(
    child: IgnorePointer(
      child: BackdropFilter(
        filter: filter,
        blendMode: BlendMode.plus,
        child: const SizedBox.expand(),
      ),
    ),
  );
}

// ===========================================================================
// The tuner. Off unless [_enableTuner] says so, and never in release. Only one
// thing above the line refers to anything below it - the ternary in
// [BloomLayer.build] - so deleting from here down, and that line, leaves a
// working effect.
// ===========================================================================

/// Whether a panel is already up. One [bloom] means one panel, however many
/// layers exist - and scoping layers to panes is what makes several likely.
bool _tunerMounted = false;

/// What the panel paints itself in: the first key, or blue if there are none.
Color get _accent =>
    keyColours.isEmpty ? const Color(0xFF7FD1FF) : keyColours.first;

/// Puts the debug panel in the overlay, and passes [child] straight through.
///
/// Via the [Overlay] rather than stacked over the child, because stacked it
/// would be trapped in whatever the layer wraps - clipped to a pane shorter
/// than the panel, and painted under later siblings. The cost is needing an
/// overlay above it, so a [BloomLayer] has to sit inside the app rather than
/// around it; with none, the effect still works and the panel does not appear.
class _Tuner extends StatefulWidget {
  const _Tuner({required this.child});

  final Widget child;

  @override
  State<_Tuner> createState() => _TunerState();
}

class _TunerState extends State<_Tuner> {
  OverlayEntry? _entry;

  @override
  void initState() {
    super.initState();
    // After the first frame: the overlay cannot be inserted into while the
    // tree that owns it is still building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _tunerMounted) return;
      final overlay = Overlay.maybeOf(context);
      if (overlay == null) return;
      _entry = OverlayEntry(
        // Its own Directionality: the panel has to keep working while the
        // app's theme is being messed with.
        builder: (context) => const Directionality(
          textDirection: TextDirection.ltr,
          child: _Puck(),
        ),
      );
      overlay.insert(_entry!);
      _tunerMounted = true;
    });
  }

  @override
  void dispose() {
    if (_entry != null) {
      _entry!.remove();
      _entry = null;
      _tunerMounted = false;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// --------------------------------------------------------------------- puck
//
// Draggable and collapsed by default: it sits on top of a game being looked at,
// so it has to be movable off whatever it covers.

class _Puck extends StatefulWidget {
  const _Puck();

  @override
  State<_Puck> createState() => _PuckState();
}

class _PuckState extends State<_Puck> {
  /// Inset from the top-right corner. Nothing persists across a restart.
  Offset _offset = const Offset(12, 44);
  bool _open = false;
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    // Upper limits floored at zero too: Android hands out a zero-size frame
    // before the first real one, and `clamp` throws if its upper limit falls
    // below its lower.
    final size = MediaQuery.sizeOf(context);
    return Positioned(
      right: _offset.dx.clamp(0.0, math.max(0.0, size.width - 56)),
      top: _offset.dy.clamp(0.0, math.max(0.0, size.height - 56)),
      child: GestureDetector(
        // dx negated: pinned to the right edge, so dragging left increases the
        // inset.
        onPanUpdate: (d) =>
            setState(() => _offset += Offset(-d.delta.dx, d.delta.dy)),
        child: Material(
          color: const Color(0xF01C1C1E),
          elevation: 8,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            alignment: Alignment.topRight,
            child: _open ? _panel() : _collapsed(),
          ),
        ),
      ),
    );
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: bloom.asDartSource));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Widget _collapsed() {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => _open = true),
      child: SizedBox(
        width: 44,
        height: 44,
        child: AnimatedBuilder(
          animation: bloom,
          builder: (context, _) => Center(
            child: Icon(
              Icons.contrast,
              size: 20,
              // Lit in the key colour while the bloom is on, so a screenshot
              // still says what it was taken through.
              color: bloom.isLit
                  ? _accent
                  : bloom.isActive
                  ? const Color(0xFF7FD1FF)
                  : const Color(0xFF8A8A8E),
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel() {
    return SizedBox(
      width: 244,
      child: AnimatedBuilder(
        animation: bloom,
        builder: (context, _) => Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 10, 12),
          child: DefaultTextStyle(
            style: const TextStyle(
              color: Color(0xFFE8E8EA),
              fontSize: 12,
              height: 1.2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'BLOOM',
                        style: TextStyle(
                          color: Color(0xFF8A8A8E),
                          fontSize: 10,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                    _iconButton(Icons.refresh, bloom.reset),
                    _iconButton(
                      Icons.close,
                      () => setState(() => _open = false),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                _preset(),
                _slider(
                  'Darken',
                  '${(bloom.darken * 100).round()}%',
                  bloom.darken,
                  (v) => bloom.set(() => bloom.darken = v),
                ),
                const SizedBox(height: 8),
                _sectionLabel('LIGHT'),
                _slider(
                  'Core',
                  '${(bloom.core * 100).round()}%',
                  bloom.core / 8,
                  (v) => bloom.set(() => bloom.core = v * 8),
                ),
                _slider(
                  'Glow',
                  '${(bloom.glow * 100).round()}%',
                  bloom.glow / 16,
                  (v) => bloom.set(() => bloom.glow = v * 16),
                ),
                _slider(
                  'Threshold',
                  '${(bloom.threshold * 100).round()}%',
                  bloom.threshold,
                  (v) => bloom.set(() => bloom.threshold = v),
                ),
                _slider(
                  'Radius',
                  '${bloom.radius.round()}px',
                  bloom.radius / 48,
                  (v) => bloom.set(() => bloom.radius = v * 48),
                ),
                const SizedBox(height: 10),
                // Press and hold, not a toggle: the comparison has to be a
                // flick.
                Listener(
                  onPointerDown: (_) => bloom.set(() => bloom.bypassed = true),
                  onPointerUp: (_) => bloom.set(() => bloom.bypassed = false),
                  onPointerCancel: (_) =>
                      bloom.set(() => bloom.bypassed = false),
                  child: _button(
                    bloom.bypassed ? 'unfiltered' : 'hold to compare',
                    on: bloom.bypassed,
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _copy,
                  child: _button(
                    _copied ? 'copied to clipboard' : 'copy settings',
                    on: _copied,
                    icon: _copied ? Icons.check : Icons.copy,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _button(String label, {bool on = false, IconData? icon}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: on ? const Color(0xFF3A3A3C) : const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: const Color(0xFFE8E8EA)),
            const SizedBox(width: 6),
          ],
          Text(label),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(
      text,
      style: const TextStyle(
        color: Color(0xFF8A8A8E),
        fontSize: 9,
        letterSpacing: 1.4,
      ),
    ),
  );

  /// On or off, and it stays put - which `hold to compare` cannot do, because
  /// it springs back.
  Widget _preset() {
    final on = bloom.isActive;
    return GestureDetector(
      onTap: () => on ? bloom.off() : bloom.reset(),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: on ? Colors.transparent : const Color(0xFF2C2C2E),
          border: Border.all(
            color: on ? _accent.withValues(alpha: 0.5) : Colors.transparent,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            on ? 'bloom on' : 'bloom off',
            style: TextStyle(
              color: on ? _accent : const Color(0xFF8A8A8E),
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  Widget _slider(
    String label,
    String value,
    double normalised,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label),
            const Spacer(),
            Text(value, style: const TextStyle(color: Color(0xFF7FD1FF))),
          ],
        ),
        _Track(value: normalised.clamp(0.0, 1.0), onChanged: onChanged),
      ],
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return InkResponse(
      onTap: onTap,
      radius: 18,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Icon(icon, size: 16, color: const Color(0xFF8A8A8E)),
      ),
    );
  }
}

/// A slider, by hand: Material's puts its value indicator in an [Overlay], and
/// hand-rolling keeps the panel from reading anything off the app's theme.
class _Track extends StatelessWidget {
  const _Track({required this.value, required this.onChanged});

  /// 0 to 1. Every caller scales its own range into this.
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    const thumb = 14.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Travel is the track minus one thumb, measured from its centre, or
        // the value cannot reach 0 or 1 without the thumb hanging off the end.
        final travel = constraints.maxWidth - thumb;
        void set(Offset local) =>
            onChanged(((local.dx - thumb / 2) / travel).clamp(0.0, 1.0));

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => set(d.localPosition),
          onHorizontalDragUpdate: (d) => set(d.localPosition),
          child: SizedBox(
            height: 26,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: thumb / 2),
                  color: const Color(0xFF48484A),
                ),
                Container(
                  height: 2,
                  width: thumb / 2 + travel * value,
                  margin: const EdgeInsets.only(left: thumb / 2),
                  color: const Color(0xFF7FD1FF),
                ),
                Positioned(
                  left: travel * value,
                  child: Container(
                    width: thumb,
                    height: thumb,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8E8EA),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
