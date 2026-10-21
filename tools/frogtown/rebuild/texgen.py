"""Frogtown v2 tileable textures (painted, Chronicle Clash storybook look).
Each material: <name>_albedo.png (sRGB), <name>_normal.png (OpenGL), 1024 px, seamless.
Run with system python3 (numpy, PIL). Output dir: argv[1]."""
import sys, os, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else 'tex'
os.makedirs(OUT, exist_ok=True)
N = 1024
rng = np.random.default_rng(7)


def tnoise(res, cells, seed, octaves=4, persist=0.5):
    """Tileable value noise in [0,1] (bicubic upsampled random grids with wrap)."""
    r = np.random.default_rng(seed)
    acc = np.zeros((res, res))
    amp = 1.0
    tot = 0.0
    c = cells
    for o in range(octaves):
        g = r.random((c, c))
        big = np.tile(g, (3, 3))
        im = Image.fromarray((big * 255).astype(np.uint8)).resize((res * 3, res * 3), Image.BICUBIC)
        a = np.asarray(im, float)[res:2 * res, res:2 * res] / 255.0
        acc += a * amp
        tot += amp
        amp *= persist
        c *= 2
    return acc / tot


def lerp(a, b, t):
    return a + (b - a) * t[..., None]


def col(h):
    h = h.lstrip('#')
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], float) / 255.0


def normal_from(hgt, strength):
    dx = (np.roll(hgt, -1, 1) - np.roll(hgt, 1, 1)) * strength
    dy = (np.roll(hgt, -1, 0) - np.roll(hgt, 1, 0)) * strength
    nx, ny, nz = -dx, dy, np.ones_like(hgt)
    L = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([(nx / L + 1) / 2, (ny / L + 1) / 2, (nz / L + 1) / 2], -1)


def save(name, rgb, hgt, strength=6.0):
    Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8)).save(f'{OUT}/{name}_albedo.png')
    Image.fromarray((normal_from(hgt, strength) * 255).astype(np.uint8)).save(f'{OUT}/{name}_normal.png')


yy, xx = np.mgrid[0:N, 0:N] / N

# ---------------------------------------------------------------- planks (boards run along U)
boards = 8
bi = np.floor(yy * boards).astype(int)
fy = yy * boards - bi
tone = np.random.default_rng(1).random(boards)[bi]
off = np.random.default_rng(2).random(boards)[bi]
grain = tnoise(N, 4, 11, 4)
streak = np.sin((xx * 3 + off) * math.tau * 1.0 + grain * 9 + fy * 3) * 0.5 + 0.5
fine = tnoise(N, 64, 12, 2)
# board ends (staggered joints)
seg = 2
jx = (xx * seg + off) % 1.0
joint = (jx < 0.006) | (jx > 0.994)
gap = (fy < 0.045) | (fy > 0.955)
base = lerp(col('#8a6640'), col('#c79e6e'), np.clip(tone * 0.7 + streak * 0.25 + fine * 0.15, 0, 1))
base = lerp(base, col('#5b4229'), (streak > 0.86) * 0.35)
rgb = np.where((gap | joint)[..., None], col('#2c1f14'), base)
# nail heads near board ends
hgt = np.clip(1.0 - (gap | joint) * 1.0, 0, 1) * 0.6 + streak * 0.15 + fine * 0.1 - np.abs(fy - 0.5) * 0.25
save('frog_planks', rgb, hgt, 5.0)

# ---------------------------------------------------------------- thatch (straw tiers, V = down the roof)
img = Image.new('RGB', (N, N), (0, 0, 0))
hi = Image.new('L', (N, N), 0)
d = ImageDraw.Draw(img)
dh = ImageDraw.Draw(hi)
r = np.random.default_rng(3)
tiers = 6
straw = [col('#c9b264'), col('#b19a4e'), col('#d8c47a'), col('#9c8a42'), col('#8f9a4a'), col('#a8a65a')]
for t in range(tiers):
    y0 = t / tiers * N
    for k in range(2600):
        x = r.random() * N
        y = y0 + r.random() * N / tiers * 0.95
        L = r.uniform(40, 110)
        ang = r.normal(0, 0.12)
        c = straw[r.integers(len(straw))] * r.uniform(0.75, 1.1)
        x2, y2 = x + math.sin(ang) * L, y + math.cos(ang) * L
        for dx in (-N, 0, N):
            for dy in (-N, 0, N):
                d.line([(x + dx, y + dy), (x2 + dx, y2 + dy)], fill=tuple((np.clip(c, 0, 1) * 255).astype(int)), width=int(r.integers(2, 5)))
                dh.line([(x + dx, y + dy), (x2 + dx, y2 + dy)], fill=int(r.integers(120, 255)), width=3)
a = np.asarray(img, float) / 255
h = np.asarray(hi.filter(ImageFilter.GaussianBlur(1)), float) / 255
tier_f = (yy * tiers) % 1.0
shade = 0.65 + 0.35 * np.clip(tier_f * 1.4, 0, 1)        # darker under each tier's lip
moss = tnoise(N, 6, 13, 4)
a = a * shade[..., None]
a = lerp(a, col('#5f7a2e'), np.clip((moss - 0.62) * 3.0, 0, 0.55))
save('frog_thatch', a, h * 0.7 + tier_f * 0.3, 7.0)

# ---------------------------------------------------------------- reed weave wall
cells = 12
u = (xx * cells) % 1.0
v = (yy * cells * 2) % 1.0
cu = np.floor(xx * cells).astype(int)
cv = np.floor(yy * cells * 2).astype(int)
over = (cu + cv) % 2 == 0
band_h = np.where(over, np.sin(v * math.pi), np.sin(u * math.pi))
strand = np.where(over, np.sin(u * math.pi * 7) * 0.5 + 0.5, np.sin(v * math.pi * 7) * 0.5 + 0.5)
nz = tnoise(N, 16, 14, 3)
rgbw = lerp(col('#7b6a3a'), col('#bfae6c'), np.clip(band_h * 0.6 + strand * 0.25 + nz * 0.2, 0, 1))
rgbw = lerp(rgbw, col('#3d3420'), (band_h < 0.15) * 0.8)
save('frog_reed', rgbw, band_h * 0.8 + strand * 0.2, 6.0)

# ---------------------------------------------------------------- bark (V along the trunk)
n1 = tnoise(N, 8, 15, 5)
ridges = np.sin((xx * 22 + n1 * 3.5) * math.tau) * 0.5 + 0.5
rgbb = lerp(col('#3a2a1c'), col('#7d6244'), np.clip(ridges * 0.7 + n1 * 0.4 - 0.1, 0, 1))
moss = tnoise(N, 5, 16, 4)
rgbb = lerp(rgbb, col('#4f6b2a'), np.clip((moss - 0.6) * 2.5, 0, 0.7))
save('frog_bark', rgbb, ridges * 0.8 + n1 * 0.2, 8.0)

# ---------------------------------------------------------------- marsh grass / moss top
n1 = tnoise(N, 6, 17, 5)
n2 = tnoise(N, 40, 18, 2)
rgbg = lerp(col('#4f7a2a'), col('#8fb04a'), np.clip(n1 * 0.9 + n2 * 0.3 - 0.15, 0, 1))
clover = tnoise(N, 24, 19, 1) > 0.72
rgbg = lerp(rgbg, col('#2f5a22'), clover * 0.5)
flowers = (tnoise(N, 90, 20, 1) > 0.86) & (tnoise(N, 7, 21, 2) > 0.55)
rgbg = np.where(flowers[..., None], col('#f2e6a8'), rgbg)
save('frog_grass', rgbg, n1 * 0.6 + n2 * 0.4, 4.0)

# ---------------------------------------------------------------- wet mud bank
n1 = tnoise(N, 5, 22, 5)
n2 = tnoise(N, 50, 23, 2)
rgbm = lerp(col('#3b2c1e'), col('#7a5a3a'), np.clip(n1 * 0.8 + n2 * 0.3, 0, 1))
wet = np.clip((0.35 - yy) * 3, 0, 1)                 # darker toward the waterline (V=0)
rgbm = rgbm * (1 - 0.35 * wet[..., None])
pebble = tnoise(N, 70, 24, 1) > 0.8
rgbm = np.where(pebble[..., None], rgbm * 1.35, rgbm)
save('frog_mud', rgbm, n1 * 0.5 + n2 * 0.5 + pebble * 0.3, 6.0)

# ---------------------------------------------------------------- leaves (canopy clusters)
img = Image.new('RGB', (N, N), tuple((col('#2d4d1e') * 255).astype(int)))
hi = Image.new('L', (N, N), 0)
d = ImageDraw.Draw(img)
dh = ImageDraw.Draw(hi)
r = np.random.default_rng(4)
greens = [col('#6f9a34'), col('#8ab445'), col('#4f7a28'), col('#a3c25a'), col('#5e8a30')]
for k in range(5200):
    x, y = r.random() * N, r.random() * N
    s = r.uniform(10, 26)
    a = r.uniform(0, math.pi)
    c = greens[r.integers(len(greens))] * r.uniform(0.8, 1.1)
    pts = [(x + math.cos(a + t) * s * (0.4 if i % 2 else 1.0), y + math.sin(a + t) * s * (0.4 if i % 2 else 1.0)) for i, t in enumerate(np.linspace(0, math.tau, 9)[:-1])]
    for dx in (-N, 0, N):
        for dy in (-N, 0, N):
            d.polygon([(px + dx, py + dy) for px, py in pts], fill=tuple((np.clip(c, 0, 1) * 255).astype(int)))
            dh.polygon([(px + dx, py + dy) for px, py in pts], fill=int(r.integers(140, 255)))
a = np.asarray(img, float) / 255
h = np.asarray(hi.filter(ImageFilter.GaussianBlur(1.5)), float) / 255
save('frog_leaves', a, h, 6.0)

# ---------------------------------------------------------------- cloth (teal hide/linen, for awnings and curtains)
weave = (np.sin(xx * N * 0.5) * np.sin(yy * N * 0.5)) * 0.5 + 0.5
n1 = tnoise(N, 8, 25, 3)
rgbc = lerp(col('#1f5f62'), col('#3a8b8a'), np.clip(weave * 0.3 + n1 * 0.7, 0, 1))
save('frog_cloth', rgbc, weave * 0.4 + n1 * 0.3, 2.0)

# ---------------------------------------------------------------- shell / bone (pearly, faint ridges)
ridges = np.sin(xx * math.tau * 10) * 0.5 + 0.5
n1 = tnoise(N, 6, 26, 3)
rgbs = lerp(col('#e6d8bc'), col('#f8efe0'), np.clip(ridges * 0.4 + n1 * 0.6, 0, 1))
rgbs = lerp(rgbs, col('#e8b8a8'), np.clip((n1 - 0.6) * 2, 0, 0.5))
save('frog_shell', rgbs, ridges * 0.6 + n1 * 0.2, 3.0)

# preview sheet
names = ['frog_planks', 'frog_thatch', 'frog_reed', 'frog_bark', 'frog_grass', 'frog_mud', 'frog_leaves', 'frog_cloth', 'frog_shell']
sheet = Image.new('RGB', (256 * len(names), 512))
for i, nm in enumerate(names):
    t = Image.open(f'{OUT}/{nm}_albedo.png').resize((128, 128))
    for a_ in range(2):
        for b_ in range(2):
            sheet.paste(t, (i * 256 + a_ * 128, b_ * 128))
    sheet.paste(Image.open(f'{OUT}/{nm}_normal.png').resize((256, 256)), (i * 256, 256))
sheet.save(f'{OUT}/_sheet.png')
print('textures done')
