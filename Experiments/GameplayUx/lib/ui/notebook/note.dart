/// The command note: where commands come from, and where they go back to.
///
/// Two rows of every command in the language, no scrolling, lying over the page
/// rather than beside it. And while a *placed* command is in the air, it becomes
/// the bin - which is why deleting needs no bin of its own, no extra chrome, and
/// no second idea for the player to learn.
library;

import 'package:flutter/material.dart';

import '../../model/commands.dart';
import '../../model/program.dart';
import 'panel.dart';
import 'lift.dart';
import 'tokens.dart';

class CommandNote extends StatelessWidget {
  const CommandNote({
    super.key,
    required this.lift,
    required this.autoScroll,
    required this.onTrash,
  });

  final LiftState lift;
  final AutoScroller autoScroll;

  /// A command dropped here is removed from the program.
  final ValueChanged<String> onTrash;

  /// Which commands sit on which row. Explicit rather than flowed: a `Wrap`
  /// would re-break by width and could land three rows on a narrow phone, and
  /// two rows that keep families together is the point.
  static const _rows = <List<String>>[
    ['take', 'ship', 'repeat', 'repeatWhile', 'ifCond'],
    ['copyFrom', 'copyTo', 'sum', 'sub'],
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: lift,
      builder: (context, _) {
        final binning = lift.isMovingPlaced;

        return DragTarget<DragPayload>(
          // Only a command that is already in the program. One dragged out of
          // here has nothing to delete yet, so dropping it back is a cancel.
          onWillAcceptWithDetails: (d) => d.data is MoveNode,
          onAcceptWithDetails: (d) => onTrash((d.data as MoveNode).id),
          // The same surface the program is written on, raised above it. It
          // was a translucent scrim, which is what something laid *over* a page
          // has to be; sitting beside the page instead, it is simply the page.
          builder: (context, candidate, rejected) => Container(
            color: Paper.sheet,
            // Even top and bottom. The note used to sit on the bottom edge
            // of the screen, so it carried the system's gesture area and a
            // deep foot to keep the last row of buttons off a rounded corner.
            // It is under the divider now, with the page below it: both of
            // those are gone, and what is left is a strip that wants the same
            // air on both sides.
            // No top padding: the air above the first command is the white
            // the divider leaves below its handle, and this surface is a
            // continuation of that one. See [Paper.trayAir].
            padding: const EdgeInsets.fromLTRB(
              Paper.noteSidePad,
              0,
              Paper.noteSidePad,
              Paper.trayAir,
            ),
            // The note keeps its exact height in both states. Resizing it would
            // reflow the page in the middle of a drag, which is the one moment
            // the player is tracking a moving object.
            child: Stack(
              children: [
                Opacity(opacity: binning ? 0 : 1, child: _buttons()),
                if (binning)
                  Positioned.fill(child: _Bin(armed: candidate.isNotEmpty)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buttons() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final row in _rows) ...[
        if (row != _rows.first) const SizedBox(height: 4),
        // IntrinsicHeight gives the row a height to stretch into: without it,
        // stretch asks for infinity inside a Column sizing to its children.
        // Stretch is what keeps the buttons in a row the same height as each
        // other, which they no longer get from being the same width.
        IntrinsicHeight(
          child: Row(
            // Each button is as wide as its own word, with equal air between
            // them *and* at both ends. They used to be [Expanded] - every
            // button in a row the same width - which made SUM as wide as COPY
            // FROM and read as a keypad. A word's own width is a better handle
            // on it.
            //
            // Evenly rather than between: `between` pins the first and last
            // words hard against the note's edges, so a row of five and a row
            // of four line up at their ends and nowhere else, and the gaps
            // differ between the two rows. Evenly gives the shelf one rhythm.
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final id in row)
                // Loose, which is the whole trick: a button takes its natural
                // width when the row has room and is squeezed only when it has
                // not - and [_Face] scales its word down rather than clipping
                // it. Natural width alone overflows, because nothing bounds the
                // sum of nine words: a narrow phone, a long label, or the 1.3x
                // the chrome still scales to are each enough.
                Flexible(
                  child: _Button(
                    spec: specFor(id),
                    lift: lift,
                    autoScroll: autoScroll,
                  ),
                ),
            ],
          ),
        ),
      ],
    ],
  );
}

/// The note in its other state.
class _Bin extends StatelessWidget {
  const _Bin({required this.armed});

  /// Something is being held over it.
  final bool armed;

  @override
  Widget build(BuildContext context) => Center(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(26, 30),
          painter: _TrashCan(armed ? Paper.binArmed : Paper.binIdle),
        ),
        const SizedBox(width: 12),
        Text(
          'DROP TO REMOVE',
          style: Paper.command.copyWith(
            fontSize: 17,
            color: armed ? Paper.binArmed : Paper.binIdle,
          ),
        ),
      ],
    ),
  );
}

/// Drawn as a path. No assets.
class _TrashCan extends CustomPainter {
  const _TrashCan(this.colour);

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final lid = h * 0.22;

    // Lid, and the little handle on top of it.
    canvas.drawLine(Offset(0, lid), Offset(w, lid), stroke);
    canvas.drawLine(
      Offset(w * 0.36, lid * 0.4),
      Offset(w * 0.64, lid * 0.4),
      stroke,
    );

    // The can: two sides tapering in, and a base.
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.12, lid)
        ..lineTo(w * 0.2, h)
        ..lineTo(w * 0.8, h)
        ..lineTo(w * 0.88, lid),
      stroke,
    );

    // Two slots down the front.
    for (final x in [w * 0.38, w * 0.62]) {
      canvas.drawLine(Offset(x, lid + 6), Offset(x, h - 5), stroke);
    }
  }

  @override
  bool shouldRepaint(_TrashCan old) => old.colour != colour;
}

/// One command, waiting to be picked up.
class _Button extends StatelessWidget {
  const _Button({
    required this.spec,
    required this.lift,
    required this.autoScroll,
  });

  final CommandSpec spec;
  final LiftState lift;
  final AutoScroller autoScroll;

  @override
  Widget build(BuildContext context) {
    final face = _Face(spec: spec);

    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: '${spec.label}, drag into the program',
      child: Draggable<DragPayload>(
        data: NewCommand(spec.id),
        // No hold: the note exists to be picked from, and there is nothing to
        // scroll underneath it. Vertical affinity, so a command comes away when
        // the finger goes *up* towards the program rather than along the shelf.
        affinity: Axis.vertical,
        onDragStarted: () => lift.lift(NewCommand(spec.id)),
        onDragUpdate: (d) => autoScroll.update(d.globalPosition),
        onDragEnd: (_) {
          autoScroll.stop();
          lift.drop();
        },
        onDraggableCanceled: (_, _) {
          autoScroll.stop();
          lift.drop();
        },
        feedback: Opacity(
          opacity: 0.92,
          child: Material(color: Colors.transparent, child: face),
        ),
        // The shelf keeps its full row while one is in the air: a gap opening
        // in it would be a second thing moving at once.
        childWhenDragging: Opacity(opacity: 0.4, child: face),
        child: face,
      ),
    );
  }
}

/// The button as it sits on the note: the same colour and the same shape as the
/// thing it becomes, so the note reads as a shelf of exactly what you are about
/// to place.
class _Face extends StatelessWidget {
  const _Face({required this.spec});

  final CommandSpec spec;

  @override
  Widget build(BuildContext context) => Panel(
    fill: spec.colour,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Center(
        widthFactor: 1,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            spec.trayLabel,
            // Smaller than the program's own rows, and smaller than the 17
            // that 7.3 sets as the floor for functional text. Deliberate: the
            // tray is a shelf of things to pick up, read at a glance rather
            // than followed line by line. The program itself keeps 17 and up.
            style: Paper.command.copyWith(fontSize: 15),
            maxLines: 1,
          ),
        ),
      ),
    ),
  );
}
