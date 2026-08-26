# GameplayUx — gameplay layout & editor experiment

A throwaway Flutter app for iterating on the **Employee #2** gameplay screen: the
two-pane portrait layout and, mainly, **how programming feels**.

Deliberately joyless — greys, plain text, flat buttons. Colour and character
would flatter the design and hide problems.

## Run

Android is the real target — gesture feel cannot be judged with a mouse.

```
cd Experiments/GameplayUx
flutter run -d emulator-5554     # or: flutter devices, to find your device id
flutter run -d windows           # fast layout iteration, mouse input
```

Hot reload works on both; `r` in the terminal, or save in the IDE.

**Android.** Portrait is locked in `AndroidManifest.xml` as well as in Dart, so
the OS cannot rotate during startup before `setPreferredOrientations` applies.
The launch background is set to `W.page` in `res/values/colors.xml` so the app
does not flash white into a dark UI, and `main.dart` sets transparent system bars
with light icons (Android 15+ forces edge-to-edge, so the page colour shows
behind the status and nav bars).

If `adb install` fails with `INSUFFICIENT_STORAGE`, uninstall first:
`adb uninstall com.example.gameplay_ux`.

**Windows.** The window opens at **393 × 852** — iPhone 15/16 portrait logical
size, set in [`windows/runner/main.cpp`](windows/runner/main.cpp). It stays
resizable on purpose, so the divider can be tested at other aspect ratios.

```
flutter test      # 84 tests: block editing, layout/text-scale, divider, caret, conditions
flutter analyze   # clean
```

## What is in scope

| | |
|---|---|
| Two stacked panes, draggable divider | yes |
| Run control, top-right of the floor | yes — label only, nothing executes |
| Snap states — program-focused 38%, floor-focused 60% | yes |
| Tap-insert at a caret, from a scrolling tray | yes |
| `SIZE` / `SPEED` par readout | **no** — removed, see below |
| Block-aware drag reorder | yes — the point of the experiment |
| Inline `[n]` argument editing, no modals | yes |
| Swipe delete / duplicate, undo & redo | yes |
| Floor simulation | **no** — grey placeholder |
| Program execution / instruction highlight | **no** — see below |

**The run control lives top-right of the floor**, not in the chrome — it belongs
next to the thing it runs. One button: it reads `RUN` with a play triangle, and
becomes `STOP` with a square while running. A separate stop button would be a
second target that is dead most of the time.

It does **not** execute anything. Tapping it flips the state so both labels can be
felt.

**While running, the program is read-only.** The tray and the caret are hidden,
and the rows answer no gestures — no cycling an argument, no swipe to delete or
duplicate, no drag to reorder. Hiding the tray while leaving swipe-delete live
would have been the worst of both: the screen says "you cannot edit this" and the
gestures disagree. The rows render identically, so the program stays perfectly
readable; it just stops being a thing you can touch. The program pane grows into
the space the tray leaves, which is space you want while watching a program.

Implementation note: running builds `flatten()` instead of `flattenWithSlots()`,
so the caret and every drop gap disappear together rather than being individually
suppressed. `ProgramRow`'s old `ghost` flag became `interactive`, since a drag
ghost and a running program are the same thing — a row that renders but does not
respond.

A deliberate consequence: **the divider can hide the floor completely, and then
there is no way to start a program.** That is intended — dragging the floor away
is a legitimate way to say "I am editing, not running". The floor is never left as
a sliver too thin to reach the button either: below `RunButton.height + 36` it
collapses outright, so it is always either runnable or gone. Two tests guard that
invariant.

**No `UNDO` / `REDO` buttons, and no bottom bar at all.** Priority is a UI that is
not intimidating; reverting by hand is an acceptable cost for now. The transient
`UNDO` in the delete toast is still there on purpose — a swipe-delete needs a way
back, and it appears only for four seconds after one. Say the word if that should
go too.

## Interactions to try

| Gesture | Result |
|---|---|
| Tap a tray command | inserts at the caret |
| Scroll the tray sideways | the fading edge shows which way there is more |
| Tap a row | caret moves below it — into the body, for a block header |
| **Long-press + drag** a row | reorder; a block carries its whole body |
| Drag near the top/bottom edge | list auto-scrolls |
| Swipe row left | delete, with a 4s undo toast |
| Swipe row right | duplicate |
| Tap an argument chip | cycle to the next value, wrapping |
| Tap `ELSE` on an `IF` header | add / remove the else branch |
| Drag the divider grip | free positioning, snaps when released near a snap state |
| Double-tap the divider | toggle between the two snap states |
| Tap `RUN` / `STOP` (top-right of the floor) | flips the run state (fake); the tray, caret and all editing gestures go away while running |
| `SAMPLE` / `CLEAR` (in the floor placeholder) | load level 4's reference solution / empty |
| `[i]` on the task card | re-open the brief |

## What has been stripped out, and why

The working principle here is to find the simplest UI that still works, and let
detail earn its way back later — possibly gated on player progress, possibly never.
Removed so far, each for the same reason (it read as intimidating, or named
something already obvious):

| Removed | Why | Cost |
|---|---|---|
| `UNDO` / `REDO` buttons | chrome, and the whole bottom bar existed only to hold them | reverting is manual. The 4-second undo in the delete toast stays — a swipe needs a way back |
| `RUN SHIFT` from the chrome | belongs next to the thing it runs | none; it moved into the floor |
| Line numbers | made the editor look like something to memorise and reason about | no way to refer to "row 4" out loud |
| `SIZE` / `SPEED` par readout | par metrics read as jargon, and §8.2 keeps pars hidden until a level is first cleared anyway | no live feedback on program length while editing |
| `TRAY` label | named something already obvious | none |
| `DROP TO PLACE` hint | drop targets light up and rows follow the finger | none apparent |
| `ELSE` | `IS NOT` covers it (§6.6-style reasoning) | see the condition section |
| Floor pane header (`FLOOR`, `% OF SPLIT`) | a label above a box that says what it is | the split percentage is no longer readable at a glance |

Each removal also deleted state rather than hiding it: `DisplayRow.number` went
with the line numbers, and the drag flag went back to being private to the program
pane when the tray strip that needed it disappeared.

**The tray fades out at whichever edge has commands off-screen.** Horizontal
scrolling is close to undiscoverable on its own, and the fade is on *both* edges
rather than just the right: once you have scrolled, the left edge is where the
rest of the vocabulary went. It is a gradient to the tray's own background, so
buttons dissolve into the edge instead of being cut off at it.

Two implementation notes. The fade reacts to `ScrollMetricsNotification` as well
as `ScrollNotification`, because how much overflows changes with text scale and
screen width without anyone scrolling — and the initial state has to be read in a
post-frame callback, since the first build has no scroll metrics yet. And the
overlay is wrapped in `IgnorePointer`, or it would swallow taps meant for the
button underneath it; there is a test for exactly that.

## Design vs scaffolding

Everything in the chrome is meant to be read as **the design**. Everything that
only exists to help test it lives **inside the floor placeholder**, in a box
labelled `TEST SCAFFOLDING · NOT PART OF THE DESIGN` — otherwise a screenshot
misrepresents the design, which is the one thing this experiment must not do.

Traceable to the spec:

- the task card, with `[i]` to re-open the brief (§7.1's mock, §5 step 2)
- the run control (§7.1 puts `RUN SHIFT` in the chrome; moving it into the floor
  is a departure worth a decision)
- the two panes, the divider, the snap states (§7.1)
- numbered rows, indentation, block spines, the caret (§7.1, §7.2)
- the tray — bare buttons. §7.1's mock puts a `⊞ TRAY  SIZE 8 / 7` strip above
  them; that strip is **removed** (see below).

Scaffolding, inside the floor rectangle:

- `SAMPLE` / `CLEAR` — fixture loaders. `CLEAR` has no designed equivalent;
  unlimited undo (§7.2) already covers starting over.
- `ROWS`, `DEPTH` — the `SIZE`-vs-rows distinction is an open question in
  `level-04-briefing.md` §5.1, and these make it inspectable.
- `TEXT x1.00` — the live OS text scale. This is what made the clipping bugs
  visible instead of guessed at.

The scaffolding block is the first thing dropped when the floor pane is dragged
small: it is the least important content on screen.

## One visual rule for the language

**Rows sit flush against each other**, separated only by a 1px line inside each
row's own decoration, so the program reads as one block of text rather than a
stack of cards. The insertion slots between rows are zero-height when idle; they
only take space when they have something to show — the caret, or a drop target
during a drag. They used to keep 6px to stay tappable, but tapping a *row* already
places the caret, so the height bought nothing.

**No line numbers.** A numbered gutter made the editor look like something to be
memorised and reasoned about, which is exactly the wrong first impression for a
player who does not write software. `DisplayRow` lost its `number` field with it,
rather than leaving an invisible numbering system in place to rot. Rows keep a
small left inset (`W.rowInset`) where the gutter used to be so text is not flush
against the screen edge, and slots use the same inset so they stay aligned.

A row reads as a sentence. **Fixed command words are bare, bright and semibold;
every word you can change is a quiet button** — soft fill, faint edge, 2px
corners, regular weight. Tap one to advance it to the next value, wrapping.

A condition is three such words: `IF` `TYPE` `IS` `BLUE`. Each cycles
independently.

| Segment | Cycles through |
|---|---|
| subject | `TYPE`, `WEIGHT` |
| comparator | `IS`, `IS NOT`, and `MATCHES` (TYPE) / `UNDER` (WEIGHT) |
| object | a package type, `ZERO`/`NEGATIVE`, or `PALLET n` |

The object slot changes *kind* with the first two words, so it resets when the
kind changes and is preserved when it does not — `IS` → `IS NOT` keeps `BLUE`;
`IS` → `MATCHES` switches to `PALLET 1`. A comparator that is illegal for the new
subject is pulled back to a legal one, so no unreachable sentence can be authored.

**There is no `ELSE`.** `IS NOT` covers what an else branch was for, without a
second block body, a toggle on every IF row, or a branch dimension threaded
through the document model, the flattener and the drag machinery. `Slot` lost a
field; `Node` lost a child list. The language stays Turing complete: `REPEAT` plus
a conditional plus unbounded integer memory (pallet weights via `MERGE`/`STRIP`)
is the standard while-language, and `ELSE` was only ever sugar over it.

How the affordance got here, since two versions were tried and rejected:

1. **Bordered chips with a solid fill.** Obvious, but three of them on a
   condition row was cluttered.
2. **Tone only — a dimmer grey, no fill.** Clean, and *nobody could tell it was
   tappable*. It also hit a hard ceiling: §7.3 puts a 7:1 contrast floor on all
   instruction text, which against a row fill means nothing dimmer than about
   `#C1C1C1`, so there was barely a band to differentiate inside. It read as a
   distinction in the code and not on a real screen.
3. **A quiet button** — much softer fill than a real button, faint edge, and the
   word at full brightness. Dim text on a lighter fill drops to ~5:1, so
   brightness had to come back; regular weight against the keyword's semibold
   carries the remaining distinction.

The caret occupies a full instruction row and blinks like a text cursor - same
height, same font size and weight as an instruction, because at a smaller size it
read as a different kind of thing rather than as "the next instruction lands
here". It holds its height while dark, so the program never jumps. Blinking is
suppressed under `disableAnimations`, and the timer is cancelled rather than left
spinning.

The divider carries a grip with a small up and down arrow. A bare rule read as
decoration - nothing else on this screen moves vertically, so the affordance has
to say so rather than wait to be discovered. The arrows are painted rather than
set as glyphs: at this size an icon font's built-in padding makes the pair too
tall for a 26px grip.

## Structure

```
lib/
  model/
    commands.dart   Act 1–3 command catalogue (no IF INTAKE IS EMPTY, per §6.6)
    program.dart    node tree, flatten, insert/move/delete/duplicate, undo
  ui/
    wireframe.dart      the grey palette and every dimension from §7.3
    gameplay_screen.dart  task card, panes, divider, snap states
    floor_pane.dart     the placeholder
    program_pane.dart   rows, caret, drop slots, drag machinery
    program_row.dart    one row: spines, keyword, cyclable words
    tray.dart           tap-to-insert command tray
test/
  program_test.dart  block-editing semantics
  layout_test.dart   overflow / text-scale sweep, caret regression guard
```

Two structural decisions worth knowing:

**The program is a tree, not a flat row list.** Every interesting operation is a
subtree operation — dragging a `REPEAT` carries its body, deleting one offers to
keep its contents. Trivial on a tree, fiddly on a flat list with span
bookkeeping. Rows are produced by flattening for display.

**Drop targets are explicit `Slot`s, not row indices.** A flat index is ambiguous
at block boundaries — "after the last child" could mean inside the block or after
it. So flattening emits `Slot(parentId, branch, index)` before every child and
after the last one in each list, which also makes empty block bodies reachable.

## Known gaps

- `Dismissible` is used with `confirmDismiss` returning `false` for both swipe
  directions, so the row never actually dismisses and the tree stays the single
  source of truth. It works, but it is a hack, and a purpose-built swipe widget
  is the real answer.
- The whole pane rebuilds on every edit. Fine at this scale; §13.3 requires
  per-row `ValueListenable` rebuilds once there is a running highlight. The caret
  blink is already scoped to its own widget for the same reason.
- Widget tests run with `disableAnimations: true` by default, because the blink
  is a repeating timer and `pumpAndSettle` never settles against one. The blink
  is covered separately with explicit `pump` durations.
- Text scaling is covered by `test/layout_test.dart` (40 tests: an overflow
  sweep across two screen sizes x 1.0-2.0, a no-clip assertion per row, and the
  caret regression guard). No golden *image* tests and no locale sweep yet -
  §13.3 wants both.
- **Beyond 200% text scale the layout degrades**: a program row's argument
  controls stop fitting a 393-wide screen. 200% is what §7.3 commits to, so this
  is a known limit rather than a covered case. Chrome text is clamped at 1.3x
  (see `W.chromeMaxTextScale`) so the furniture cannot starve the panes - the
  program keeps scaling, the buttons do not.
- The program font is `Consolas` with a `Courier New` / `monospace` fallback.
  Consolas does not exist on Android, so the two platforms render the program in
  **different typefaces** — Android lands on the system monospace. Fine for
  layout work, but bundle a font before judging letterform legibility (§7.3 wants
  disambiguated `1/l/I` and `0/O`).
- After a drop, the list stays wherever drag auto-scroll left it rather than
  scrolling back to show the moved row in context.
- The `IF TYPE IS` row is the tightest in the set: label + type chip + `ELSE`
  toggle nearly fills a 393-wide screen at 1.0x. It will be the first row to
  break under a longer localised label (German), and it is what fails past 200%.
