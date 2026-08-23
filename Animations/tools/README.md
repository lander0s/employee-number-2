# tools

Generators for the sprite assets. **Several files in this folder are the only
source for assets that would otherwise be unrecoverable** — see the warning
below.

Run everything **from the assets folder**, not from here:

```
cd path/to/animations
python tools/mkboss.py       # boss-idle.svg   -> boss-talking.svg
python tools/rebuild.py      # rig-template.svg -> pickup + merge .svg
python tools/walk2.py        # all .svg        -> all .json (Lottie)
python tools/mkpreview.py    # all .svg        -> preview.html
```

Only `python` (3.x) is required; `walk2.py` imports `lottiegen.py` from this
folder automatically.

---

## `rig-template.svg` is load-bearing

It is **not** a build artifact. `delivery-robot-pickup.svg` and
`delivery-robot-merge.svg` are generated *from* it — they carry the nested arm
rig, which is far too fiddly to hand-edit. Editing those two files directly
works until the next `rebuild.py` run silently reverts them.

To change the robot's body in the pickup/merge poses, edit this template, then
re-run `rebuild.py`.

This has already bitten once: a stale copy of this template regenerated both
files with the antenna back in the wrong draw order, and the only clue was a
diff nobody had asked for. If you change the template, re-run and diff.

## What generates what

```
boss-idle.svg  ──mkboss.py──▶  boss-talking.svg
rig-template.svg ─rebuild.py─▶ delivery-robot-{pickup,merge}.svg
                                      │
  all *.svg ──────walk2.py───────────▶ all *.json
  all *.svg ──────mkpreview.py───────▶ preview.html
```

Hand-authored (no generator): `delivery-robot-{idle,walking,holding,
walking-holding}.svg`, `boss-idle.svg`.

**Order matters.** Change an SVG → re-run `walk2.py` and `mkpreview.py`.
Change `boss-idle.svg` → run `mkboss.py` *first*. Change `rig-template.svg` →
run `rebuild.py` *first*.

`preview.html` inlines every SVG so it opens from `file://` with no server.
That means **it goes stale the moment you edit an SVG.**

---

## Things that will bite you

**Lottie draws array-first on TOP** — the opposite of SVG. Every group is
emitted in reverse. Within a shape group, `[path, stroke, fill, transform]` is
what puts the stroke over the fill.

**Lottie cycles must be whole FRAMES that divide the comp.** Dividing evenly
in *seconds* is not enough: `0.68s` at 60fps is 40.8 frames, which forces the
comp onto a different length. Two states that should stay in phase when
swapped mid-scene then drift. `walk2.py` retimes automatically and reports how
far; `mkboss.py` asserts the property outright.

**A Lottie comp always starts at 0,0; an SVG viewBox need not.** The robot's
`viewBox="-30 0 300 240"` means `lottie_x = svg_x + 30`. The converter reads
the viewBox, so any canvas works — but the offset is real and matters when
positioning sprites in-game.

**`flutter_svg` ignores SMIL.** The SVGs render as static first-pose sprites
there. Use the `.json` on Flutter; the SVGs are for web/inline-SVG targets.

**Elbow angles may cross 0, never ±180.** Crossing 0 straightens the arm and
reads fine. Crossing ±180 folds the forearm back through its own shoulder and
puts the hand inside the chassis. `rebuild.py` checks this every run, along
with ground clearance and caster overlap, and refuses to write if it fails.

**Ground clearance is per-animation, not global.** Idle and walking must never
touch the line; pickup and merge deliberately reach *through* it, because that
line only marks where the robot's own wheels sit and the cell it grabs from is
nearer the camera.

**`mkpreview.py` namespaces every id.** Nine SVGs share one document, so
`begin="x.begin"` and `url(#grad)` would otherwise all bind to the first card.

---

## Verifying changes

The reliable method is headless Chrome plus a pixel diff against the SVG.
Two traps:

- `--virtual-time-budget` **does not advance SMIL inside an `<img>`**, and
  stops advancing at all once a page uses `fetch()`. Both make correct output
  look broken. Inline the SVG, or drive a real browser over the DevTools
  Protocol.
- When comparing a one-shot Lottie against its SVG, strip the SVG's ambient
  loops first — the one-shot drops them by design — and bake the antenna's
  first keyframe angle, which the one-shot freezes at rather than leaving at
  the base value.

A 0.02–0.4% pixel difference is the normal antialiasing floor for a rigged
pose. Filled regions in the diff (rather than thin outlines) mean a real
discrepancy.
