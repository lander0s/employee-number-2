/// The program document: a tree of nodes, flattened for display.
///
/// A tree rather than a flat row list, because every interesting editor
/// operation is a subtree operation. Dragging a `REPEAT` has to carry its body;
/// deleting one has to offer to keep its contents. Both are trivial on a tree
/// and fiddly on a flat list with span bookkeeping.
library;

import 'commands.dart';

int _nextId = 1;
String _newId() => 'n${_nextId++}';

/// What a drag is carrying.
///
/// Two intents land on the same targets: a command taken from the tray, and a
/// node already in the program being moved. Keeping them in one type means a
/// spacer has exactly one drop handler rather than two overlapping ones.
sealed class DragPayload {
  const DragPayload();
}

/// A command dragged out of the tray, to be inserted.
class NewCommand extends DragPayload {
  const NewCommand(this.commandId);
  final String commandId;
}

/// A node already in the program, to be moved.
class MoveNode extends DragPayload {
  const MoveNode(this.id);
  final String id;
}

/// Which cyclable segment of a row is being addressed. A row carries at most
/// one of each: a condition has a comparator, everything else with an argument
/// has an object.
enum ArgSlot { comparator, object }

/// One cyclable word in a row, in reading order.
class ArgChip {
  const ArgChip(this.slot, this.text);

  final ArgSlot slot;
  final String text;
}

/// One instruction, or one block with its body.
class Node {
  Node({
    required this.commandId,
    String? id,
    this.palletArg = 1,
    this.comparator = 'ZERO',
    List<Node>? children,
  }) : id = id ?? _newId(),
       children = children ?? (specFor(commandId).isBlock ? <Node>[] : null);

  final String id;
  final String commandId;

  int palletArg;

  /// The comparison an IF makes against zero. Unused by every other command.
  String comparator;

  /// Body of a block. Null for plain commands.
  List<Node>? children;

  CommandSpec get spec => specFor(commandId);
  bool get isBlock => spec.isBlock;

  /// Deep copy that preserves ids - used for undo snapshots, where identity has
  /// to survive so an in-flight drag still refers to a real node.
  Node cloneKeepingIds() => Node(
    id: id,
    commandId: commandId,
    palletArg: palletArg,
    comparator: comparator,
    children: children?.map((c) => c.cloneKeepingIds()).toList(),
  );

  /// The cyclable words this row carries, in reading order.
  List<ArgChip> get chips => switch (spec.argKind) {
    ArgKind.none => const [],
    ArgKind.pallet => [ArgChip(ArgSlot.object, 'PALLET $palletArg')],
    ArgKind.condition => [ArgChip(ArgSlot.comparator, comparator)],
  };

  /// The whole row as one line of text. For traces and tests.
  String get text => [spec.label, ...chips.map((c) => c.text)].join(' ');
}

/// Which slot a row occupies. Closers are rendered but are not commands: they
/// are free for SIZE purposes (see level-04-briefing 5.1).
enum RowKind { command, blockHeader, blockCloser }

/// A flattened row, ready to render.
class DisplayRow {
  DisplayRow({required this.node, required this.kind, required this.depth});

  final Node node;
  final RowKind kind;
  final int depth;

  bool get isCloser => kind == RowKind.blockCloser;
  bool get isDraggable =>
      kind == RowKind.command || kind == RowKind.blockHeader;
}

/// An unambiguous insertion point: a specific index in a specific child list.
///
/// Deriving the parent from a flat row index is ambiguous at block boundaries
/// (is "after the last child" inside the block or after it?), so slots are
/// generated explicitly during flattening instead.
class Slot {
  const Slot(this.parentId, this.index, this.depth);

  /// Null parent means the program root.
  final String? parentId;

  final int index;
  final int depth;

  @override
  bool operator ==(Object other) =>
      other is Slot && other.parentId == parentId && other.index == index;

  @override
  int get hashCode => Object.hash(parentId, index);
}

class ProgramDocument {
  ProgramDocument();

  List<Node> root = <Node>[];

  final List<_Snapshot> _undo = [];
  final List<_Snapshot> _redo = [];

  int lastUsedPallet = 1;

  // ---------------------------------------------------------------- flattening

  List<DisplayRow> flatten() {
    final rows = <DisplayRow>[];

    void walk(List<Node> nodes, int depth) {
      for (final node in nodes) {
        if (node.isBlock) {
          rows.add(
            DisplayRow(node: node, kind: RowKind.blockHeader, depth: depth),
          );
          walk(node.children!, depth + 1);
          rows.add(
            DisplayRow(node: node, kind: RowKind.blockCloser, depth: depth),
          );
        } else {
          rows.add(DisplayRow(node: node, kind: RowKind.command, depth: depth));
        }
      }
    }

    walk(root, 0);
    return rows;
  }

  /// Interleaved rows and drop slots, in render order.
  ///
  /// Every child list contributes a slot before each of its children and one
  /// after the last, so every legal insertion point - including empty block
  /// bodies - is reachable.
  List<Object> flattenWithSlots() {
    final out = <Object>[];

    void walk(List<Node> nodes, String? parentId, int depth) {
      for (var i = 0; i < nodes.length; i++) {
        out.add(Slot(parentId, i, depth));
        final node = nodes[i];
        if (node.isBlock) {
          out.add(
            DisplayRow(node: node, kind: RowKind.blockHeader, depth: depth),
          );
          walk(node.children!, node.id, depth + 1);
          out.add(
            DisplayRow(node: node, kind: RowKind.blockCloser, depth: depth),
          );
        } else {
          out.add(DisplayRow(node: node, kind: RowKind.command, depth: depth));
        }
      }
      out.add(Slot(parentId, nodes.length, depth));
    }

    walk(root, null, 0);
    return out;
  }

  /// SIZE: command rows and block headers cost 1; closers are free.
  int get size {
    var n = 0;
    void walk(List<Node> nodes) {
      for (final node in nodes) {
        n++;
        if (node.children != null) walk(node.children!);
      }
    }

    walk(root);
    return n;
  }

  int get rowCount => flatten().length;

  int get maxDepth {
    var deepest = 0;
    void walk(List<Node> nodes, int depth) {
      for (final node in nodes) {
        if (depth > deepest) deepest = depth;
        if (node.children != null) walk(node.children!, depth + 1);
      }
    }

    walk(root, 1);
    return deepest;
  }

  // ------------------------------------------------------------------ lookups

  List<Node> _listFor(String? parentId) {
    if (parentId == null) return root;
    final parent = _find(root, parentId);
    return parent?.children ?? root;
  }

  Node? _find(List<Node> nodes, String id) {
    for (final node in nodes) {
      if (node.id == id) return node;
      if (node.children != null) {
        final hit = _find(node.children!, id);
        if (hit != null) return hit;
      }
    }
    return null;
  }

  Node? nodeById(String id) => _find(root, id);

  /// True when [ancestorId] is [descendantId], or contains it. Used to reject
  /// dropping a block inside its own body.
  bool contains(String ancestorId, String descendantId) {
    if (ancestorId == descendantId) return true;
    final ancestor = nodeById(ancestorId);
    if (ancestor == null) return false;
    return _find(ancestor.children ?? const [], descendantId) != null;
  }

  /// The list holding [id], plus its index in that list.
  ({List<Node> list, int index})? _locate(String id) {
    ({List<Node> list, int index})? search(List<Node> nodes) {
      for (var i = 0; i < nodes.length; i++) {
        if (nodes[i].id == id) return (list: nodes, index: i);
        if (nodes[i].children != null) {
          final hit = search(nodes[i].children!);
          if (hit != null) return hit;
        }
      }
      return null;
    }

    return search(root);
  }

  // ------------------------------------------------------------------- editing

  /// Inserts [commandId] at [slot].
  ///
  /// Every insertion names its own place. There is no stored insertion point to
  /// keep in sync, because a drop already knows exactly where it landed.
  void insertAt(String commandId, Slot slot) {
    _push();
    final spec = specFor(commandId);
    final node = Node(
      commandId: commandId,
      palletArg: spec.argKind == ArgKind.pallet ? lastUsedPallet : 1,
    );
    final list = _listFor(slot.parentId);
    list.insert(slot.index.clamp(0, list.length), node);
  }

  /// Appends to the end of the program. Used by tests and the sample loader.
  void insert(String commandId) =>
      insertAt(commandId, Slot(null, root.length, 0));

  /// Deletes [id]. When it is a block, [keepContents] splices its body into the
  /// block's place instead of deleting it with the block.
  void delete(String id, {bool keepContents = false}) {
    _push();
    final at = _locate(id);
    if (at == null) return;
    final node = at.list[at.index];
    at.list.removeAt(at.index);
    if (keepContents && node.isBlock) {
      at.list.insertAll(at.index, node.children!);
    }
  }

  /// Moves [id] into [slot]. Rejected when the slot is inside the moved node.
  bool move(String id, Slot slot) {
    if (slot.parentId != null && contains(id, slot.parentId!)) return false;
    _push();
    final at = _locate(id);
    if (at == null) return false;

    final target = _listFor(slot.parentId);
    var index = slot.index;

    // Removing first would shift the target index when both are in the same
    // list, so compensate before splicing.
    if (identical(target, at.list) && at.index < index) index -= 1;

    final node = at.list.removeAt(at.index);
    target.insert(index.clamp(0, target.length), node);
    return true;
  }

  /// Advances one segment of a row's argument to its next value, wrapping.
  ///
  /// One gesture for every argument, and for every segment of a condition.
  void cycleArg(String id, [ArgSlot slot = ArgSlot.object]) {
    final node = nodeById(id);
    if (node == null || node.spec.argKind == ArgKind.none) return;

    // Checks first, then _push: bailing out after pushing would leave an undo
    // entry for an edit that never happened.
    _push();

    switch (slot) {
      case ArgSlot.comparator:
        _cycleComparator(node);
      case ArgSlot.object:
        _cycleObject(node);
    }
  }

  void _cycleComparator(Node node) {
    if (node.spec.argKind != ArgKind.condition) return;
    final i = comparators.indexOf(node.comparator);
    node.comparator = comparators[(i + 1) % comparators.length];
  }

  /// The pallet an argument points at. One cycle, wrapping, for every command
  /// that takes one - COPY TO, COPY FROM, SUM and SUB all address the same
  /// numbered floor.
  void _cycleObject(Node node) {
    if (node.spec.argKind != ArgKind.pallet) return;
    node.palletArg = (node.palletArg + 1) % palletCount;
    lastUsedPallet = node.palletArg;
  }

  // ------------------------------------------------------------ undo and redo

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void _push() {
    _undo.add(_snapshot());
    _redo.clear();
    if (_undo.length > 200) _undo.removeAt(0);
  }

  _Snapshot _snapshot() =>
      _Snapshot(root.map((n) => n.cloneKeepingIds()).toList());

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(_snapshot());
    root = _undo.removeLast().root;
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(_snapshot());
    root = _redo.removeLast().root;
  }

  void clear() {
    _push();
    root = <Node>[];
  }

  /// Level 4's reference solution, for checking the editor against a program
  /// we already know how we want to read.
  void loadSample() {
    _push();
    final ifNode = Node(
      commandId: 'ifCond',
      comparator: 'POSITIVE',
      children: [Node(commandId: 'ship')],
    );
    root = <Node>[
      Node(
        commandId: 'repeat',
        children: [
          Node(commandId: 'take'),
          ifNode,
        ],
      ),
    ];
  }
}

class _Snapshot {
  _Snapshot(this.root);
  final List<Node> root;
}
