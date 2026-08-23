# -*- coding: utf-8 -*-
"""Regenerate delivery-robot-pickup.svg and delivery-robot-merge.svg so both
grab from FRONT-CENTRE (the grid cell directly below the robot) instead of
off to one side.

Reach limit: the left wrist cannot get past x~111 (max reach 61.5 from the
shoulder at 58,144). The CLAW extends 14 further along its bisector, so the
grip point can still land on the centre line x=120 - that is what makes a
front-centre grab possible at all.

  pickup  both hands are free, so they converge symmetrically. The object
          sits exactly on x=120 by symmetry; claws splay downward (bisector
          70 deg) to leave a gap wide enough to hold something.
  merge   only the left hand is free (the right holds object A), so its claw
          is angled inboard (bisector 30 deg) to put the grip point near the
          centre line on its own.

Both read from a snapshot of the rig (rig-template.svg) rather than from the
files they overwrite, so this stays re-runnable.
"""
import io, math, os, re

S = (58.0, 144.0)
L1, L2 = 32.5, 29.0
FINGER, SPREAD = 13.0, 33.0
CLAW = 14.0
GROUND, CASTER = 195.0, (74.0, 99.0)
# resolved next to this script, so it works from tools/ while the
# assets it reads and writes stay relative to the CWD
TEMPLATE = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                        'rig-template.svg')


def ik(w, wrist, sign):
    dx, dy = w[0] - S[0], w[1] - S[1]
    d = math.hypot(dx, dy)
    assert abs(L1 - L2) + 1e-9 < d < L1 + L2 - 1e-9, 'unreachable: d=%.1f' % d
    a = (L1 * L1 - L2 * L2 + d * d) / (2 * d)
    h = math.sqrt(max(0.0, L1 * L1 - a * a))
    ux, uy = dx / d, dy / d
    px, py = S[0] + a * ux, S[1] + a * uy
    best = None
    for ex, ey in ((px - h * uy, py + h * ux), (px + h * uy, py - h * ux)):
        A = math.degrees(math.atan2(ey - S[1], ex - S[0]))
        fore = math.degrees(math.atan2(w[1] - ey, w[0] - ex))
        B = (fore - A + 540) % 360 - 180
        if (B >= 0) == (sign > 0):
            kind, val = wrist
            best = (A, B, val if kind == 'rel' else val - fore)
    assert best, 'no solution with elbow sign %+d at %s' % (sign, w)
    return best


def unwrap(seq):
    out = [seq[0]]
    for v in seq[1:]:
        while v - out[-1] > 180:
            v -= 360
        while v - out[-1] < -180:
            v += 360
        out.append(v)
    return out


def fk(A, B, W):
    ex = S[0] + L1 * math.cos(math.radians(A))
    ey = S[1] + L1 * math.sin(math.radians(A))
    f = A + B
    wx = ex + L2 * math.cos(math.radians(f))
    wy = ey + L2 * math.sin(math.radians(f))
    bis = f + W
    return ((ex, ey), (wx, wy),
            (wx + CLAW * math.cos(math.radians(bis)),
             wy + CLAW * math.sin(math.radians(bis))), bis)


def tips(A, B, W):
    _, (wx, wy), _, bis = fk(A, B, W)
    return [(wx + FINGER * math.cos(math.radians(bis + s)),
             wy + FINGER * math.sin(math.radians(bis + s)))
            for s in (+SPREAD, -SPREAD)]


def solve(poses, which):
    raw = [ik(*p[which]) for p in poses]
    return list(zip(*[unwrap([r[j] for r in raw]) for j in range(3)]))


def check(name, Lang, Rang, poses, min_clear=2):
    worst, overlap, minreach, at = 0.0, False, 1e9, None
    for angs, mirror in ((Lang, False), (Rang, True)):
        for i in range(len(angs) - 1):
            for s in range(61):
                t = s / 60.0
                a = [angs[i][k] + (angs[i + 1][k] - angs[i][k]) * t for k in range(3)]
                _, (wx, wy), _, _ = fk(*a)
                minreach = min(minreach, math.hypot(wx - S[0], wy - S[1]))
                for tx, ty in tips(*a):
                    if ty + 6 > worst:
                        worst, at = ty + 6, (poses[i][0], poses[i + 1][0], round(t, 2))
                    x = 240 - tx if mirror else tx
                    if CASTER[0] - 6 < x < CASTER[1] + 6 and ty + 6 > 172:
                        overlap = True
    print('  ground: lowest painted %.1f -> clearance %+.1f  (worst %s->%s t=%.2f)'
          % (worst, GROUND - worst, at[0], at[1], at[2]))
    print('  wrist never closer than %.1f to the shoulder (folds flat below ~10)' % minreach)
    print('  claw passes in front of a caster: %s  (fine - drawn on top)'
          % ('yes' if overlap else 'no'))
    return GROUND - worst > min_clear and minreach > 12


def emit(outfile, Lang, Rang, kt, spl, dur, payloads, trig, header, play):
    src = io.open(TEMPLATE, encoding='utf-8').read()
    seq = [[p[j] for p in Lang] for j in range(3)] + \
          [[p[j] for p in Rang] for j in range(3)]
    ktS = ';'.join(str(k) for k in kt)
    splS = ';'.join(spl)
    pat = re.compile(r'( *)<animateTransform[^>]*?attributeName="transform" type="rotate"'
                     r'\s*\n\s*data-pose="[^"]*" values="[^"]*"\s*\n'
                     r'\s*begin="[^"]*" dur="[^"]*" fill="freeze"\s*\n'
                     r'\s*calcMode="spline" keySplines="[^"]*"/>', re.S)
    idx = [0]

    def sub(m):
        ind = m.group(1)
        i = idx[0]; idx[0] += 1
        v = ';'.join('%.1f' % x for x in seq[i])
        ident = ' id="%s"' % trig if i == 0 else ''
        begin = '0s' if i == 0 else trig + '.begin'
        return (ind + '<animateTransform' + ident +
                ' attributeName="transform" type="rotate"\n' +
                ind + '   values="' + v + '"\n' +
                ind + '   keyTimes="' + ktS + '"\n' +
                ind + '   begin="' + begin + '" dur="' + str(dur) + 's" fill="freeze"\n' +
                ind + '   calcMode="spline" keySplines="' + splS + '"/>')

    src = pat.sub(sub, src)
    assert idx[0] == 6, 'patched %d joint animations' % idx[0]

    blocks = []
    for pid, pts, op, note in payloads:
        vals = ';'.join('%.1f %.1f' % p for p in pts)
        b = ('<g id="%s" transform="translate(%.1f,%.1f)" opacity="%s">\n'
             % (pid, pts[0][0], pts[0][1], op.split(';')[0]))
        b += '        <!-- %s -->\n' % note
        if len(set(pts)) > 1:
            b += ('        <animateTransform attributeName="transform" type="translate"\n'
                  '           values="' + vals + '"\n'
                  '           keyTimes="' + ktS + '" begin="' + trig + '.begin"'
                  ' dur="' + str(dur) + 's"\n'
                  '           fill="freeze" calcMode="spline" keySplines="' + splS + '"/>\n')
        if len(set(op.split(';'))) > 1:
            b += ('        <animate attributeName="opacity" values="' + op + '"\n'
                  '           keyTimes="' + ktS + '" begin="' + trig + '.begin"'
                  ' dur="' + str(dur) + 's" fill="freeze"/>\n')
        b += '      </g>'
        blocks.append(b)
    src = src.replace(re.search(r'<g id="payload".*?</g>', src, re.S).group(0),
                      '\n\n      '.join(blocks))
    src = src.replace('id="pickup"', 'id="%s"' % trig)

    for cls, v in (('j-sh', Lang[0][0]), ('j-el', Lang[0][1]), ('j-wr', Lang[0][2])):
        src = re.sub(r'(class="' + cls + r'" transform="rotate\()[-0-9.]+(\)")',
                     lambda m, v=v: '%s%.1f%s' % (m.group(1), v, m.group(2)), src)

    a = src.index('       CARTOON DELIVERY ROBOT / STATE:')
    b = src.index('       Camera sits above')
    src = src[:a] + header + src[b:]
    a = src.index('           PLAYBACK.')
    b = src.index('-->', a)
    src = src[:a] + play + '           ' + src[b:]
    io.open(outfile, 'w', encoding='utf-8').write(src)


def table(poses, Lang):
    return '\n'.join('             %-8s %8.1f %8.1f %8.1f'
                     % (poses[i][0], Lang[i][0], Lang[i][1], Lang[i][2])
                     for i in range(len(poses)))


# ===================================================================== PICKUP
IDLE = ((5.55, 170.5), ('rel', -45), -1)
HOLD = ((77.4, 96.3), ('rel', 37.5), +1)
# both hands free -> converge on the centre line, claws splayed down (70 deg)
# Grab lower than before: this animation is picking something off the floor,
# so the claws are ALLOWED through the ground line - that line only marks
# where this robot's own wheels sit, and the cell it reaches into is nearer
# the camera. Keeping the old never-touch-the-ground rule here is what forced
# the previous up-and-over transit.
# Reach as deep into the cell below as the rig allows. The binding limit is
# no longer the ground line (that only marks where this robot's own wheels
# sit) but arm extension: this is 90% of the 61.5 max, which still leaves a
# readable elbow bend. Grip lands ON the ground line, claws into the shadow.
GRAB2 = ((95, 185), ('abs', 48), -1)
# No transit. Straight from idle the shoulders simply close inward: the
# viewer-left arm swings counter-clockwise and the right one clockwise, the
# hands meet at bottom-centre, and then both lift.
P_POSES = [('idle', IDLE, IDLE), ('idle', IDLE, IDLE),
           ('grab', GRAB2, GRAB2), ('hold-still', GRAB2, GRAB2),
           ('hold', HOLD, HOLD)]
P_KT = [0, .05, .46, .58, 1]
P_SPL = ['0 0 1 1', '.4 0 .25 1', '0 0 1 1', '.35 0 .2 1']
P_DUR = 1.15

print('PICKUP')
PL = solve(P_POSES, 1); PR = solve(P_POSES, 2)
for (nm, _, _), a in zip(P_POSES, PL):
    print('  %-6s [%7.1f,%7.1f,%7.1f]' % (nm, a[0], a[1], a[2]))
Lc = [fk(*a)[2] for a in PL]
Rc = [(240 - fk(*a)[2][0], fk(*a)[2][1]) for a in PR]
grip = [((l[0] + r[0]) / 2, (l[1] + r[1]) / 2) for l, r in zip(Lc, Rc)]
print('  grab point (midway between the claws): %.1f, %.1f' % grip[3])
print('  claw gap at the grab: %.1f' % (Rc[3][0] - Lc[3][0]))
ok = check('pickup', PL, PR, P_POSES, min_clear=-40)
P_PAY = [('payload',
          [grip[3], grip[3], grip[3], grip[3], (120.0, 96.0)],
          '1;1;1;1;1',
          'the object: sits in the cell in front until the claws close, '
          'then rides up into the two-handed grip')]

# ====================================================================== MERGE
CARRY = ((95, 100), ('rel', 30), +1)
# only the left hand is free -> claw angled inboard so the grip point still
# lands near the centre line
# One hand cannot get as deep AND as central as two, so this trades ~5 units
# of centring for ~10 of depth: grip at x=115 rather than 120, but 9 units
# lower. At sprite scale 5 units is well under a pixel.
GRAB1 = ((104, 180), ('abs', 38), -1)
M_POSES = [
    ('hold', HOLD, HOLD), ('hold', HOLD, HOLD),
    ('reach', GRAB1, CARRY), ('grab', GRAB1, CARRY),
    ('twoup', ((66, 92), ('rel', 40), +1), ((66, 92), ('rel', 40), +1)),
    ('wind', ((54, 86), ('rel', 55), +1), ((54, 86), ('rel', 55), +1)),
    ('smash', ((95, 100), ('rel', 25), +1), ((95, 100), ('rel', 25), +1)),
    ('settle', ((74, 94), ('rel', 40), +1), ((74, 94), ('rel', 40), +1)),
    ('hold', HOLD, HOLD),
]
M_KT = [0, .06, .30, .42, .56, .68, .79, .88, 1]
M_SPL = ['0 0 1 1', '.4 0 .2 1', '0 0 1 1', '.4 0 .2 1',
         '.3 0 .7 1', '.8 0 1 1', '.1 0 .3 1', '.4 0 .2 1']
M_DUR = 2.2

print('\nMERGE')
ML = solve(M_POSES, 1); MR = solve(M_POSES, 2)
for (nm, _, _), a in zip(M_POSES, ML):
    print('  %-6s [%7.1f,%7.1f,%7.1f]' % (nm, a[0], a[1], a[2]))
MLc = [fk(*a)[2] for a in ML]
MRc = [(240 - fk(*a)[2][0], fk(*a)[2][1]) for a in MR]
print('  grab point (left claw): %.1f, %.1f   (centre line is x=120)' % MLc[3])
ok2 = check('merge', ML, MR, M_POSES, min_clear=-40)
for k in range(3):
    assert abs((ML[-1][k] - ML[0][k]) % 360) < 1e-6
    assert abs((MR[-1][k] - MR[0][k]) % 360) < 1e-6
print('  ends on exactly the HOLD pose: yes')

M_PAY = [
    ('payload-a', [(120.0, 96.0), (120.0, 96.0)] + MRc[2:], '1;1;1;1;1;1;1;0;0',
     'object A: starts in the two-handed grip, slides into the right claw '
     'as the left hand leaves, ends at the collision'),
    ('payload-b', [MLc[3]] * 4 + MLc[4:], '1;1;1;1;1;1;1;0;0',
     'object B: waits in the cell in front, then rides the left claw up'),
    ('payload', [(120.0, 96.0)] * len(M_KT), '0;0;0;0;0;0;0;1;1',
     'the merged result, in the same slot the HOLDING sprite uses'),
]

if not (ok and ok2):
    raise SystemExit('\nSAFETY CHECK FAILED - not writing files')

emit('delivery-robot-pickup.svg', PL, PR, P_KT, P_SPL, P_DUR, P_PAY, 'pickup',
     ('       CARTOON DELIVERY ROBOT / STATE: PICKUP  -  3/4 top-down view\n'
      '       ONE-SHOT, %.1fs. IDLE -> reach down to FRONT-CENTRE -> grab ->\n'
      '       lift into HOLDING, then freezes there.\n\n'
      '       "Front-centre" is the grid cell directly below the robot. Both\n'
      '       hands converge on the centre line, so the grab point is exactly\n'
      '       x=120 by symmetry.\n\n'
      '       Statically (no SMIL) it renders the IDLE pose.\n') % P_DUR,
     ('           PLAYBACK. One animation per joint plus the payload slot,\n'
      '           %d keyframes each. The first carries id="pickup"; everything\n'
      '           else is slaved to begin="pickup.begin", so ONE call runs it:\n\n'
      '               svg.getElementById(\'pickup\').beginElement();\n\n'
      '           begin="0s" self-demos on load; change to begin="indefinite"\n'
      '           for game control.\n\n'
      '           GRAB POINT: %.1f, %.1f  (claws %.1f apart). #payload sits\n'
      '           there until the claws close, then rides up to 120,96 - the\n'
      '           same slot the HOLDING sprite uses.\n\n'
      '           POSE TABLE (left arm; right arm is the same rig under\n'
      '           scale(-1,1) and takes these same numbers):\n'
      '             pose     shoulder    elbow    wrist\n%s\n'
      ) % (len(P_KT), grip[3][0], grip[3][1], Rc[3][0] - Lc[3][0], table(P_POSES, PL)))

emit('delivery-robot-merge.svg', ML, MR, M_KT, M_SPL, M_DUR, M_PAY, 'merge',
     ('       CARTOON DELIVERY ROBOT / STATE: MERGE  -  3/4 top-down view\n'
      '       ONE-SHOT, %.1fs. Starts AND ends on exactly the HOLDING pose.\n\n'
      '         hold -> reach -> grab -> lift -> twoup -> wind -> SMASH\n'
      '              -> settle -> hold\n\n'
      '       The left hand dives to FRONT-CENTRE (the cell below the robot)\n'
      '       for a second object while the right keeps hold of the first;\n'
      '       both come up, the arms wind apart, then slam together and the\n'
      '       robot is left holding a single object.\n\n'
      '       Statically (no SMIL) it renders the HOLDING pose.\n') % M_DUR,
     ('           PLAYBACK. One animation per joint, %d keyframes each. The\n'
      '           first carries id="merge"; the other five and all three\n'
      '           payload slots are slaved to begin="merge.begin":\n\n'
      '               svg.getElementById(\'merge\').beginElement();\n\n'
      '           GRAB POINT: %.1f, %.1f  - the left claw alone, angled inboard\n'
      '           so the grip lands near the centre line (x=120).\n\n'
      '           PAYLOAD SLOTS:\n'
      '             #payload-a  object A, already held. Slides into the right\n'
      '                         claw as the left hand leaves.\n'
      '             #payload-b  object B, waiting in the cell in front.\n'
      '             #payload    the merged result at 120,96.\n\n'
      '           POSE TABLE (left arm; right arm mirrored, same numbers):\n'
      '             pose     shoulder    elbow    wrist\n%s\n'
      '           The elbow may cross 0 (arm straightens) but never +/-180,\n'
      '           which would fold it flat back through its own shoulder.\n'
      ) % (len(M_KT), MLc[3][0], MLc[3][1], table(M_POSES, ML)))

print('\nwrote delivery-robot-pickup.svg and delivery-robot-merge.svg')
