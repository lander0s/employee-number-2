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
/// **Two rows, no scrolling.** The tray used to be one horizontal strip that
/// scrolled, with a fade on whichever side had more commands off-screen. It
/// worked, but it meant part of the vocabulary was always hidden behind a gesture
/// nobody is told about - and the whole point of a tray is that the player can
/// see what the language contains. Nine commands fit two rows on a phone, so
/// they get two rows, and the fades, the scroll controller and the notification
/// listeners that drove them are gone with the scrolling.
///
/// The split is by family: flow and the doors on top, the floor and arithmetic
/// underneath.
library;

import 'package:flutter/material.dart';

import '../model/commands.dart';
import '../model/program.dart';
import 'wireframe.dart';

class CommandTray extends StatefulWidget {
  const CommandTray({super.key, this.onDragUpdate, this.onDragEnd});

  /// Where the finger is while a command is being carried out of the tray, in
  /// global coordinates. The program pane uses it to scroll itself when the
  /// finger reaches one of its edges - the tray cannot know that on its own, and
  /// a command dragged from here has the same right to it as a row being moved.
  final ValueChanged<Offset>? onDragUpdate;
  final VoidCallback? onDragEnd;

  @override
  State<CommandTray> createState() => _CommandTrayState();
}

class _CommandTrayState extends State<CommandTray> {
  /// Which commands sit on which row. Explicit rather than flowed: a `Wrap`
  /// would re-break by width and could land three rows on a narrow phone, and
  /// two rows that keep families together is the point.
  static const _rows = <List<String>>[
    ['take', 'ship', 'repeat', 'repeatWhile', 'ifCond'],
    ['copyFrom', 'copyTo', 'sum', 'sub'],
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: W.chrome,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in _rows) ...[
            if (row != _rows.first) const SizedBox(height: 6),
            Row(
              children: [
                for (final id in row) ...[
                  if (id != row.first) const SizedBox(width: 6),
                  // Expanded, so the buttons divide the row exactly and both
                  // rows end flush with the edges. Natural widths left a ragged
                  // right margin and made SUB a smaller target than COPY FROM
                  // for no reason a player could see. Each label is a scaleDown
                  // FittedBox, the last resort before anything is clipped.
                  Expanded(
                    child: _TrayButton(
                      spec: specFor(id),
                      onDragUpdate: widget.onDragUpdate,
                      onDragEnd: widget.onDragEnd,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TrayButton extends StatelessWidget {
  const _TrayButton({required this.spec, this.onDragUpdate, this.onDragEnd});

  final CommandSpec spec;
  final ValueChanged<Offset>? onDragUpdate;
  final VoidCallback? onDragEnd;

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
        // Vertical affinity is kept even though the tray no longer scrolls: a
        // command should come away when the finger goes *up* towards the
        // program, not when it slides along the shelf.
        affinity: Axis.vertical,
        onDragUpdate: (d) => onDragUpdate?.call(d.globalPosition),
        onDragEnd: (_) => onDragEnd?.call(),
        onDraggableCanceled: (_, _) => onDragEnd?.call(),
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
    // Every command wears the same face here, block or not. A `┐` hint and an
    // `_` argument slot used to make REPEAT and IF look like different kinds of
    // object while still in the tray; being a container is something a command
    // becomes once it is in the program, not a property of the thing you pick
    // up.
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Center(
        widthFactor: 1,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            spec.trayLabel,
            style: W.label.copyWith(
              color: W.ink,
              fontWeight: FontWeight.w700,
              fontFamily: W.rowFamily,
              fontFamilyFallback: W.rowFallback,
              letterSpacing: W.rowLetterSpacing,
            ),
            maxLines: 1,
          ),
        ),
      ),
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
