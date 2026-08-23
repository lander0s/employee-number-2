# -*- coding: utf-8 -*-
"""SVG -> Lottie for the delivery-robot sprite set.

Written against the subset these assets use, not general SVG:
  geometry  M/L/Q/A/Z paths, rect+rx, ellipse, circle
  paint     solid fills, linear gradients (objectBoundingBox), uniform strokes
  groups    transform="translate(...) rotate(...) scale(...)", nested
  motion    <animate> on rx/ry/opacity, <animateTransform> translate/rotate

Coordinates stay in SVG user space; the layer position carries the viewBox
offset, so nested local coordinates (the pickup rig) are untouched.
"""
import json, math, re
import xml.etree.ElementTree as ET

SVG = '{http://www.w3.org/2000/svg}'
FPS = 60
VB_DX = 30.0            # viewBox -30..270 -> comp 0..300
CFG = {'dur': 1.0}      # comp duration in seconds, set per file

EASE = (.45, 0, .55, 1)   # matches every keySplines in these files
LIN = (0, 0, 1, 1)


def rgb(h):
    h = h.lstrip('#')
    return [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]


# ------------------------------------------------------------------ path
TOK = re.compile(r'([MLQAZmlqaz])|(-?\d*\.?\d+(?:[eE]-?\d+)?)')


def tokens(d):
    for m in TOK.finditer(d):
        yield m.group(1) if m.group(1) else float(m.group(2))


def arc_to_cubics(p0, rx, ry, phi, laf, sf, p1):
    x0, y0 = p0
    x1, y1 = p1
    if rx == 0 or ry == 0:
        return [((x0, y0), (x1, y1), (x1, y1))]
    phi = math.radians(phi)
    cs, sn = math.cos(phi), math.sin(phi)
    dx2, dy2 = (x0 - x1) / 2.0, (y0 - y1) / 2.0
    x1p, y1p = cs * dx2 + sn * dy2, -sn * dx2 + cs * dy2
    rx, ry = abs(rx), abs(ry)
    lam = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
    if lam > 1:
        s = math.sqrt(lam)
        rx *= s
        ry *= s
    num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
    den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
    co = math.sqrt(max(0.0, num / den)) if den else 0.0
    if laf == sf:
        co = -co
    cxp, cyp = co * rx * y1p / ry, -co * ry * x1p / rx
    cx = cs * cxp - sn * cyp + (x0 + x1) / 2.0
    cy = sn * cxp + cs * cyp + (y0 + y1) / 2.0

    def ang(ux, uy, vx, vy):
        d = (ux * vx + uy * vy) / (math.hypot(ux, uy) * math.hypot(vx, vy))
        a = math.acos(max(-1.0, min(1.0, d)))
        return -a if ux * vy - uy * vx < 0 else a

    th1 = ang(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
    dth = ang((x1p - cxp) / rx, (y1p - cyp) / ry,
              (-x1p - cxp) / rx, (-y1p - cyp) / ry)
    if not sf and dth > 0:
        dth -= 2 * math.pi
    elif sf and dth < 0:
        dth += 2 * math.pi
    n = max(1, int(math.ceil(abs(dth) / (math.pi / 2))))
    out = []
    delta = dth / n
    t = 4.0 / 3.0 * math.tan(delta / 4.0)
    for i in range(n):
        a0 = th1 + i * delta
        a1 = a0 + delta

        def pt(a):
            return (cs * rx * math.cos(a) - sn * ry * math.sin(a) + cx,
                    sn * rx * math.cos(a) + cs * ry * math.sin(a) + cy)

        def dv(a):
            return (-cs * rx * math.sin(a) - sn * ry * math.cos(a),
                    -sn * rx * math.sin(a) + cs * ry * math.cos(a))

        pa, pb = pt(a0), pt(a1)
        da, db = dv(a0), dv(a1)
        out.append(((pa[0] + t * da[0], pa[1] + t * da[1]),
                    (pb[0] - t * db[0], pb[1] - t * db[1]), pb))
    return out


def parse_path(d):
    ts = list(tokens(d))
    k = 0
    cur = None
    subs = []
    p = (0.0, 0.0)
    start = (0.0, 0.0)
    cmd = None
    while k < len(ts):
        if isinstance(ts[k], str):
            cmd = ts[k]
            k += 1
        if cmd == 'M':
            p = (ts[k], ts[k + 1]); k += 2; start = p
            if cur:
                subs.append(cur)
            cur = {'v': [[p[0], p[1]]], 'i': [[0.0, 0.0]], 'o': [[0.0, 0.0]],
                   'c': False}
            cmd = 'L'
        elif cmd == 'L':
            p = (ts[k], ts[k + 1]); k += 2
            cur['v'].append([p[0], p[1]])
            cur['i'].append([0.0, 0.0])
            cur['o'].append([0.0, 0.0])
        elif cmd == 'Q':
            q = (ts[k], ts[k + 1]); e = (ts[k + 2], ts[k + 3]); k += 4
            c1 = (p[0] + 2.0 / 3 * (q[0] - p[0]), p[1] + 2.0 / 3 * (q[1] - p[1]))
            c2 = (e[0] + 2.0 / 3 * (q[0] - e[0]), e[1] + 2.0 / 3 * (q[1] - e[1]))
            cur['o'][-1] = [c1[0] - p[0], c1[1] - p[1]]
            cur['v'].append([e[0], e[1]])
            cur['i'].append([c2[0] - e[0], c2[1] - e[1]])
            cur['o'].append([0.0, 0.0])
            p = e
        elif cmd == 'A':
            rx, ry, phi = ts[k], ts[k + 1], ts[k + 2]
            laf, sf = int(ts[k + 3]), int(ts[k + 4])
            e = (ts[k + 5], ts[k + 6]); k += 7
            for c1, c2, end in arc_to_cubics(p, rx, ry, phi, laf, sf, e):
                cur['o'][-1] = [c1[0] - p[0], c1[1] - p[1]]
                cur['v'].append([end[0], end[1]])
                cur['i'].append([c2[0] - end[0], c2[1] - end[1]])
                cur['o'].append([0.0, 0.0])
                p = end
        elif cmd in ('Z', 'z'):
            cur['c'] = True
            if (len(cur['v']) > 1
                    and abs(cur['v'][-1][0] - cur['v'][0][0]) < 1e-6
                    and abs(cur['v'][-1][1] - cur['v'][0][1]) < 1e-6):
                cur['i'][0] = cur['i'][-1]
                for key in ('v', 'i', 'o'):
                    cur[key].pop()
            p = start
            cmd = None
            if k < len(ts) and isinstance(ts[k], str):
                continue
        else:
            raise ValueError('unhandled path command %r' % cmd)
    if cur:
        subs.append(cur)
    for s in subs:
        for key in ('v', 'i', 'o'):
            s[key] = [[round(a, 3) for a in pt] for pt in s[key]]
    return subs


# -------------------------------------------------------------- transform
TRF = re.compile(r'(translate|rotate|scale)\s*\(([^)]*)\)')


def parse_transform(s):
    """SVG transform list -> Lottie (p, a, r, s). Lottie composes as
    T(p).R(r).S(s).T(-a), which covers translate[ rotate][ scale] in order."""
    p = [0.0, 0.0]; a = [0.0, 0.0]; r = 0.0; sc = [100.0, 100.0]
    if not s:
        return p, a, r, sc
    for name, args in TRF.findall(s):
        n = [float(x) for x in re.split(r'[\s,]+', args.strip()) if x]
        if name == 'translate':
            p = [n[0], n[1] if len(n) > 1 else 0.0]
        elif name == 'rotate':
            r = n[0]
            if len(n) == 3:                      # rotate about a point
                a = [n[1], n[2]]
                p = [n[1], n[2]]
        elif name == 'scale':
            sc = [n[0] * 100, (n[1] if len(n) > 1 else n[0]) * 100]
    return p, a, r, sc


# -------------------------------------------------------------- keyframes
def _kf(t, val, e):
    """One Lottie keyframe. `e` is this SEGMENT's cubic-bezier (x1,y1,x2,y2):
    o carries the out-tangent of this keyframe, i the in-tangent of the next."""
    return {"t": round(t, 3),
            "s": val if isinstance(val, list) else [val],
            "o": {"x": [e[0]], "y": [e[1]]},
            "i": {"x": [e[2]], "y": [e[3]]}}


def cycles(per_cycle, cyc_s, eases=None, phase=0.0):
    """per_cycle: [(frac, value)] repeated to fill the comp.
    eases: one cubic-bezier per SEGMENT (len(per_cycle)-1 of them).
    phase shifts the whole train earlier (SMIL begin="-0.13s")."""
    dur = CFG['dur']
    n = int(round(dur / cyc_s))
    assert abs(dur / cyc_s - n) < 1e-6, 'cycle %s does not divide comp %s' % (cyc_s, dur)
    m = len(per_cycle) - 1
    if eases is None:
        eases = [EASE] * m
    cf = cyc_s * FPS
    out = []
    for c in range(n + (1 if phase else 0)):
        for j, (fr, val) in enumerate(per_cycle):
            if c > 0 and j == 0:
                continue
            # the cycle's LAST keyframe is followed by the next cycle's
            # second one, so it owns segment 0, not segment m
            out.append(_kf(c * cf + fr * cf - phase * FPS, val,
                           eases[j] if j < m else eases[0]))
    last = dict(out[-1]); last.pop("o", None); last.pop("i", None)
    out[-1] = last
    return out


def oneshot(pairs, dur_s, eases=None):
    """pairs: [(frac_of_dur, value)] played once."""
    if eases is None:
        eases = [EASE] * (len(pairs) - 1)
    out = [_kf(fr * dur_s * FPS, val, eases[min(i, len(eases) - 1)])
           for i, (fr, val) in enumerate(pairs)]
    last = dict(out[-1]); last.pop("o", None); last.pop("i", None)
    out[-1] = last
    return out


def stat(v): return {"a": 0, "k": v}
def anim(k): return {"a": 1, "k": k}


# ------------------------------------------------------------ shape items
def fill(color, op=100, opk=None):
    return {"ty": "fl", "c": stat(rgb(color) + [1]),
            "o": anim(opk) if opk else stat(op), "r": 1, "bm": 0, "nm": "fill"}


def stroke(color, w, lc=2, lj=2):
    return {"ty": "st", "c": stat(rgb(color) + [1]), "o": stat(100),
            "w": stat(w), "lc": lc, "lj": lj, "ml": 4, "bm": 0, "nm": "stroke"}


def grad_fill(stops, s, e, op=100):
    ck, ak = [], []
    for pos, col, al in stops:
        ck += [pos] + rgb(col)
        ak += [pos, al]
    return {"ty": "gf", "o": stat(op), "r": 1, "t": 1, "bm": 0, "nm": "grad",
            "s": stat([round(s[0], 2), round(s[1], 2)]),
            "e": stat([round(e[0], 2), round(e[1], 2)]),
            "g": {"p": len(stops), "k": stat(ck + ak)}}


def tr(p=(0, 0), a=(0, 0), r=0, s=(100, 100), o=100,
       pk=None, rk=None, ok=None):
    return {"ty": "tr",
            "p": anim(pk) if pk else stat(list(p)),
            "a": stat(list(a)), "s": stat(list(s)),
            "r": anim(rk) if rk else stat(r),
            "o": anim(ok) if ok else stat(o),
            "sk": stat(0), "sa": stat(0), "nm": "tr"}


def group(name, items, **kw):
    return {"ty": "gr", "nm": name, "bm": 0, "hd": False,
            "it": items + [tr(**kw)]}
