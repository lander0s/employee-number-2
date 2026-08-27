/// The command catalogue for the experiment.
///
/// **A package is a number.** Nothing else. There are no types, no colours, no
/// weights, no stacking and no merging: the vocabulary below is Human Resource
/// Machine's, near enough, because that vocabulary is *known to make good
/// puzzles*. Arithmetic and comparison are where the interesting levels live -
/// sorting, counting, running totals, min and max - and a language without them
/// can only ask the player to filter and forward.
///
/// The AmaCorp fiction is unchanged; only what is written on the boxes changed.
/// Anything more inventive gets proposed on top of a game that is already fun,
/// not instead of one.
///
/// Two deliberate departures from GameDesign/game-design-document.md 6.3 remain:
///
/// - No `IF INTAKE IS EMPTY` (6.6): termination is implicit.
/// - No `ELSE`. The three comparisons cover the branch an else was for without a
///   second block body, a toggle on every IF row, or a branch dimension running
///   through the whole document model.
library;

import 'dart:ui' show Color;

enum ArgKind {
  /// No argument.
  none,

  /// A pallet index: the numbered floor spots a package can be copied to or
  /// from, and the operands of SUM and SUB.
  pallet,

  /// A comparison against zero.
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
    this.tail,
    this.argKind = ArgKind.none,
    this.isBlock = false,
  });

  final String id;

  /// The fixed part of the row, e.g. `COPY FROM`. Cyclable values are appended
  /// by the row widget.
  final String label;

  /// A fixed word *after* the cyclable value, for rows that read as a sentence
  /// around their argument: `IF [GREATER THAN] ZERO`. Zero is the only thing a
  /// condition ever compares against, so it is a keyword and not a chip - there
  /// is nothing to cycle it to.
  final String? tail;

  /// Shorter form for the tray button, where horizontal space is scarce.
  final String trayLabel;

  final ArgKind argKind;
  final bool isBlock;

  /// **Related commands share a colour.** Colour names the family, not the
  /// command: what a player needs at a glance is "this is a movement, that is
  /// arithmetic", and the word says which one. Five families, five colours.
  ///
  /// Every one clears 7.3's 7:1 floor against the dark ink these fills are
  /// written in, and no two families are closer than deltaE 20.
  final Color colour;

  bool get takesArg => argKind != ArgKind.none;
}

/// The numbered floor spots. HRM calls them tiles; the warehouse calls them
/// pallets.
const palletCount = 6;

// ---------------------------------------------------------- condition grammar

/// The comparison an IF or a REPEAT WHILE makes against zero, and the only
/// cyclable part of it.
///
/// Worded so the row reads as English with `ZERO` after it. `EQUALS THAN ZERO`
/// was the obvious first cut and is not a sentence.
const comparators = <String>['EQUALS', 'GREATER THAN', 'LESS THAN'];

// ------------------------------------------------------------------- families

const _movement = Color(0xFF4DCB6D); // green: in and out of the building
const _storage = Color(0xFFFF8275); // red: the floor
const _loop = Color(0xFF5EAAFF); // blue
const _branch = Color(0xFFFFD83D); // yellow
const _arithmetic = Color(0xFFC98EFF); // purple

/// Ordered by expected frequency of use, not by unlock date - the tray scrolls
/// horizontally and the most-reached-for commands should never require a scroll.
const commandCatalogue = <CommandSpec>[
  CommandSpec(id: 'take', label: 'TAKE', trayLabel: 'TAKE', colour: _movement),
  CommandSpec(id: 'ship', label: 'SHIP', trayLabel: 'SHIP', colour: _movement),

  CommandSpec(
    id: 'repeat',
    label: 'REPEAT',
    trayLabel: 'REPEAT',
    isBlock: true,
    colour: _loop,
  ),
  CommandSpec(
    id: 'repeatWhile',
    label: 'REPEAT WHILE',
    trayLabel: 'REPEAT WHILE',
    tail: 'ZERO',
    argKind: ArgKind.condition,
    isBlock: true,
    colour: _loop,
  ),
  CommandSpec(
    id: 'ifCond',
    label: 'IF',
    trayLabel: 'IF',
    tail: 'ZERO',
    argKind: ArgKind.condition,
    isBlock: true,
    colour: _branch,
  ),

  CommandSpec(
    id: 'copyFrom',
    label: 'COPY FROM',
    trayLabel: 'COPY FROM',
    argKind: ArgKind.pallet,
    colour: _storage,
  ),
  CommandSpec(
    id: 'copyTo',
    label: 'COPY TO',
    trayLabel: 'COPY TO',
    argKind: ArgKind.pallet,
    colour: _storage,
  ),

  CommandSpec(
    id: 'sum',
    label: 'SUM',
    trayLabel: 'SUM',
    argKind: ArgKind.pallet,
    colour: _arithmetic,
  ),
  CommandSpec(
    id: 'sub',
    label: 'SUB',
    trayLabel: 'SUB',
    argKind: ArgKind.pallet,
    colour: _arithmetic,
  ),
];

CommandSpec specFor(String id) =>
    commandCatalogue.firstWhere((c) => c.id == id);
