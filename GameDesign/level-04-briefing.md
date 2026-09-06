# Level 4 — "Positives Only"

**Act:** 1 · ONBOARDING · **Position:** 4 of 8 · **ID:** `a1_l04_positives_only`
**Status:** Spec ready for Milestone 1 vertical slice
**Companion docs:** [game-design-document.md](game-design-document.md) ·
[level-01-briefing.md](level-01-briefing.md) · [program-editor.md](program-editor.md)

> **Re-cut** for the numeric vocabulary (§6.2–6.3). This level used to filter on
> `IF TYPE IS BLUE`; it now filters on `IF POSITIVE`. Everything else about it — the discard
> lesson, the six-shipment set, the reference solution's shape, the pars, the adversarial
> suite, and every one of the three counting rules in §5.1 — survived the change with the
> numbers swapped in. The predicate was never what this level was about.

---

## 4.0 Where this sits

| Level | Teaches | New commands |
|---|---|---|
| 1 | a program is a list, run top to bottom | `TAKE`, `SHIP` |
| 2 | you don't write the list, you write the rule | `REPEAT` |
| 3 | packages have values, and values can be compared | `IF` (+ the six conditions) |
| **4** | **not every package gets shipped** | *(none — this is a synthesis level)* |
| 5 | packages can be held somewhere other than the claws | `COPY TO`, `COPY FROM` |

Level 4 introduces **no new command.** It is a **Synthesizer** (§8.1): the first level where
`REPEAT` and `IF` have to be used *together*, and the first where the correct answer involves
UNIT-02 deliberately destroying something.

Level 3 taught the player to *read* a condition — a program with an `IF` where every package
happened to satisfy it. Level 4 is the first time the `IF` is load-bearing: the shipment
contains packages that must not be shipped, and there is no command for "throw this away."

---

## 1. Purpose

### What it teaches
- **The filter shape.** `REPEAT { TAKE; IF cond { SHIP } }` — the single most reused program
  shape in the game. Every later level either contains this or contains something built on it.
- **Discarding by taking.** There is no `DISCARD` command (§6.3). The only way to get rid of a
  package you're holding is to `TAKE` the next one, which destroys it. The player has to
  *notice* that the program they already wrote does this, and that it's correct.
- **Zero is not positive.** The condition family says exactly what it says. A shipment
  containing `0` separates the player who read `IF POSITIVE` from the player who read "if it's
  a number that isn't negative."
- **The shift can end with something still in the claws** — and that can be right.

### What it must NOT do
- **No arithmetic.** `SUM` and `SUB` exist in the language but not on this note. The discard
  rule is subtle enough to deserve a level with nothing else in it; arithmetic lands at
  level 6, once the filter shape is muscle memory.
- **No pallets.** `COPY TO` / `COPY FROM` arrive next level. The floor stays empty.
- **No nesting past one level.** The `IF` sits inside the `REPEAT` and nothing sits inside the
  `IF` but a single `SHIP`.
- **No optimization pressure.** The reference solution is the shortest solution and there is no
  second shape (see §6.2).

---

## 2. The call

Brent, portrait framing, same home office, later in the day. Three lines.

> **BRENT:** Okay so — inventory sent up a mixed batch. Some of those numbers are junk.
>
> **BRENT:** Anything positive, ship it. Anything else, I don't want to see it. Not on the
> belt, not on the floor, gone.
>
> **BRENT:** I'd tell you how to get rid of them but honestly? You'll figure it out. That's
> why we hired you, champ.

Notes for the writer:
- Line 2 states the rule in the player's language — *"anything positive"* — which is the exact
  wording of the condition on the note. It is not a puzzle to translate the brief into a
  program; the puzzle is the *shape*.
- Line 2 says "anything else," not "anything negative." Zero is anything else. Brent doesn't
  point at it, and the player finding out the hard way on shipment `s1` is the lesson.
- Line 3 is the level's only hint, and it is deliberately not a hint. Brent does not know how
  discarding works. Nobody at this company knows how anything works.
- "champ" again. Fourth time. Keep the count — it matters in Act 5.

**Task Card:**

> Ship the positive packages. Nothing else.

---

## 3. Input — the shipment set

Six shipments, one rolled at random when the level opens (§8.5). Every one of them is a real
test: §7.2 shows that four different *wrong* programs each pass at least one member of this
set, which is why the set has six members and not two.

```
SHIPMENT SET — 1 of 6, rolled on open
```

| Shipment | Intake, in order | Len | Positives | Role |
|---|---|---|---|---|
| `s1` | `-4` `7` `0` `3` `9` `-1` | 6 | 3 | **par shipment.** Typical, and the longest. Mixed signs, a zero in the middle, ends on a rejected package. |
| `s2` | *(empty)* | 0 | 0 | Empty intake. The loop must survive zero iterations. |
| `s3` | `-5` `0` `-2` | 3 | 0 | Nothing to ship. Outbound must end empty and that is a **pass**. |
| `s4` | `2` `8` `5` | 3 | 3 | Nothing to reject. A ship-everything program passes this one — see §7.2. |
| `s5` | `6` `-3` `0` `4` | 4 | 2 | Boundary: positive first *and* last. Catches off-by-one programs that skip the first or last package. |
| `s6` | `-7` | 1 | 0 | Single rejected package. **The shift ends with it still in the claws** — see §5.3. |

`parShipment: s1`

### Why the zeros

Three of the six shipments contain `0`, and that is the level's sharpest edge. A player who
writes `IF NOT NEGATIVE` — a perfectly reasonable reading of "anything positive" if you're
moving fast — has a program that is correct on `s4`, correct on `s6`, correct on `s2`, and
**wrong on `s1`, `s3` and `s5`.** The failure is one box in outbound that shouldn't be there,
and the fix is one tap on a cyclable word.

That is the best possible shape for a mistake in Act 1: cheap to make, instantly legible in
the failure message, and one gesture to repair.

**FLOOR:** no pallets.
**OUTBOUND:** empty.
**UNIT-02:** idle, claws empty.

---

## 4. Expected output

**OUTBOUND** must contain the positive packages of the rolled shipment, in intake order.

| Shipment | Expected outbound |
|---|---|
| `s1` | `7` `3` `9` |
| `s2` | *(empty)* |
| `s3` | *(empty)* |
| `s4` | `2` `8` `5` |
| `s5` | `6` `4` |
| `s6` | *(empty)* |

Nothing may remain on intake. **Something may remain in the claws** (§5.3).

Written as a derived expression rather than six literal lists, per §13.2:

```
goal.outbound = shipment.intake.where(value > 0)
```

---

## 5. Rules in play

| Rule | Behaviour here |
|---|---|
| `TAKE` with claws full | **The held package is discarded.** One step. No failure. This is the level. |
| `TAKE` with intake empty | **The shift ends**, successfully, and the goal is checked. |
| `TAKE` with intake empty *and* claws full | **The shift ends. The held package is not discarded** — see below. |
| `IF POSITIVE` with a package held | Compares the held value against zero. `> 0` enters the body. |
| `IF` with empty claws | **Failure.** See §5.2. |
| `REPEAT` | Loops its body forever. The only exits are an empty `TAKE` or the end of the program. |
| Program runs past its last instruction | The shift ends and the goal is checked. |

### The ordering that matters

When `TAKE` finds an empty intake *while the claws are full*, the shift-end wins and the held
package survives. The alternative ordering — discard, then end — would leave `s6` finishing
with empty claws, which is a difference nobody would ever see in the outbound but which
changes what UNIT-02 is holding in the end-of-shift animation. **The robot is standing there
holding the rejected package when the screen dims**, and that image is worth more to the
lesson than any wording in the failure text. Lock the ordering in the VM and test it; it is
one line and it is easy to get backwards.

### 5.1 Counting: what SIZE and SPEED actually count

Three rules, all of which have bitten before, none of which are about this level specifically.

1. **SIZE counts command rows. Closers are free.** A container is one row, not two: the `END`
   that closes a `REPEAT` is not a command the player placed — the editor has no `END` to
   place (see [program-editor.md](program-editor.md)). Counting it would make loops look more
   expensive than they are and would punish the exact shape this level exists to teach.

2. **SPEED counts robot actions.** Structure is free; work costs one step each.

   | Costs 1 | Costs 0 |
   |---|---|
   | `TAKE` | `REPEAT` |
   | `SHIP` | `REPEAT WHILE` |
   | `COPY TO` | `IF` |
   | `COPY FROM` | *(loop back-edge)* |
   | `SUM` | *(container close)* |
   | `SUB` | |

   The rule is physical, not syntactic: a step is a thing the player watches the robot do.
   Deciding is free because deciding has no animation.

3. **The infinite-loop guard counts instructions, not steps.** This is the one that is a bug
   rather than a design choice, and it is stated here because this is the first level where a
   `REPEAT` can spin without doing anything.

   A program of `REPEAT { IF POSITIVE { } }` with a package held executes forever while its
   *step* count stays frozen at whatever it was. A guard that watches SPEED never trips, the
   frame never advances, and the app hangs — on a phone, with no console, in front of a
   playtester. **Count executed instructions**, cap them at something generous (100k), and
   fail with *"UNIT-02 got stuck in a loop."*

   Test it explicitly. Adversarial case 9 in §7.1 exists for exactly this.

### 5.2 A condition with empty claws is a failure

`IF POSITIVE` asks about the package UNIT-02 is holding. With nothing in the claws there is no
question to answer, so the program fails rather than picking a branch.

The alternative — treating empty claws as false — is worse in a way that is invisible: the
program keeps running and produces a wrong shipment several seconds later, and the player has
to work backwards from a missing box to a condition that quietly answered a question nobody
asked. Failing at the instruction puts the error where the mistake is.

Message: *"UNIT-02 checked what it was holding. It wasn't holding anything."*

This is reachable here by putting the `IF` above the `TAKE` inside the loop — adversarial
case 5, and a likely first attempt for a player who thinks in terms of "check, then fetch."

### 5.3 `requireHandsEmpty` must be **false**

Shipment `s6` is a single rejected package. The correct program takes it, declines to ship it,
loops, calls `TAKE` on an empty intake, and the shift ends **with `-7` still in the claws.**

If the goal required empty hands, the reference solution would fail its own level on one
shipment in six — a bug that appears once every six plays, in a random level roll, on a
program the player has every reason to believe is right. That is close to the worst failure
mode a puzzle game can ship.

```json
"requireHandsEmpty": false
```

Level 1 sets it `true`, because there it is a real check (§7 case 3). It is a per-level flag
for exactly this reason, and level 4 is the level that proves the flag has to exist.

---

## 6. Reference solution

```
REPEAT
    TAKE
    IF POSITIVE
        SHIP
```

Four rows.

### 6.1 Step trace, shipment `s1` (`-4 7 0 3 9 -1`)

| Step | Instruction | Claws | Intake left | Outbound | Note |
|---|---|---|---|---|---|
| 1 | `TAKE` | `-4` | 7 0 3 9 -1 | — | |
| — | `IF POSITIVE` | `-4` | | | false, skip |
| 2 | `TAKE` | `7` | 0 3 9 -1 | — | **`-4` discarded** |
| — | `IF POSITIVE` | `7` | | | true |
| 3 | `SHIP` | empty | 0 3 9 -1 | 7 | |
| 4 | `TAKE` | `0` | 3 9 -1 | 7 | |
| — | `IF POSITIVE` | `0` | | | **false — zero is not positive** |
| 5 | `TAKE` | `3` | 9 -1 | 7 | `0` discarded |
| — | `IF POSITIVE` | `3` | | | true |
| 6 | `SHIP` | empty | 9 -1 | 7 3 | |
| 7 | `TAKE` | `9` | -1 | 7 3 | |
| — | `IF POSITIVE` | `9` | | | true |
| 8 | `SHIP` | empty | -1 | 7 3 9 | |
| 9 | `TAKE` | `-1` | — | 7 3 9 | |
| — | `IF POSITIVE` | `-1` | | | false |
| 10 | `TAKE` | `-1` | — | 7 3 9 | intake empty → **shift ends, still holding `-1`** |
| | | | | **7 3 9 ✓** | |

Steps 2 and 5 are the whole lesson: the discard is not an instruction the player wrote, it is
a *consequence* of the instruction they wrote. Both must clang.

### 6.2 There is exactly one correct shape

An earlier draft of this level discussed an `ELSE`-based variant. `ELSE` was cut from the
language (§6.3), and with it went the only alternative solution: with no `ELSE` and no
`DISCARD`, the only way to get rid of a package is to take the next one, and the only way to
take the next one is to reach the top of the loop. Every correct program is the reference
solution modulo dead rows.

This is unusual and it is fine here. Level 4 is a Synthesizer, not a Toy (§8.1) — its job is
to make one shape automatic, and a level with one answer makes that answer stick. The levels
with a design space are 6, 7 and 8.

It does mean the pars are **not a challenge**, they are a confirmation. Both are awarded on
any correct clear, exactly as in level 1.

### 6.3 Pars

| | `s1` (par shipment) |
|---|---|
| `SIZE` | **4** |
| `SPEED` | **10** steps |

SPEED on the reference solution generalises to:

```
speed = len + 1 + positives
```

One `TAKE` per package, one final `TAKE` that ends the shift, one `SHIP` per positive.

| Shipment | Len | Positives | Steps |
|---|---|---|---|
| `s1` | 6 | 3 | **10** |
| `s2` | 0 | 0 | 1 |
| `s3` | 3 | 0 | 4 |
| `s4` | 3 | 3 | 7 |
| `s5` | 4 | 2 | 7 |
| `s6` | 1 | 0 | 2 |

Pars are stated against the par shipment only (§8.2). SPEED varies with the roll, so the
shift-complete card compares against `s1`'s numbers and a player who rolled `s3` sees a
smaller step count than par. That is not a bug and must not read as one: the card shows the
par shipment's figure with the rolled shipment's beside it.

---

## 7. Failure cases and the CI suite

### 7.1 The adversarial programs

Ten programs, each run against **all six shipments** — sixty executions in `dart test` (§13.2).
A program passes the level only if it passes all six.

| # | Program | Passes | Fails | Why it matters |
|---|---|---|---|---|
| 1 | `REPEAT { TAKE; IF POSITIVE { SHIP } }` | **all 6** | — | reference solution |
| 2 | `REPEAT { TAKE; SHIP }` | `s4` | `s1 s2 s3 s5 s6` | ships everything. On `s2`, `SHIP` with empty claws → clean failure. |
| 3 | `REPEAT { TAKE }` | `s2 s3 s6` | `s1 s4 s5` | ships nothing. Passes half the set. |
| 4 | `TAKE; IF POSITIVE { SHIP }` | `s2 s6` | `s1 s3 s4 s5` | no loop — one package only. `s3` fails on intake-not-empty. |
| 5 | `REPEAT { IF POSITIVE { SHIP }; TAKE }` | — | all 6 | condition before take → §5.2 failure on step 1, every shipment. |
| 6 | `REPEAT { TAKE; IF NOT NEGATIVE { SHIP } }` | `s2 s4 s6` | `s1 s3 s5` | **ships the zeros.** The level's signature wrong answer. |
| 7 | `REPEAT { TAKE; IF NOT ZERO { SHIP } }` | `s2 s4` | `s1 s3 s5 s6` | ships the negatives. |
| 8 | `REPEAT { TAKE; IF POSITIVE { SHIP }; SHIP }` | — | all 6 | double ship → empty-claws failure. |
| 9 | `REPEAT { IF POSITIVE { } }` | — | all 6 | **fails on §5.2 before it can spin.** Pair with case 10. |
| 10 | `TAKE; REPEAT { IF POSITIVE { } }` | — | all 6 | claws full, condition legal, body empty, no `TAKE` — **the infinite loop.** Must trip the instruction guard (§5.1 rule 3), not hang. This test is the reason rule 3 is written down. |

Case 10 is the single most important test in this file. It is the only program in Act 1 that
can hang the app, and a SPEED-based guard passes every other case here while failing this one
silently — by locking up the device.

### 7.2 Why the shipment set needs all six members

The set is not decoration. Cross-referencing §7.1:

| Wrong program | Passes | Only caught by |
|---|---|---|
| ships everything (#2) | `s4` | any shipment with a non-positive |
| ships nothing (#3) | `s2 s3 s6` | any shipment with a positive |
| no loop (#4) | `s2 s6` | any shipment of length ≥ 2 |
| **ships the zeros (#6)** | `s2 s4 s6` | **only `s1`, `s3`, `s5` — the shipments containing `0`** |

Drop the zeros and program #6 clears the level. Drop `s4` and "ship everything" survives longer
than it should in playtest. Drop `s6` and `requireHandsEmpty` never gets exercised, and the bug
in §5.3 ships.

**QA card for this level:** run all four wrong programs above, on all six shipments, before
sign-off. If any of them passes the level, either the goal expression or the shipment set has
regressed.

### 7.3 Player-facing messages

| Situation | Message |
|---|---|
| shipped a non-positive | *"UNIT-02 shipped a package Brent didn't want: `0`."* — name the value. |
| missed a positive | *"UNIT-02 was supposed to ship `9`. It didn't."* |
| shift ended with intake non-empty | *"The shift ended with 4 packages still on intake."* |
| `SHIP` with empty claws | *"UNIT-02 tried to ship, but its claws were empty."* |
| `IF` with empty claws | *"UNIT-02 checked what it was holding. It wasn't holding anything."* |
| instruction guard tripped | *"UNIT-02 got stuck in a loop."* |

Every message names a **value** where it can. The player's whole model of this level is "which
numbers went where," and a message that says "the shipment was wrong" throws that away.

---

## 8. Level file

```json
{
  "id": "a1_l04_positives_only",
  "act": 1,
  "index": 4,
  "title": "Positives Only",
  "taskCard": "Ship the positive packages. Nothing else.",
  "call": "a1_l04_call",

  "shipments": [
    { "id": "s1", "intake": [-4, 7, 0, 3, 9, -1] },
    { "id": "s2", "intake": [] },
    { "id": "s3", "intake": [-5, 0, -2] },
    { "id": "s4", "intake": [2, 8, 5] },
    { "id": "s5", "intake": [6, -3, 0, 4] },
    { "id": "s6", "intake": [-7] }
  ],
  "parShipment": "s1",

  "pallets": [],

  "allowedCommands": ["TAKE", "SHIP", "REPEAT", "IF"],
  "allowedConditions": [
    "ZERO", "NOT ZERO",
    "POSITIVE", "NOT POSITIVE",
    "NEGATIVE", "NOT NEGATIVE"
  ],

  "goal": {
    "outbound": "shipment.intake.where(value > 0)",
    "requireIntakeEmpty": true,
    "requireHandsEmpty": false,
    "requireHandsEmptyReason": "s6 correctly ends holding a rejected package. See §5.3."
  },

  "pars": { "size": 4, "speed": 10 },

  "referenceSolution": [
    { "cmd": "REPEAT", "body": [
      { "cmd": "TAKE" },
      { "cmd": "IF", "arg": "POSITIVE", "body": [ { "cmd": "SHIP" } ] }
    ]}
  ]
}
```

Three notes:

- **`allowedCommands` omits `REPEAT WHILE`, `COPY TO`, `COPY FROM`, `SUM`, `SUB`.** They exist
  in the language; they are not on this level's note. `REPEAT WHILE` in particular is a
  tempting inclusion — it isn't, because the exit condition here is "intake ran out," which is
  not a condition about a held value and cannot be written as one.
- **`allowedConditions` is the full family**, deliberately. Restricting it to `POSITIVE` would
  delete the level's best mistake (§3, and case 6 in §7.1). The cyclable word is the puzzle.
- **`requireHandsEmptyReason`** is a comment that survives into the file on purpose. The next
  person to see a level end with a package in the claws will assume it's a bug.

---

## 9. Portrait layout

Opens in **Balanced** snap state (§7.1) rather than Program-focused: the discard is a floor
event and the player has to be able to see it happen. This is the first level where the top
pane is worth more than the extra program rows.

```
┌───────────────────────────┐
│  TASK                     │
│  Ship the positive         │
│  packages. Nothing else.[i]│
├───────────────────────────┤
│   ▼ ▼ ▼  intake    ▶ RUN  │
│  ┌──┐┌──┐┌──┐             │
│  │-4││ 7││ 0│    🤖       │   floor, 50% — the bin is
│  └──┘└──┘└──┘      ┌───┐  │   visible, and used
│                    │🗑 │  │
│                    └───┘  │
│              outbound ▶   │
├──────────── ⌃⌄ ───────────┤
│ ╎     ┌─────────────┐  🖇 │
│ ╎     │ REPEAT      │     │   containers are notes,
│ ╎     │  ┌────────┐ │     │   glued at the top
│ ╎     │  │ TAKE   │ │     │
│ ╎     │  ├─────────┴──┐   │
│ ╎     │  │ IF POSITIVE│   │
│ ╎     │  │  ┌───────┐ │   │
│ ╎     │  │  │ SHIP  │ │   │
│ ╎     │  │  └───────┘ │   │
│ ╎     │  └────────────┘   │
│ ╎     └─────────────────┘  │
│ ╎  ┌──────┬──────┬──────┐ │   the note: four commands,
│ ╎  │ TAKE │ SHIP │REPEAT│ │   one row
└───┴──────┴──────┴───IF───┴┘
```

`POSITIVE` is a cyclable word inside the `IF` row: tapping it walks the six conditions in
order. See [program-editor.md](program-editor.md) §3 for the chip's behaviour and target size.

### UX beats
1. **The bin gets an entrance.** It is on the floor from level 1 but nothing has ever gone into
   it. The first discard of this level should be the first time the camera has any reason to
   care about it — a small shake, and the sound is not reused from anything else.
2. **The rejected package is visible in the claws at shift end** on `s3`, `s5` and `s6`. UNIT-02
   does its end-of-shift wave while still holding it. Do not add a tidy-up animation; the
   image is the lesson (§5).
3. **No hint system fires on the condition.** A player stuck on `NOT NEGATIVE` vs `POSITIVE`
   gets the failure message naming the zero, and that is enough. If playtest says otherwise,
   fix the message, not the level.

---

## 10. Playtest criteria

1. **4 of 5** players reach a correct program within 4 minutes of the call ending.
2. **At least 2 of 5 discover the discard by accident** — write the reference solution without
   having thought about where the rejects go, then notice the bin firing during the run. If
   nobody does, the discard is too quiet.
3. **Every player who triggers a discard can explain afterwards what happened to the package.**
   This is the criterion that fails if the audio or the animation is wrong, and it is the one
   worth re-running after any change to the run view.
4. **At least 1 of 5 writes `NOT NEGATIVE` first.** If nobody does, the zeros are doing nothing
   and the shipment set can be simplified. If *everybody* does, the condition names are
   ambiguous and §6.3 needs another look.
5. **Nobody hangs the app.** If any playtester reproduces case 10 in §7.1 and the device locks,
   the level does not ship.
6. **No player asks for a "throw away" command after clearing the level.** Before clearing is
   fine and expected; after clearing means the discard never landed as an idea.

---

## 11. Open items

1. **Whether `s2` (empty intake) is fun or just correct.** It is a real edge case and the loop
   must survive it, but a player who rolls it sees a shift that lasts one step and ends. Worth
   deciding whether empty shipments should be excluded from the *first* roll of a level and
   only appear on replays.
2. **Whether the par card should show both figures** (par-shipment SPEED and rolled-shipment
   SPEED) or normalise. See §6.3 — the current answer is "show both," untested.
3. **Whether the discard needs a one-time diegetic line** the first time it fires in the game.
   Currently no. Brent saying *"...huh. Okay, that works"* over the bin clang is tempting and
   is probably one line too many.

**Resolved since first draft:**
- *`ELSE` variant of the solution* → `ELSE` was cut from the language. There is exactly one
  correct shape now (§6.2), which suits a Synthesizer.
- *Type-based predicate* → replaced by `IF POSITIVE`. The level's structure was independent of
  it, which is why this rewrite touched the numbers and almost nothing else.
- *Where the zeros go* → three of six shipments carry one, and §7.2 shows they are the only
  thing standing between the player and a wrong program that passes.
