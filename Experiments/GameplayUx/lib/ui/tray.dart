/// The command tray.
///
/// A command is placed by **dragging it out of the tray and dropping it into a
/// spacer** in the program. This is a deliberate departure from
/// game-design-document.md 7.2, which chose tap-to-insert precisely to avoid
/// drag-from-palette, calling it a two-hand interaction. Dragging up from a
/// bottom tray with one thumb is the thing to judge on a real device - if the
/// GDD is right, this is where it shows.
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
import '../model/program.dart';
import 'wireframe.dart';

class CommandTray extends StatefulWidget {
  const CommandTray({super.key});

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
                      _TrayButton(spec: spec),
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
  const _TrayButton({required this.spec});

  final CommandSpec spec;

  @override
  Widget build(BuildContext context) {
    final button = _Face(spec: spec);

    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: '${spec.label}, drag into the program',
      child: Draggable<DragPayload>(
        data: NewCommand(spec.id),
        // Vertical affinity, or the draggable swallows the horizontal drags that
        // scroll the tray - and with nine commands on a phone, a tray you cannot
        // scroll is a tray you cannot use. Up picks a command out; sideways
        // still moves the shelf.
        affinity: Axis.vertical,
        // No long press: the tray exists to be picked from, so a command should
        // come away on the first movement rather than after a hold.
        feedback: _Feedback(spec: spec),
        // The tray keeps its full row of commands while one is in the air - a
        // gap opening in the shelf would be a second thing moving at once.
        childWhenDragging: Opacity(opacity: 0.4, child: button),
        child: button,
      ),
    );
  }
}

/// The button as it sits in the tray.
class _Face extends StatelessWidget {
  const _Face({required this.spec});

  final CommandSpec spec;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: W.minTarget),
    // The same colour the command wears in the program, and the same moulding,
    // so the tray reads as a shelf of the very things you are about to place.
    decoration: BoxDecoration(
      color: spec.colour,
      border: Border.all(color: W.chipEdge(spec.colour)),
      borderRadius: BorderRadius.circular(W.rowRadius),
      boxShadow: W.plastic(spec.colour),
    ),
    child: Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: W.glossHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: W.gloss,
              borderRadius: BorderRadius.circular(W.rowRadius),
            ),
          ),
        ),
        // Every command wears the same face here, block or not. A `┐` hint and
        // an `_` argument slot used to make REPEAT and IF look like different
        // kinds of object while still in the tray; being a container is
        // something a command becomes once it is in the program, not a property
        // of the thing you pick up.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Center(
            widthFactor: 1,
            child: Text(
              spec.trayLabel,
              style: W.label.copyWith(
                color: W.ink,
                fontWeight: FontWeight.w800,
                fontFamily: W.rowFamily,
                fontFamilyFallback: W.rowFallback,
                letterSpacing: W.rowLetterSpacing,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// What follows the finger out of the tray: the button itself, lifted.
///
/// It used to be a real `ProgramRow`, so that the drag previewed its own result.
/// That looked wrong for exactly the commands that need to look most ordinary: a
/// block header paints no background of its own - the container behind it does -
/// so REPEAT flew as bare floating letters, and IF carried its condition chips
/// with nothing behind them. The row is a row once it lands somewhere.
class _Feedback extends StatelessWidget {
  const _Feedback({required this.spec});

  final CommandSpec spec;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: 0.92,
    child: Material(
      color: Colors.transparent,
      child: _Face(spec: spec),
    ),
  );
}
