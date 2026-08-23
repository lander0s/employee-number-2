# -*- coding: utf-8 -*-
"""Derive boss-talking.svg from boss-idle.svg.

Talking is the idle body with the mustache twitching and a mouth opening
under it - so it is generated rather than copied, and the two cannot drift
apart if the character gets redrawn.

Cycle lengths are chosen to be whole FRAMES at 60fps that divide the 408
frame (6.8s) loop: bob 34, waggle 51, sway 204, brow 408. Dividing evenly in
seconds is not enough - 0.68s is 40.8 frames, which forces a Lottie
conversion onto a different comp length than boss-idle, and the two then
drift apart in sway phase when you swap between them mid-scene.
"""
import io, re

IDLE, TALK = 'boss-idle.svg', 'boss-talking.svg'

OLD = '''        <!-- mustache: thick chevron, the silhouette's second-best landmark -->
        <path fill="#2E3542" stroke-width="4"
              d="M82 124 Q88 114 102 119 Q110 122 118 119 Q132 114 138 124
                 Q134 133 120 130 Q110 128 100 130 Q86 133 82 124 Z"/>

        <!-- mouth: a small frown under the mustache -->
        <path fill="none" stroke-width="3.5" d="M103 139 Q110 134 117 139"/>'''

NEW = '''        <!-- MOUTH: opens and shuts under the mustache. Drawn BEFORE the
             mustache so the mustache overhangs it, the way a real one does -
             which is also why no mouth SHAPES are needed. Nobody can see
             enough of it to tell. -->
        <ellipse id="mouth" cx="110" cy="137" rx="9" ry="1.2"
                 fill="#1B2838" stroke="none">
          <animate attributeName="ry"
                   values="1.2;3.8;1.4;3.2;1.2;3.8;1.6;2.8;1.2"
                   keyTimes="0;.12;.24;.37;.5;.63;.75;.88;1"
                   dur=".5667s" repeatCount="indefinite"/>
        </ellipse>

        <!-- MUSTACHE: this is the talking.
             Two nested transforms at DIFFERENT rates - a vertical bob at
             .68s and a waggle at .85s. They beat against each other, so
             the twitch never settles into an obvious loop.
             The bob is mostly NEGATIVE - the mustache lifts as the mouth
             opens beneath it. Bobbing it down instead moves it with the
             jaw, which closes the gap and swallows the mouth entirely.
             A single transform at a single rate reads as a metronome, which
             is the giveaway that kills cheap lip sync. -->
        <g id="mustache">
          <animateTransform attributeName="transform" type="translate"
                            values="0 0;0 -2.2;0 0.8;0 -2.8;0 0;0 -1.8;0 1;0 -2.4;0 0"
                            keyTimes="0;.12;.24;.37;.5;.63;.75;.88;1"
                            dur=".5667s" repeatCount="indefinite"/>
          <g>
            <animateTransform attributeName="transform" type="rotate"
                              values="0 110 124;-5 110 124;3 110 124;-2.5 110 124;5 110 124;-4 110 124;2 110 124;-5 110 124;0 110 124"
                              keyTimes="0;.12;.25;.37;.5;.62;.75;.87;1"
                              dur=".85s" repeatCount="indefinite"/>
            <path fill="#2E3542" stroke-width="4"
                  d="M82 124 Q88 114 102 119 Q110 122 118 119 Q132 114 138 124
                     Q134 133 120 130 Q110 128 100 130 Q86 133 82 124 Z"/>
          </g>
        </g>'''

s = io.open(IDLE, encoding='utf-8').read()
assert OLD in s, 'mustache/mouth block not found - did boss-idle.svg change?'
s = s.replace(OLD, NEW)

s = s.replace('BOSS / STATE: IDLE  -  full-body cutscene overlay',
              'BOSS / STATE: TALKING  -  full-body cutscene overlay')
s = s.replace('aria-label="Cartoon office boss, full body, idle, hands behind his back"',
              'aria-label="Cartoon office boss, full body, talking, hands behind his back"')
s = s.replace('''         #brow-r lifts every 7s. One brow, not two - two is surprise,
                 one is contempt.''',
              '''         #brow-r lifts every 6.8s. One brow, not two - two is
                 surprise, one is contempt.
         #mustache twitches, and #mouth opens beneath it. Every cycle
                 is a whole number of frames at 60fps dividing the 408
                 frame loop, so this and boss-idle convert to the SAME
                 comp length and stay in phase when swapped.

       Identical to boss-idle.svg apart from the mustache and mouth, and
       GENERATED from it - so the two cannot drift apart.''')
s = s.replace('''         #brow-r lifts every 6.8s. One brow, not two - two is surprise,
                 one is contempt.''',
              '''         #brow-r lifts every 6.8s. One brow, not two - two is
                 surprise, one is contempt.
         #mustache twitches, and #mouth opens beneath it. Every cycle
                 is a whole number of frames at 60fps dividing the 408
                 frame loop, so this and boss-idle convert to the SAME
                 comp length and stay in phase when swapped.

       Identical to boss-idle.svg apart from the mustache and mouth, and
       GENERATED from it - so the two cannot drift apart.''')

io.open(TALK, 'w', encoding='utf-8').write(s)
print('wrote %s (%d bytes)' % (TALK, len(s)))

# Every looping cycle must be a whole number of frames AND divide the comp,
# which is what the Lottie converter actually requires.
COMP = 408                       # frames, 6.8s at 60fps
durs = sorted(set(float(d) for d in re.findall(r'dur="([\d.]+)s"', s)))
print('cycle lengths (comp = %d frames / %.1fs at 60fps):' % (COMP, COMP / 60.0))
for d in durs:
    fr = d * 60
    assert abs(fr - round(fr)) < 0.05, '%gs is %.2f frames, not a whole one' % (d, fr)
    fr = round(fr)
    assert COMP % fr == 0, '%d frames does not divide %d' % (fr, COMP)
    print('   %-8gs = %3d frames  x%-3d  -> no retiming' % (d, fr, COMP // fr))
