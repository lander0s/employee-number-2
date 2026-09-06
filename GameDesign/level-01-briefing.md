# Level 1 — "First Shift"

**Act:** 1 · ONBOARDING · **Position:** 1 of 8 · **ID:** `a1_l01_first_shift`
**Status:** Spec ready for Milestone 1 vertical slice
**Companion docs:** [game-design-document.md](game-design-document.md) ·
[program-editor.md](program-editor.md)

> **Re-cut** for the numeric vocabulary (§6.2–6.3). A package is a number now; there are no
> types. The level's shape, its pars, its adversarial suite and its playtest criteria all
> survived that change unaltered, which is the strongest evidence available that the level was
> about the interface rather than about the contents of the boxes.

---

## 1. Purpose

This is the first program the player ever writes. It is a **Teacher** (§8.1) and it teaches
exactly two commands: `TAKE` and `SHIP`.

It also has a second job that matters more than its content: it has to prove the interface.
The GDD's slice criteria (§14) demand that five out of five new players write and run a
correct program here with no help, one-handed, standing up. **Every decision below is
subordinate to that.** If this level is interesting, it is too hard.

### What it teaches
- Packages arrive on **INTAKE**, one at a time, in a fixed order.
- `TAKE` puts one in UNIT-02's claws. `SHIP` puts what it's holding into **OUTBOUND**.
- A program is a list of instructions, executed top to bottom, once.
- The RUN button exists and watching the robot is fun.

### What it must NOT do
- No loops. `REPEAT` is level 2's entire lesson and must not appear on the note.
- No conditions, no pallets, no arithmetic.
- **No pallets on the floor at all** — an empty middle floor keeps the first Floor View
  readable and gives the `COPY TO` level something new to reveal.
- No optimization pressure. The shortest solution is the only solution (§10).
- No failure the player can't immediately understand and undo.

**Nothing here depends on the numbers on the boxes.** They are printed, they are visible, and
the correct program ignores them completely. That is deliberate — see §3.

---

## 2. The call

Brent, portrait framing, home office background, mid-morning light. Talking animation on
every line, idle between. Four lines, per the GDD's 60-second-to-first-program budget (§5).

> **BRENT:** Hey! There you are. Welcome to the team — genuinely, we are *thrilled*.
>
> **BRENT:** So you've got a unit down on the floor. That's UNIT-02, your new little helper.
> Say hi later, it doesn't mind.
>
> **BRENT:** Today's real simple. There's three packages on intake. I need all three of them
> shipped out. That's the whole day.
>
> **BRENT:** Just tell the unit what to do and hit run. You've got this, champ.

Notes for the writer:
- "champ" is the nickname. It is the same nickname in Act 5, delivered by something that
  is not Brent. Do not change it, ever.
- He says "three packages" out loud. The player should never have to count boxes to
  understand the goal.
- **He never mentions the numbers.** Not once, not even to say they don't matter — naming them
  would invite the player to look for a rule that isn't there. They are scenery in this level
  and they become the whole game two levels later.
- He does not use the words *program*, *code*, *loop*, or *instruction*. He says "tell the
  unit what to do." (§15, marketing risk row.)
- First-view skip is disabled here only (§16.5). This is the one call in the game that must
  land.

**Task Card** (pinned above the editor for the rest of the level):

> Ship all 3 packages.

---

## 3. Input — the shipment set

Levels define a **set** of possible shipments and roll one at random when the level opens
(§8.5). Level 1 is the deliberate exception: **its set has exactly one member.**

```
SHIPMENT SET — 1 of 1
```

| Shipment | Intake, in order | Length |
|---|---|---|
| `s1` *(the only one)* | `4` `7` `2` | 3 |

`parShipment: s1` · `singleShipment: true`

### Why exactly one

With `TAKE` and `SHIP` as the entire vocabulary and no loop construct, **a variable-length
intake is unsolvable.** A six-instruction program can move exactly three packages; if the set
contained a four-package shipment, no legal level-1 program could clear it. Variation requires
the player to own a command that responds to variation, and that command is `REPEAT` — which is
level 2's whole lesson.

So level 1 is the one place in the game where the intake sequence *is* the solution, and
that's fine, because at three packages with no branching there is no rule to abstract: the
transcription and the procedure are the same six instructions. Nothing is being taught that
level 2 then has to un-teach.

The verifier still has to be told about this on purpose. `singleShipment: true` declares the
hardcoding check vacuous rather than letting it silently pass (§13.2), so a level that ends up
with one shipment *by accident* still fails CI.

**Variation begins in level 2** and the set grows from there — see §8.5's table of which axes
may vary once which commands are in the player's hands.

**FLOOR:** no pallets.
**OUTBOUND:** empty.
**UNIT-02:** idle, claws empty, standing centre-floor.

### Why `4 7 2`, and why they are visible

An earlier draft of this level shipped three identical packages with blank faces, to keep the
player from suspecting that arithmetic existed. That reasoning died with the type system: **a
package is a number now (§6.2), so there is no blank face to show.** The numbers are on the
boxes from the first second of the game, and the question is only which ones.

- **Three different values, not three of the same.** Distinct numbers cost the lesson nothing —
  "all three" is unambiguous because Brent said three — and they buy the validator something
  real: this level can now detect a program that ships the right *count* in the wrong *order*.
  Identical packages made that undetectable (see §4), and order-sensitivity used to have to
  wait for level 3.
- **Small, positive, unremarkable.** No zero, no negatives, nothing that looks like a pattern.
  `4 7 2` is not ascending, not descending, and does not sum or differ into anything. A player
  hunting for the trick finds nothing, which is correct: there is no trick until level 3.
- **Three, not two, and not five.** Two doesn't establish a pattern. Five makes six
  instructions feel like ten and invites the player to look for a shortcut that doesn't
  exist yet. Three is the smallest count that makes the repetition *visible* — which is
  exactly the itch level 2 scratches with `REPEAT`.

---

## 4. Expected output

**OUTBOUND** must contain, in order:

| # | Value |
|---|---|
| 1 | `4` |
| 2 | `7` |
| 3 | `2` |

Nothing may remain on intake. Nothing may remain in UNIT-02's claws.

**Order is checked, and checkable.** This is a change from the first draft, where three
identical packages meant the validator could only compare counts. With distinct numbers the
goal expression `shipment.intake` is order-sensitive from level 1, so a program that somehow
shipped `4 2 7` fails here rather than surviving to level 3.

---

## 5. Rules in play

Only these VM rules are exercised. Everything else in §6.3 is inert for this level.

| Rule | Behaviour here |
|---|---|
| `TAKE` with empty claws, intake non-empty | Robot walks to the chute and catches the next package. |
| `SHIP` with a package held | Robot walks to the belt and tosses it into outbound. |
| `SHIP` with empty claws | **Failure.** See §7. |
| Program runs past its last instruction | **The shift ends, successfully**, and the goal is checked. Termination is implicit — there is no command that ends a shift (§6.3). |
| `TAKE` with intake empty | The shift ends (§6.3). Reachable here only by a program with a trailing `TAKE`; see the adversarial suite. |
| `TAKE` with claws full | **The held package is discarded** — tossed into the recycling bin, one step, no failure. The discard rule, specified in §6.3. |

**The note holds two commands:** `TAKE`, `SHIP`. Nothing else.

### The discard rule's first appearance

`TAKE` with full claws quietly destroys a package (§6.3). Level 1 is where a player can first
trigger it — adversarial case 6 — and it's the level's only silent failure mode: the symptom
is a missing box in outbound, several steps after the cause.

That makes level 1 the place to verify the mitigations the GDD requires, because here the
player can hold the whole program in their head and still be confused:

- The discard must be **loud** — bin clang, distinct sound, box tumbling out of frame. If a
  playtester discards a package and doesn't notice, the audio and animation are wrong, and
  every later level inherits that.
- The failure message must name the count mismatch (*"shipped 2, Brent asked for 3"*), not
  just say the shipment was wrong.

This level does not *teach* discarding — nothing here needs it. It is taught deliberately in
Act 1 level 4, where discarding is the point.

---

## 6. Reference solution

Six instructions. This is also the only solution, ignoring trailing no-ops.

```
TAKE
SHIP
TAKE
SHIP
TAKE
SHIP
```

### Step trace

| Step | Instruction | UNIT-02 does | Claws | Intake left | Outbound |
|---|---|---|---|---|---|
| — | *(start)* | idle | empty | 4 7 2 | — |
| 1 | `TAKE` | walk to chute, catch | `4` | 7 2 | — |
| 2 | `SHIP` | walk to belt, toss | empty | 7 2 | 4 |
| 3 | `TAKE` | walk to chute, catch | `7` | 2 | 4 |
| 4 | `SHIP` | walk to belt, toss | empty | 2 | 4 7 |
| 5 | `TAKE` | walk to chute, catch | `2` | — | 4 7 |
| 6 | `SHIP` | walk to belt, toss | empty | — | 4 7 2 |
| — | *(end of program)* | wave, screen dims | empty | — | **4 7 2 ✓** |

Runtime at 1× is roughly 12–14 seconds of robot animation — long enough to be a reward,
short enough that nobody reaches for the 2× button on their first ever run. Tune the walk
cycle timing against this number, not against the later levels.

### Pars

| | Value |
|---|---|
| `SIZE` | **6** |
| `SPEED` | **6** steps |

Both are exactly the reference solution, so both are awarded on any first clear. Pars stay
hidden until first clear (§8.2), which here means the player discovers they've already earned
the Efficiency Sticker — a deliberately cheap first win that teaches what the two numbers on
the shift-complete card mean.

---

## 7. Failure cases and the CI suite

Per §13.2 every level ships with a reference solution plus adversarial programs, all executed
headless in `dart test`. This is level 1's full suite — it doubles as the spec for the failure
messages, which are the player's only debugging teacher in the first five minutes.

| # | Program | Verdict | Player-facing message |
|---|---|---|---|
| 1 | *(empty)* | FAIL | *"UNIT-02 didn't do anything. Brent is expecting three packages."* |
| 2 | `SHIP` | FAIL | *"UNIT-02 tried to ship, but its claws were empty."* |
| 3 | `TAKE` | FAIL | *"The shift ended with 2 packages still on intake."* |
| 4 | `TAKE SHIP` | FAIL | *"The shift ended with 2 packages still on intake."* |
| 5 | `TAKE SHIP TAKE SHIP` | FAIL | *"The shift ended with 1 package still on intake."* |
| 6 | `TAKE TAKE SHIP TAKE SHIP` | FAIL | *"UNIT-02 shipped 2 packages. Brent asked for 3."* (the `4` was discarded — tests the §5 discard ruling) |
| 7 | `TAKE SHIP ×3` | **PASS** | reference solution, `SIZE 6 / SPEED 6` |
| 8 | `TAKE SHIP ×3` + `TAKE` | **PASS** | correct, but `SIZE 7` — trailing `TAKE` hits an empty intake and ends the shift. Verifies that par misses don't block progress (§8.2). |
| 9 | `TAKE SHIP ×3` + `SHIP` | FAIL | *"UNIT-02 tried to ship, but its claws were empty."* — the goal was already met; the program still fails. Confirms the goal is checked at shift end, not on the fly. |
| 10 | `SHIP TAKE SHIP TAKE SHIP TAKE` | FAIL | *"UNIT-02 tried to ship, but its claws were empty."* — the classic off-by-one first attempt. |

Case 10 is the one real playtest prediction: a meaningful share of first-timers will place
`SHIP` first. The message must point at the offending row, highlight it, and drop the player
straight back into editing with that row on screen. **That single interaction is the most
important error-handling moment in the game** — it's where a player decides whether this game
makes them feel stupid.

No infinite-loop guard is reachable here: there is no loop construct on the note.

---

## 8. Level file

Per §13.2 — declarative, no code. Field names are indicative, to be locked with the schema.

```json
{
  "id": "a1_l01_first_shift",
  "act": 1,
  "index": 1,
  "title": "First Shift",
  "taskCard": "Ship all 3 packages.",
  "call": "a1_l01_call",
  "callSkippableOnFirstView": false,

  "shipments": [
    { "id": "s1", "intake": [4, 7, 2] }
  ],
  "parShipment": "s1",
  "singleShipment": true,
  "singleShipmentReason": "TAKE/SHIP only, no loop — variable length is unsolvable. See §8.5.",

  "pallets": [],

  "allowedCommands": ["TAKE", "SHIP"],

  "goal": {
    "outbound": "shipment.intake",
    "requireIntakeEmpty": true,
    "requireHandsEmpty": true
  },

  "pars": { "size": 6, "speed": 6 },

  "referenceSolution": ["TAKE", "SHIP", "TAKE", "SHIP", "TAKE", "SHIP"]
}
```

Three notes on the shape:

- `intake` is a bare list of integers. A package has no other properties (§6.2), so there is
  nothing to wrap in an object — this is the whole schema for a package now.
- `goal.outbound` is written as the **derived** expression `shipment.intake` — "ship whatever
  arrived, in order" — not as a literal three-number list. It happens to evaluate to the same
  thing here, but writing it derived is the habit that keeps every later level's goal correct
  across its whole shipment set (§13.2).
- `singleShipment: true` is a **declaration, not a default.** It tells the verifier the
  anti-hardcoding check is vacuous for this level. Without it, CI fails — which is the point:
  a level that drops to one shipment by accident should never pass quietly.

The adversarial programs from §7 live beside this file as the level's test fixture, not inside
it. CI runs every program against every shipment in the set (§13.2); here that cross product
is 10 × 1.

---

## 9. Portrait layout

Level 1 opens in **Program-focused** snap state (§7.1). The floor is empty of pallets, so the
top pane can sit at its minimum height and still read clearly — the first screen the player
ever sees is mostly program, which is pillar P2 stating itself before any text explains it.

```
┌───────────────────────────┐
│  TASK                     │
│  Ship all 3 packages.  [i]│
├───────────────────────────┤
│   ▼ ▼ ▼  intake    ▶ RUN  │
│   ┌──┐                    │   floor, 34% — no pallets
│   │4 │       🤖           │
│   └──┘         outbound ▶ │
├──────────── ⌃⌄ ───────────┤
│ ╎        ┌──────────┐  🖇 │
│ ╎        │ TAKE     │     │   the page: ruled, margin,
│ ╎        └──────────┘     │   clip. Commands are tabs
│ ╎        ┌──────────┐     │   glued at the left.
│ ╎        │ SHIP     │     │
│ ╎        └──────────┘     │
│ ╎                         │
│ ╎  ┌────────┬────────┐    │   the note, lying over the
│ ╎  │  TAKE  │  SHIP  │    │   page: two commands
└───┴────────┴─────────┴────┘
```

Two commands means the note has one row rather than two, and the page below it is almost
entirely empty — which is the correct first impression. See [program-editor.md](program-editor.md)
for the surface itself.

### First-time-only UX beats
Level 1 carries the only hand-holding in the game. All of it is diegetic or gestural — no
modal tutorial popups (§9.7).

1. On entering the editor, the two commands on the note pulse once, in sequence. Nothing else
   moves.
2. The first time a command is dragged onto the page, the gap that opens under it is the only
   feedback needed. The pulse stops permanently after that.
3. `RUN` is dimmed while the program is empty — not disabled-with-a-scold, just quiet.
4. If the program has been untouched for 20 seconds, UNIT-02 looks up at the player and
   shrugs. That's the entire hint system for this level.
5. **Long-press-to-lift is not taught here.** With two commands and six rows there is nothing
   worth rearranging, and a player who never discovers it this level loses nothing. It is
   taught by need in level 2, when a misplaced row inside a `REPEAT` is worth moving rather
   than deleting.
6. Dragging the divider is not taught either. Players find it during the run, or during level
   2, and criterion 4 of the slice test measures whether they do.

---

## 10. Playtest criteria for this level specifically

Level 1 is the instrument the Milestone 1 slice test is measured with (§14). It passes when:

1. **5 of 5** first-time players produce a correct program with no help and no hint.
2. **Zero** players rotate the phone or use a second hand.
3. Median time from end-of-call to first `RUN` tap is **under 45 seconds**.
4. Every player can state what `TAKE` and `SHIP` do, in their own words, immediately after,
   without having read a definition tooltip.
5. Every player reads their own program without moving the phone closer.
6. Players who hit failure case 10 recover **without assistance and without frustration** —
   watch faces here, not timers.
7. **No player asks what the numbers on the boxes mean.** If they do, they are looking for a
   rule that does not exist yet, and the level has failed to be boring enough. This one is new
   with the numeric vocabulary and is the criterion most likely to fail.

If criterion 1 or 5 fails, the interface is wrong and no further levels get authored (§14).
If criterion 3 fails but 1 passes, the call is too long — cut a Brent line, not a package.

---

## 11. Open items

1. **Whether the numbers should be single-digit for the whole of Act 1.** `4 7 2` is one
   character per box, which keeps the package art small and the floor readable. Two-digit
   values arrive with arithmetic; worth deciding whether they arrive at all before Act 2.
2. **Whether "First Shift" is ever shown to the player.** The GDD has no level-title UI. If
   levels stay untitled in-game, these names are internal only — decide before the level
   select screen is designed.

**Resolved since first draft:**
- *Full-claws `TAKE`* → discards the held package. Now specified as the general **discard
  rule** in §6.3, covering `COPY FROM` as well.
- *Single-shipment level* → confirmed correct for level 1, and formalised as the
  axis-of-variation rule in §8.5.
- *Identical, faceless packages* → replaced by three distinct numbers. Types are gone (§6.2),
  there is no faceless package to ship, and distinct values give the validator order coverage
  it previously had to wait two levels for.
