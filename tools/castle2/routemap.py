import json, pickle
from PIL import Image, ImageDraw, ImageFont
from shapely.ops import unary_union
R = json.load(open('out/route3.json'))
B = pickle.load(open('massing.pkl', 'rb'))
S = 9.0; W = 1400; H = 1600; OX, OZ = W / 2, 640
F = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 20)
Fb = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 26)
def tf(x, z): return (OX + x * S, OZ + z * S)
im = Image.new('RGB', (W, H), 'white'); d = ImageDraw.Draw(im)
for k in range(-60, 110, 10):
    d.line([tf(-75, k), tf(75, k)], fill=(235, 235, 242)); d.line([tf(k if k <= 75 else 75, -60), tf(k if k <= 75 else 75, 100)], fill=(235, 235, 242))
out = unary_union([g for (y0, y1, g) in B if y0 >= 52 and not g.is_empty])
for p in getattr(out, 'geoms', [out]):
    d.polygon([tf(x, z) for x, z in p.exterior.coords], fill=(214, 214, 214), outline=(150, 150, 150))
COL = {'A': (40, 110, 230), 'B': (220, 120, 20), 'C': (20, 170, 110), 'S': (190, 40, 160)}
def pts(seq):
    out = []
    for st in seq:
        if st['act'] in ('walk', 'jump', 'pad', 'drop'):
            out.append(st.get('to', st.get('p')) if st['act'] == 'jump' else st['p'])
        if st['act'] == 'ladder':
            l = R['ladders'][st['i']]; out += [l['bottom'], l['top']]
    return out
P = R['paths']
for key, seqs, off in (('A', ['A1', 'A2', 'A3'], 0.0), ('B', ['B1', 'B2'], 0.6), ('C', ['C1', 'C2', 'C3'], -0.6), ('S', ['S4'], 0.0)):
    for name in seqs:
        ps = pts(P[name])
        for i in range(len(ps) - 1):
            a, b = ps[i], ps[i + 1]
            pad = name.startswith('C') and P[name][min(i + 1, len(P[name]) - 1)]['act'] == 'pad'
            d.line([tf(a[0] + off, a[2] + off), tf(b[0] + off, b[2] + off)], fill=COL[key], width=5)
for pl in R['platforms']:
    x, y, z = pl['pos']
    c = tf(x, z); r = 2.0 * S
    d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], outline=COL['C'], width=3, fill=(220, 245, 235))
    d.text((c[0] + r + 2, c[1] - 10), '%.1f' % y, fill=(0, 110, 70), font=F)
    if pl.get('pad'):
        t = pl['pad']['to']; tt = tf(t[0], t[2])
        d.line([c, tt], fill=(0, 200, 230), width=3)
        d.ellipse([c[0] - 7, c[1] - 7, c[0] + 7, c[1] + 7], fill=(0, 200, 230))
for name, p in R['hubs'].items():
    c = tf(p[0], p[2]); d.ellipse([c[0] - 11, c[1] - 11, c[0] + 11, c[1] + 11], fill=(0, 0, 0))
    lab = {'H2': 'Ring 2 hub 74 m', 'H3': 'Core Floor hub 102 m', 'summit': 'Summit 119 m'}[name]
    off = {'H2': (14, -26), 'H3': (-300, 6), 'summit': (14, -40)}[name]
    d.text((c[0] + off[0], c[1] + off[1]), lab, fill=(0, 0, 0), font=Fb)
dk = R['dock']; c = tf(dk[0], dk[2]); d.text((c[0] + 20, c[1]), 'DOCK 52 m (start)', fill=(0, 0, 0), font=Fb)
a = R['alcove']; c = tf(a[0], a[2] - 4); d.rectangle([c[0] - 8, c[1] - 8, c[0] + 8, c[1] + 8], fill=(230, 180, 0)); d.text((c[0] + 12, c[1] - 10), 'hidden alcove 77 m', fill=(150, 110, 0), font=F)
y = 60
for k, txt in (('A', 'A  outer ledges + ladders (proven ring route)'), ('B', 'B  inner tower: front door, spiral stair, broken-arch bridge'), ('C', 'C  sky path: hover platforms (circles, height in m) + crystal pads (cyan lines = launch)'), ('S', 'shared: sky stair to the crown, drop through the eye')):
    d.line([(30, y + 14), (90, y + 14)], fill=COL[k], width=8); d.text((105, y), txt, fill=(0, 0, 0), font=F); y += 40
d.text((30, 20), 'SKY CITADEL v3 - route map (top view, front = down, 10 m grid)', fill=(0, 0, 0), font=Fb)
im.save('out/CC_castle_v3_routemap.png'); print('ok')
