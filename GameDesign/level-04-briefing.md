# Level 4 — "Blues Only"

**Act:** 1 · ONBOARDING · **Position:** 4 of 8 · **ID:** `a1_l04_blues_only`
**Status:** Spec ready · outside the Milestone 1 slice (slice is levels 1–3)
**Companion docs:** [game-design-document.md](game-design-document.md) ·
[level-01-briefing.md](level-01-briefing.md)

---

## 1. Purpose

This is the **discard level**. It is the first puzzle where the correct program has to get rid
of a package, and it teaches the discard rule (§6.3) in the best possible way: by making the
*intuitive* program the correct one.

The player's instinct is "if it's not blue, do nothing with it." That instinct is exactly
right — the next `TAKE` throws the unwanted package away on its own. There is nothing to
write. The lesson is a subtraction, and the recycling bin does the teaching.

### Assumed prior levels
| Level | Taught |
|---|---|
| 1 | `TAKE`, `SHIP`, programs run top to bottom |
| 2 | `REPEAT` / `END`, variable-length shipments, `TAKE` on empty intake ends the shift |
| 3 | `IF TYPE IS` / `ELSE` / `END` |

### What it teaches
- Packages you don't want need no handling. Take the next one; the old one goes in the bin.
- A conditional that has **no `ELSE`** — the first time "do nothing" is a valid branch.
- Output length is no longer input length. Three levels have trained "one in, one out," and
  this is where that assumption breaks.

### What it must NOT do
- No new command in the tray. `IF TYPE IS` arrived in level 3; this level adds a *pattern*, and
  §8.1 forbids introducing a command and a pattern together.
- No arithmetic, no pallets, no weights.
- No level where the discard is *optional*. If a player can clear this by routing packages
  cleverly instead of dropping them, the level has failed at its one job.

### ⚠ A note on level ordering
§8.3 lists Act 1's sample beats as *"ship everything; ship everything forever; ship only the
blues; ship two greens per blue"*, which reads as this level being **3rd**. This briefing puts
it **4th**, with level 3 introducing `IF TYPE IS` on a non-discarding task (*"ship everything,
but ship blues twice"*).

The reason is §8.1's Teacher rule: combining a brand-new conditional with a brand-new discard
idiom in one level is exactly the "new command + new pattern" pairing the doc rules out. Split
in two, each level has one idea. §14's slice (three levels ending at `IF TYPE IS`) is
unaffected. Flagging it because it contradicts a written beat list — easy to reorder if you
disagree, and level 1's briefing plus §6.3 both already reference "Act 1 level 4" as the
discard level.

---

## 2. The call

Brent, portrait framing, home office. Six lines — longer than level 1's four, because by now
the player is fluent in the call UI and skipping is enabled.

> **BRENT:** Morning! Okay, slight change of pace today.
>
> **BRENT:** Batch coming in is mixed. Blues, greens, reds, whatever else procurement felt
> like. We only want the blues going out.
>
> **BRENT:** Everything else? Not our problem. There's a bin down there — have the unit just
> grab the next one and let the old one go. It'll figure it out.
>
> **BRENT:** And don't worry about telling it when to stop. It stops when the chute runs dry.
> Union thing. Long story.
>
> **BRENT:** Oh, and heads up, the batches aren't the same size every day. Some days it's all
> blue, some days there's not a single one. Write it so it just... handles that.
>
> **BRENT:** Honestly the unit's picking this up fast. Faster than I did.
>
> **BRENT:** Anyway. Blues only. Thanks champ.

Notes for the writer:
- Line 3 introduces the recycling bin **diegetically**, in the level where it first matters.
  This is the game's only explanation of the discard rule, so it has to be in the call, not a
  tooltip (§9.7).
- Line 4 is load-bearing: it tells the player, out loud, that the shipment varies — including
  the two degenerate cases in the set. A player who meets the QUALITY ASSURANCE card here
  (§8.5) should be able to remember being warned.
- Line 5 is the **first seed of the whole story.** It's a throwaway compliment and it means
  nothing yet. It should be delivered as filler, not as a beat — no music change, no pause.
  It is the earliest point in the game where the theme is on screen.
- "champ" again. Same nickname, every act, unchanged (see level 1 §2).

**Task Card:**

> Ship only the BLUE packages.

---

## 3. Input — the shipment set

Six authored shipments (§8.5). The player has `REPEAT` and `IF TYPE IS`, so per the axis table
this level may vary **length, type composition, and order** — all three.

| ID | Role | Intake, in order | Len | Expected outbound |
|---|---|---|---|---|
| `s1` | **typical / max length** · `parShipment` | `RED` `BLUE` `GREEN` `BLUE` `BLUE` `RED` | 6 | `BLUE` ×3 |
| `s2` | **degenerate** — empty batch | *(nothing)* | 0 | *(nothing)* |
| `s3` | **adversarial** — no blues at all | `RED` `GREEN` `RED` | 3 | *(nothing)* |
| `s4` | **adversarial** — nothing but blues | `BLUE` ×5 | 5 | `BLUE` ×5 |
| `s5` | **boundary** — blue first *and* last | `BLUE` `RED` `RED` `BLUE` | 4 | `BLUE` ×2 |
| `s6` | **degenerate** — one package, rejected | `RED` | 1 | *(nothing)* |

Each earns its place against a specific wrong solution:

- **`s2` / `s6`** break "there is always something to ship." `s6` additionally leaves UNIT-02
  holding a package at shift end, which is the case that catches a mis-set `requireHandsEmpty`
  (§5).
- **`s3`** breaks any program that ships unconditionally, and is the only shipment where the
  correct answer is *nothing at all* from a non-empty batch. Expect playtesters to be
  genuinely unsettled by a correct empty outbound; that discomfort is the level working.
- **`s4`** breaks inverted conditionals — a program that reads `IF TYPE IS RED → discard` looks
  right on `s1` and collapses when the batch has no reds to key off.
- **`s5`** breaks off-by-one loop structures in both directions: a blue at index 0 catches
  "take one before the loop starts," and a blue at the last index catches "the loop exits one
  iteration early."
- **`s1`** is the one tuned for the teaching moment — enough non-blues to make the bin fire
  three times, mixed enough that the pattern is visible, longest in the set so fixed-count
  unrolling fails.

`singleShipment` is **absent** here (unlike level 1). The verifier's auto-generated
transcription of `s1` must fail — it fails `s2` immediately on length — so the anti-hardcoding
check is live and non-vacuous (§13.2).

**FLOOR:** no pallets. The **recycling bin** is visible for the first time, downstage, and it
is the only new thing on the floor.
**OUTBOUND:** empty.
**UNIT-02:** idle, claws empty.

---

## 4. Expected output

The goal is a **rule**, not a list (§13.2):

> outbound == the BLUE packages from this shipment, in their original relative order

Written derived in the level file as `shipment.intake.where(type == BLUE)`. Every entry in the
table above is that expression evaluated, not an independently authored answer — which is what
makes adding a seventh shipment a one-line change.

Order **is** checked here, unlike level 1: the blues are indistinguishable from each other, but
a program that reversed or duplicated them would produce a wrong-length or wrong-position
outbound against `s1` and `s5`. This is the first level whose validator has real coverage.

---

## 5. Rules in play

| Rule | Behaviour here |
|---|---|
| `TAKE`, claws empty, intake non-empty | Robot catches the next package. |
| **`TAKE`, claws full** | **The held package is discarded** into the bin — one step, no failure (§6.3). This is the level's whole subject. |
| `TAKE`, intake empty | The shift ends successfully. **This is the only loop exit that exists** (§6.6) — there is no way to ask whether the intake is empty, so the reference solution's `REPEAT` is deliberately never closed by the player. |
| `SHIP`, claws full | Package goes to outbound. |
| `SHIP`, claws empty | Failure. |
| `IF TYPE IS <t>`, claws full | Compares the held package's type. |
| **`IF TYPE IS <t>`, claws empty** | **Failure** — see §5.2. |
| `IF` with no `ELSE` | The skip branch does nothing and falls through to `END`. First appearance. |
| Program runs past its last instruction | Shift ends, goal checked. Unreachable inside `REPEAT`. |
| Instruction guard | 2,000 *instructions* (not steps — see §5.1). Unreachable with a correct solution. |

**Tray contents:** `TAKE`, `SHIP`, `REPEAT`, `IF TYPE IS [type]` — four buttons, plus `ELSE` as
an option on any placed `IF`. **The tray does not scroll** (§6.6).

### 5.1 Three counting rules this level forces us to pin down

The GDD defines `SIZE` and `SPEED` (§8.2) but not how to count them, and level 1 had no blocks
so it never came up. Level 4 is the first level where the answer changes the numbers.
**Proposed, needs back-porting to §8.2:**

1. **`SIZE` counts command rows. Block closers are free.** `REPEAT` and `IF` each cost 1;
   their `END`s and any `ELSE` cost 0. Rationale: closers are auto-inserted as a matched pair
   (§6.4) and were never separately authored, so charging for them would penalise the
   structured-block model against the flat-jump model it replaced — and would make our `SIZE`
   numbers incomparable to the genre's.
2. **`SPEED` counts robot actions only.** `TAKE`, `SHIP`, `STACK ON`, `PICK FROM`, `MERGE`,
   `STRIP`, `PAD`, `TRIM`, `THROW` cost 1 step each. `REPEAT`, `IF`, `END`, `ELSE` and
   `CLOCK OUT` cost 0. Rationale: `SPEED` is UNIT-02's working day, which is what the fiction
   measures and what the player is actually optimising. It also keeps `SPEED` stable if we
   ever change how control flow compiles.
3. **The infinite-loop guard counts instructions, not steps.** Consequence of rule 2: an
   empty `REPEAT / END` performs no robot actions, so a step-based guard would never fire and
   the app would hang. The guard needs its own counter. **This is a real bug avoided, not a
   style preference** — write it into the VM spec.

A `TAKE` that ends the shift by finding the intake empty **does** cost a step: the robot walked
to the chute. This matters — it's what creates the par tension in §6.

### 5.2 Package conditions with empty claws

Also unspecified in the GDD, and reachable here for the first time (a player who puts
`IF TYPE IS BLUE` before `TAKE`).

**Proposed: it is a failure**, not a silently-false comparison.

> *"UNIT-02 checked what it was holding. It wasn't holding anything."*

Silent-false would let a broken program limp along and fail much later with an unrelated
symptom, which violates P4. A hard stop at the offending instruction is honest and teaches the
ordering in one attempt — and the fix is to move the `TAKE`, which is the thing the player needs
to learn.

(This was previously justified by pointing at `HANDS ARE EMPTY` as the safe alternative. That
condition is now itself under review (§6.6) and cannot be leaned on. The failure message has to
stand on its own, which it does: it names what UNIT-02 did and why it couldn't.)

### 5.3 `requireHandsEmpty` must be **false**

On `s6` (a single `RED`), the correct program takes it, doesn't ship it, loops, and the next
`TAKE` ends the shift with the `RED` **still in UNIT-02's claws**. Perfectly correct. If this
level inherited level 1's `requireHandsEmpty: true`, the reference solution would fail.

Level 1 set it `true` harmlessly, since there everything must ship. **The field's default
should be `false`**, and level 1's `true` should be understood as redundant belt-and-braces
rather than the norm. Worth simplifying when the schema is locked.

---

## 6. Reference solution

Four command rows. No `ELSE`, and no loop guard — because none exists (§6.6). The `REPEAT` is
never closed by the player; the shift ends when `TAKE` finds the chute empty.

```
1  REPEAT
2    TAKE
3    IF TYPE IS BLUE
4      SHIP
5    END
6  END
```

`SIZE 4` (rows 5 and 6 are free closers, §5.1).

### Step trace — shipment `s5` (`BLUE` `RED` `RED` `BLUE`)

Traced on `s5` rather than `s1` because it's shorter and fires the bin twice.

| Step | Instruction | UNIT-02 does | Claws | Intake left | Outbound |
|---|---|---|---|---|---|
| — | *(start)* | idle | empty | B R R B | — |
| 1 | `TAKE` | catch | `BLUE` | R R B | — |
| — | `IF TYPE IS BLUE` | *(true)* | `BLUE` | R R B | — |
| 2 | `SHIP` | toss to belt | empty | R R B | B |
| 3 | `TAKE` | catch | `RED` | R B | B |
| — | `IF TYPE IS BLUE` | *(false, skip)* | `RED` | R B | B |
| 4 | `TAKE` | **bin the RED**, catch | `RED` | B | B |
| — | `IF TYPE IS BLUE` | *(false, skip)* | `RED` | B | B |
| 5 | `TAKE` | **bin the RED**, catch | `BLUE` | — | B |
| — | `IF TYPE IS BLUE` | *(true)* | `BLUE` | — | B |
| 6 | `SHIP` | toss to belt | empty | — | B B |
| 7 | `TAKE` | walk to chute — **empty** | empty | — | B B |
| — | *(shift ends)* | wave | empty | — | **B B ✓** |

Steps 4 and 5 are the level. The player wrote nothing to make them happen.

### The variant that is also correct

`ELSE` may be placed and left empty. It changes nothing:

```
1  REPEAT
2    TAKE
3    IF TYPE IS BLUE
4      SHIP
5    ELSE
6    END
7  END
```

Same `SIZE 4` (`ELSE` is a free closer, §5.1), same `SPEED`, same result. Worth having in the
adversarial suite as a **PASS**: a player who reaches for `ELSE` and finds it does nothing has
learned that "do nothing" is a real branch, which is one of this level's stated lessons.

### Pars

Measured on `parShipment: s1` (`RED BLUE GREEN BLUE BLUE RED`, 3 blues).

| | Value |
|---|---|
| `SIZE` | **4** |
| `SPEED` | **10** steps — 7 `TAKE` (the last finds the chute empty) + 3 `SHIP` |

**Both pars are met by the reference solution.** There is exactly one shape of correct program
here, and it is simultaneously the smallest and the fastest.

This is a change from an earlier draft, and the change is an improvement worth recording. With
`IF INTAKE IS EMPTY` in the tray, this level had two solutions — the four-row one, and a
six-row one that spent two rows to skip the final wasted walk to the chute — giving mutually
exclusive pars of `SIZE 4` / `SPEED 9`. That looked like the §8.2 *"two ways to be a good
employee"* tension arriving early. It wasn't. It was an artifact of a redundant command: the
player wasn't choosing between two strategies, only between writing a guard and not writing
one. Cutting the condition (§6.6) removed the fake tension. **The real `SIZE`/`SPEED` conflicts
should come from genuinely different algorithms, and those live in Act 3 and later.**

`SPEED` for the reference solution across the whole set, for the record: `s1` 10 · `s2` 1 ·
`s3` 4 · `s4` 11 · `s5` 7 · `s6` 2. It is `len + 1 + (number of blues)` in every case.

---

## 7. Adversarial suite

Per §13.2 CI runs **every program × every shipment**. This table is the spec for that cross
product; `✓` = clears, `✗` = fails.

| # | Program | s1 | s2 | s3 | s4 | s5 | s6 | Verdict |
|---|---|---|---|---|---|---|---|---|
| 1 | reference (§6) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | **PASS** |
| 2 | empty-`ELSE` variant (§6) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | **PASS** |
| 3 | `REPEAT / TAKE / SHIP / END` — ship everything | ✗ | ✓ | ✗ | ✓ | ✗ | ✗ | FAIL → **QA card** |
| 4 | auto-generated transcription of `s1` | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ | FAIL — the anti-hardcode check |
| 5 | `TAKE / IF TYPE IS BLUE / SHIP / END` — no loop | ✗ | ✓ | ✗ | ✗ | ✗ | ✓ | FAIL → **QA card** |
| 6 | `REPEAT / TAKE / IF TYPE IS RED / ELSE / SHIP / END / END` — inverted | ✗ | ✓ | ✗ | ✓ | ✓ | ✓ | FAIL → **QA card** |
| 7 | `REPEAT / SHIP / TAKE / END` — ship first | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | FAIL, instruction 2 |
| 8 | `REPEAT / IF TYPE IS BLUE / TAKE / SHIP / END / END` — check before take | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | FAIL, instruction 2 (§5.2) |
| 9 | reference + a second `SHIP` inside the `IF` | ✗ | ✓ | ✓ | ✗ | ✗ | ✓ | FAIL → **QA card** |
| 10 | `REPEAT / END` — empty loop | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | FAIL, instruction guard (§5.1 rule 3) |

### Player-facing messages

| Case | Message |
|---|---|
| 3, 6 on `s1` | *"Shipped a RED. Brent asked for BLUE only."* + expected/actual boxes |
| 3 on `s3` | *"Shipped 3 packages. Brent asked for none today."* |
| 5 on `s1` | *"The shift ended with 5 packages still on intake."* |
| 7 | *"UNIT-02 tried to ship, but its claws were empty."* |
| 8 | *"UNIT-02 checked what it was holding. It wasn't holding anything."* |
| 9 on `s1` | *"UNIT-02 shipped 6 packages. Brent asked for 3."* |
| 10 | *"This program has run 2,000 steps. UNIT-02 will keep doing this forever unless you stop it."* |

### This level is where the QUALITY ASSURANCE card earns its keep

**Four of the ten programs pass at least one shipment while being wrong** — cases 3, 5, 6 and
9. Case 3 (ship everything) passes `s4` outright, and `s4` is one shipment in six, so roughly
one player in six who writes the laziest possible program will see it clear on screen.

Without §8.5 that player learns the wrong lesson and hits a wall two levels later with no idea
why. With it, they get the QA card, watch their own program ship a red on `s1`, and learn the
actual rule. **Level 4 is the earliest place in the game where randomised shipments change what
the player believes**, which makes it the level to watch hardest in playtest.

Case 6 (inverted conditional) is the subtle one — it clears four of six shipments. Whichever
shipment the QA card promotes should be `s1` or `s3`, i.e. the first failure in set order, so
the counterexample the player watches is the clearest one available. Worth confirming that "first
in set order" is the promotion rule rather than "random failing shipment."

---

## 8. Level file

```json
{
  "id": "a1_l04_blues_only",
  "act": 1,
  "index": 4,
  "title": "Blues Only",
  "taskCard": "Ship only the BLUE packages.",
  "call": "a1_l04_call",
  "callSkippableOnFirstView": true,

  "shipments": [
    { "id": "s1", "intake": ["RED", "BLUE", "GREEN", "BLUE", "BLUE", "RED"] },
    { "id": "s2", "intake": [] },
    { "id": "s3", "intake": ["RED", "GREEN", "RED"] },
    { "id": "s4", "intake": ["BLUE", "BLUE", "BLUE", "BLUE", "BLUE"] },
    { "id": "s5", "intake": ["BLUE", "RED", "RED", "BLUE"] },
    { "id": "s6", "intake": ["RED"] }
  ],
  "parShipment": "s1",

  "pallets": [],
  "showWeights": false,
  "showRecyclingBin": true,

  "allowedCommands": ["TAKE", "SHIP", "REPEAT", "IF_TYPE_IS"],
  "availableTypes": ["BLUE", "RED", "GREEN"],

  "goal": {
    "outbound": "shipment.intake.where(type == BLUE)",
    "requireIntakeEmpty": true,
    "requireHandsEmpty": false
  },

  "pars": { "size": 4, "speed": 10 },

  "referenceSolution": [
    "REPEAT", "TAKE", "IF_TYPE_IS:BLUE", "SHIP", "END", "END"
  ]
}
```

`intake` is written as a bare type list rather than objects, since `showWeights` is false and
Act 1 packages have no other properties — worth deciding whether the schema allows this
shorthand or requires the verbose form used in level 1.

There is no `parsMutuallyExclusive` flag on this level any more — see §6. Keep the field in the
schema for the levels that genuinely have the tension (Act 3+), so the shift-complete card can
show the §8.2 line from data rather than from hardcoded level ids.

---

## 9. Portrait layout

Opens in **Program-focused** (§7.1). The program is now six rows with one level of nesting —
the first time the colored block spine and indentation carry real meaning, and the first real
test of whether the editor reads at a glance.

```
┌───────────────────────────┐
│  ▣ Ship only the BLUE     │
├───────────────────────────┤
│      ▼ ▼ ▼   intake       │
│    ┌──┐                   │
│    │▨▢│      🤖      ⌸    │   floor, 34% — bin at right
│    └──┘                   │
│              outbound ▶   │
├───────────────────────────┤
│ 1  REPEAT              ┐  │
│ 2    TAKE              │  │
│ 3    IF TYPE IS BLUE  ┐│  │   program, 66%
│ 4      SHIP           ││  │
│ 5    END              ┘│  │
│ 6  END                 ┘  │
│ ▸ ·······  caret ········ │
├───────────────────────────┤
│ ⊞ [TAKE][SHIP][REPEAT][IF]│   4 commands — no scroll
├───────────────────────────┤
│      ▶  RUN SHIFT         │
└───────────────────────────┘
```

Layout notes specific to this level:

- **The bin needs to be visible without stealing focus.** It sits opposite the outbound belt so
  that ship-right / discard-left reads as a spatial decision, and a discard is legible in
  peripheral vision even when the player is watching the program pane.
- **The tray still fits on one screen** — four buttons, no horizontal scroll, nothing hidden.
  A direct dividend of cutting `IF INTAKE IS EMPTY` (§6.6), and it holds for all of Act 1 at
  five commands maximum. **Treat "the Act 1 tray never scrolls" as a constraint on future
  command additions**, not as a happy accident: any command that pushes Act 1 into a scrolling
  tray has to justify hiding part of the vocabulary from a player who has been programming for
  fifteen minutes.
- **First real nesting.** Row 4's indentation is the only thing distinguishing "ship inside the
  if" from "ship after the if." If the golden tests (§13.3) don't already assert indentation
  legibility at 2.0× text scale in German, add the case with this level's program.

---

## 10. Playtest criteria

1. **8 of 10** players clear it without a hint.
2. **No player asks how to throw a package away.** If they ask, the call's line 3 or the bin's
   animation failed — the answer is supposed to be "you don't."
3. Every player who triggers a discard **notices it**, unprompted, on the first occurrence.
   This is the single most important observation in this playtest: it validates the §6.3
   mitigation for the whole rest of the game.
4. Players who meet the QUALITY ASSURANCE card resume editing **without asking what happened.**
   Watch for the failure mode where they think the game cheated.
5. No player believes an empty outbound on `s3` is a bug.
6. Median time to clear under **4 minutes**, including the call.

If criterion 3 fails, stop and fix the discard's audio and animation before authoring any
level past this one — every later act depends on discards being noticeable.

---

## 11. Open items

1. **Level ordering vs §8.3's beat list** (§1). Needs a ruling; everything else here is
   independent of it.
2. **The three counting rules** (§5.1) and the **empty-claws condition ruling** (§5.2) should be
   back-ported to §8.2 and §6.3 respectively once confirmed. Rule 3 (guard counts instructions)
   is a genuine hang bug if missed.
3. **`requireHandsEmpty` default** (§5.3) — flip to `false` and drop level 1's redundant `true`.
4. **QA card promotion rule** (§7) — first failing shipment in set order, or random? First-in-
   order is the recommendation, so the promoted counterexample is predictable and designers can
   author `s1` to be the clearest failure.
5. **Third package type.** `GREEN` appears in `s1` only, purely so the batch isn't a binary
   blue/red split. Confirm it's worth spending a third type's art on in Act 1, or collapse to
   two types and rely on `s3`/`s4` for the composition variety.

**Resolved since first draft:**
- *`IF INTAKE IS EMPTY` cut from the game* (§6.6). This level was the main beneficiary: tray
  down from six commands to four and no longer scrolling, one canonical solution instead of two,
  and both pars met by the same program. The mutually-exclusive pars this briefing previously
  celebrated were an artifact of the redundant command, not a real tradeoff.
- *`HANDS ARE EMPTY` is now also under review* (§6.6) and §5.2 no longer relies on it.
