# The program editor — UI/UX spec

**Second pass.** The first one (`Experiments/GameplayUx/lib/ui/`) was an exploration: it found
the notebook, the container blocks, the drag-and-drop and the colour families by trying things.
This document is what it found, written down before any of it is built again — so the second
implementation can be shaped by the destination instead of by the route.

Supersedes GDD §7.2 for the editing surface. Everything else in the GDD stands.

---

## 1. What this second pass is and is not

**It is a rewrite of the view layer only.** The pane widget now holds the page, the ruling
painter, the paperclip, the slot, the open gap, the dashed outline and the drag ghost, and the
slot alone carries four modes that each arrived to fix one bug. That is the part where knowing
the destination would have produced something much simpler.

**It is not a rewrite of the model.** `model/program.dart` and `model/commands.dart` are
unchanged and untouched: a tree of `Node`, explicit `Slot(parentId, index, depth)` insertion
points, a `sealed DragPayload`, undo by snapshot. That layer was designed rather than evolved,
it is pure Dart with no Flutter import, and nothing in this spec changes it.

**It is not a re-exploration of the look.** The paper, the families, the container shape and
the type are settled. They are *specified* below, not reopened. Re-deriving them would be the
same mistake in the other direction.

---

## 2. The one real change

Placed commands can be picked up and moved. That was possible before but undiscoverable, and it
is now first class — which in turn resolves the gesture model:

| Verb | Pick up from | Drop on | Meaning |
|---|---|---|---|
| drag | the note | a gap | add |
| drag | the page | a gap | move |
| drag | the page | the note | **delete** |
| drag | anywhere | anything else | nothing — it returns home |

The note the commands come from is the place they go back to. No bin appears from nowhere, no
extra chrome, and the answer to "how do I get rid of this" is the gesture the player already
knows.

---

## 3. Gestures

### 3.1 Lift

- **From the note: immediately.** There is nothing to scroll under the note, so a command comes
  away on the first movement.
- **From the page: long-press, ~180ms.** The page scrolls vertically and rows must not fight
  it. Holding is the cost of moving a placed row, and it is the standard gesture for exactly
  this on both platforms.
- On lift the row rises: it follows the finger at full opacity with a shadow, and the space it
  came from stays open (the program does not close up behind it).

### 3.2 The note becomes a bin

While a **placed** command is lifted — and only then — the note turns into a drop target for
removal:

- Its buttons cross-fade out and a trash can with `DROP TO REMOVE` fades in.
- **The note does not change size.** It keeps its exact height, or the page reflows in the
  middle of a drag, which is the one moment a player is tracking a moving object.
- Dropping there deletes the command — with its whole body, if it is a block — and shows the
  `Deleted X · UNDO` toast for one second.
- Dragging *from* the note leaves it a note. Dropping a new command back on it is a cancel, not
  a delete: there is nothing to delete yet.
- The trash can is drawn as a path, like the paperclip. No assets.

### 3.3 Swipe to delete stays

Either direction, red backdrop, `DELETE`, same undo toast. It does not collide with the move
because moving requires a hold. It is the one thing here that is redundant with something else,
kept because it is fast and one-handed; if we ever want strictly one way to do each thing, this
is what goes.

### 3.4 Arguments

Tap a cyclable word to advance it. One control, one gesture, everywhere — the pallet number and
the condition behave identically. No steppers, no pickers, no modals.

### 3.5 Scrolling and auto-scroll

- The page scrolls vertically. It carries half a pane of empty page below the last row, so a
  short program can always be pulled up to a comfortable height.
- Holding a lifted command near the top or bottom of the **visible** page scrolls it, at a
  speed that ramps from the edge of the zone (2px/frame) to the edge of the page (16px/frame).
  The zone is capped at a quarter of the pane, or a short pane has no neutral middle.
- Auto-scroll stops the moment the finger leaves the zone or the list reaches its end.

---

## 4. The page

- **Paper**, not a dark editor pane: a warm sheet (`#F6F1E4`), ruled in faint blue at exactly
  one row's pitch so instructions sit *on* the lines, with a red margin down the left.
- **The ruling scrolls with the program.** Only the phase changes, so the sheet is endless.
- **The program starts right of the margin** (34dp gutter). The page — rules and margin — is
  drawn full width behind everything; only what is *written* on the page respects the margin.
- **A paperclip** on the top-right corner, over the content, fixed rather than scrolled: it
  holds the page, it is not written on it. Never intercepts a touch.
- **The note lies over the page**, translucent, so the ruling shows through it. The page runs
  full height beneath it. Pressing RUN uncovers page rather than resizing it.

### No tilt

The first pass tilted every command a fraction of a degree, like hand-placed stickers. It is
**out** in this pass. It looked good and it cost real precision: every measured rect became a
rotated bounding box, so every geometry test carried an ~8dp tolerance, and a genuine 8dp
regression could hide inside it. The notebook reads as a notebook without it.

---

## 5. The program

- **A tree, drawn as nested containers.** A block is a literal container with its body inset,
  so it reads as a "C" wrapped around what it owns. No connector lines, no `END` row — the
  bottom arm of the container closes the bracket, and it is as thick as the left arm.
- **A block header paints the container's own fill**, in the container's rounding, so at rest
  the two are one shape — and so the title always has a background to travel on.
- **A block is one object.** Swiping or dragging it carries its body. It cannot be dropped
  inside itself.
- **Colour names the family, the word names the command**: movement (`TAKE`, `SHIP`) green,
  the floor (`COPY TO`, `COPY FROM`) red, the loop (`REPEAT`, `REPEAT WHILE`) blue, the branch
  (`IF`) yellow, arithmetic (`SUM`, `SUB`) purple. Nesting a block inside another of the same
  colour steps the fill one shade, so the inset arm stays visible.
- **A row hugs its text.** 36dp, which is under the 48dp target guidance and deliberate: a row
  is not a tap target — its gestures are a swipe and a long-press — and the one thing on it
  that *is* tapped carries its own target.

### 5.1 Two shapes: notes and tabs

The two kinds of command are two kinds of sticky note, and the difference is **where the glue
is**. That is not decoration: it is what tells you at a glance whether something holds other
things.

**A container is a note, glued along the top.**

- No shadow on the top edge. It is stuck down there.
- A soft shadow along the **bottom**, where a note lifts away from the page; the sides get a
  trace of it, the top none. `offset (0, 4)`, `blur 6`, `spread -3` - the negative spread is
  what keeps it off the top edge.
- The **bottom-right corner is very slightly folded**: a ~10dp dog-ear, the cut showing the
  underside of the paper a shade darker than the note. Small enough to register as physical
  rather than as a graphic.

**A single command is a tab, glued along the left.**

- No shadow on the left edge.
- The shadow is on the **right end**, where it lifts. `offset (4, 2)`, `blur 6`, `spread -3`.
- The same fold, at the right end rather than the corner.

**Both shapes have a right edge, and the overhang is retired.** Today the whole program is laid
out wider than the screen so that a container never shows its right edge. That existed to sell
the "C": a container was an abstract bracket, and a visible right edge made it read as a closed
box instead of as something wrapping its contents.

A sticky note *is* a closed box. Four edges, glued along one of them. The illusion the overhang
was protecting no longer needs protecting - and the bottom-right fold cannot exist without the
corner it folds. So:

- **A container is a whole note.** Its fill wraps its children on all four sides: 12 left, 8
  right, 12 below. The left arm still carries the nesting, and the right and bottom arms are
  what make it a note rather than a bracket.
- **A single command fills the body it sits in**, so its lifted right end falls against its
  container's right arm. At the root, where there is no container, it ends 16dp short of the
  page's right edge so the shadow and the fold have somewhere to land.
- **Nothing is laid out wider than the page.** The horizontal scroll view that existed only to
  give the extra width a legal home goes with it, and so does the clipping it needed.

This is the one piece of the old design this pass deliberately reverses, so the reason is worth
keeping: the "C" was the best an abstract object could do. The metaphor is better than the
abstraction, and it does not need the trick.

---

## 6. Slots: where things land

- Every list has a slot before its first child, between each pair, and after its last. They are
  the only spacing in the program: 12dp closed, and no margins anywhere else competing with
  them.
- **The root's trailing slot owns the rest of the page**, including the half-pane of slack, so
  dropping past the end of the program always works.
- **An open slot is the shape of the row that will land in it**: a row's height *plus the gaps
  that row will have above and below it*, with a dashed outline inset exactly as a row's first
  word is. So when the drop lands, **nothing moves** — the row replaces the preview in the
  space already reserved for it.
- Opening and closing animates linearly over 120ms. Closing *after a drop* is instant, because
  the row is taking that space and animating it shut would shove the page down and pull it back.
- An **empty block body** is one slot, permanently in that reserved-row shape, painted in the
  shade a real child would wear. An empty body reads as a container missing its first
  instruction, not as a gap.
- Slots refuse everything while a program runs, but they **stay in the layout** — removing them
  reflowed the whole program at the exact moment you want to watch it.

---

## 7. Running

RUN hides the note and freezes the program: no drops, no swipes, no argument taps. The rows
render identically and hold their exact positions. Nothing about the program's geometry changes
between editing and running.

---

## 8. Metrics

| | |
|---|---|
| Instruction text | Sniglet 20pt, weight 700, letterSpacing 0.8, even leading distribution |
| Row height | 36 (minimum, grows with text scale) |
| Indent / slot (closed) | 12 |
| Open slot | row + 2 × 12, outline inset 12 from its own left edge |
| Row text inset | 10 left, 6 right |
| Chip | 8 × 2 padding, 36 target inside the row |
| Tray button | hugs its label (~30), 48 target, 4 gutters, two rows, never scrolls |
| Page | gutter 34, margin line at 26, rules at row pitch |
| Tail slack | 0.5 × pane |
| Container shadow | `(0, 4)` blur 6 spread -3, bottom only, never the top |
| Command shadow | `(4, 2)` blur 6 spread -3, right end only, never the left |
| Fold (dog-ear) | ~10dp, underside one shade darker than the fill |
| Container body inset | 12 left, 8 right, 12 below - the note wraps its children |
| Right edge | everything ends on the page; a root-level command stops 16dp inside it |
| Text scaling | to 200% without clipping (GDD §7.3) |
| Contrast | ink ≥ 7:1 on every fill; families ≥ 20 ΔE apart |

---

## 9. Invariants that must not regress

Each of these is a bug the first pass actually produced. They are the reason this rewrite is
cheap rather than risky, and each should be a test.

1. Nothing moves when a drop lands.
2. Nothing moves when a run starts or stops.
3. Spacers exist while running, and refuse drops.
4. Every list has leading, between and trailing slots; the root's trailing slot covers all
   remaining page.
5. An empty body reserves exactly one ghost row, in the child's shade.
6. An open gap's outline is inset from its own edge exactly as a row's first word is.
7. A block carries its body when moved, swiped or deleted, and cannot be dropped into itself.
8. A drag started on the note is never swallowed by the page, and vice versa.
9. Auto-scroll measures from the *visible* page, not the pane's box (the note covers its
   bottom), ramps with depth, and stops at the extents.
10. All nine commands are visible without scrolling, in two rows.
11. No shadow falls on a glued edge: never above a container, never left of a command.
12. Every command's right edge is on screen, container and single alike. Nothing is laid out
    wider than the page.

---

## 10. Out of scope

The floor simulation, the virtual machine, the executing-row highlight, level data, the boss
call, and the chrome (task card, divider, floor pane, RUN button). The chrome is reused as-is.

---

## 11. Where the code goes

```
lib/ui/notebook/          new; the editing surface
  page.dart               the sheet: paper, ruling, margin, clip
  program.dart            the recursive tree: blocks, rows, slots
  row.dart                one instruction, presentational
  slot.dart               a gap, its open state, the reserved row
  note.dart               the command note, and its bin state
  lift.dart               long-press lift, payloads, feedback, auto-scroll
  tokens.dart             paper-era tokens (the notebook's own)
```

`wireframe.dart` keeps the chrome tokens the rest of the app uses. `gameplay_screen.dart`
swaps one widget. The old `program_pane.dart`, `program_row.dart` and `tray.dart` are deleted
once the new surface is in, not left beside it.
