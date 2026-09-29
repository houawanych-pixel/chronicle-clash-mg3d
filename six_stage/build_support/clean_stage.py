"""Rebuild a stage as clean, flat, low-poly geometry from its walkable-floor data.

Reads the ORIGINAL nav{N}.json (kept as nav{N}_source.json) and mission{N}.json and writes:
  assets/stages/stage{N}_clean.glb  visual mesh, split into 8 m chunks (frustum culling + camera cutaway)
  assets/stages/floor{N}.glb        collision floor that matches the visual surface exactly
  assets/stages/nav{N}.json         navigation cells + edge walls rebuilt from the flattened floors
  assets/stages/mission{N}.json     objective/start/route heights snapped to the new floors

Method (per Facility Map Bible v3 budgets, "only build what the camera sees"):
  1. Flat areas are grown from the walkable grid and snapped to one height each (plateaus).
  2. Leftover sloped cells are fitted with a plane (clean ramps); bridge corridors keep their slope.
  3. Small holes left by the old lumpy mesh are filled.
  4. Only top surfaces, cliff faces and outer walls are generated; nothing underneath or inside.
Usage: python3 clean_stage.py 1
"""
import json, struct, sys
from pathlib import Path
import numpy as np
from scipy.ndimage import label, binary_dilation, binary_fill_holes, distance_transform_edt

stage = int(sys.argv[1]) if len(sys.argv) > 1 else 1
root = Path(__file__).resolve().parents[1]
S = root / 'assets/stages'
src_nav = S / f'nav{stage}_source.json'
if not src_nav.exists():
    src_nav.write_text((S / f'nav{stage}.json').read_text())
nav = json.loads(src_nav.read_text())
mission_src = S / f'mission{stage}_source.json'
if not mission_src.exists():
    mission_src.write_text((S / f'mission{stage}.json').read_text())
mission = json.loads(mission_src.read_text())

N = nav['size']; off = nav['offset']; STEP = nav['step']
H = np.full((N, N), np.nan)
for x, z, h in nav['cells']:
    H[x, z] = h
navmask = np.isfinite(H)

def cell_xz(x, z):
    return off + x * STEP, off + z * STEP

# ---- bridge corridors keep their authored slope -------------------------------------------
xs, zs = np.meshgrid(np.arange(N), np.arange(N), indexing='ij')
wx, wz = off + xs * STEP, off + zs * STEP
bridge = np.zeros_like(navmask)
for a, b in nav['bridges']:
    p = np.array([a[0], a[2]]); q = np.array([b[0], b[2]]); d = q - p
    t = np.clip(((wx - p[0]) * d[0] + (wz - p[1]) * d[1]) / max(d @ d, 1e-6), 0, 1)
    dist = np.hypot(wx - (p[0] + t * d[0]), wz - (p[1] + t * d[1]))
    bridge |= (dist <= 1.3) & navmask

# ---- fill small holes (props baked into the old mesh) --------------------------------------
holes = binary_fill_holes(navmask) & ~navmask
lab, n = label(holes)
for i in range(1, n + 1):
    cells = lab == i
    ring = binary_dilation(cells) & navmask
    # only plug holes that sit inside one floor (never bridge two levels)
    if cells.sum() <= 8 and np.ptp(H[ring]) < 0.3:
        H[cells] = np.median(H[ring]); navmask |= cells

# ---- stairs: rebuild staircases the old mesh mashed into lumps (x0,x1,z0,z1 in metres) ------
STAIRS = {1: [dict(x0=-14.5, x1=-10.0, z0=-9.0, z1=-5.5, axis="x", h0=2.95, h1=5.72)]}
stairs = np.zeros_like(navmask)
for st in STAIRS.get(stage, []):
    for x, z in zip(*np.where(navmask)):
        wxv, wzv = cell_xz(x, z)
        if st["x0"] - 1e-6 <= wxv <= st["x1"] + 1e-6 and st["z0"] - 1e-6 <= wzv <= st["z1"] + 1e-6:
            t = (wxv - st["x0"]) / (st["x1"] - st["x0"]) if st["axis"] == "x" else (wzv - st["z0"]) / (st["z1"] - st["z0"])
            H[x, z] = st["h0"] + t * (st["h1"] - st["h0"]); stairs[x, z] = True
bridge |= stairs

# ---- plateaus -----------------------------------------------------------------------------
TOL = 0.12
region = -np.ones((N, N), int); regions = []
cand = navmask & ~bridge
for x0, z0 in zip(*np.where(cand)):
    if region[x0, z0] >= 0: continue
    rid = len(regions); stack = [(x0, z0)]; region[x0, z0] = rid; members = []
    while stack:
        x, z = stack.pop(); members.append((x, z))
        for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            u, v = x + dx, z + dz
            if 0 <= u < N and 0 <= v < N and cand[u, v] and region[u, v] < 0 and abs(H[u, v] - H[x, z]) <= TOL:
                region[u, v] = rid; stack.append((u, v))
    regions.append(members)

newH = H.copy(); kind = np.zeros((N, N), int)  # 0 none, 1 plateau, 2 ramp/transition, 3 bridge
plateau_level = {}
for rid, members in enumerate(regions):
    m = np.array(members); hs = H[m[:, 0], m[:, 1]]
    if len(members) >= 10 and np.percentile(hs, 90) - np.percentile(hs, 10) < 0.3:
        plateau_level[rid] = float(np.median(hs))
        kind[m[:, 0], m[:, 1]] = 1
# merge touching plateaus whose heights are within 0.2 m (one clean level instead of two)
levels = sorted(plateau_level.items(), key=lambda kv: -len(regions[kv[0]]))
for rid, h in levels:
    for x, z in regions[rid]:
        newH[x, z] = h
changed = True
while changed:
    changed = False
    for x, z in zip(*np.where(kind == 1)):
        for dx, dz in ((1, 0), (0, 1)):
            u, v = x + dx, z + dz
            if u < N and v < N and kind[u, v] == 1 and 0 < abs(newH[u, v] - newH[x, z]) < 0.2:
                a, b = region[x, z], region[u, v]
                keep, drop = (a, b) if len(regions[a]) >= len(regions[b]) else (b, a)
                for p, q in regions[drop]: newH[p, q] = newH[regions[keep][0]]; region[p, q] = keep
                regions[keep] = regions[keep] + regions[drop]; regions[drop] = []
                changed = True

# ---- ramps / transitions: plane fit per connected group -----------------------------------
trans = navmask & (kind == 0) & ~bridge
lab, n = label(trans, structure=np.ones((3, 3)))
for i in range(1, n + 1):
    m = np.argwhere(lab == i); hs = H[m[:, 0], m[:, 1]]
    A = np.c_[m[:, 0] * STEP, m[:, 1] * STEP, np.ones(len(m))]
    coef, *_ = np.linalg.lstsq(A, hs, rcond=None); fit = A @ coef
    rms = float(np.sqrt(np.mean((fit - hs) ** 2)))
    if len(m) >= 4 and rms < 0.22:
        newH[m[:, 0], m[:, 1]] = fit
    else:  # small/irregular: snap to the nearest neighbouring plateau height when close, else keep
        for x, z in m:
            best = None
            for dx in (-2, -1, 0, 1, 2):
                for dz in (-2, -1, 0, 1, 2):
                    u, v = x + dx, z + dz
                    if 0 <= u < N and 0 <= v < N and kind[u, v] == 1 and abs(newH[u, v] - H[x, z]) < 0.45:
                        if best is None or abs(newH[u, v] - H[x, z]) < abs(best - H[x, z]): best = newH[u, v]
            if best is not None: newH[x, z] = best
    kind[m[:, 0], m[:, 1]] = 2
kind[bridge] = 3

# ---- expanded footprint (capsule clearance, same as the original pipeline) -----------------
mask = binary_dilation(navmask, iterations=1)
_, nearest = distance_transform_edt(~navmask, return_indices=True)
E = newH.copy(); ring = mask & ~navmask
E[ring] = newH[tuple(nearest[:, ring])]
# A clearance cell touching two levels takes the LOWER one, so it never becomes a raised
# pillar in the lower walkway (it only trims half a metre off the upper ledge).
for x, z in zip(*np.where(ring)):
    around = [newH[u, v] for u in range(max(0, x - 1), min(N, x + 2)) for v in range(max(0, z - 1), min(N, z + 2)) if navmask[u, v]]
    if around: E[x, z] = min(around)

# ---- per-cell corner heights: weld across small steps (<0.7 m), split across cliffs --------
CLIFF = 0.9
corner = np.zeros((N, N, 4))  # corners in order (x,z),(x+1,z),(x+1,z+1),(x,z+1)
CORNERS = [(0, 0), (1, 0), (1, 1), (0, 1)]
for x, z in zip(*np.where(mask)):
    h0 = E[x, z]
    for ci, (cx, cz) in enumerate(CORNERS):
        vals = []
        for ax in (cx - 1, cx):
            for az in (cz - 1, cz):
                u, v = x + ax, z + az
                if 0 <= u < N and 0 <= v < N and mask[u, v] and abs(E[u, v] - h0) < CLIFF:
                    vals.append(E[u, v])
        corner[x, z, ci] = np.mean(vals) - 0.02  # nav height sits 2 cm above the surface
# exact-flat plateaus: drop tiny averaging noise so greedy merge works
corner = np.round(corner, 3)
collision_corner = corner.copy()
# Stairs and bridge ramps: collision stays a smooth slope; the visual is flat treads + risers.
for x, z in zip(*np.where(bridge & mask)):
    corner[x, z, :] = round(float(E[x, z]) - 0.02, 3)

GROUND = -1.1
def P(x, z, ci):
    cx, cz = CORNERS[ci]
    return [off + (x + cx) * STEP - .25, float(corner[x, z, ci]), off + (z + cz) * STEP - .25]

tops, cliffs, skirts, trims, walls, coll_side = [], [], [], [], [], []
# greedy merge of flat cells with identical height
flat = np.zeros((N, N), bool)
for x, z in zip(*np.where(mask)):
    flat[x, z] = np.ptp(corner[x, z]) < 1e-6
used = np.zeros((N, N), bool)
for x in range(N):
    for z in range(N):
        if not mask[x, z] or used[x, z]: continue
        if not flat[x, z]:
            used[x, z] = True
            tops.append([P(x, z, 0), P(x, z, 1), P(x, z, 2), P(x, z, 3)]); continue
        h = corner[x, z, 0]; w = 1
        while x + w < N and mask[x + w, z] and flat[x + w, z] and not used[x + w, z] and corner[x + w, z, 0] == h: w += 1
        d = 1
        while z + d < N and all(mask[x + i, z + d] and flat[x + i, z + d] and not used[x + i, z + d] and corner[x + i, z + d, 0] == h for i in range(w)): d += 1
        used[x:x + w, z:z + d] = True
        x0 = off + x * STEP - .25; z0 = off + z * STEP - .25; x1 = x0 + w * STEP; z1 = z0 + d * STEP
        tops.append([[x0, h, z0], [x1, h, z0], [x1, h, z1], [x0, h, z1]])

EDGES = [((0, -1), 0, 1), ((1, 0), 1, 2), ((0, 1), 2, 3), ((-1, 0), 3, 0)]
NEIGHBOUR = {(0, -1): (3, 2), (1, 0): (0, 3), (0, 1): (1, 0), (-1, 0): (2, 1)}

def orient(q, out):
    """Keep the top edge first; make the face normal point along `out`."""
    q = [list(map(float, p)) for p in q]
    n = np.cross(np.subtract(q[1], q[0]), np.subtract(q[3], q[0]))
    if np.dot(n, out) < 0: q = [q[1], q[0], q[3], q[2]]
    return q

for x, z in zip(*np.where(mask)):
    for (dx, dz), a, b in EDGES:
        u, v = x + dx, z + dz
        out = (dx, 0, dz)
        pa, pb = P(x, z, a), P(x, z, b)
        if 0 <= u < N and 0 <= v < N and mask[u, v]:
            ia, ib = NEIGHBOUR[(dx, dz)]
            qa, qb = P(u, v, ia), P(u, v, ib)
            if pa[1] - qa[1] > 1e-3 or pb[1] - qb[1] > 1e-3:
                face = orient([pa, pb, [pb[0], qb[1], pb[2]], [pa[0], qa[1], pa[2]]], out)
                cliffs.append(face); coll_side.append(face)
                if min(pa[1] - qa[1], pb[1] - qb[1]) > .3:
                    trims.append(orient([pa, pb, [pb[0], pb[1] - .12, pb[2]], [pa[0], pa[1] - .12, pa[2]]], out))
        else:
            walls.append([pa, pb])
            skirts.append(orient([[pa[0], pa[1] - .12, pa[2]], [pb[0], pb[1] - .12, pb[2]], [pb[0], GROUND, pb[2]], [pa[0], GROUND, pa[2]]], out))
            trims.append(orient([pa, pb, [pb[0], pb[1] - .12, pb[2]], [pa[0], pa[1] - .12, pa[2]]], out))

def merge_strips(quads):
    """Join collinear neighbouring vertical strips that share heights (fewer triangles)."""
    key = lambda p: tuple(np.round(p, 3))
    start = {}
    for i, q in enumerate(quads): start.setdefault((key(q[0]), key(q[3])), []).append(i)
    used = [False] * len(quads); out = []
    for i, q in enumerate(quads):
        if used[i]: continue
        # walk backwards to the first strip of the run
        used[i] = True; cur = [list(p) for p in q]
        d = np.subtract(cur[1], cur[0])
        while True:
            nxt = None
            for j in start.get((key(cur[1]), key(cur[2])), []):
                if used[j]: continue
                d2 = np.subtract(quads[j][1], quads[j][0])
                if abs(d[1]) < 1e-6 and abs(d2[1]) < 1e-6 and np.allclose(np.cross(d, d2), 0, atol=1e-6) and np.dot(d, d2) > 0 \
                   and abs(quads[j][1][1] - cur[1][1]) < 1e-6 and abs(quads[j][2][1] - cur[2][1]) < 1e-6:
                    nxt = j; break
            if nxt is None: break
            used[nxt] = True; cur[1] = list(quads[nxt][1]); cur[2] = list(quads[nxt][2])
        out.append(cur)
    return out

skirts = merge_strips(skirts); trims = merge_strips(trims); cliffs_v = merge_strips(cliffs)

def tri_data(quads, flip_up=False):
    pos, nor, idx = [], [], []
    for q in quads:
        q = np.array(q, float)
        n = np.cross(q[1] - q[0], q[3] - q[0])
        if np.linalg.norm(n) < 1e-9: n = np.cross(q[2] - q[1], q[3] - q[1])
        if np.linalg.norm(n) < 1e-9: continue
        n = n / np.linalg.norm(n)
        if flip_up and n[1] < 0: q = q[::-1]; n = -n
        b = len(pos); pos += q.tolist(); nor += [n.tolist()] * 4
        ccw = np.dot(np.cross(q[1] - q[0], q[2] - q[0]), n) > 0
        idx += [b, b + 1, b + 2, b, b + 2, b + 3] if ccw else [b, b + 2, b + 1, b, b + 3, b + 2]
    return pos, nor, idx

def write_glb(path, meshes, materials=None):
    js = {"asset": {"version": "2.0", "generator": "HOVAGI clean_stage.py"}, "scenes": [{"nodes": []}], "scene": 0,
          "nodes": [], "meshes": [], "accessors": [], "bufferViews": [], "buffers": []}
    if materials:
        js["materials"] = [{"name": n, "pbrMetallicRoughness": {"baseColorFactor": c, "metallicFactor": 0.05, "roughnessFactor": 0.92}} for n, c in materials]
    blob = bytearray()
    def view(data, target):
        while len(blob) % 4: blob.append(0)
        o = len(blob); blob.extend(data)
        js["bufferViews"].append({"buffer": 0, "byteOffset": o, "byteLength": len(data), "target": target})
        return len(js["bufferViews"]) - 1
    def accessor(arr, comp, typ, target, minmax=False):
        a = {"bufferView": view(arr.tobytes(), target), "componentType": comp, "count": int(arr.shape[0]), "type": typ}
        if minmax: a["min"] = arr.min(0).tolist(); a["max"] = arr.max(0).tolist()
        js["accessors"].append(a); return len(js["accessors"]) - 1
    tris = 0
    for name, prims in meshes:
        mprims = []
        for mat_index, (pos, nor, idx) in prims:
            if not idx: continue
            p = np.array(pos, np.float32); nn = np.array(nor, np.float32); ii = np.array(idx, np.uint32)
            prim = {"attributes": {"POSITION": accessor(p, 5126, "VEC3", 34962, True), "NORMAL": accessor(nn, 5126, "VEC3", 34962)},
                    "indices": accessor(ii, 5125, "SCALAR", 34963)}
            if mat_index is not None: prim["material"] = mat_index
            mprims.append(prim); tris += len(idx) // 3
        if not mprims: continue
        js["meshes"].append({"name": name, "primitives": mprims})
        js["nodes"].append({"name": name, "mesh": len(js["meshes"]) - 1})
        js["scenes"][0]["nodes"].append(len(js["nodes"]) - 1)
    while len(blob) % 4: blob.append(0)
    js["buffers"].append({"byteLength": len(blob)})
    j = json.dumps(js, separators=(",", ":")).encode()
    while len(j) % 4: j += b" "
    out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(j) + 8 + len(blob)) + struct.pack("<II", len(j), 0x4E4F534A) + j + struct.pack("<II", len(blob), 0x004E4942) + bytes(blob)
    path.write_bytes(out)
    return tris

# ---- visual mesh, 8 m chunks ---------------------------------------------------------------
MATS = [("floor", [0.105, 0.125, 0.135, 1]), ("wall", [0.045, 0.058, 0.068, 1]), ("trim", [0.10, 0.55, 0.45, 1])]
CH = 8.0
chunks = {}
def add(quads, mat):
    for q in quads:
        c = np.mean(np.array(q)[:, [0, 2]], axis=0)
        k = (int(np.floor(c[0] / CH)), int(np.floor(c[1] / CH)))
        chunks.setdefault(k, {m[0]: [] for m in MATS})[mat].append(q)
add(tops, "floor"); add(cliffs_v, "wall"); add(skirts, "wall"); add(trims, "trim")
meshes = []
for (cx, cz), bym in sorted(chunks.items()):
    prims = [(mi, tri_data(bym[mname], flip_up=(mname == "floor"))) for mi, (mname, _) in enumerate(MATS)]
    meshes.append((f"chunk_{cx}_{cz}", prims))
vis_tris = write_glb(S / f"stage{stage}_clean.glb", meshes, MATS)

# ---- collision floor: smooth slopes on stairs, same surface elsewhere + cliff faces ----------
ctops, csides = [], []
for x, z in zip(*np.where(mask)):
    Q = lambda ci: [off + (x + CORNERS[ci][0]) * STEP - .25, float(collision_corner[x, z, ci]), off + (z + CORNERS[ci][1]) * STEP - .25]
    ctops.append([Q(0), Q(1), Q(2), Q(3)])
    for (dx, dz), a, b in EDGES:
        u, v = x + dx, z + dz
        if 0 <= u < N and 0 <= v < N and mask[u, v]:
            ia, ib = NEIGHBOUR[(dx, dz)]
            pa, pb = Q(a), Q(b)
            qa = [pa[0], float(collision_corner[u, v, ia]), pa[2]]; qb = [pb[0], float(collision_corner[u, v, ib]), pb[2]]
            if pa[1] - qa[1] > 1e-3 or pb[1] - qb[1] > 1e-3:
                csides.append(orient([pa, pb, qb, qa], (dx, 0, dz)))
coll_tris = write_glb(S / f"floor{stage}.glb", [("floor_collision", [(None, tri_data(ctops, flip_up=True)), (None, tri_data(csides))])])

# ---- navigation + walls ---------------------------------------------------------------------
nav_out = {"step": STEP, "offset": off, "size": N,
           "cells": [[int(x), int(z), round(float(newH[x, z]), 3)] for x, z in np.argwhere(navmask)],
           "bridges": nav["bridges"], "walls": [[list(map(float, a)), list(map(float, b))] for a, b in walls]}
(S / f"nav{stage}.json").write_text(json.dumps(nav_out))

def snap(p):
    x, y, z = p
    i, k = int(round((x - off) / STEP)), int(round((z - off) / STEP))
    if 0 <= i < N and 0 <= k < N and navmask[i, k] and np.isfinite(H[i, k]):
        return [x, round(y + float(newH[i, k] - H[i, k]), 3), z]
    return p
mission["start"] = snap(mission["start"])
for p in mission["points"]: p["at"] = snap(p["at"])
mission["routes"] = [[snap(a), snap(b)] for a, b in mission["routes"]]
mission["asset"] = f"res://assets/stages/stage{stage}_clean.glb"
(S / f"mission{stage}.json").write_text(json.dumps(mission, indent=2))

moved = np.abs(newH - H)[navmask & np.isfinite(H)]
print(f"stage {stage}: visual triangles {vis_tris} in {len(meshes)} chunks, collision triangles {coll_tris}")
print(f"  cells {int(navmask.sum())} (filled {int(navmask.sum()) - int(np.isfinite(H).sum())} holes), plateaus {int((kind==1).sum())} cells, ramps {int((kind==2).sum())}, bridge {int((kind==3).sum())}")
print(f"  height change: median {np.median(moved):.3f} m, 95% {np.percentile(moved,95):.3f} m, max {moved.max():.3f} m")
print(f"  tops {len(tops)} cliffs {len(cliffs_v)} skirts {len(skirts)} trims {len(trims)} walls {len(walls)}")
