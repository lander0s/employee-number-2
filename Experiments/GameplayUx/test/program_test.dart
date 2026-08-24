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
    test('a block is inserted with its closer and the caret lands inside', () {
      final doc = ProgramDocument();
      doc.insert('repeat');
      doc.insert('take');

      expect(render(doc), 'REPEAT\n  TAKE\nEND');
    });

    test('nesting a block inside a block', () {
      final doc = ProgramDocument();
      doc.insert('repeat');
      doc.insert('take');
      doc.insert('ifCond');
      doc.insert('ship');

      expect(
        render(doc),
        'REPEAT\n  TAKE\n  IF TYPE IS BLUE\n    SHIP\n  END\nEND',
      );
      expect(doc.maxDepth, 3);
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
      expect(render(doc), 'REPEAT\n  TAKE\nEND\nIF TYPE IS BLUE\n  SHIP\nEND');
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
      doc.caret = const Slot(null, 0, 0);
      doc.insert('take');
      doc.insert('ship');
      doc.insert('clockOut');
      expect(render(doc), 'TAKE\nSHIP\nCLOCK OUT');

      // Move the first row to the end.
      final take = doc.root.first;
      doc.move(take.id, const Slot(null, 3, 0));
      expect(render(doc), 'SHIP\nCLOCK OUT\nTAKE');
    });

    test('moving into an empty block body works', () {
      final doc = ProgramDocument();
      doc.insert('take');
      doc.caret = const Slot(null, 1, 0);
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
      expect(render(doc), 'TAKE\nIF TYPE IS BLUE\n  SHIP\nEND');
    });
  });

  group('undo', () {
    test('undo restores structure and redo reapplies it', () {
      final doc = ProgramDocument()..loadSample();
      final before = render(doc);

      doc.insert('mergeWith');
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
      doc.insert('stackOn');
      final first = doc.root.first;

      doc.cycleArg(first.id);
      doc.cycleArg(first.id);
      expect(first.palletArg, 3);
      expect(doc.lastUsedPallet, 3);

      doc.caret = const Slot(null, 1, 0);
      doc.insert('pickFrom');
      expect(doc.root[1].palletArg, 3);
    });

    test('type argument cycles and wraps', () {
      final doc = ProgramDocument();
      doc.insert('ifCond');
      final node = doc.root.first;
      expect(node.typeArg, 'BLUE');
      doc.cycleArg(node.id);
      expect(node.typeArg, 'RED');
      doc.cycleArg(node.id);
      expect(node.typeArg, 'GREEN');
      doc.cycleArg(node.id);
      expect(node.typeArg, 'BLUE');
    });

    test('pallet argument cycles and wraps, like a type does', () {
      final doc = ProgramDocument();
      doc.insert('pickFrom');
      final node = doc.root.first;

      // Same gesture for both argument kinds: one control, one behaviour.
      expect(node.palletArg, 1);
      for (var expected = 2; expected < palletCount; expected++) {
        doc.cycleArg(node.id);
        expect(node.palletArg, expected);
      }
      doc.cycleArg(node.id);
      expect(node.palletArg, 0, reason: 'wraps back to the first pallet');
      expect(doc.lastUsedPallet, 0);
    });

    test('cycling an argument is undoable', () {
      final doc = ProgramDocument();
      doc.insert('mergeWith');
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
    Node ifNode(ProgramDocument doc) => doc.root.first;

    test('every segment cycles independently', () {
      final doc = ProgramDocument();
      doc.insert('ifCond');
      final node = ifNode(doc);

      expect(node.text, 'IF TYPE IS BLUE');

      doc.cycleArg(node.id, ArgSlot.object);
      expect(node.text, 'IF TYPE IS RED');

      doc.cycleArg(node.id, ArgSlot.comparator);
      expect(
        node.text,
        'IF TYPE IS NOT RED',
        reason: 'IS NOT is what replaces ELSE, and it keeps the object',
      );

      doc.cycleArg(node.id, ArgSlot.subject);
      expect(node.text, 'IF WEIGHT IS NOT ZERO');
    });

    test('the comparator cycle carries the negation of every condition', () {
      final doc = ProgramDocument();
      doc.insert('ifCond');
      final node = ifNode(doc);

      // Without an ELSE branch, `IS NOT` is the only way to act on the
      // complement of a condition, so it has to exist for both subjects.
      expect(comparatorsFor('TYPE'), contains('IS NOT'));
      expect(comparatorsFor('WEIGHT'), contains('IS NOT'));

      doc.cycleArg(node.id, ArgSlot.subject);
      expect(node.subject, 'WEIGHT');
      doc.cycleArg(node.id, ArgSlot.comparator);
      expect(node.comparator, 'IS NOT');
    });

    test(
      'cycling the comparator keeps the object when its kind is unchanged',
      () {
        final doc = ProgramDocument();
        doc.insert('ifCond');
        final node = ifNode(doc);

        doc.cycleArg(node.id, ArgSlot.object);
        doc.cycleArg(node.id, ArgSlot.object);
        expect(node.typeArg, 'GREEN');

        // IS -> IS NOT: still comparing against a package type.
        doc.cycleArg(node.id, ArgSlot.comparator);
        expect(node.text, 'IF TYPE IS NOT GREEN');
      },
    );

    test('cycling into a different object kind resets the object', () {
      final doc = ProgramDocument();
      doc.insert('ifCond');
      final node = ifNode(doc);

      // IS -> IS NOT -> MATCHES, which compares against a pallet instead.
      doc.cycleArg(node.id, ArgSlot.comparator);
      doc.cycleArg(node.id, ArgSlot.comparator);
      expect(node.comparator, 'MATCHES');
      expect(node.objectKind, ObjectKind.pallet);
      expect(node.text, 'IF TYPE MATCHES PALLET 1');
    });

    test('a WEIGHT condition never keeps a TYPE-only comparator', () {
      final doc = ProgramDocument();
      doc.insert('ifCond');
      final node = ifNode(doc);

      doc.cycleArg(node.id, ArgSlot.comparator);
      doc.cycleArg(node.id, ArgSlot.comparator);
      doc.cycleArg(node.id, ArgSlot.subject);

      expect(comparatorsFor(node.subject), contains(node.comparator));
    });

    test('every reachable condition renders a legal sentence', () {
      final doc = ProgramDocument();
      doc.insert('ifCond');
      final node = ifNode(doc);

      // Walk the whole space and assert nothing renders an impossible pairing.
      for (var s = 0; s < conditionSubjects.length; s++) {
        for (var c = 0; c < 4; c++) {
          for (var o = 0; o < 7; o++) {
            expect(comparatorsFor(node.subject), contains(node.comparator));
            expect(node.text.startsWith('IF '), isTrue);
            expect(node.chips.length, 3);
            doc.cycleArg(node.id, ArgSlot.object);
          }
          doc.cycleArg(node.id, ArgSlot.comparator);
        }
        doc.cycleArg(node.id, ArgSlot.subject);
      }
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
