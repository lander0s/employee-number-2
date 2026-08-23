# -*- coding: utf-8 -*-
"""Generate preview.html with every SVG inlined, so it opens straight from
disk with no server. (Browsers block fetch() on file://, which is what forced
an earlier version to be served.)

Also derives a PUTDOWN card by reversing the pickup animation - reverse the
values, mirror keyTimes about the midpoint, and reverse AND flip each
keySplines segment.
"""
import io, re, json

# src file, card name, blurb, seconds, loops, payload slots, reverse?
STATES = [
    ('delivery-robot-idle',    'idle',    'at rest, arms down',        18.20, True,  {}, False),
    ('delivery-robot-walking', 'walking', 'rolling, exaggerated',       4.80, True,  {}, False),
    ('delivery-robot-holding', 'holding', 'at rest, carrying',         18.20, True,  {'payload': 'crate'}, False),
    ('delivery-robot-walking-holding', 'walking-holding', 'rolling, carrying',
     4.80, True, {'payload': 'crate'}, False),
    ('delivery-robot-pickup',  'pickup',  'arms close in, grab, lift',  1.15, False, {'payload': 'crate'}, False),
    ('delivery-robot-pickup',  'putdown', 'the same animation, reversed', 1.15, False, {'payload': 'crate'}, True),
    ('delivery-robot-merge',   'merge',   'two objects -> one',         2.20, False,
     {'payload-a': 'crate', 'payload-b': 'orb', 'payload': 'gem'}, False),
    ('boss-idle',              'boss idle',    'sway + occasional brow',    6.80, True, {}, False),
    ('boss-talking',           'boss talking', 'mustache does the talking', 6.80, True, {}, False),
]

MOCK = {
    'crate': '<rect x="-17" y="-17" width="34" height="34" rx="5" fill="#F2A65A"'
             ' stroke="#1B2838" stroke-width="4" stroke-linejoin="round"/>',
    'orb':   '<circle r="15" fill="#7A5BD6" stroke="#1B2838" stroke-width="4"/>',
    'gem':   '<path d="M0 -24 L21 -12 L21 12 L0 24 L-21 12 L-21 -12 Z" fill="#5CF2DF"'
             ' stroke="#1B2838" stroke-width="4.5" stroke-linejoin="round"/>',
}


def _fmt(v):
    s = ('%.4f' % v).rstrip('0').rstrip('.')
    return s if s else '0'


def reverse_animations(svg):
    """Play the one-shot backwards. Ambient loops are left alone."""
    def rev_el(m):
        el = m.group(0)
        if 'repeatCount="indefinite"' in el:
            return el

        def attr(name):
            mm = re.search(r'%s="([^"]*)"' % name, el)
            return mm.group(1) if mm else None

        vals = attr('values')
        if not vals:
            return el
        parts = [p.strip() for p in vals.split(';')]
        el = re.sub(r'(values=")[^"]*(")',
                    lambda x: x.group(1) + ';'.join(reversed(parts)) + x.group(2), el)
        kt = attr('keyTimes')
        if kt:
            t = [float(v) for v in kt.split(';')]
            new = [round(1 - t[len(t) - 1 - i], 4) for i in range(len(t))]
            el = re.sub(r'(keyTimes=")[^"]*(")',
                        lambda x: x.group(1) + ';'.join(_fmt(v) for v in new) + x.group(2), el)
        ks = attr('keySplines')
        if ks:
            segs = [[float(v) for v in s.split()] for s in ks.split(';') if s.strip()]
            # a cubic-bezier (x1,y1,x2,y2) played backwards is (1-x2,1-y2,1-x1,1-y1)
            flipped = [[1 - s[2], 1 - s[3], 1 - s[0], 1 - s[1]] for s in reversed(segs)]
            el = re.sub(r'(keySplines=")[^"]*(")',
                        lambda x: x.group(1) +
                        ';'.join(' '.join(_fmt(v) for v in s) for s in flipped) +
                        x.group(2), el)
        return el

    svg = re.sub(r'<animate(?:Transform)?\b[^>]*/>', rev_el, svg, flags=re.S)
    # the no-SMIL fallback pose must become the new FIRST keyframe
    for cls in ('j-sh', 'j-el', 'j-wr'):
        pat = re.compile(r'(class="%s" transform="rotate\()[-0-9.]+(\)">\s*\n\s*'
                         r'<animateTransform[^>]*values=")([^;"]+)' % cls, re.S)
        svg = pat.sub(lambda m: m.group(1) + m.group(3) + m.group(2) + m.group(3), svg)
    return svg


def namespace(svg, sfx):
    """Nine SVGs share one document, so every id has to be made unique or
    SMIL's begin="x.begin" and every url(#grad) binds to the wrong card."""
    for i in sorted(set(re.findall(r'\bid="([^"]+)"', svg)), key=len, reverse=True):
        new = '%s__%s' % (i, sfx)
        svg = svg.replace('id="%s"' % i, 'id="%s"' % new)
        svg = svg.replace('url(#%s)' % i, 'url(#%s)' % new)
        svg = svg.replace('begin="%s.begin"' % i, 'begin="%s.begin"' % new)
    return svg


def inject_mocks(svg, slots):
    for sid, kind in slots.items():
        # the closing quote matters: '<g id="payload' also matches
        # '<g id="payload-a"', which drops the merged shape in the wrong slot
        marker = '<g id="%s"' % sid
        assert svg.count(marker) == 1, 'expected exactly one %s' % marker
        i = svg.index(marker)
        j = svg.index('>', i) + 1
        svg = svg[:j] + MOCK[kind] + svg[j:]
    return svg


cards, templates = [], []
for src, name, blurb, dur, loops, slots, rev in STATES:
    svg = io.open('%s.svg' % src, encoding='utf-8').read()
    svg = svg[svg.index('<svg'):]
    if rev:
        svg = reverse_animations(svg)
    svg = inject_mocks(svg, slots)
    key = name.replace('-', '_').replace(' ', '_')
    svg = namespace(svg, key)
    vb = [float(v) for v in re.split(r'[ ,]+',
          re.search(r'viewBox="([^"]+)"', svg).group(1).strip())]
    trig = {'pickup': 'pickup', 'putdown': 'pickup', 'merge': 'merge'}.get(name)
    templates.append('<template id="tpl-%s">%s</template>' % (key, svg))
    cards.append({'name': name, 'key': key, 'blurb': blurb, 'dur': dur,
                  'loops': loops, 'vw': vb[2], 'vh': vb[3],
                  'trig': '%s__%s' % (trig, key) if trig else ''})

HTML = '''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Sprite set preview</title>
<style>
  :root{--bg:#15171d;--panel:#1e2128;--line:#2c313b;--ink:#e6eaf2;--dim:#8b95a7;--accent:#5CF2DF}
  *{box-sizing:border-box}
  body{margin:0;background:var(--bg);color:var(--ink);
       font:14px/1.5 ui-sans-serif,system-ui,'Segoe UI',sans-serif}
  header{position:sticky;top:0;z-index:10;background:rgba(21,23,29,.94);
         backdrop-filter:blur(8px);border-bottom:1px solid var(--line);padding:14px 20px}
  h1{margin:0 0 10px;font-size:16px;font-weight:600}
  h1 small{color:var(--dim);font-weight:400;margin-left:8px}
  .bar{display:flex;flex-wrap:wrap;gap:18px;align-items:center}
  .grp{display:flex;gap:8px;align-items:center}
  .grp>span{color:var(--dim);font-size:12px;text-transform:uppercase;letter-spacing:.6px}
  button{background:var(--panel);color:var(--ink);border:1px solid var(--line);
         padding:6px 12px;border-radius:6px;cursor:pointer;font:inherit;font-size:13px}
  button:hover{border-color:#3d4450}
  button.on{background:var(--accent);color:#0d1114;border-color:var(--accent);font-weight:600}
  input[type=range]{width:130px;accent-color:var(--accent)}
  main{padding:20px;display:grid;gap:18px;align-items:start;
       grid-template-columns:repeat(auto-fill,minmax(300px,1fr))}
  .card{background:var(--panel);border:1px solid var(--line);border-radius:10px;overflow:hidden}
  .head{display:flex;align-items:center;gap:8px;padding:10px 13px;border-bottom:1px solid var(--line)}
  .nm{font-weight:600}
  .tag{font-size:11px;padding:2px 7px;border-radius:20px;border:1px solid var(--line);
       color:var(--dim);white-space:nowrap}
  .tag.shot{color:#ffcf70;border-color:#5a4420}
  .head .sp{flex:1}
  .head button{font-size:12px;padding:4px 9px}
  .body{display:flex;flex-direction:column;align-items:center;gap:7px;padding:14px 10px 12px}
  .stage{display:grid;place-items:center;border-radius:8px;overflow:hidden}
  .stage svg{display:block}
  .blurb{font-size:11px;color:var(--dim);text-align:center;min-height:16px}
  .bg-dark .stage{background:#3a4152}
  .bg-light .stage{background:#e9e4d8}
  .bg-mid .stage{background:#7d8496}
  .bg-checker .stage{background-image:
      linear-gradient(45deg,#3a3f4b 25%,transparent 25%,transparent 75%,#3a3f4b 75%),
      linear-gradient(45deg,#3a3f4b 25%,#2a2e37 25%,#2a2e37 75%,#3a3f4b 75%);
      background-size:16px 16px;background-position:0 0,8px 8px}
  footer{padding:4px 20px 28px;color:var(--dim);font-size:12px}
  footer code{color:var(--ink)}
</style>
</head>
<body class="bg-dark">

<header>
  <h1>Sprite set <small>robot &middot; boss &middot; animated SVG &middot; opens straight from disk</small></h1>
  <div class="bar">
    <div class="grp"><span>bg</span>
      <button data-bg="dark" class="on">dark</button>
      <button data-bg="light">light</button>
      <button data-bg="mid">mid</button>
      <button data-bg="checker">checker</button>
    </div>
    <div class="grp"><span>size</span>
      <input id="size" type="range" min="90" max="380" value="230">
      <span id="sizeval" style="min-width:46px">230px</span>
    </div>
    <div class="grp"><button id="pause">pause</button></div>
  </div>
</header>

<main id="grid"></main>

<footer>
  Cargo shapes are placeholders in the <code>#payload</code> slots. One-shots
  replay on a loop. <code>putdown</code> is <code>pickup</code> with every
  keyframe list reversed at build time &mdash; no separate asset.
  Sprites are scaled to fit a common box, so the robot (300&times;240) and the
  boss (220&times;300) are NOT at true relative scale &mdash; on a shared ground
  line he is about twice the robot's height. See README.md.
</footer>

__TEMPLATES__

<script>
const CARDS = __CARDS__;
const grid = document.getElementById('grid');
let paused = false, timers = [];

for (const c of CARDS) {
  const el = document.createElement('div');
  el.className = 'card';
  el.innerHTML =
    `<div class="head"><span class="nm">${c.name}</span>
       <span class="tag">${c.dur.toFixed(2)}s</span>
       <span class="tag ${c.loops ? '' : 'shot'}">${c.loops ? 'loop' : 'one-shot'}</span>
       <span class="sp"></span></div>
     <div class="body"><div class="stage"></div><div class="blurb">${c.blurb}</div></div>`;
  const stage = el.querySelector('.stage');
  stage.appendChild(document.getElementById('tpl-' + c.key).content.cloneNode(true));
  c.svg = stage.querySelector('svg');
  c.stage = stage;
  if (c.trig) {
    const b = document.createElement('button');
    b.textContent = 'replay';
    b.onclick = () => fire(c);
    el.querySelector('.head').appendChild(b);
  }
  grid.appendChild(el);
}

function fire(c) {
  const a = c.svg.querySelector('#' + CSS.escape(c.trig));
  if (a && a.beginElement) { try { a.beginElement(); } catch (e) {} }
}

// The sprites no longer share an aspect - robot 300x240 landscape, boss
// 220x300 portrait. Setting a width and deriving height from a fixed ratio
// (which is what this did when everything was a robot) squashes the boss and
// makes his card twice as tall as the rest. Scale each to FIT a common box
// instead.
function resize() {
  const w = +document.getElementById('size').value;
  document.getElementById('sizeval').textContent = w + 'px';
  const boxW = w, boxH = Math.round(w * 0.85);
  for (const c of CARDS) {
    const k = Math.min(boxW / c.vw, boxH / c.vh);
    c.stage.style.width = boxW + 'px';
    c.stage.style.height = boxH + 'px';
    c.svg.removeAttribute('width'); c.svg.removeAttribute('height');
    c.svg.style.width = Math.round(c.vw * k) + 'px';
    c.svg.style.height = Math.round(c.vh * k) + 'px';
  }
}

function schedule() {
  timers.forEach(clearInterval); timers = [];
  for (const c of CARDS) if (c.trig)
    timers.push(setInterval(() => { if (!paused) fire(c); }, (c.dur + 0.9) * 1000));
}

document.querySelectorAll('[data-bg]').forEach(b => b.onclick = () => {
  document.querySelectorAll('[data-bg]').forEach(x => x.classList.remove('on'));
  b.classList.add('on');
  document.body.className = 'bg-' + b.dataset.bg;
});
document.getElementById('size').oninput = resize;
document.getElementById('pause').onclick = e => {
  paused = !paused;
  e.target.textContent = paused ? 'play' : 'pause';
  e.target.classList.toggle('on', paused);
  for (const c of CARDS) {
    try { paused ? c.svg.pauseAnimations() : c.svg.unpauseAnimations(); } catch (e) {}
  }
};

resize();
schedule();
CARDS.filter(c => c.trig).forEach(fire);
</script>
</body>
</html>
'''

out = HTML.replace('__TEMPLATES__', '\n'.join(templates))
out = out.replace('__CARDS__', json.dumps(
    [{k: v for k, v in c.items() if k not in ('svg', 'stage')} for c in cards]))
io.open('preview.html', 'w', encoding='utf-8').write(out)
print('wrote preview.html  (%d cards, %.0f KB)' % (len(cards), len(out) / 1024))
for c in cards:
    print('   %-16s %gx%g' % (c['name'], c['vw'], c['vh']))
