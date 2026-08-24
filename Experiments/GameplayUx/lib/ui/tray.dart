/// The command tray. Tap-to-insert at the caret - never drag-from-palette,
/// which is a two-hand interaction (game-design-document.md 7.2).
///
/// Just the buttons. There was a strip above them carrying a `TRAY` label and the
/// `SIZE / SPEED` par readout (7.1's mock shows "⊞ TRAY  SIZE 8 / 7"), and both
/// are gone: the label named something already obvious, and the par numbers read
/// as jargon to someone meeting the screen for the first time. 8.2 says pars stay
/// hidden until a level is first cleared anyway, so a live count during editing
/// was ahead of itself.
///
/// The strip also carried a `DROP TO PLACE` hint during a drag. That went with
/// it: the drop targets light up and the dragged rows follow the finger, so the
/// words were restating what the screen already showed.
///
/// Horizontal scrolling is close to undiscoverable on its own, so the tray fades
/// out on whichever side has more commands off-screen. The fade is on both edges,
/// not just the right: once you have scrolled, the left edge is where the rest of
/// the vocabulary went.
library;

import 'package:flutter/material.dart';

import '../model/commands.dart';
import 'wireframe.dart';

class CommandTray extends StatefulWidget {
  const CommandTray({super.key, required this.onInsert});

  final ValueChanged<String> onInsert;

  @override
  State<CommandTray> createState() => _CommandTrayState();
}

class _CommandTrayState extends State<CommandTray> {
  static const _fadeWidth = 40.0;

  final _scroll = ScrollController();
  bool _moreLeft = false;
  bool _moreRight = false;

  @override
  void initState() {
    super.initState();
    // The first frame has no scroll metrics yet, so the initial state has to be
    // read once layout exists.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshEdges());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _refreshEdges() {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    // A pixel of slack: exact comparisons flicker at the extremes.
    final left = p.pixels > 1;
    final right = p.pixels < p.maxScrollExtent - 1;
    if (left != _moreLeft || right != _moreRight) {
      setState(() {
        _moreLeft = left;
        _moreRight = right;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: W.chrome,
      padding: const EdgeInsets.only(top: 8, bottom: 14),
      child: Stack(
        children: [
          // ScrollMetricsNotification as well as ScrollNotification: the amount
          // of overflow changes with text scale and screen width without anyone
          // scrolling.
          NotificationListener<ScrollMetricsNotification>(
            onNotification: (_) {
              _refreshEdges();
              return false;
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: (_) {
                _refreshEdges();
                return false;
              },
              child: SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    for (final spec in commandCatalogue) ...[
                      _TrayButton(
                        spec: spec,
                        onTap: () => widget.onInsert(spec.id),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
            ),
          ),
          _EdgeFade(
            key: const ValueKey('tray-fade-left'),
            visible: _moreLeft,
            side: _FadeSide.left,
            width: _fadeWidth,
          ),
          _EdgeFade(
            key: const ValueKey('tray-fade-right'),
            visible: _moreRight,
            side: _FadeSide.right,
            width: _fadeWidth,
          ),
        ],
      ),
    );
  }
}

enum _FadeSide { left, right }

/// A gradient from the tray's own background to transparent, so buttons dissolve
/// into the edge rather than being cut off at it.
class _EdgeFade extends StatelessWidget {
  const _EdgeFade({
    super.key,
    required this.visible,
    required this.side,
    required this.width,
  });

  final bool visible;
  final _FadeSide side;
  final double width;

  @override
  Widget build(BuildContext context) {
    final left = side == _FadeSide.left;

    return Positioned(
      top: 0,
      bottom: 0,
      left: left ? 0 : null,
      right: left ? null : 0,
      width: width,
      // Never eat a tap meant for the button underneath.
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 120),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: left ? Alignment.centerLeft : Alignment.centerRight,
                end: left ? Alignment.centerRight : Alignment.centerLeft,
                colors: [W.chrome, W.chrome.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrayButton extends StatelessWidget {
  const _TrayButton({required this.spec, required this.onTap});
  final CommandSpec spec;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: spec.label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: W.minTarget),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: spec.isBlock ? W.buttonPressed : W.button,
            border: Border.all(color: W.line),
          ),
          child: Row(
            children: [
              Text(
                spec.trayLabel,
                style: W.label.copyWith(
                  fontFamily: W.rowFamily,
                  fontFamilyFallback: W.rowFallback,
                ),
              ),
              if (spec.takesArg)
                Text(' _', style: W.label.copyWith(color: W.textFaint)),
              if (spec.isBlock)
                Text('  ┐', style: W.label.copyWith(color: W.textDim)),
            ],
          ),
        ),
      ),
    );
  }
}
