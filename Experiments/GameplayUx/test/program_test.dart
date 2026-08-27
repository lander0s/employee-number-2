// Model tests. The block-aware editing operations are the part of this
// experiment most likely to be subtly wrong, and they are pure Dart, so they
// get checked here rather than by eye.
import 'package:flutter_test/flutter_test.dart';
import 'package:gameplay_ux/model/commands.dart';
import 'package:gameplay_ux/model/program.dart';

/// A compact readable rendering of the program, for asserting structure.
String render(ProgramDocument doc) => doc
    .flatten()
    .map(
      (r) =>
          '${'  ' * r.depth}${switch (r.kind) {
            RowKind.blockCloser => 'END',
            _ => r.node.text,
          }}',
    )
    .join('\n');

void main() {
  group('insertion', () {
    test('a block is inserted with its closer, and a drop lands inside', () {
      final doc = ProgramDocument();
      doc.insert('repeat');
      final repeat = doc.root.first;

      // Every insertion names its own slot: there is no stored position that
      // quietly advances into the block just created.
      doc.insertAt('take', Slot(repeat.id, 0, 1));

      expect(render(doc), 'REPEAT\n  TAKE\nEND');
    });

    test('nesting a block inside a block', () {
      final doc = ProgramDocument();
      doc.insert('repeat');
      final repeat = doc.root.first;

      doc.insertAt('take', Slot(repeat.id, 0, 1));
      doc.insertAt('ifCond', Slot(repeat.id, 1, 1));
      doc.insertAt('ship', Slot(repeat.children![1].id, 0, 2));

      expect(
        render(doc),
        'REPEAT\n  TAKE\n  IF EQUALS ZERO\n    SHIP\n  END\nEND',
      );
      expect(doc.maxDepth, 3);
    });

    test('a drop at the front of a list goes in front', () {
      final doc = ProgramDocument();
      doc.insert('take');
      doc.insertAt('ship', const Slot(null, 0, 0));

      expect(render(doc), 'SHIP\nTAKE');
    });

    test('SIZE counts commands and headers but not closers', () {
      final doc = ProgramDocument()..loadSample();
      // REPEAT, TAKE, IF TYPE IS, SHIP = 4 commands; 6 rendered rows.
      expect(doc.size, 4);
      expect(doc.rowCount, 6);
    });
  });

  group('drag reorder', () {
    test('moving a block carries its whole body', () {
      final doc = ProgramDocument()..loadSample();
      final repeat = doc.root.first;
      final ifNode = repeat.children![1];

      // Drag the IF out of the REPEAT, to the end of the program.
      final ok = doc.move(ifNode.id, Slot(null, 1, 0));

      expect(ok, isTrue);
      expect(
        render(doc),
        'REPEAT\n  TAKE\nEND\nIF GREATER THAN ZERO\n  SHIP\nEND',
      );
    });

    test('a block cannot be dropped inside its own body', () {
      final doc = ProgramDocument()..loadSample();
      final repeat = doc.root.first;
      final ifNode = repeat.children![1];

      // Try to drop the REPEAT into the IF that lives inside it.
      expect(doc.move(repeat.id, Slot(ifNode.id, 0, 0)), isFalse);
      expect(doc.contains(repeat.id, ifNode.id), isTrue);
      expect(doc.contains(ifNode.id, repeat.id), isFalse);
    });

    test('reordering within the same list does not lose the node', () {
      final doc = ProgramDocument();
      doc.insert('take');
      doc.insert('ship');
      doc.insert('sum');
      expect(render(doc), 'TAKE\nSHIP\nSUM PALLET 1');

      // Move the first row to the end.
      final take = doc.root.first;
      doc.move(take.id, const Slot(null, 3, 0));
      expect(render(doc), 'SHIP\nSUM PALLET 1\nTAKE');
    });

    test('moving into an empty block body works', () {
      final doc = ProgramDocument();
      doc.insert('take');
      doc.insert('repeat');
      expect(render(doc), 'TAKE\nREPEAT\nEND');

      final repeat = doc.root[1];
      doc.move(doc.root.first.id, Slot(repeat.id, 0, 1));
      expect(render(doc), 'REPEAT\n  TAKE\nEND');
    });
  });

  group('delete', () {
    test('deleting a block removes its body with it', () {
      final doc = ProgramDocument()..loadSample();
      doc.delete(doc.root.first.id);
      expect(doc.root, isEmpty);
    });

    test('keepContents splices the body into the block position', () {
      final doc = ProgramDocument()..loadSample();
      doc.delete(doc.root.first.id, keepContents: true);
      expect(render(doc), 'TAKE\nIF GREATER THAN ZERO\n  SHIP\nEND');
    });
  });

  group('undo', () {
    test('undo restores structure and redo reapplies it', () {
      final doc = ProgramDocument()..loadSample();
      final before = render(doc);

      doc.insert('sub');
      expect(render(doc), isNot(before));

      doc.undo();
      expect(render(doc), before);

      doc.redo();
      expect(render(doc), isNot(before));
    });

    test('undo survives a move', () {
      final doc = ProgramDocument()..loadSample();
      final before = render(doc);
      final ifNode = doc.root.first.children![1];

      doc.move(ifNode.id, Slot(null, 1, 0));
      doc.undo();
      expect(render(doc), before);
    });
  });

  group('arguments', () {
    test('a new pallet command pre-fills with the last used pallet', () {
      final doc = ProgramDocument();
      doc.insert('copyTo');
      final first = doc.root.first;

      doc.cycleArg(first.id);
      doc.cycleArg(first.id);
      expect(first.palletArg, 3);
      expect(doc.lastUsedPallet, 3);

      doc.insert('copyFrom');
      expect(doc.root[1].palletArg, 3);
    });

    test('every command that takes a pallet cycles the same way', () {
      // COPY TO, COPY FROM, SUM and SUB all address the same numbered floor, so
      // they are one control with one behaviour rather than four.
      for (final id in ['copyTo', 'copyFrom', 'sum', 'sub']) {
        final doc = ProgramDocument();
        doc.insert(id);
        final node = doc.root.first;

        expect(node.palletArg, 1);
        for (var expected = 2; expected < palletCount; expected++) {
          doc.cycleArg(node.id);
          expect(node.palletArg, expected, reason: id);
        }
        doc.cycleArg(node.id);
        expect(node.palletArg, 0, reason: '$id wraps back to the first pallet');
      }
    });

    test('cycling an argument is undoable', () {
      final doc = ProgramDocument();
      doc.insert('sum');
      final node = doc.root.first;
      final before = node.palletArg;

      doc.cycleArg(node.id);
      expect(node.palletArg, isNot(before));

      doc.undo();
      expect(doc.root.first.palletArg, before);
    });

    test(
      'cycling a command with no argument does nothing and is not undoable',
      () {
        final doc = ProgramDocument();
        doc.insert('take');
        final canUndoBefore = doc.canUndo;

        doc.cycleArg(doc.root.first.id);

        // A no-op must not leave an undo entry for an edit that never happened.
        expect(doc.canUndo, canUndoBefore);
      },
    );
  });

  group('slots', () {
    test('every child list exposes a trailing insertion slot', () {
      final doc = ProgramDocument()..loadSample();
      final slots = doc.flattenWithSlots().whereType<Slot>().toList();

      final repeat = doc.root.first;
      final ifNode = repeat.children![1];

      // Root: before REPEAT and after it.
      expect(slots.where((s) => s.parentId == null).length, 2);
      // REPEAT body: before TAKE, before IF, after IF.
      expect(slots.where((s) => s.parentId == repeat.id).length, 3);
      // IF body: before SHIP, after SHIP.
      expect(slots.where((s) => s.parentId == ifNode.id).length, 2);
    });
  });

  group('condition grammar', () {
    test('the comparison cycles and wraps, and zero never moves', () {
      final doc = ProgramDocument();
      doc.insert('ifCond');
      final node = doc.root.first;

      // One cyclable segment. The old grammar had three - a subject, a
      // comparator and an object - because a package had a type and a weight to
      // ask about. A package is a number now, so the only question worth asking
      // is how it stands against zero.
      expect(node.chips, hasLength(1));
      expect(node.text, 'IF EQUALS ZERO');

      doc.cycleArg(node.id, ArgSlot.comparator);
      expect(node.text, 'IF GREATER THAN ZERO');

      doc.cycleArg(node.id, ArgSlot.comparator);
      expect(node.text, 'IF LESS THAN ZERO');

      doc.cycleArg(node.id, ArgSlot.comparator);
      expect(node.text, 'IF EQUALS ZERO', reason: 'wraps');
    });

    test('every comparison renders a legal sentence', () {
      final doc = ProgramDocument();
      doc.insert('ifCond');
      final node = doc.root.first;

      for (var i = 0; i < comparators.length; i++) {
        expect(comparators, contains(node.comparator));
        expect(node.text, startsWith('IF '));
        expect(node.text, endsWith(' ZERO'));
        doc.cycleArg(node.id, ArgSlot.comparator);
      }
    });

    test('the three comparisons cover the branch an ELSE was for', () {
      // Without an else, acting on the complement of a condition has to be
      // expressible. Equal, greater and less partition the number line, so it
      // always is.
      expect(comparators, hasLength(3));
      expect(comparators, containsAll(['EQUALS', 'GREATER THAN', 'LESS THAN']));
    });
  });

  group('no else branch', () {
    test('a block has exactly one body', () {
      final doc = ProgramDocument();
      doc.insert('ifCond');
      final node = doc.root.first;

      // ELSE is gone: no second child list, and no branch dimension on a Slot.
      expect(node.children, isNotNull);
      final slots = doc.flattenWithSlots().whereType<Slot>();
      expect(
        slots.where((s) => s.parentId == node.id).length,
        1,
        reason: 'one empty body means exactly one insertion slot',
      );
    });
  });
}
