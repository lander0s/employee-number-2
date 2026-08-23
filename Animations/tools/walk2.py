# -*- coding: utf-8 -*-
"""Tree walk + comp assembly. See lottiegen.py for the primitives."""
import json, re, sys
import xml.etree.ElementTree as ET
from lottiegen import (SVG, FPS, VB_DX, CFG, EASE, LIN, parse_path,
                       parse_transform, cycles, oneshot, stat, anim,
                       fill, stroke, grad_fill, tr, group)

CAP = {'butt': 1, 'round': 2, 'square': 3}
JOIN = {'miter': 1, 'round': 2, 'bevel': 3}
GRADS = {}
MODE = 'loop'


def secs(s):
    return float(str(s).replace('s', '')) if s else 0.0


def collect_durs(root):
    out = []
    for tag in ('animate', 'animateTransform'):
        for a in root.iter(SVG + tag):
            if a.get('repeatCount') == 'indefinite':
                out.append(secs(a.get('dur')))
    return sorted(set(out))


def pick_comp(durs, max_frames=1600):
    """Smallest frame count where every looping sub-cycle divides the comp
    evenly, minimising how far each has to be retimed to get there."""
    best = None
    for n in range(FPS // 2, max_frames + 1):
        worst = 0.0
        ok = True
        for d in durs:
            k = max(1, int(round(n / (d * FPS))))
            if n % k:
                ok = False
                break
            worst = max(worst, abs((n / k) / FPS - d) / d)
        if ok and (best is None or worst < best[1] - 1e-9):
            best = (n, worst)
            if worst < 1e-9:
                break
    return best


def retime(d):
    n = int(round(CFG['dur'] * FPS))
    k = max(1, int(round(n / (d * FPS))))
    return (n / k) / FPS


def kt_of(a, nvals):
    if a.get('keyTimes'):
        return [float(x) for x in a.get('keyTimes').split(';')]
    return [i / (nvals - 1.0) for i in range(nvals)]


def ease_of(a, nseg):
    """One cubic-bezier per segment. keySplines is per-segment in SMIL, so
    collapsing it to a single curve would flatten deliberately varied timing
    (the merge holds still on linear dwells and accelerates into the smash)."""
    if a.get('calcMode') != 'spline':
        return [LIN] * nseg
    ks = a.get('keySplines')
    if not ks:
        return [EASE] * nseg
    out = [tuple(float(x) for x in seg.split()) for seg in ks.split(';') if seg.strip()]
    assert len(out) == nseg, 'keySplines %d != segments %d' % (len(out), nseg)
    return out


def build(a, vals, loop_ok=True):
    """<animate>/<animateTransform> -> keyframes, honouring MODE."""
    kts = kt_of(a, len(vals))
    pairs = list(zip(kts, vals))
    eases = ease_of(a, len(vals) - 1)
    if a.get('repeatCount') == 'indefinite':
        if MODE == 'oneshot' or not loop_ok:
            return None                      # ambient loop, dropped
        ph = -secs(a.get('begin')) if a.get('begin', '').startswith('-') else 0.0
        return cycles(pairs, retime(secs(a.get('dur'))), eases, ph)
    return oneshot(pairs, secs(a.get('dur')), eases)


def bbox(subs):
    xs = [v[0] for s in subs for v in s['v']]
    ys = [v[1] for s in subs for v in s['v']]
    return min(xs), min(ys), max(xs), max(ys)


def inherit(style, el):
    s = dict(style)
    for at, k in (('fill', 'fill'), ('stroke', 'stroke'), ('stroke-width', 'sw'),
                  ('stroke-linecap', 'lc'), ('stroke-linejoin', 'lj'),
                  ('fill-opacity', 'fop')):
        if el.get(at) is not None:
            s[k] = el.get(at)
    if el.get('opacity') is not None:
        s['op'] = float(style.get('op', 1)) * float(el.get('opacity'))
    return s


def paints(style, subs, fill_kf=None):
    out = []
    sw = float(style.get('sw', 0) or 0)
    st = style.get('stroke')
    if st and st != 'none' and sw > 0:
        out.append(stroke(st, sw, CAP.get(style.get('lc', 'butt'), 1),
                          JOIN.get(style.get('lj', 'miter'), 1)))
    fl = style.get('fill')
    # fill-opacity multiplies into the fill only, leaving the stroke opaque
    op = float(style.get('op', 1)) * float(style.get('fop', 1)) * 100
    if fl and fl != 'none':
        if fl.startswith('url('):
            g = GRADS[fl[5:-1]]
            x0, y0, x1, y1 = bbox(subs)
            s = (x0 + g['x1'] * (x1 - x0), y0 + g['y1'] * (y1 - y0))
            e = (x0 + g['x2'] * (x1 - x0), y0 + g['y2'] * (y1 - y0))
            out.append(grad_fill(g['stops'], s, e, op))
        else:
            out.append(fill(fl, op, fill_kf))
    return out


def shape_items(el):
    t = el.tag.replace(SVG, '')
    if t == 'path':
        subs = parse_path(el.get('d'))
        return ([{"ty": "sh", "ind": i, "ks": stat(s), "nm": "p%d" % i}
                 for i, s in enumerate(subs)], subs)
    if t == 'rect':
        x, y = float(el.get('x')), float(el.get('y'))
        w, h = float(el.get('width')), float(el.get('height'))
        sub = [{'v': [[x, y], [x + w, y], [x + w, y + h], [x, y + h]],
                'i': [], 'o': [], 'c': True}]
        return ([{"ty": "rc", "p": stat([x + w / 2, y + h / 2]),
                  "s": stat([w, h]), "r": stat(float(el.get('rx', 0))),
                  "d": 1, "nm": "rc"}], sub)
    if t in ('ellipse', 'circle'):
        cx, cy = float(el.get('cx', 0)), float(el.get('cy', 0))
        if t == 'circle':
            rx = ry = float(el.get('r'))
        else:
            rx, ry = float(el.get('rx')), float(el.get('ry'))
        sub = [{'v': [[cx - rx, cy - ry], [cx + rx, cy - ry],
                      [cx + rx, cy + ry], [cx - rx, cy + ry]],
                'i': [], 'o': [], 'c': True}]
        return ([{"ty": "el", "p": stat([cx, cy]),
                  "s": stat([rx * 2, ry * 2]), "d": 1, "nm": "el"}], sub)
    raise ValueError('unhandled shape ' + t)


def walk(el, style):
    out = []
    for ch in el:
        t = ch.tag.replace(SVG, '')
        if t in ('defs', 'animate', 'animateTransform', 'title', 'desc'):
            continue
        st = inherit(style, ch)
        if t == 'g':
            kids = walk(ch, st)
            p, a, r, sc = parse_transform(ch.get('transform'))
            kw = dict(p=p, a=a, r=r, s=sc)
            at = ch.find(SVG + 'animateTransform')
            if at is not None:
                vs = [v.strip().split() for v in at.get('values').split(';')]
                if at.get('type') == 'rotate':
                    if len(vs[0]) == 3:                 # rotate about a point
                        c = [float(vs[0][1]), float(vs[0][2])]
                        kw['p'], kw['a'] = c, c
                    k = build(at, [float(v[0]) for v in vs])
                    if k:
                        kw['rk'] = k
                    else:
                        kw['r'] = float(vs[0][0])
                else:                                    # translate
                    k = build(at, [[float(x) for x in v] for v in vs])
                    if k:
                        kw['pk'] = k
            an = ch.find(SVG + 'animate')
            if an is not None and an.get('attributeName') == 'opacity':
                k = build(an, [float(v) * 100 for v in an.get('values').split(';')])
                if k:
                    kw['ok'] = k
                else:
                    kw['o'] = float(ch.get('opacity', 1)) * 100
            elif ch.get('opacity') is not None:
                kw['o'] = float(ch.get('opacity')) * 100
            out.append(group(ch.get('id') or 'g', list(reversed(kids)), **kw))
            continue

        items, subs = shape_items(ch)
        fkf = None
        an = {x.get('attributeName'): x for x in ch.findall(SVG + 'animate')}
        if 'ry' in an or 'rx' in an:
            # rx and ry may BOTH be animated (the walking shadow squashes on
            # each axis); fold them into the single 2D ellipse size property
            rx0 = float(ch.get('rx')); ry0 = float(ch.get('ry'))
            arx, ary = an.get('rx'), an.get('ry')
            # NB: an ElementTree Element with no children is falsy, so these
            # must be `is not None` checks, not truthiness tests
            rxv = ([float(v) for v in arx.get('values').split(';')]
                   if arx is not None else None)
            ryv = ([float(v) for v in ary.get('values').split(';')]
                   if ary is not None else None)
            if rxv and ryv:
                assert len(rxv) == len(ryv), 'rx/ry keyframe counts differ'
            n = len(rxv or ryv)
            vals = [[(rxv[i] if rxv else rx0) * 2, (ryv[i] if ryv else ry0) * 2]
                    for i in range(n)]
            k = build(arx if arx is not None else ary, vals)
            if k:
                items[0]["s"] = anim(k)
        if 'opacity' in an:
            base = float(style.get('op', 1)) * 100
            fkf = build(an['opacity'],
                        [float(v) * base for v in an['opacity'].get('values').split(';')])
        out.append(group(ch.get('id') or t, items + paints(st, subs, fkf)))
    return out


def convert(src, name, mode='loop', shot_dur=None):
    global MODE
    MODE = mode
    root = ET.parse(src).getroot()
    GRADS.clear()
    for g in root.iter(SVG + 'linearGradient'):
        GRADS[g.get('id')] = {
            'x1': float(g.get('x1', 0)), 'y1': float(g.get('y1', 0)),
            'x2': float(g.get('x2', 1)), 'y2': float(g.get('y2', 0)),
            'stops': [(float(s.get('offset')), s.get('stop-color'),
                       float(s.get('stop-opacity', 1))) for s in g]}
    if mode == 'oneshot':
        n = int(round(shot_dur * FPS)) + 1
        CFG['dur'] = shot_dur
        note = 'one-shot, %.2fs' % shot_dur
    else:
        durs = collect_durs(root)
        n, err = pick_comp(durs)
        CFG['dur'] = n / FPS
        note = 'loop %.3fs, worst retime %.2f%%' % (n / FPS, err * 100)
        for d in durs:
            print('      %5.2fs -> %6.3fs  (%+.1f%%)  x%d'
                  % (d, retime(d), (retime(d) - d) / d * 100,
                     round(CFG['dur'] / retime(d))))
    shapes = list(reversed(walk(root, {})))
    # A Lottie comp always starts at 0,0; an SVG viewBox need not. Shift by
    # -min so any viewBox works, not just the robot's -30 0 300 240.
    vb = [float(v) for v in re.split(r'[ ,]+', root.get('viewBox').strip())]
    ox, oy, cw, ch = -vb[0], -vb[1], vb[2], vb[3]
    print('   %-34s %s  [%gx%g, offset %+g%+g]' % (name, note, cw, ch, ox, oy))
    return {"v": "5.7.4", "fr": FPS, "ip": 0, "op": n, "w": cw, "h": ch,
            "nm": name, "ddd": 0, "assets": [], "markers": [],
            "layers": [{"ddd": 0, "ind": 1, "ty": 4, "nm": "robot", "sr": 1,
                        "ip": 0, "op": n, "st": 0, "bm": 0,
                        "ks": {"o": stat(100), "r": stat(0),
                               "p": stat([ox, oy, 0]), "a": stat([0, 0, 0]),
                               "s": stat([100, 100, 100])},
                        "shapes": shapes}]}


if __name__ == '__main__':
    jobs = [('delivery-robot-idle', 'loop', None),
            ('delivery-robot-walking', 'loop', None),
            ('delivery-robot-holding', 'loop', None),
            ('delivery-robot-walking-holding', 'loop', None),
            ('delivery-robot-pickup', 'oneshot', 1.15),
            ('delivery-robot-merge', 'oneshot', 2.2),
            ('boss-idle', 'loop', None),
            ('boss-talking', 'loop', None)]
    for nm, mode, sd in jobs:
        d = convert(nm + '.svg', nm, mode, sd)
        json.dump(d, open(nm + '.json', 'w'), separators=(',', ':'))
