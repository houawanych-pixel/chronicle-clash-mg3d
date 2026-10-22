"""Ground material weights from the terrain itself (AAA-style rules), biome hints from the Tripo colours.
Outputs two RGBA splat maps (8 materials) at 2048 (0.38 m/px) + a flow map."""
import numpy as np, cv2, json
from scipy import ndimage as nd
PX = 786.76 / 2048; N = 2048
z = np.load('terrain_h.npy'); wl = np.load('water_h.npy'); m = np.load('masks.npz')
ocean, marsh, lake, river, A = m['ocean'], m['marsh'], m['lake'], m['river'], m['A']
C = cv2.imread('gc2048.png').astype(np.float32) / 255
def sstep(x): x = np.clip(x, 0, 1); return x * x * (3 - 2 * x)
def fbm(seed, cells, oct=4):
    r = np.random.default_rng(seed); out = np.zeros((N, N), np.float32); a = 1; t = 0
    for _ in range(oct):
        g = r.random((cells + 3, cells + 3)).astype(np.float32)
        q = nd.zoom(g, (N + 3 * N / cells) / (cells + 3), order=3)[:N, :N]; q = (q - q.min()) / (np.ptp(q) + 1e-6)
        out += q * a; t += a; a *= .5; cells *= 2
    return out / t

gy, gx = np.gradient(z, PX)
slope = np.degrees(np.arctan(np.hypot(gx, gy)))
# curvature (convex ridges dry/rocky, concave hollows damp/soil)
lap = cv2.Laplacian(cv2.GaussianBlur(z, (0, 0), 3), cv2.CV_32F)
# flow accumulation (D8, approx) -> where water runs: gravel/wet soil
zz = cv2.resize(z, (512, 512), interpolation=cv2.INTER_AREA)
order = np.argsort(-zz, axis=None); acc = np.ones(zz.size, np.float32)
H, Wd = zz.shape; flat = zz.ravel()
nb = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]
for idx in order:
    y, x = divmod(idx, Wd); best = None; bz = flat[idx]
    for dy, dx in nb:
        yy, xx = y + dy, x + dx
        if 0 <= yy < H and 0 <= xx < Wd and flat[yy * Wd + xx] < bz: bz = flat[yy * Wd + xx]; best = yy * Wd + xx
    if best is not None: acc[best] += acc[idx]
flow = cv2.resize(np.log1p(acc.reshape(H, Wd)), (N, N))
flow = (flow - flow.min()) / np.ptp(flow)

water = ~np.isnan(wl) & (wl > z + 0.02)
d_water = nd.distance_transform_edt(~(water | ocean)) * PX
n1, n2, n3 = fbm(1, 12), fbm(2, 30), fbm(3, 6)
# Tripo biome hints (blurred: big patches only)
Cb = cv2.GaussianBlur(C, (0, 0), 10)
b, g, r = Cb[..., 0], Cb[..., 1], Cb[..., 2]
forest_hint = sstep((g - r) * 6 + (0.35 - (r + g + b) / 3) * 4)        # dark green = forest floor
dry_hint = sstep((r - b) * 4 - 0.2)                                      # yellow/tan grass

w = {}
w['rock'] = sstep((slope - 41 + n2 * 8) / 9) + sstep((lap - 0.6) * 2) * 0.3 * sstep((slope - 20) / 10)
w['scree'] = sstep((slope - 30 + n1 * 6) / 8) * (1 - sstep((slope - 44) / 8)) * sstep((flow - 0.35) * 4 + 0.4)
w['sand'] = sstep((2.2 - z + n2 * 1.5) / 1.5) * sstep(1 - d_water / 8) * (1 - sstep((slope - 22) / 8))
w['sand'] *= (~marsh)
w['mud'] = np.maximum(marsh.astype(np.float32), sstep(1 - d_water / 5) * (~ocean)) * sstep((2.0 - z) / 1.2 + n1 * .6) + sstep((flow - 0.62) * 6) * 0.6
w['mud'] = np.clip(w['mud'], 0, 1) * (1 - sstep((slope - 25) / 8))
w['forest'] = forest_hint * (1 - sstep((slope - 30) / 8)) * sstep((n3 - 0.35) * 3)
w['drygrass'] = dry_hint * (1 - sstep((slope - 30) / 8)) * sstep((z - 4) / 6)
w['grass'] = np.full((N, N), 0.45, np.float32) * (1 - sstep((slope - 32) / 8))
w['moss'] = sstep((-lap - 0.2) * 3) * (1 - sstep((slope - 30) / 8)) * sstep((25 - z) / 15) * 0.7
names = ['grass', 'drygrass', 'forest', 'moss', 'mud', 'sand', 'scree', 'rock']
Wt = np.stack([np.clip(np.nan_to_num(w[k]), 0, None) for k in names], -1).astype(np.float32)
Wt[~A] = 0; Wt[~A, names.index('sand')] = 1
Wt[ocean & (z < -1.5)] = 0; Wt[ocean & (z < -1.5), names.index('sand')] = 0.6; Wt[ocean & (z < -1.5), names.index('rock')] += sstep((z[ocean & (z < -1.5)] + 30) / 30) * 0
# sharpen (height-blend look) and normalise
Wt = Wt ** 2.2; Wt /= Wt.sum(-1, keepdims=True) + 1e-6
s1 = (np.clip(Wt[..., :4], 0, 1) * 255).astype(np.uint8); s2 = (np.clip(Wt[..., 4:], 0, 1) * 255).astype(np.uint8)
cv2.imwrite('splat_a.png', cv2.cvtColor(s1, cv2.COLOR_RGBA2BGRA)); cv2.imwrite('splat_b.png', cv2.cvtColor(s2, cv2.COLOR_RGBA2BGRA))
np.save('flow.npy', flow.astype(np.float32)); np.save('slope.npy', slope.astype(np.float32))
json.dump({'materials': names, 'splat_a': names[:4], 'splat_b': names[4:]}, open('splat_info.json', 'w'))
# preview
pal = {'grass': (60, 140, 70), 'drygrass': (70, 165, 175), 'forest': (35, 75, 45), 'moss': (60, 120, 90), 'mud': (40, 65, 85),
       'sand': (140, 185, 205), 'scree': (125, 130, 135), 'rock': (95, 100, 105)}
col = sum(Wt[..., i:i+1] * np.array(pal[k], np.float32) for i, k in enumerate(names))
hs = np.clip(0.55 + 0.45 * (-gx * 0.7 + gy * 0.7) / np.sqrt(1 + gx**2 + gy**2), 0.25, 1.1)
col = col * hs[..., None]
d = np.where(water, wl - z, 0); a = np.clip(0.4 + d / 5, 0, .9)[..., None] * water[..., None]
col = col * (1 - a) + np.array([120, 95, 40]) * a
cv2.imwrite('ground_preview.jpg', cv2.resize(np.clip(col, 0, 255).astype(np.uint8), (1024, 1024), interpolation=cv2.INTER_AREA))
print({k: round(float(Wt[..., i][A].mean()), 3) for i, k in enumerate(names)})
