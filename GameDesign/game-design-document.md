# Employee #2 — Game Design Document

**Version:** 0.1 (living document) · **Date:** 2026-08-23 · **Owner:** David Landeros
**Status:** Pre-production. Character designs for ROBOT and BOSS exist with animations.

---

## 1. Elevator pitch

> **Employee #2** is a portrait-first programming puzzle game about working from home while
> remotely controlling a robot employee. Your boss calls with a task, explains exactly what
> needs to be accomplished, and leaves you to figure out the instructions. You build a small
> program using simple commands, then watch your robot physically walk, pick up, throw,
> combine, and deliver objects until the job is complete.

What the pitch doesn't say out loud — and the game never says until the end — is that the
robot is not your tool. It's your successor. Every program you write is a training sample.

---

## 2. High concept

You are a remote fulfillment operator for **OMNICART**, a logistics megacorp that has
discovered it is cheaper to let humans work from bed than to keep them in a warehouse. You
never see the warehouse. You see your robot, your program, and your boss's face on a video
call.

The game is a *visual instruction-set puzzler*: each level gives you a goal stated in plain
language, a small set of commands, and a robot that executes your program literally and
without mercy. The comedy and the difficulty both come from the same place — the machine
does exactly what you said.

- **Genre:** programming puzzle / logic puzzle
- **Platform:** mobile first (iOS + Android), portrait only, one-handed
- **Session length:** 2–8 minutes per level, resumable mid-level
- **Audience:** the Human Resource Machine / Baba Is You / Zachtronics-curious crowd, plus
  the much larger group of people who like puzzles but bounce off tiny landscape UI
- **Business model:** premium, one-time purchase, first act free (see §12)
- **Length:** ~45 levels main line + ~15 optional overtime puzzles, 8–14 hours

---

## 3. Design pillars

Every decision in this document should be traceable to one of these five. If a feature
doesn't serve a pillar, cut it.

### P1 — Portrait, one thumb, always
The game must be fully playable with one hand, phone held naturally, thumb reaching only the
bottom two thirds of the screen. Landscape is not supported, not "supported later." This is
the pillar that makes the game *sneak up* on players: it looks like scrolling, so it feels
like a free action, not a commitment to a session. Nothing in the game may require a second
hand, a rotation, or a precise two-finger gesture.

### P2 — Readable at arm's length, in bed, at night
The original genre standard puts a wall of 9pt text in a quarter of a landscape screen. We
do the opposite: **the program is the biggest thing on screen.** Instruction rows are
finger-sized and legible without leaning in. Dark theme is the default. No decorative font
for anything functional.

### P3 — The robot makes the abstraction physical
Any concept the program can express must have a body: a walk, a lift, a throw, a *merge*.
The player should be able to understand what a command does by watching it once, before
reading its name. The merge animation is the centerpiece — it is our version of arithmetic,
and it should be satisfying enough that players run programs just to watch it.

### P4 — Comedy in the framing, honesty in the machine
The boss lies. The company lies. The onboarding videos lie. **The execution model never
lies.** The simulation is deterministic, single-stepped, inspectable, and never introduces
randomness or hidden state. All difficulty comes from the puzzle, never from ambiguity about
what a command does.

### P5 — The story is told by the interface
The reveal that you're training your replacement is not delivered by a cutscene. It's
delivered by UI drift: your badge number, the wording of your task briefings, who is on the
other end of the call, and what the "Performance" screen chooses to measure. Players who
skim dialogue should still feel it.

---

## 4. Fiction and cast

### The company: OMNICART
A "customer-obsessed" fulfillment company with a smiling arrow logo, a mission statement
that changes every act, and a mandatory-optional wellness program. Never named as a real
company; the parody is of the genre of corporate voice, not of one firm. All copy passes a
simple test: *would this be funny on a poster in a break room nobody uses?*

Alternate names to hold onto if OMNICART clears trademark badly: **CARTWRIGHT**,
**VERTEX FULFILLMENT**, **SMILEBOX**.

### YOU — Operator, badge on the HUD
Never seen, never voiced, never named. The player's presence is the phone itself. Your only
representation in the game is a badge in the corner of the home screen that reads
`OPERATOR · EMPLOYEE #1`. Remember that badge; it matters in Act 5.

### BRENT — the boss (existing character, talk + idle animations)
Regional Synergy Lead. Not a villain and never cruel — that's the joke. Brent is warm,
slightly over-caffeinated, genuinely believes the mission statement, and delivers
increasingly dystopian instructions in the voice of a man who has just come from a very
good stand-up meeting. He calls you by a nickname he made up. He apologizes for calling
late and then calls later.

Brent's arc: enthusiastic → managing metrics → visibly nervous → reading from a script →
absent. Every one of those states is expressible with the two animations we already have
(talking, idle) plus timing, framing, and call quality. Act 4 Brent calls from a car. Act 5
Brent doesn't call.

### UNIT-02 — the robot (existing character design)
Your robot. Cheerful, tireless, no dialogue, expressive only through body language. It
performs your program with total literalism, including your bugs, which it performs
*enthusiastically*. In Act 1, Brent introduces it as "your new little helper, Employee #2."

The robot's characterization arc is the whole story: at first it hesitates before acting (a
tiny "thinking" beat before each instruction). Over the acts that hesitation shrinks. By Act
4 it starts moving a frame *before* the instruction highlights. By Act 5 it's waiting for
you.

### The title
`EMPLOYEE #2` is the robot's badge for four acts. In the finale, the roster screen updates
and the number is yours.

---

## 5. Core loop

The shift loop, one level:

1. **The call.** The screen becomes a parody video call. Brent, framed vertically like a
   real phone call, talks; his words appear as text below him. He states the day's task in
   plain language, with an example. He can be skipped after first read; the brief is always
   re-openable from a pinned card.
2. **The brief.** His instruction condenses into a persistent one-or-two-line **Task Card**
   docked at the top of the editor. This is the contract the level checks. Wording is
   deliberately concrete: *"For every BLUE package on intake, ship TWO GREEN. Ignore
   everything else."*
3. **Program.** The editor fills the screen. You assemble instructions from a command tray
   with single taps, reorder by drag, and edit targets in place. (§7)
4. **Run.** One big PLAY button. The program executes.
5. **Watch, or don't.** During execution you can be on the **Floor View** (the robot doing
   the thing) or the **Program View** (the current instruction highlighted, values visible).
   A single swipe flips between them at any time, including mid-run, without pausing.
   Speed control (1×/2×/4×/instant) and step-by-step are always available.
6. **The verdict.** Pass → shift-complete card with SIZE (instruction count) and SPEED
   (steps executed) versus par. Fail → the robot stops at the exact instruction that went
   wrong with a plain-language explanation of what happened, one tap from resuming editing.
7. **Next call.** Occasionally a story beat, a company memo, or a performance review
   replaces the next call.

**Time to first program: under 60 seconds from app launch on a fresh install.** Level 1's
call is four lines and the tray has two commands.

---

## 6. The instruction set

The language is the game. It needs to be small, physical, and expressible in finger-sized
rows of large text.

### 6.1 The world
Portrait floor layout, read top to bottom:

- **INTAKE** (top): a chute that drops packages one at a time, in a fixed order per level.
- **THE FLOOR** (middle): numbered **PALLETS** — the level's memory. Some are pre-loaded,
  some are empty, some are locked.
- **OUTBOUND** (bottom): the chute you ship to. Order matters.
- **UNIT-02**: walks the floor, one thing in its claws at a time.

### 6.2 Packages
Each package has a **TYPE** (shape + color + icon — never color alone) and a **WEIGHT**
(an integer, printed large on the box). Early acts use TYPE only, so the first hours are
pure logic with zero arithmetic. Weights unlock in Act 2 and the merge machinery follows.

This split is a deliberate improvement over the genre standard, which mixes letters and
numbers immediately: **learn the control flow first, then the math.**

### 6.3 Commands

| Command | Reads as | Semantics | Robot performs |
|---|---|---|---|
| `TAKE` | take from intake | Grab next package from INTAKE. If intake is empty, the shift ends. | walk to chute, catch box |
| `SHIP` | ship it | Put held package into OUTBOUND. Hands must be full. | walk to belt, toss box |
| `STACK ON [n]` | stack on pallet n | Write held package onto pallet n. Robot keeps holding it (a scan/duplicate — diegetically, OMNICART's inventory system "records" it). Overwrites pallet n. | slam onto pallet, scanner flash |
| `PICK FROM [n]` | pick from pallet n | Receive a copy of pallet n's package. Pallet n must not be empty. | lift from pallet, fabricator hum |
| `MERGE WITH [n]` | merge with pallet n | held.weight += pallet[n].weight. **The merge animation.** | the two-things-become-one animation |
| `STRIP BY [n]` | strip by pallet n | held.weight −= pallet[n].weight. Can go negative. | reverse merge, pieces fly off |
| `PAD [n]` / `TRIM [n]` | add / remove padding | pallet[n].weight ±1, then pick it up. | quick tape-gun gag animation |
| `THROW AT [n]` | throw at pallet n | Long-range `STACK ON`. Costs 1 step instead of walking. Unlocked as an optimization tool. | the throw animation |
| `REPEAT … END` | repeat forever | Unconditional loop. The workhorse. | — |
| `IF <cond> … ELSE … END` | branch | Structured conditional, indented, always closed. | — |
| `CLOCK OUT` | clock out | Terminate the program successfully, here. | robot waves, screen dims |

**Conditions:** `INTAKE IS EMPTY` · `HANDS ARE EMPTY` · `TYPE IS <type>` · `TYPE MATCHES
PALLET [n]` · `WEIGHT IS ZERO` · `WEIGHT IS NEGATIVE` · `WEIGHT UNDER PALLET [n]`

Conditions are introduced one per level, and each one's first appearance gets a short
diegetic explanation from Brent rather than a tutorial popup.

### 6.4 Structured blocks, not jump arrows — a deliberate divergence

The genre standard uses raw `JUMP` / `JUMPIFZERO` with drag-drawn arrows down the side of
the program. On a touchscreen in portrait that is the single worst interaction in the genre:
it needs precision, two hands, and a wide gutter we don't have.

**We use structured blocks instead**: `REPEAT`/`END`, `IF`/`ELSE`/`END`, with real
indentation and a colored spine connecting each block's open and close. Blocks are created
as a matched pair in one tap — you cannot author an unbalanced program, so an entire class
of frustrating non-puzzle errors disappears.

Cost of this choice: a handful of classic "spaghetti jump" puzzles become impossible to
pose. Accepted. Benefit: the program is *readable at a glance in portrait*, which is P2, and
nesting depth becomes a visible, teachable difficulty axis. Deep nesting is our version of
the late-game brain-melt.

Late Act 4 unlocks one escape hatch for optimization hunters: `BAIL` (break out of the
current loop) and `AGAIN` (continue). Both are tap-inserted, both stay inside the block
model, and neither can produce an unbalanced program.

### 6.5 Failure taxonomy
Every failure names itself in plain language, points at the instruction, and never uses the
word "error":

- *"UNIT-02 tried to ship, but its claws were empty."*
- *"Pallet 3 is empty. There was nothing to pick up."*
- *"Shipped a BLUE. Brent asked for GREEN."* (with the expected/actual boxes drawn)
- *"This program has run 2,000 steps. UNIT-02 will keep doing this forever unless you stop
  it."* (infinite-loop guard, framed as a labor complaint)

---

## 7. Portrait UX — the core of the product

### 7.1 Screen budget
Portrait is not a constraint we tolerate; it is the feature. The screen splits into two
stacked panes with a draggable divider and two snap states.

```
┌───────────────────────────┐   ┌───────────────────────────┐
│  ▣ TASK CARD          [i] │   │  ▣ TASK CARD          [i] │
├───────────────────────────┤   ├───────────────────────────┤
│                           │   │                           │
│     FLOOR VIEW            │   │     FLOOR VIEW            │
│     intake / pallets      │   │     (expanded, 60%)       │
│     UNIT-02 / outbound    │   │                           │
│                    (38%)  │   │     UNIT-02 working       │
├───────────────────────────┤   │                           │
│ 1  TAKE                   │   │                           │
│ 2  REPEAT              ┐  │   ├───────────────────────────┤
│ 3    IF TYPE IS BLUE  ┐│  │   │ ▸ 4    SHIP               │
│ 4      SHIP           ││  │   │   5    SHIP               │
│ 5      SHIP           ││  │   ├───────────────────────────┤
│ 6    END              ┘│  │   │  [◀◀] [ ❙❙ ] [1× 2× 4×]   │
│ 7    TAKE              │  │   └───────────────────────────┘
│ 8  END                 ┘  │       Run mode, Floor-focused
├───────────────────────────┤
│  ⊞ TRAY      SIZE 8 / 7   │
├───────────────────────────┤
│      ▶  RUN SHIFT         │
└───────────────────────────┘
   Edit mode, Program-focused
```

Snap states, one vertical swipe apart:
- **Program-focused** (editing default): floor 38% / program 62%
- **Floor-focused** (run default): floor 60–100% / program strip showing current instruction

The divider is draggable to anything in between and the position persists per player. The
game remembers which state you prefer during runs and defaults to it.

### 7.2 Editing with one thumb
The genre's usual "drag a command from a palette into a slot" is a two-hand interaction.
Ours is tap-first, drag-optional:

- **Insert:** tap a command in the horizontally scrolling **TRAY** at the bottom. It's
  appended at the **cursor**, a visible insertion caret in the program. The tray sits in the
  thumb zone; the program grows toward it.
- **Move the cursor:** tap any row. The caret goes below it.
- **Set a target:** commands with a `[n]` slot insert with the last-used or only-valid
  pallet pre-filled, then open an inline stepper. **No modal dialog ever opens for an
  argument.** Where a level has one legal pallet, we fill it and don't ask.
- **Reorder:** long-press a row and drag. Dragging a block header drags its whole body,
  indentation and all. Auto-scroll at the edges.
- **Delete:** swipe a row left. Undo toast for 4 seconds. Deleting a block header offers
  "delete block" vs "keep contents."
- **Duplicate:** swipe right on a row. High-frequency operation in this genre; give it a
  gesture.
- **Undo/redo:** always visible, unlimited within a level, survives app backgrounding.

Every interactive target is ≥48dp. Instruction rows are 56–64dp tall. Nothing functional
lives in the top 15% of the screen except the Task Card, which is display-only.

### 7.3 Readability spec (P2, enforced)
- Minimum functional text size **17pt**, instruction rows **20pt semibold**, and everything
  scales with the OS accessibility text setting up to 200% without clipping.
- Contrast ≥ 7:1 for instruction text on its row; ≥ 4.5:1 for all secondary chrome.
- Dark theme default; light theme available; both hand-tuned, not auto-inverted.
- **No information encoded in color alone.** Every package type is shape + icon + color.
  Verified against protanopia / deuteranopia / tritanopia simulation.
- One monospaced-but-humanist typeface for program text (open apertures, disambiguated
  `1/l/I` and `0/O`), one clean sans for chrome. Optional dyslexia-friendly face in settings.
- Long programs scroll, and during runs the pane auto-scrolls to keep the current
  instruction centered, with a "jump to cursor" button when the player scrolls away.

### 7.4 Run-time inspection
- **Speed:** 1× / 2× / 4× / instant, persistent per player.
- **Step:** a dedicated step button; holding it repeats. Stepping is the main debugging tool
  and should feel great.
- **Scrub back:** the execution log is retained, so stepping *backward* is possible. This is
  a significant quality-of-life win over the genre standard and cheap to implement given a
  deterministic VM (§13).
- **Inspect a pallet:** tap it any time, running or not, to see its contents big.
- **Watched values:** long-press a pallet to pin its current value into a small always-on
  readout strip. Solves "what is pallet 4 doing right now" without leaving the program view.

---

## 8. Level design

### 8.1 The three level roles
- **Teachers** (~40%): introduce exactly one new command, condition, or idea. Solvable in
  under two minutes by a player who understood the last teacher. Never combine a new command
  with a new *pattern*.
- **Builders** (~45%): combine two or three known ideas. This is the meat.
- **Walls** (~15%): one per act, deliberately hard, always solvable with only the commands
  taught. The Act 3 and Act 5 walls should be the levels people post about.

### 8.2 Par goals, optional and non-blocking
Each level shows `SIZE` (instruction count) and `SPEED` (steps executed) with par values.
Meeting par is never required to progress, and pars stay hidden until first clear so nobody
optimizes before understanding. Meeting both awards a cosmetic **Efficiency Sticker** on the
level card — and, in fiction, a slightly ominous congratulatory memo.

Two pars can be mutually exclusive on the same level. That's intentional and called out in
the UI: *"There are two ways to be a good employee."*

### 8.3 Act structure and content plan

**ACT 1 — ONBOARDING (8 levels, free)** · *Types only. No math.*
`TAKE`, `SHIP`, `REPEAT`, `CLOCK OUT`, `IF TYPE IS`, `IF INTAKE IS EMPTY`
Brent is delighted you're here. HR has sent a welcome video. Sample beats: ship everything;
ship everything forever; ship only the blues; ship two greens per blue.
*Story:* Brent introduces UNIT-02 as "Employee #2." Nobody thinks about it.

**ACT 2 — YOU'RE CRUSHING IT (10 levels)** · *Pallets and weights arrive.*
`STACK ON`, `PICK FROM`, `MERGE WITH`, `WEIGHT IS ZERO`, `TYPE MATCHES PALLET`
The merge animation debuts as a full-screen moment. Puzzles: totals, duplication, swapping
two pallets, "ship the heavier one."
*Story:* a Performance dashboard appears. Brent mentions the metrics are "for you, mostly."

**ACT 3 — Q3 EFFICIENCY INITIATIVE (10 levels)** · *Comparison and real algorithms.*
`STRIP BY`, `WEIGHT IS NEGATIVE`, `WEIGHT UNDER PALLET`, `PAD` / `TRIM`, nesting depth 3
Puzzles: min/max, clamping, counting, multiplication by repeated merge, sorting three items.
*Story:* calls start arriving outside working hours. Brent's background changes to his
kitchen. A memo announces that "operator hours are being optimized." UNIT-02's hesitation
beat before each instruction gets shorter.

**ACT 4 — TRANSITION PERIOD (10 levels)** · *Scale and optimization.*
`THROW AT`, `BAIL`, `AGAIN`, indirect pallet addressing (`PICK FROM PALLET [PALLET n]`),
nesting depth 4+
Puzzles: variable-length sequences, division by repeated stripping, a real sort,
sequence-processing set pieces.
*Story:* the call UI degrades — pre-recorded, then captioned, then a "COMPOSED WITH OMNICART
ASSIST" watermark on Brent's messages. One level's brief arrives with no call at all, just
text. UNIT-02 starts moving a frame before the highlight lands.

**ACT 5 — HANDOVER (7 levels + finale)** · *Everything, and the truth.*
Puzzles are framed as "documentation": each level asks you to write a program that *teaches*
a procedure rather than performs one. The last real puzzle is a program that writes a
program — the robot loading instructions onto pallets and executing them.
*Story:* Brent doesn't call. The task briefs come from UNIT-02, in Brent's phrasing, using
Brent's nickname for you. The final screen is the OMNICART roster: `UNIT-02 · OPERATOR ·
EMPLOYEE #1` above `YOU · TRAINING DATA · EMPLOYEE #2`.

**OVERTIME (~15 optional levels)**, unlocked per act — pure optimization and brutal
brain-teasers, framed as volunteer shifts you are warmly thanked for.

### 8.4 Ending
No twist ending, no boss fight. The last thing you do is a small kindness: the final program
is one instruction long, you choose it, and UNIT-02 performs it. The options are quiet and
non-mechanical (wave, clock out, hold the door). Then the app returns you to a home screen
that now reads `EMPLOYEE #2` and lets you keep playing Overtime forever. The joke completes
itself.

---

## 9. What we deliberately do NOT copy

Recorded so it doesn't get re-litigated:

1. **Landscape.** Not supported. (P1)
2. **Drag-drawn jump arrows.** Replaced by structured blocks. (§6.4)
3. **Drag-from-palette authoring.** Replaced by tap-to-insert at a caret. (§7.2)
4. **Abstract letter/number cargo from minute one.** Types first, weights in Act 2. (§6.2)
5. **Office-drone theme.** Warehouse + remote work + replacement, which is a fresher and
   more specific satire and gives the robot a body worth animating.
6. **Mandatory optimization gates.** Pars are always optional. (§8.2)
7. **Text-dense tutorials.** Every new idea is taught by a call and a demonstration, and
   every command is discoverable by tapping it for a one-sentence, illustrated definition.

---

## 10. Art direction

- **Format:** everything authored for portrait, 9:19.5 to 9:16 safe, notch- and
  home-indicator-aware.
- **Style:** clean vector-ish shapes, thick outlines, flat fills with one soft light source.
  Big silhouettes, so a robot the size of a thumbnail still reads. Grounded palette for the
  warehouse (concrete, cardboard, safety yellow) so the package types can own the saturated
  colors.
- **The floor:** a shallow, slightly-above-eye isometric slab so the whole floor fits a
  short, wide viewport. Pallets in a single horizontal row where possible; two rows max.
  Never scroll the floor view horizontally during a run — if a level needs more pallets than
  fit, redesign the level.
- **UNIT-02:** existing design. Animations needed: idle, walk cycle, pick up, put down,
  throw, **merge** (hero), strip (merge reversed, with debris), wave, confused/stop, and the
  shrinking "thinking" beat that carries the story arc.
- **BRENT:** existing design with talk + idle. The call frame does the rest of the acting —
  aspect ratio, connection quality, background, time of day, and whether he's looking at the
  camera.
- **Authoring both characters in Rive**, one state machine each, is the intended pipeline
  (§13.1). Practically: the animator ships one file per character with named states, the
  code triggers states by name, and the hesitation beat is an *input* on the state machine
  rather than nine exported variants. Vector art keeps the files small and lets the same
  artboard scale from the thumbnail-sized floor view to a full-screen merge.
- **The call UI:** a loving parody of a video-call app, portrait, with a real REJECT button
  that does nothing except make Brent call back immediately, once, as a gag.
- **UI:** the program editor is the game's visual identity. Rows are physical cards, blocks
  have a colored spine, the running instruction glows. Treat it like a beautiful piece of
  industrial software.

## 11. Audio

- Warehouse ambience that thins out as the acts progress and the building empties.
- **Each command has a signature sound**, short and distinct; a running program becomes a
  rhythm, and an experienced player can hear a bug before they see it. This is a real
  mechanic, not decoration.
- The merge sound is the best sound in the game.
- Music: light, jazzy corporate optimism in Act 1, gradually processed, quantized and
  synthesized until by Act 5 it's the same melody rendered by a machine.
- Brent has vocal *presence* (mumble and tone, no real words) so the animation reads without
  full VO cost. Full VO is a stretch goal; the text is the source of truth.
- Everything mutable independently. The game must be fully playable muted, since it will
  mostly be played muted.

---

## 12. Business model

**Premium, one-time purchase.** Act 1 free as a demo, full game unlocked with a single IAP.
No ads, no energy, no currency, no timers.

Rationale beyond taste: this game's text is a satire of exploitative labor optimization. An
ad-gated, energy-metered version of it would be an unintentional self-own, and the audience
that buys puzzle games would notice loudly.

Optional and non-punitive:
- **Hints**, free and unlimited, delivered as three escalating tiers per level (a nudge, a
  strategy, a worked partial). Framed as calls to "the operator who had this job before you."
- Cosmetic **robot paint jobs**, earned only by play. Never sold.
- Diegetic in-fiction "ads" for OMNICART products appear as gags between acts. They are
  content, not monetization, and they never interrupt a run.

Pricing target: premium mobile puzzle tier, one price globally adjusted, no discounting for
the first three months.

---

## 13. Technical design

**Stack: Flutter (Dart), one codebase for iOS and Android.** No 3D, no physics, no heavy
runtime cost. Target 60fps on a four-year-old mid-range Android.

Flutter is an unconventional choice for a game and a very good one for *this* game. Two
thirds of the product is a text-and-touch interface — big legible rows, drag-reorder,
OS text scaling, screen readers, localization — and that is Flutter's home turf, not a
game engine's. The one genuinely game-shaped part (the floor view) is a shallow scene with
a single walking character, which Flame and Rive handle comfortably. See §15 for the risk
this incurs and how we bound it.

### 13.1 Layer split

| Layer | Tech | Notes |
|---|---|---|
| **Shift VM** | pure Dart package, **zero Flutter imports** | The simulation. Runs headless, testable with `dart test`, usable from a CLI. |
| **Level data + validator** | Dart package + CLI | Level JSON, schema, reference solutions, the CI verifier. |
| **Program editor, call scene, menus** | Flutter widgets | Idiomatic Flutter. The product's identity lives here. |
| **Floor view** | **Flame** (`GameWidget`, embedded in the top pane) | Scene graph, camera, sprite/animation timing. Only this pane is a "game". |
| **UNIT-02 + BRENT** | **Rive** state machines (`flame_rive` on the floor, `RiveAnimation` in the call scene) | Artist-authored vector animation, tiny files, one state machine per character. Fits the art direction in §10 exactly and makes the "shrinking hesitation beat" a driveable parameter rather than a re-export. |
| **Audio** | `flutter_soloud` | Low latency matters: §11 makes per-command sounds a rhythm the player debugs by ear. Do not ship this on a high-latency player. |
| **App state** | Riverpod | Thin. The VM is the model; the app layer only holds the editor document, run controller, and progress. |

Repo shape: a small monorepo — `packages/shift_vm`, `packages/shift_levels`, `app/`. The VM
package must never gain a Flutter dependency; enforce it with a CI check, because that
constraint is what keeps the simulation testable and the level validator headless.

### 13.2 Architecture, non-negotiable
The program compiles to a tiny deterministic VM that runs **headless and instantly**. The
view is a *subscriber* to a step log, never the authority.

- Same program + same level = same log, always. No randomness, no frame-time dependence,
  and **nothing in the VM ever reads a clock or a frame delta.** Animation duration is a
  presentation concern applied to an already-finished log.
- Enables: instant-speed runs, step-backward debugging (replay the log to index *n*), par
  verification, automated solvability tests, and offline level validation.
- **Every level ships with a reference solution and a set of adversarial programs, executed
  in CI** via `dart test` with no Flutter and no device. A level that can't be auto-verified
  doesn't ship.
- **Level format:** declarative JSON — intake sequence, pallet initial state, allowed
  commands, the goal predicate, pars, and briefing text. Levels are data; designers never
  touch code. Deserialized into immutable Dart models (`freezed`) so a malformed level fails
  loudly at load, not mid-run.
- **Goal predicate:** a small expression language over the outbound sequence, so goals are
  data too and readable in the level file.

### 13.3 Flutter-specific implementation notes

These are the places where a naive Flutter implementation will fight the design, written
down now so they aren't discovered in Milestone 3.

- **Block-aware reordering is custom.** `ReorderableListView` can move one row; it cannot
  drag a `REPEAT` header together with its body (§7.2). Plan on a hand-rolled
  `SliverReorderableList` or a custom drag layer over a flattened tree with explicit
  parent/child spans. Budget real time for this — it is the single most important interaction
  in the game.
- **Never rebuild the program list during a run.** The running-instruction highlight is
  driven by a `ValueListenable` consumed *inside* each row, so a step repaints one row, not
  the list. Same for the pallet readouts. This is the difference between 60fps and visible
  jank on a mid-range phone.
- **Portrait lock in three places:** `SystemChrome.setPreferredOrientations`, the Android
  manifest, and `Info.plist`. Locking it only in Dart still lets the OS rotate during
  startup, which is exactly the first impression P1 cannot afford.
- **Text scaling:** honor `MediaQuery.textScaler` up to 200% (§7.3). Every instruction row
  must be height-flexible, never a fixed `SizedBox`. Verify with golden tests, below.
- **Golden tests as the P2 enforcement mechanism.** Render the editor at 1.0×, 1.5×, and
  2.0× text scale, in light and dark, in English, German, and a pseudo-locale, at three
  device widths — and fail CI on a diff. This turns "readable at arm's length" from a
  pillar we believe in into a build that breaks when someone violates it. It is the highest-
  leverage test in the project.
- **Rendering:** Impeller on both platforms. Precache Rive artboards and package sprites at
  level load, behind the call scene, so the first run never stutters.
- **Save:** local-first, full mid-level state (program + caret + undo stack) written as JSON
  to app documents via `path_provider`, debounced ~300ms and flushed on
  `AppLifecycleState.paused`. Not `shared_preferences` — this is a structured document.
  The app can die at any moment and lose nothing. Optional cloud sync later.
- **Localization:** ARB files with `flutter gen-l10n` from day one. All program text is
  composed from short tokens, never sentences — commands are `TAKE`/`SHIP`-length precisely
  so they survive translation into German. Reserve 40% width overflow on every row.
- **Accessibility:** wrap instruction rows in `Semantics` with a spoken form that reads the
  command, its argument, and its nesting depth. Honor `MediaQuery.disableAnimations` with a
  reduced-motion path that skips animation and runs at instant speed. No timed inputs
  anywhere in the game.
- **Instrumentation:** per-level attempt count, time-to-first-run, time-to-clear, hint tier
  used, most common failing instruction, abandonment point. Vendor-neutral event sink behind
  one interface so analytics can be swapped without touching gameplay code. This tells us
  which levels are broken far better than opinions will.
- **Test pyramid:** `dart test` for the VM and every level's solvability (fast, hermetic,
  the bulk); `flutter test` goldens for readability and layout; one `integration_test` that
  plays a full level end to end on a device per CI run.

---

## 14. Production plan

### Milestone 1 — Vertical slice (the only thing that matters right now)
Three levels (`TAKE`/`SHIP`, `REPEAT`, `IF TYPE IS`), one call from Brent, the full portrait
editor with tap-insert and drag-reorder, the floor view with walk/pick/ship animations, both
snap states with swipe, and the VM with step and step-back.

Tech-wise the slice must prove the whole layer split in §13.1 end to end — pure-Dart VM,
Flame floor pane embedded under a Flutter editor pane, Rive characters in both panes, and
the golden-test harness running. **Build the block-aware drag-reorder in this milestone, not
later**; it is the riskiest interaction and the one Flutter gives us least for free.

**Slice success criteria, tested on real people, on a phone, one-handed, standing up:**
1. Five of five new players write and run a correct program for level 1 with no help.
2. No player rotates the phone or reaches for a second hand.
3. No player asks what a command does after seeing it execute once.
4. Every player flips between floor and program view at least once, unprompted.
5. Every player reads the whole program without squinting or bringing the phone closer.

If 1 or 5 fails, the interface is wrong and the level list waits.

### Milestone 2 — Act 1 complete, shaped as the free demo, soft launch to a small region.
### Milestone 3 — Acts 2–3, merge economy tuned, par values set from real telemetry.
### Milestone 4 — Acts 4–5, the story drift and the finale, the Overtime set.
### Milestone 5 — Polish, localization, accessibility audit, launch.

---

## 15. Risks

| Risk | Mitigation |
|---|---|
| Portrait can't fit a legible program *and* a legible floor | Two snap states + draggable divider + never needing both at full size simultaneously; validated in Milestone 1 before content is built |
| Structured blocks make late puzzles too easy | Nesting depth, indirect addressing, and step-count pars as the late-game difficulty axes; Overtime levels absorb the hardcore demand |
| "Programming game" scares off mobile players | The word "program" never appears in the store listing or Act 1 — it's a job, and you're writing a schedule for your robot |
| Satire lands as mean or preachy | Brent is never the villain and is never punished; the target is the system's voice, and the ending is a small kindness, not a sermon |
| Comparison to the obvious inspiration dominates reception | Lead every piece of marketing with the portrait one-hand hook and the robot's physicality, which are genuinely ours |
| Scope creep into a level editor or level sharing | Explicitly post-launch. Not in this document's scope. |
| **Flutter is off the beaten path for games** — thinner ecosystem for scene work, fewer people to ask, and animation jank is the classic failure mode | The game-shaped surface is deliberately tiny: one shallow scene, one walking character, no physics. Flame + Rive cover it, and §13.3 pins the two known jank sources (list rebuilds during runs, uncached artboards) as build-time rules. Milestone 1 proves the floor pane at 60fps on the cheapest target device *before* any content is built. |
| Block-aware drag-reorder is not something Flutter provides | Hand-rolled in Milestone 1, ahead of all content, and treated as a first-class deliverable rather than a polish task (§14) |

---

## 16. Open questions

1. **Package type cap.** How many distinct types before the floor view stops reading at
   thumbnail size? Guess: five plus a wildcard. Needs an art test, not a debate.
2. **`STACK ON` semantics.** Copy (as specified) preserves the classic puzzle space but is
   physically odd. Is the "inventory scanner / fabricator" fiction enough to sell it, or do
   we want move semantics and a redesigned puzzle set? **Prototype both in Milestone 1** —
   this is the single most load-bearing unresolved decision in the design.
3. **`THROW AT` as mechanic vs. flavor.** Making it a cheaper step is a real optimization
   lever, but it adds a spatial cost model players must learn. Introduce in Act 4, or keep it
   as pure flavor?
4. **How explicit is the reveal?** The current plan keeps it almost entirely in UI drift
   (P5). Playtest whether players who skip dialogue actually get it, then add exactly as much
   text as the data demands — no more.
5. **Call skippability.** Skipping is required for replays, but the calls carry the story.
   Proposal: never skippable on first view, always skippable after, and Brent looks visibly
   hurt the first time you skip him.
6. **Overtime framing.** "Volunteer shifts" is the funniest option and also the one most
   likely to read as endorsement. Alternative: they're the *previous* operator's unfinished
   tickets.
