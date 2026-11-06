"""make_atlas.py -> assets/cc/foliage/foliage_atlas.png (1024 x 1024 RGBA)
The CC foliage atlas. Everything is drawn in light greys: the foliage shader tints it with the
planet / biome palette, so one atlas serves every biome (no per-planet copies).
  young leaves   (0,0)-(512,512)      a few bigger fresh leaves, airy spacing
  mature leaves  (512,0)-(1024,512)   many SMALLER, denser, still crisp individual leaves
  vine           (0,512)-(512,1024)   a wavy stem with small leaves, tiles top to bottom
  grass          (512,512)-(768,1024) short lower-cut blades
  solid white    (768,512)-(1024,1024) opaque (flower shell, core, stem, bark)
Run: python3 tools/foliage/make_atlas.py
"""
import math, random, os
from PIL import Image, ImageDraw, ImageFilter

S = 4  # supersample, then shrink (smooth, crisp edges)
W = 1024 * S
img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
rnd = random.Random(7)

def leaf(cx, cy, length, width, ang, tone):
    """A pointed leaf: two arcs, a darker midrib and a few veins."""
    pts = []
    n = 24
    for i in range(n + 1):
        t = i / n
        x = t * length
        y = math.sin(math.pi * t) ** 0.8 * width * (1.0 - 0.25 * t)
        pts.append((x, y))
    for i in range(n, -1, -1):
        t = i / n
        x = t * length
        y = -math.sin(math.pi * t) ** 0.8 * width * (1.0 - 0.25 * t)
        pts.append((x, y))
    ca, sa = math.cos(ang), math.sin(ang)
    P = [(cx + x * ca - y * sa, cy + x * sa + y * ca) for x, y in pts]
    g = int(255 * tone)
    d.polygon(P, fill=(g, g, g, 255), outline=(int(g * 0.72),) * 3 + (255,))
    rib = int(g * 0.58)
    d.line([(cx, cy), (cx + length * 0.95 * ca, cy + length * 0.95 * sa)], fill=(rib, rib, rib, 255), width=max(2, int(width * 0.09)))
    for k in range(1, 5):   # veins
        t = k / 5.5
        bx, by = cx + length * t * ca, cy + length * t * sa
        for sgn in (-1, 1):
            vx = bx + (length * 0.14) * ca - sgn * (width * 0.55) * sa
            vy = by + (length * 0.14) * sa + sgn * (width * 0.55) * ca
            d.line([(bx, by), (vx, vy)], fill=(int(g * 0.8),) * 3 + (255,), width=max(1, int(width * 0.04)))

def twig(x0, y0, x1, y1, w):
    d.line([(x0, y0), (x1, y1)], fill=(150, 140, 130, 255), width=w)

# young leaves: a small fan of ~9 bigger leaves on a twig, lots of air between
ox, oy = 0, 0
base = (ox + 256 * S, oy + 470 * S)
twig(base[0], base[1], base[0], oy + 250 * S, 10 * S)
for i in range(9):
    a = -math.pi / 2 + (i - 4) * 0.36 + rnd.uniform(-0.08, 0.08)   # a fan, left to right
    sx = base[0] + math.cos(a) * 70 * S
    sy = base[1] - 170 * S + math.sin(a) * 60 * S
    twig(base[0], base[1] - 120 * S, sx, sy, 4 * S)
    ln = rnd.uniform(120, 160) * S
    leaf(sx, sy, ln, ln * 0.28, a + rnd.uniform(-0.15, 0.15), rnd.uniform(0.86, 1.0))

# mature leaves: many small leaves packed (gaps kept so they stay readable)
ox = 512 * S
cells = []
for gy in range(17):
    for gx in range(17):
        cells.append((gx, gy))
rnd.shuffle(cells)
for gx, gy in cells:
    if rnd.random() < 0.06:
        continue
    cx = ox + (gx + 0.5) * (512 / 17) * S + rnd.uniform(-8, 8) * S
    cy = (gy + 0.5) * (512 / 17) * S + rnd.uniform(-8, 8) * S
    ln = rnd.uniform(24, 32) * S
    a = rnd.uniform(0, math.tau)
    cx = min(max(cx, ox + 40 * S), ox + 472 * S)
    cy = min(max(cy, 40 * S), 472 * S)
    leaf(cx - math.cos(a) * ln * 0.5, cy - math.sin(a) * ln * 0.5, ln, ln * 0.32, a, rnd.uniform(0.74, 1.0))

# vine: a wavy stem that starts and ends at the same x (tiles), small paired leaves
oy = 512 * S
pts = [(256 * S + math.sin(t / 512 * math.tau * 2) * 40 * S, oy + t * S) for t in range(0, 513)]
d.line(pts, fill=(170, 175, 160, 255), width=9 * S)
for k in range(12):
    t = 20 + k * 40
    x = 256 * S + math.sin(t / 512 * math.tau * 2) * 40 * S
    side = 1 if k % 2 == 0 else -1
    a = (0.0 if side > 0 else math.pi) + rnd.uniform(-0.5, 0.5) + 0.6 * side * 0.0
    leaf(x, oy + t * S, rnd.uniform(70, 95) * S, rnd.uniform(26, 32) * S, a + (0.35 if side > 0 else -0.35), rnd.uniform(0.82, 1.0))

# grass: short lower-cut blades, lighter tips
ox, oy = 512 * S, 512 * S
for b in range(9):
    bx = ox + (20 + b * 26 + rnd.uniform(-6, 6)) * S
    h = rnd.uniform(200, 380) * S
    bend = rnd.uniform(-45, 45) * S
    wdt = rnd.uniform(30, 44) * S
    poly = [(bx - wdt / 2, oy + 512 * S), (bx + wdt / 2, oy + 512 * S), (bx + bend * 0.6 + wdt * 0.18, oy + 512 * S - h * 0.6), (bx + bend, oy + 512 * S - h)]
    poly2 = [(bx - wdt / 2, oy + 512 * S), (bx + bend * 0.6 - wdt * 0.18, oy + 512 * S - h * 0.6), (bx + bend, oy + 512 * S - h)]
    g = int(255 * rnd.uniform(0.85, 1.0))
    d.polygon(poly + poly2[::-1], fill=(g, g, g, 255))
    d.line([(bx, oy + 512 * S), (bx + bend, oy + 512 * S - h)], fill=(int(g * 0.8),) * 3 + (255,), width=2 * S)

# solid white
d.rectangle([768 * S, 512 * S, 1024 * S - 1, 1024 * S - 1], fill=(255, 255, 255, 255))

out = img.resize((1024, 1024), Image.LANCZOS)
p = os.path.join(os.path.dirname(__file__), "../../assets/cc/foliage/foliage_atlas.png")
out.save(os.path.normpath(p))
print("saved", os.path.normpath(p))
