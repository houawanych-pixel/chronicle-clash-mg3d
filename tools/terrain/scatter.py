"""Rule-based placement (Horizon/Far Cry style): density from ground weights + slope + water distance,
blue-noise spacing per type, footprints so big things push small things away."""
import numpy as np, cv2, json
from scipy import ndimage as nd
from scipy.spatial import cKDTree
PX = 786.76 / 2048; N = 2048; S = 786.76
z = np.load('terrain_h.npy'); slope = np.load('slope.npy'); wl = np.load('water_h.npy'); m = np.load('masks.npz')
pads = np.load('pads.npy')
names = json.load(open('splat_info.json'))['materials']
sa = cv2.cvtColor(cv2.imread('splat_a.png', cv2.IMREAD_UNCHANGED), cv2.COLOR_BGRA2RGBA).astype(np.float32) / 255
sb = cv2.cvtColor(cv2.imread('splat_b.png', cv2.IMREAD_UNCHANGED), cv2.COLOR_BGRA2RGBA).astype(np.float32) / 255
Wt = {k: (sa if i < 4 else sb)[..., i % 4] for i, k in enumerate(names)}
water = (~np.isnan(wl) & (wl > z - 0.05)) | m['ocean']
d_water = nd.distance_transform_edt(~water) * PX
rng = np.random.default_rng(42)
def sstep(x): x = np.clip(x, 0, 1); return x * x * (3 - 2 * x)
def cluster(seed, cells):
    g = np.random.default_rng(seed).random((cells, cells)).astype(np.float32)
    return sstep((cv2.resize(g, (N, N), interpolation=cv2.INTER_CUBIC) - 0.35) * 2.5)

dry = d_water > 2.5
flatish = 1 - sstep((slope - 34) / 10)
dens = {
    # per m^2 at weight 1
    'tree_conifer': (Wt['forest'] * 0.07 + Wt['grass'] * 0.008 * cluster(1, 18) + Wt['scree'] * 0.004) * flatish * dry * (1 - pads) * sstep((z - 2) / 3),
    'tree_broadleaf': (Wt['forest'] * 0.025 + Wt['grass'] * 0.004 * cluster(2, 14) + Wt['drygrass'] * 0.002) * flatish * dry * (1 - pads) * sstep((z - 1.5) / 2) * sstep((60 - z) / 25),
    'bush': (Wt['forest'] * 0.03 + Wt['grass'] * 0.012 * cluster(3, 30) + Wt['moss'] * 0.03) * (1 - sstep((slope - 35) / 8)) * (d_water > 1.0) * (1 - pads * 0.7),
    'boulder': (Wt['rock'] * 0.010 + Wt['scree'] * 0.020 + Wt['grass'] * 0.0008 * cluster(4, 40)) * (~m['ocean']),
    'rock_small': (Wt['rock'] * 0.04 + Wt['scree'] * 0.08 + Wt['sand'] * 0.004 + Wt['grass'] * 0.002) * (~m['ocean']),
    'reeds': (Wt['mud'] * 0.08 * sstep(1 - np.abs((wl - z) if False else 0)) + 0) * (~m['ocean']),
}
# reeds: shallow water and wet banks only (water depth < 0.6 m or bank < 3 m from water)
depth = np.where(~np.isnan(wl), wl - z, -9)
reed_zone = ((depth > -0.3) & (depth < 0.6) & ~m['ocean']) | ((d_water < 3) & (d_water > 0) & (slope < 15) & ~m['ocean'])
dens['reeds'] = 0.25 * reed_zone * cluster(5, 50)
spacing = {'tree_conifer': 4.5, 'tree_broadleaf': 6.5, 'bush': 1.8, 'boulder': 2.5, 'rock_small': 0.8, 'reeds': 0.6}
scale = {'tree_conifer': (14, 26), 'tree_broadleaf': (10, 18), 'bush': (0.8, 2.0), 'boulder': (1.2, 4.0), 'rock_small': (0.25, 0.9), 'reeds': (1.4, 2.4)}
avoid = {'bush': ['tree_conifer', 'tree_broadleaf'], 'rock_small': ['boulder'], 'reeds': [], 'boulder': ['tree_conifer', 'tree_broadleaf']}

placed = {}
order = ['tree_conifer', 'tree_broadleaf', 'boulder', 'bush', 'rock_small', 'reeds']
for k in order:
    d = np.clip(dens[k], 0, None)
    exp_n = d.sum() * PX * PX
    n_try = int(exp_n * 2.2) + 10
    # candidates by density (importance sampling), then blue-noise rejection
    p = d.ravel() / d.sum()
    idx = rng.choice(d.size, n_try, p=p)
    r, c = np.divmod(idx, N)
    xy = np.stack([(c + rng.random(n_try)) * PX - S / 2, S / 2 - (r + rng.random(n_try)) * PX], -1)
    keep = []; pts = []
    others = np.concatenate([placed[o][:, :2] for o in avoid.get(k, []) if o in placed and len(placed[o])] or [np.zeros((0, 2))])
    ot = cKDTree(others) if len(others) else None
    tree = None; acc = []
    sp = spacing[k]
    grid = {}
    for i in range(n_try):
        x, y = xy[i]
        if ot is not None and ot.query([x, y])[0] < sp * 1.2: continue
        gx, gy = int(x // sp), int(y // sp); ok = True
        for ax in (gx - 1, gx, gx + 1):
            for ay in (gy - 1, gy, gy + 1):
                for q in grid.get((ax, ay), []):
                    if (q[0] - x) ** 2 + (q[1] - y) ** 2 < sp * sp: ok = False; break
                if not ok: break
            if not ok: break
        if not ok: continue
        grid.setdefault((gx, gy), []).append((x, y)); acc.append(i)
        if len(acc) >= exp_n: break
    acc = np.array(acc, int)
    if len(acc) == 0: placed[k] = np.zeros((0, 5)); continue
    rr, cc = r[acc], c[acc]
    lo, hi = scale[k]
    sz = lo + (hi - lo) * rng.random(len(acc)) ** 1.5
    placed[k] = np.stack([xy[acc, 0], xy[acc, 1], z[rr, cc], sz, rng.random(len(acc)) * 6.2832], -1)
    print(k, len(acc), 'expected', int(exp_n))
json.dump({k: np.round(v, 2).tolist() for k, v in placed.items()}, open('scatter.json', 'w'), separators=(',', ':'))
json.dump({'columns': ['x_m', 'y_m', 'z_m', 'height_or_size_m', 'rot_z_rad'], 'counts': {k: len(v) for k, v in placed.items()},
           'scale_m': scale, 'spacing_m': spacing}, open('scatter_info.json', 'w'), indent=1)
# preview
pv = cv2.imread('ground_preview.jpg'); f = 1024 / S
cols = {'tree_conifer': (20, 60, 20), 'tree_broadleaf': (40, 120, 60), 'bush': (60, 140, 90), 'boulder': (150, 150, 150), 'rock_small': (190, 190, 190), 'reeds': (90, 190, 200)}
for k in order:
    for x, y, _, s, _ in placed[k]:
        rad = max(1, int((s * (0.18 if 'tree' in k else 0.5)) * f))
        cv2.circle(pv, (int((x + S / 2) * f), int((S / 2 - y) * f)), rad, cols[k], -1)
cv2.imwrite('scatter_preview.jpg', pv)
