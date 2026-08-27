/// The command catalogue for the experiment: Act 1-3 vocabulary.
///
/// See GameDesign/game-design-document.md 6.3. Two deliberate departures:
///
/// - No `IF INTAKE IS EMPTY` (6.6): termination is implicit.
/// - No `ELSE`. A condition carries its own negation (`IS NOT`) as one position
///   in the comparator cycle, which covers what an else branch was for without a
///   second block body, a toggle on every IF row, or a branch dimension running
///   through the whole document model.
library;

import 'dart:ui' show Color;

enum ArgKind {
  /// No argument.
  none,

  /// A pallet index.
  pallet,

  /// A three-part condition: subject, comparator, object.
  condition,
}

/// A command the tray can insert. Block commands (`REPEAT`, `IF`) are inserted
/// as a matched pair with their closer - unbalanced programs are unauthorable.
class CommandSpec {
  const CommandSpec({
    required this.id,
    required this.label,
    required this.trayLabel,
    required this.colour,
    this.argKind = ArgKind.none,
    this.isBlock = false,
  });

  final String id;

  /// The fixed part of the row, e.g. `MERGE WITH`. Cyclable values are appended
  /// by the row widget.
  final String label;

  /// Shorter form for the tray button, where horizontal space is scarce.
  final String trayLabel;

  final ArgKind argKind;
  final bool isBlock;

  /// Bright and cheerful first, then pulled back about a fifth of the way to
  /// grey. Starting from a dark, desaturated palette produced nine tones nobody
  /// could tell apart; starting from playdoh colours and stepping *down* leaves
  /// them obviously distinct - no two are closer than deltaE 23 - while keeping
  /// headroom to push saturation back up for the executing line.
  ///
  /// Every one clears 7.3's 7:1 floor against [W.ink], the dark text these
  /// fills are written in.
  final Color colour;

  bool get takesArg => argKind != ArgKind.none;
}

const packageTypes = <String>['BLUE', 'RED', 'GREEN'];
const weightStates = <String>['ZERO', 'NEGATIVE'];
const palletCount = 6;

// ---------------------------------------------------------- condition grammar

/// What the condition looks at. Every condition inspects the held package
/// (6.3) - nothing inspects the world.
const conditionSubjects = <String>['TYPE', 'WEIGHT'];

const _comparators = <String, List<String>>{
  'TYPE': ['IS', 'IS NOT', 'MATCHES'],
  'WEIGHT': ['IS', 'IS NOT', 'UNDER'],
};

List<String> comparatorsFor(String subject) =>
    _comparators[subject] ?? const ['IS'];

/// What the third segment holds, which depends on the first two.
enum ObjectKind { packageType, weightState, pallet }

ObjectKind objectKindFor(String subject, String comparator) {
  // `MATCHES` and `UNDER` compare against a pallet rather than a literal.
  if (comparator == 'MATCHES' || comparator == 'UNDER') {
    return ObjectKind.pallet;
  }
  return subject == 'TYPE' ? ObjectKind.packageType : ObjectKind.weightState;
}

/// Act 1-3. Ordered by expected frequency of use, not by unlock date - the
/// tray scrolls horizontally and the most-reached-for commands should never
/// require a scroll.
const commandCatalogue = <CommandSpec>[
  CommandSpec(
    id: 'take',
    label: 'TAKE',
    trayLabel: 'TAKE',
    colour: Color(0xFF4DCB6D), // green
  ),
  CommandSpec(
    id: 'ship',
    label: 'SHIP',
    trayLabel: 'SHIP',
    colour: Color(0xFFFF8275), // red
  ),

  CommandSpec(
    id: 'repeat',
    label: 'REPEAT',
    trayLabel: 'REPEAT',
    isBlock: true,
    colour: Color(0xFF5EAAFF), // blue
  ),
  CommandSpec(
    id: 'ifCond',
    label: 'IF',
    trayLabel: 'IF',
    argKind: ArgKind.condition,
    isBlock: true,
    colour: Color(0xFFFFD83D), // yellow
  ),

  CommandSpec(
    id: 'stackOn',
    label: 'STACK ON',
    trayLabel: 'STACK ON',
    argKind: ArgKind.pallet,
    colour: Color(0xFFFF963B), // orange
  ),
  CommandSpec(
    id: 'pickFrom',
    label: 'PICK FROM',
    trayLabel: 'PICK FROM',
    argKind: ArgKind.pallet,
    colour: Color(0xFFC98EFF), // purple
  ),

  CommandSpec(
    id: 'mergeWith',
    label: 'MERGE WITH',
    trayLabel: 'MERGE',
    argKind: ArgKind.pallet,
    colour: Color(0xFFFF78BC), // pink
  ),
  CommandSpec(
    id: 'stripBy',
    label: 'STRIP BY',
    trayLabel: 'STRIP',
    argKind: ArgKind.pallet,
    colour: Color(0xFF33EBFF), // cyan
  ),

  CommandSpec(
    id: 'clockOut',
    label: 'CLOCK OUT',
    trayLabel: 'CLOCK OUT',
    colour: Color(
      0xFFBBA498,
    ), // warm grey - the one that ends a shift stands apart
  ),
];

CommandSpec specFor(String id) =>
    commandCatalogue.firstWhere((c) => c.id == id);
