import numpy as np, cv2, json, time
from scipy import ndimage as nd
from erosion import hydraulic, thermal

T0 = time.time()
SIZE_M = 786.76          # region tile width in metres (from world layout)
N = 2048; PX = SIZE_M / N
rng = np.random.default_rng(7)

G = np.load('gh.npy').astype(np.float32)          # Tripo guide height (m), row0 = north
A = np.load('ga.npy')                              # tile coverage
W = np.load('water_raw.npy')
C = cv2.imread('gc2048.png')
hsv = cv2.cvtColor(C, cv2.COLOR_BGR2HSV).astype(int)

def disk(r):
    y, x = np.mgrid[-r:r+1, -r:r+1]; return (x*x + y*y) <= r*r

def fbm(n, octaves, base_cells, gain=0.5, ridged=False, seed=0):
    r = np.random.default_rng(seed); out = np.zeros((n, n), np.float32); amp = 1.0; tot = 0
    cells = base_cells
    for _ in range(octaves):
        g = r.random((cells + 3, cells + 3)).astype(np.float32)
        z = nd.zoom(g, (n + 3 * n / cells) / (cells + 3), order=3)[:n, :n]
        z = (z - z.min()) / (np.ptp(z) + 1e-6)
        if ridged: z = 1 - np.abs(2 * z - 1); z = z * z
        out += z * amp; tot += amp; amp *= gain; cells *= 2
    return out / tot

# ---------- 1. water classes ----------
def sstep(x): x=np.clip(x,0,1); return x*x*(3-2*x)
teal = (hsv[..., 0] >= 78) & (hsv[..., 0] <= 100) & (hsv[..., 1] > 25) & A
outside = nd.binary_dilation(~A, iterations=6)
Wo = nd.binary_opening(W, disk(7))                       # wide water only
lab, n = nd.label(Wo)
core = np.isin(lab, [i for i in range(1, n+1) if (outside & (lab == i)).any()])
ocean = core.copy()
for _ in range(10): ocean = nd.binary_dilation(ocean) & (W | ~A)   # regrow shape, stop at thin river mouths
ocean |= ~A
holes = nd.binary_fill_holes(ocean) & ~ocean
lh, nh = nd.label(holes); sh = nd.sum(holes, lh, range(1, nh+1))
ocean |= np.isin(lh, [k+1 for k, s in enumerate(sh) if s < 9000])   # small islands = sea stacks, rebuilt below
wet = cv2.GaussianBlur((teal & ~nd.binary_dilation(ocean, iterations=25)).astype(np.float32), (0, 0), 14)
marsh = (wet > 0.33) & ~ocean
marsh = nd.binary_opening(marsh, disk(26))
for _ in range(14): marsh = nd.binary_dilation(marsh) & (wet > 0.33)
marsh = nd.binary_closing(marsh, disk(10))
lab2, n2 = nd.label(marsh)
marsh = lab2 == (np.argmax(nd.sum(marsh, lab2, range(1, n2+1))) + 1) if n2 else marsh
marsh |= W & nd.binary_dilation(marsh, iterations=4) & ~ocean
rest = W & ~ocean & ~marsh
lab3, n3 = nd.label(rest); s3 = nd.sum(rest, lab3, range(1, n3+1))
lake = np.zeros_like(W)
for k, s in enumerate(s3, 1):
    if s > 6000:
        comp = lab3 == k
        if nd.binary_opening(comp, disk(10)).sum() > 0.6 * s: lake |= comp      # round body, not a long river
lake = nd.binary_fill_holes(nd.binary_closing(lake, disk(6)))
river = rest & ~lake
river = nd.binary_closing(river, disk(3))
lab4, n4 = nd.label(river); s4 = nd.sum(river, lab4, range(1, n4+1))
river = np.isin(lab4, [k+1 for k, s in enumerate(s4) if s > 400])

# ---------- 2. landform: strip baked trees / rocks / buildings ----------
land = A & ~ocean
Gl = np.where(land, G, np.nan)
fill = nd.distance_transform_edt(np.isnan(Gl), return_distances=False, return_indices=True)
Gf = Gl[fill[0], fill[1]]
base = nd.grey_opening(Gf, footprint=disk(22))          # kills bumps < ~17 m across
base = nd.grey_opening(base, footprint=disk(48))        # tree clumps / houses < ~37 m
base = cv2.GaussianBlur(base, (0, 0), 14)

floor = np.percentile(base[land], 12)                   # the diorama 'table top'
rel = np.maximum(base - floor, 0)
# vertical shaping: plains stay gentle, hills get a little more drama
z = 2.5 + rel * 0.55 + np.maximum(rel - 18, 0) * 0.9


pad_w = np.zeros((N, N), np.float32)

# coast: broad shores, some rocky stretches
d_ocean = nd.distance_transform_edt(~ocean) * PX
cliffy = fbm(N, 3, 6, seed=3)
ramp = sstep(d_ocean / (55 + 110 * cliffy))
z = z * ramp + (1 - ramp) * 0.5

# ---------- 3. water carving with smooth signed-distance profiles ----------
def body(mask, level, depth, w_in, w_out, bank_up=0.35):
    global z
    s_in = nd.distance_transform_edt(mask) * PX
    s_out = nd.distance_transform_edt(~mask) * PX
    bed = level - depth * sstep(s_in / w_in)
    k_out = 1 - sstep(s_out / w_out)
    shore = level + bank_up + (s_out / w_out) * 0     # banks come down to just above water
    target = np.where(mask, bed, np.minimum(z, level + bank_up + s_out * 0.08))
    k = np.where(mask, 1.0, k_out)
    z = z * (1 - k) + target * k

marsh_lvl = 1.2; lake_lvl = 0.9
d_marsh_out = np.maximum(nd.distance_transform_edt(~marsh) * PX + (fbm(N, 3, 10, seed=14) - 0.5) * 40 * (~marsh), 0)
mk = 1 - sstep(d_marsh_out / 35)
mz = marsh_lvl - 0.7 + (fbm(N, 4, 20, seed=11) - 0.5) * 1.6 + (fbm(N,2,6,seed=12)-0.5)*1.0
z = z * (1 - mk) + np.minimum(z, mz + d_marsh_out*0.22) * mk
body(lake, lake_lvl, 6.0, 25, 35)
river = river & ~nd.binary_dilation(marsh, iterations=12) & ~nd.binary_dilation(lake, iterations=6)
# river: follow land, sunk below banks with a smooth V-U profile
s_in = nd.distance_transform_edt(river) * PX; s_out = nd.distance_transform_edt(~river) * PX
bank = cv2.GaussianBlur(z, (0, 0), 16)
carve = np.where(river, 2.0 + np.minimum(s_in, 4)*0.25, 2.0*(1 - sstep(s_out/14)))
z = np.minimum(z, bank - carve + 0.0*z) * np.where((s_out < 14) | river, 1, 0) + z * np.where((s_out < 14) | river, 0, 1)

# ocean floor + sea stacks from the guide
d_in_ocean = nd.distance_transform_edt(ocean) * PX
sea_floor = -0.8 - np.minimum(d_in_ocean * 0.08, 22)
stacks = ocean & A & (G > 12)
stacks = nd.binary_opening(stacks, disk(4))
lab5, n5 = nd.label(stacks); keep5 = []
for k in range(1, n5+1):
    comp = lab5 == k; ys, xs = np.where(comp); a = comp.sum()
    box = (np.ptp(ys)+1) * (np.ptp(xs)+1)
    if a < 9000 and a / box > 0.55: keep5.append(k)
stacks = np.isin(lab5, keep5)
stk_h = cv2.GaussianBlur(np.where(stacks, np.clip((G - 8) * 0.9, 0, 30), 0).astype(np.float32), (0, 0), 4)
z = np.where(ocean, np.maximum(sea_floor, sea_floor + stk_h * 1.3), z)
z = np.where(~A, -24, z)
z = cv2.GaussianBlur(z, (0,0), 1.2)

# ---------- 4. natural detail ----------
hillness = sstep((z - 10) / 45) * (1 - pad_w)
plains = fbm(N, 4, 10, seed=21) - 0.5
rid = fbm(N, 4, 6, gain=0.45, ridged=True, seed=33)
waterish = ocean | marsh | lake | (s_out < 10)
z += np.where(waterish, 0, plains * 2.0 * (1 - hillness) * (1-pad_w) + (rid - 0.35) * 18 * hillness)

protect = np.clip((ocean | lake).astype(np.float32) + mk * 0.9 + (1 - sstep(s_out / 8)) * 0.7 + pad_w*0.9, 0, 1)

# ---------- 5. erosion: big features at 1.5 m cells, then a light pass at 0.77 m ----------
def erode(z, size, drops, cell, radius, talus):
    h = cv2.resize(z, (size, size), interpolation=cv2.INTER_AREA).astype(np.float64)
    p = cv2.resize(protect, (size, size), interpolation=cv2.INTER_AREA).astype(np.float64)
    h0 = h.copy()
    h = thermal(h, p, cell, talus, 25, 0.25)
    S = 50.0 * cell
    h = hydraulic(h / S, p, drops, 1, 1.0, 0.05, 4.0, 0.01, 0.3, 0.3, 0.015, 4.0, 60, radius) * S
    h = thermal(h, p, cell, talus - 3, 10, 0.2)
    return z + cv2.resize((h - h0).astype(np.float32), (N, N), interpolation=cv2.INTER_CUBIC)
t = time.time()
z = erode(z, 512, 220000, PX*4, 3, 42.0)
z = erode(z, 1024, 60000, PX*2, 5, 40.0)
print('erosion s', round(time.time() - t, 1))
z += (fbm(N, 3, 160, seed=55) - 0.5) * 0.3 * (~(ocean | lake))

# building sites from the Tripo diorama -> gentle buildable ground for step-3 areas
SITES = {'Castle_NE':(1510,640,230),'RingFort_S':(1037,1331,150),'Village_SE':(1664,1536,250)}
yy, xx = np.mgrid[0:N, 0:N]
wob = fbm(N, 3, 8, seed=17) - 0.5
pad_w = np.zeros((N, N), np.float32)
for nm,(cx,cy,r) in SITES.items():
    d = np.hypot(xx-cx, yy-cy) * (1 + 0.45*wob)
    pad_w = np.maximum(pad_w, 1 - sstep((d - r*0.55)/(r*0.6)))
smooth = cv2.GaussianBlur(z, (0,0), 45)
z = z*(1-pad_w*0.88) + (smooth + 0.4*(fbm(N,3,12,seed=5)-0.5))*pad_w*0.88

# marsh stays a wetland: clamp anything that piled up
z = z * (1 - mk) + np.minimum(z, mz + d_marsh_out*0.22) * mk
# re-assert water levels
z = np.where(lake, np.minimum(z, lake_lvl - 0.4), z)
z = np.where(river, np.minimum(z, cv2.GaussianBlur(z, (0, 0), 5) - 0.2), z)

# ---------- 6. water surfaces ----------
wl = np.full((N, N), np.nan, np.float32)
wl[ocean | ~A] = 0.0
wl[lake] = lake_lvl
wlr = cv2.GaussianBlur((z + 0.9) * river, (0, 0), 6) / (cv2.GaussianBlur(river.astype(np.float32), (0, 0), 6) + 1e-6)
wl = np.where(river, np.maximum(wlr, marsh_lvl), wl)
wl[nd.binary_dilation(marsh, iterations=8)] = marsh_lvl
water_any = ~np.isnan(wl)
wl_d = nd.binary_dilation(water_any, iterations=10)
idx = nd.distance_transform_edt(~water_any, return_distances=False, return_indices=True)
wl_full = np.where(wl_d, wl[idx[0], idx[1]], np.nan)
np.save('pads.npy', pad_w); json.dump(SITES, open('sites.json','w'))
land = A & ~ocean
np.save('terrain_h.npy', z.astype(np.float32)); np.save('water_h.npy', wl_full.astype(np.float32))
np.savez('masks.npz', ocean=ocean, marsh=marsh, lake=lake, river=river, A=A)
gy, gx = np.gradient(z, PX)
slope = np.degrees(np.arctan(np.hypot(gx, gy)))
json.dump(dict(px_m=PX, size_m=SIZE_M, zmin=float(z.min()), zmax=float(z.max()), floor_guide=float(floor), marsh_lvl=marsh_lvl, lake_lvl=lake_lvl,
               land_pct=float(land.mean()), slope_p95=float(np.percentile(slope[land], 95)), secs=round(time.time()-T0)), open('terrain_info.json', 'w'), indent=1)
print(json.load(open('terrain_info.json')))
