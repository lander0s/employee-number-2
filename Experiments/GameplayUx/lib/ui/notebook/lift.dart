/// Picking things up, and what happens while they are in the air.
///
/// Two pieces, both shared between the page and the note, because a drag that
/// starts on one of them routinely ends on the other:
///
/// - [LiftState]: what is currently held. The note watches it, because a
///   *placed* command in the air turns the note into a bin.
/// - [AutoScroller]: the page scrolls itself while something is held near an
///   edge, whichever surface the drag started from.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../model/program.dart';
import 'tokens.dart';

/// What is in the air, if anything.
///
/// A `ChangeNotifier` rather than a callback pair because two widgets that are
/// siblings both need to know, and neither owns the other.
class LiftState extends ChangeNotifier {
  DragPayload? _held;

  DragPayload? get held => _held;
  bool get isEmpty => _held == null;

  /// True only while a command that is *already in the program* is held. This
  /// is the condition for the note to become a bin: a command dragged out of
  /// the note has nothing to delete yet, so dropping it back is a cancel.
  bool get isMovingPlaced => _held is MoveNode;

  void lift(DragPayload payload) {
    if (_held == payload) return;
    _held = payload;
    notifyListeners();
  }

  void drop() {
    if (_held == null) return;
    _held = null;
    notifyListeners();
  }
}

/// Scrolls the page while something is held near its top or bottom edge.
///
/// Owned by the screen rather than by the page, so a command carried up out of
/// the note gets the same behaviour as a row being moved within the program.
/// The expectation is the same either way: holding at the edge of a list should
/// bring the rest of it into view.
class AutoScroller {
  AutoScroller({required this.controller, required this.visiblePage});

  final ScrollController controller;

  /// The part of the page a finger can actually reach, in global coordinates.
  /// Not the pane's box: the note lies over its bottom edge, and an edge zone
  /// nobody can reach is not one.
  final Rect Function() visiblePage;

  Timer? _ticker;

  void update(Offset globalPosition) {
    _ticker?.cancel();

    final page = visiblePage();
    if (page.height <= 0) return;

    // Capped, or a short pane is all edge and has no neutral middle.
    final zone = math.min(Paper.edgeZone, page.height / 4);
    final y = globalPosition.dy - page.top;

    final double direction;
    final double into; // 0 at the inner boundary, 1 at the very edge
    if (y < zone) {
      direction = -1;
      into = (zone - y) / zone;
    } else if (y > page.height - zone) {
      direction = 1;
      into = (y - (page.height - zone)) / zone;
    } else {
      return;
    }

    final speed =
        Paper.edgeSlow +
        (Paper.edgeFast - Paper.edgeSlow) * into.clamp(0.0, 1.0);

    _ticker = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!controller.hasClients) return stop();
      final next = (controller.offset + direction * speed).clamp(
        0.0,
        controller.position.maxScrollExtent,
      );
      // Nothing left in that direction: stop rather than tick against the end.
      if (next == controller.offset) return stop();
      controller.jumpTo(next);
    });
  }

  void stop() {
    _ticker?.cancel();
    _ticker = null;
  }

  void dispose() => stop();
}
