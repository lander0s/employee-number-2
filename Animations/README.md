# Sprite set

Two characters, each shipped as an animated **SVG** and an equivalent
**Lottie JSON**.

**Delivery robot** — 3/4 top-down ("roguelike") view, six states.
**Boss** — full-body cutscene overlay, two states. See
[the boss section](#boss) below.

| state | SVG | Lottie | length | loops |
|---|---|---|---|---|
| idle | `delivery-robot-idle.svg` | `delivery-robot-idle.json` | 18.20s | yes |
| walking | `delivery-robot-walking.svg` | `delivery-robot-walking.json` | 4.80s | yes |
| holding | `delivery-robot-holding.svg` | `delivery-robot-holding.json` | 18.20s | yes |
| walking-holding | `delivery-robot-walking-holding.svg` | `delivery-robot-walking-holding.json` | 4.80s | yes |
| pickup | `delivery-robot-pickup.svg` | `delivery-robot-pickup.json` | 1.15s | **no** |
| merge | `delivery-robot-merge.svg` | `delivery-robot-merge.json` | 2.20s | **no** |

`idle`/`holding` share a duration, as do the two `walking` variants, so swapping
within a pair mid-cycle is seamless. `pickup` and `merge` are one-shots that end
exactly on the `holding` pose and hand off to it with no visible jump.

`putdown` is not a file — it is `pickup` played backwards. `preview.html`
demonstrates it, and `tools/mkpreview.py` shows how (reverse `values`, mirror
`keyTimes`, reverse *and* flip each `keySplines` segment).

## Boss

| state | SVG | Lottie | length |
|---|---|---|---|
| idle | `boss-idle.svg` | `boss-idle.json` | 6.80s |
| talking | `boss-talking.svg` | `boss-talking.json` | 6.80s |

Canvas `viewBox="0 0 220 300"`, centred on `x=110`, feet plant on `y=286`.
`#mouth-anchor` marks where a speech-bubble tail should point; it lives inside
`#head` so it tracks the sway.

Both share a 408-frame comp, so swapping mid-scene keeps the sway in phase.
`boss-talking.svg` is **generated** from `boss-idle.svg` — see
[tools/README.md](tools/README.md).

His palette deliberately avoids hue 165–180 so the robot's bloom pass does not
light him up.

---

## Coordinate systems

**The two formats do not share an origin.** Everything is authored in SVG user
units; the Lottie comp is shifted **+30 on x**.

| | SVG | Lottie |
|---|---|---|
| canvas | `viewBox="-30 0 300 240"` | comp `300 x 240` |
| horizontal centre | `x = 120` | `x = 150` |
| ground line (casters plant here) | `y = 195` | `y = 195` |
| two-handed grip point | `120, 96` | `150, 96` |

```
lottie_x = svg_x + 30
lottie_y = svg_y
```

The SVG viewBox starts at `-30` to give the arms room; a Lottie composition
always starts at `0`, hence the offset. Y is untouched.

Within the image the anchor is the same in both: horizontal centre, and the
ground line sits at **81.25%** of the height. All six states share this, so you
can swap sprites without repositioning.

---

## Colour code

| role | hex | notes |
|---|---|---|
| **eye cyan** | `#5CF2DF` | eyes, smile, lidar dot — **the bloom colour** |
| outline | `#1B2838` | every stroke, uniform |
| body white | `#EEF3F9` | chassis, arm segments |
| panel / shade | `#DCE5EF` | lid inner panel |
| joints | `#5A7288` | shoulder / elbow / wrist balls, lidar top |
| lidar body | `#3E5468` | |
| casters | `#2C3B4B` | |
| visor gradient | `#33475C` → `#1B2838` | |
| body shade gradient | `#FFFFFF` → `#8FA3BA` | left highlight to right shade |
| headlights | `#FFD166` | also the flag finial |
| flag pennant | `#FF8A3D` | |
| parcel emblem | `#F2A65A` / `#C9762F` | kraft box + tape |
| catchlights | `#FFFFFF` | eye glints |

### Bloom / post-processing

The colour to key on is **`#5CF2DF`**:

```
hex      #5CF2DF
sRGB     rgb(92, 242, 223)      normalised (0.361, 0.949, 0.875)
linear   (0.1070, 0.8879, 0.7379)
HSL      hsl(172, 85%, 65%)
relative luminance  0.711
```

It is used in exactly three places, identically in all six states:

| element | geometry (SVG units) |
|---|---|
| left eye | `ellipse cx=101 cy=154 rx=9.5 ry=11` |
| right eye | `ellipse cx=139 cy=154 rx=9.5 ry=11` |
| smile | `path M110 167 Q120 172.5 130 167`, stroke width 3.5 |
| lidar dot | `ellipse cx=120 cy=84 rx=5 ry=2.4`, opacity 0.9 |

**Do not drive the bloom off a luminance threshold.** The body white
`#EEF3F9` has a relative luminance of **0.891**, well above the eye cyan's
**0.711**, and the catchlights are pure white at 1.000. A brightness pass
would blow out the chassis before it touched the eyes.

Key on hue/saturation instead — the cyan is the only strongly saturated cool
colour in the palette (hue 172°, saturation 85%; everything else is either
near-neutral blue-grey or warm orange) — or render a dedicated emissive mask
from those four elements.

Secondary glow candidates, if you want a warm counterpoint: headlights
`#FFD166` (luminance 0.678, two `17x8 rx=4` rects at `71,174` and `152,174`)
and the flag finial `#FFD166` (`circle cx=168 cy=42 r=4.5`).

**The eyes blink.** `ry` animates `11 → 1 → 11` across keyTimes
`0.90 → 0.935 → 0.97` of the blink cycle — roughly a 0.32s closure. If you
drive a light or glow from the eye colour, it will collapse to a slit and
recover on that beat. The catchlights fade to 0 in sync.

---

## Merge animation — hand positions

`merge` runs **2.2s** and is the only state where the two hands do different
things. Positions below are **SVG user units** (add 30 to x for Lottie).

Two anchors per hand:

- **wrist** — the wrist joint centre, i.e. where the claw pivots.
- **claw** — the centre of what the claw is gripping, 14 units out along the
  claw bisector. **This is the one you want for attaching an object.**

| # | pose | keyTime | sec | Lottie frame | L wrist | L claw | R wrist | R claw |
|---|---|---|---|---|---|---|---|---|
| 0 | hold | 0.00 | 0.000 | 0 | 77, 96 | 91, 98 | 163, 96 | 149, 98 |
| 1 | hold | 0.06 | 0.132 | 8 | 77, 96 | 91, 98 | 163, 96 | 149, 98 |
| 2 | reach | 0.30 | 0.660 | 40 | 104, 180 | **115, 189** | 145, 100 | 131, 101 |
| 3 | grab | 0.42 | 0.924 | 55 | 104, 180 | **115, 189** | 145, 100 | 131, 101 |
| 4 | two-up | 0.56 | 1.232 | 74 | 66, 92 | 80, 90 | 174, 92 | 160, 90 |
| 5 | wind | 0.68 | 1.496 | 90 | 54, 86 | 67, 81 | 186, 86 | 173, 81 |
| 6 | **SMASH** | 0.79 | 1.738 | 104 | 95, 100 | 109, 99 | 145, 100 | 131, 99 |
| 7 | settle | 0.88 | 1.936 | 116 | 74, 94 | 88, 94 | 166, 94 | 152, 94 |
| 8 | hold | 1.00 | 2.200 | 132 | 77, 96 | 91, 98 | 163, 96 | 149, 98 |

The grab point is **115, 189** — the left claw alone, angled inboard so the
grip lands near the centre line. It sits *below* the `y=195` ground line by
design: that line only marks where the robot's own wheels rest, and the cell
it reaches into is nearer the camera.

### Interpolating between keyframes

**Positions between rows are not linear.** Each segment has its own
cubic-bezier, and they vary deliberately — flat dwells, a slow anticipation,
then a hard acceleration into the hit:

| segment | curve | |
|---|---|---|
| 0 → 1 | `0 0 1 1` | linear (dwell) |
| 1 → 2 | `.4 0 .2 1` | ease down to the grab |
| 2 → 3 | `0 0 1 1` | linear (dwell, nothing moves) |
| 3 → 4 | `.4 0 .2 1` | ease up |
| 4 → 5 | `.3 0 .7 1` | slow — anticipation |
| 5 → 6 | `.8 0 1 1` | **accelerate hard into the impact** |
| 6 → 7 | `.1 0 .3 1` | quick recoil |
| 7 → 8 | `.4 0 .2 1` | ease |

Lerping the table linearly will desync worst around the smash, which is
exactly where it shows.

### Easier: use the payload slots

You usually should not reimplement the paths at all. All three states that
carry cargo expose empty `<g>` slots that already move correctly — drop an
object in and it rides the hand with the right easing for free.

| slot | in | behaviour |
|---|---|---|
| `#payload` | holding, walking-holding, pickup, merge | the two-handed grip at `120, 96` |
| `#payload-a` | merge | object A — starts in the grip, slides into the right claw, ends at the collision |
| `#payload-b` | merge | object B — hidden until the left claw closes at the ground, then rides up |

Slots translate but never rotate, so an object stays upright instead of
tumbling with the wrist.

The authoritative merge paths, as authored (SVG units, same 9 keyTimes):

```
payload-a  120.0 96.0 ; 120.0 96.0 ; 131.0 100.5 ; 131.0 100.5 ; 160.1 90.0 ;
           172.7 81.5 ; 131.0 99.3 ; 152.0 94.3 ; 148.7 97.5

payload-b  115.0 188.6 ; 115.0 188.6 ; 115.0 188.6 ; 115.0 188.6 ; 79.9 90.0 ;
            67.3 81.5 ; 109.0 99.3 ;  88.0 94.3 ;  91.3 97.5
```

Note `payload-a`'s first two keyframes are `120, 96` — the two-handed grip
centre, **not** the right claw. That is deliberate: it makes frame 0 identical
to the `holding` sprite, and the object then slides into the right claw as the
left hand leaves.

Opacity is animated on each slot, so objects appear and disappear on the right
beats: A visible until the impact, B from the grab until the impact, the merged
result from the impact onward.

---

## Driving the one-shots

**SVG** — one call fires every joint and slot; the rest are slaved to it:

```js
svg.getElementById('merge').beginElement();    // or 'pickup'
```

Both files carry `begin="0s"` so they demo themselves when opened. Change that
one word to `begin="indefinite"` for game control and they sit on their first
pose until fired.

**Lottie** — plays once and holds the last frame:

```dart
Lottie.asset('assets/delivery-robot-merge.json', repeat: false)
```

Note the SVGs animate with SMIL, which **`flutter_svg` ignores** — there they
render as static sprites in their first pose. Use the Lottie files on Flutter;
the SVGs are for web/inline-SVG targets.

---

## Regenerating

Several assets are generated, and `tools/rig-template.svg` is the only source
for the pickup and merge arm rigs. Read [tools/README.md](tools/README.md)
before editing — hand-editing a generated file works until the next build
silently reverts it.

```
python tools/mkboss.py      # boss-idle.svg    -> boss-talking.svg
python tools/rebuild.py     # rig-template.svg -> pickup + merge .svg
python tools/walk2.py       # all .svg         -> all .json
python tools/mkpreview.py   # all .svg         -> preview.html
```

## Rig notes

The arms are a nested joint rig: `translate → rotate(shoulder) →
translate(32.5,0) → rotate(elbow) → translate(29,0) → rotate(wrist)`. A pose is
three angles per arm. Segment lengths are upper **32.5**, forearm **29**,
finger **13** at ±33°.

The right arm is the same rig under `scale(-1,1)`, so **both arms take
identical angle numbers** — never flip signs.

If you re-pose anything: the elbow angle may cross **0** (the arm straightens,
which reads fine) but must never cross **±180**, which folds the forearm flat
back through its own shoulder and puts the hand inside the chassis. The merge's
`merge` needs no transit pose for this any more, but `pickup` relies on the
constraint being *relaxed*: it reaches through the ground line on purpose.

Ground clearance is checked at generation: the lowest painted arm pixel in the
merge is `y = 188.9`, giving **6.1 units** of clearance above the `y = 195`
ground line, and no claw crosses a caster.
