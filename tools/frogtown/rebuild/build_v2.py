"""Frogtown v2: the village rebuilt as clean game geometry on the Tripo layout.
Run: FROG_LOD=1.0 /opt/bpyenv/bin/python build_v2.py   (desktop)
     FROG_LOD=0.55 FROG_NORMALS=0 FROG_NAME=frogtown_v2_lite ... (phone)
Writes <OUT>/<name>.glb (visual), and for the desktop run also
frogtown_v2_col.glb ('walk' floors + 'walls') and frogtown_v2_layout.json (doors)."""
import bpy, bmesh, sys, os, math, json, random
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)
from rkit import *
import pieces
from pieces import *

LOD = float(os.environ.get('FROG_LOD', '1.0'))
NAME = os.environ.get('FROG_NAME', 'frogtown_v2')
OUT = os.environ.get('FROG_OUT', '/tmp/claude-0/sp/retopo/out')
os.makedirs(OUT, exist_ok=True)
L = json.load(open(os.path.join(HERE, 'layout.json')))
WY = L['water_y']
pieces.WATER_Y = WY
ISL = {o['name']: o for o in L['islands']}
rnd = random.Random(5)


def ang(o, p):
    return math.atan2(p[1] - o['z'], p[0] - o['x'])


def near_island(p):
    best = None
    for o in L['islands']:
        d = math.hypot(p[0] - o['x'], p[1] - o['z']) - o['r']
        if best is None or d < best[0]:
            best = (d, o)
    return best


# walkway endpoints snap to the nearest island rim; collect rim entry angles
entries = {k: [] for k in ISL}
walks = []
for w in L['walks']:
    pts = [list(p) for p in w['pts']]
    ys = []
    for idx in (0, -1):
        d, o = near_island(pts[idx])
        if d < 2.5:
            a = ang(o, pts[idx])
            pts[idx] = [o['x'] + math.cos(a) * (o['r'] - 0.3), o['z'] + math.sin(a) * (o['r'] - 0.3)]
            entries[o['name']].append(a)
            ys.append(o['y'] + 0.22)
        else:
            ys.append(None)
    walks.append((w, pts, ys))
# walkway joins (an end that isn't on an island, e.g. the south junction) take their neighbour's height
for w, pts, ys in walks:
    for i in (0, 1):
        if ys[i] is None:
            ys[i] = 0.32

vis = Builder(NAME)
fol = Builder(NAME + '_foliage')
walk = Builder('walk')
walls = Builder('walls')

# ---------------------------------------------------------------- collision helpers


def col_ring(bd, x, z, r, y0, y1, n=24, a0=0.0, a1=TAU):
    full = abs(a1 - a0 - TAU) < 1e-6
    lo = [(x + math.cos(a0 + (a1 - a0) * i / n) * r, y0, z + math.sin(a0 + (a1 - a0) * i / n) * r) for i in range(n if full else n + 1)]
    hi = [(p[0], y1, p[2]) for p in lo]
    bd.grid([lo, hi], [[(0, 0)] * len(lo), [(0, 0)] * len(lo)], 'dark', close_u=full)


def col_strip(bd, pts3, h):
    lo = [tuple(p) for p in pts3]
    hi = [(p[0], p[1] + h, p[2]) for p in pts3]
    bd.grid([lo, hi], [[(0, 0)] * len(lo), [(0, 0)] * len(lo)], 'dark')


# ---------------------------------------------------------------- islands + plaza
for o in L['islands']:
    if o.get('kind') == 'plaza':
        dy = plaza(vis, o, LOD, entries[o['name']])
        ring_flat(walk, (o['x'], 0, o['z']), 3.55, o['r'] + 0.05, dy, 'dark', segs=48, radial_boards=False)
        col_ring(walls, o['x'], o['z'], 3.6, dy - 0.2, dy + 0.9, 32)
    else:
        dy = island(vis, o, LOD, seed=hash(o['name']) % 97, entries=entries[o['name']])
        ri = o['r'] - 2.0
        # walk: dome -> ramp to the deck -> deck
        rows = []
        for rr, yy in ((0.0, o['y'] + 0.12), (ri * 0.7, o['y'] + 0.06), (ri - 0.2, o['y'] + 0.02), (ri + 0.4, dy), (o['r'] + 0.05, dy)):
            rows.append([(o['x'] + math.cos(i / 40 * TAU) * rr, yy, o['z'] + math.sin(i / 40 * TAU) * rr) for i in range(40)])
        walk.grid(rows, [[(0, 0)] * 40] * len(rows), 'dark', close_u=True)
    # rail walls around the rim, open at walkway entries
    o['deck_y'] = dy
    n = 72
    seg = []
    for i in range(n + 1):
        a = i / n * TAU
        blocked = any(abs(((a - e + math.pi) % TAU) - math.pi) < 0.12 + 1.3 / o['r'] for e in entries[o['name']])
        if blocked:
            if len(seg) > 1:
                col_strip(walls, seg, 1.0)
            seg = []
        else:
            seg.append((o['x'] + math.cos(a) * (o['r'] + 0.05), dy, o['z'] + math.sin(a) * (o['r'] + 0.05)))
    if len(seg) > 1:
        col_strip(walls, seg, 1.0)

print('STAGE', '----------- walkways', vis.tris, fol.tris)
# ---------------------------------------------------------------- walkways


def seg_dist(px, pz, a, b):
    ax, az, bx, bz = a[0], a[1], b[0], b[1]
    vx, vz = bx - ax, bz - az
    t = max(0.0, min(1.0, ((px - ax) * vx + (pz - az) * vz) / max(1e-9, vx * vx + vz * vz)))
    return math.hypot(px - ax - vx * t, pz - az - vz * t)


def crossing(skip):
    """True where a point lies on another walkway's deck or on an island deck:
    rails stop there so crossing walkways stay open to each other."""
    def f(x, z):
        for w2, pts2, _ in walks:
            if w2 is skip:
                continue
            for i in range(len(pts2) - 1):
                if seg_dist(x, z, pts2[i], pts2[i + 1]) < 1.45:
                    return True
        return any(math.hypot(x - o['x'], z - o['z']) < o['r'] + 0.2 for o in L['islands'])
    return f


for w, pts, ys in walks:
    clear = crossing(w)
    samples = boardwalk(vis, pts, ys[0], ys[1], width=2.3, lod=LOD, seed=hash(w['id']) % 50, lanterns=w.get('lanterns', False), clear=clear)
    left, right = [], []
    for p, d, dist in samples:
        side = Vector((-d.z, 0, d.x))
        left.append(tuple(p + side * 1.2))
        right.append(tuple(p - side * 1.2))
    walk.grid([right, left], [[(0, 0)] * len(left)] * 2, 'dark')
    # side rails (stop short of the islands so the joins stay open)
    for side in (left, right):
        run = []
        for q in side + [None]:
            if q is None or clear(q[0], q[2]):
                if len(run) > 1:
                    col_strip(walls, run, 1.0)
                run = []
            else:
                run.append(q)

print('STAGE', '---------- buildings', vis.tris, fol.tris)
# ---------------------------------------------------------------- buildings
doors = {}
plaza_o = ISL['PLAZA']
for b in L['buildings']:
    o = ISL[b['island']]
    gy = o['y'] + 0.12
    # doors face the walkway ring: outward from the island centre (toward the plaza if central)
    dx, dz = b['x'] - o['x'], b['z'] - o['z']
    if math.hypot(dx, dz) < 1.5:
        dx, dz = plaza_o['x'] - b['x'], plaza_o['z'] - b['z']
    yaw_out = math.atan2(dz, dx)
    if b['kind'] == 'hut':
        # turn the door (by the smallest angle) until its steps and threshold
        # land on the island, clear of the other buildings
        reach = b['r'] * 1.1 + 1.71
        for k in range(25):
            yy = yaw_out + (k + 1) // 2 * 0.13 * (1 if k % 2 else -1)
            tx_, tz_ = b['x'] + math.cos(yy) * reach, b['z'] + math.sin(yy) * reach
            if math.hypot(tx_ - o['x'], tz_ - o['z']) > o['r'] - 0.9:
                continue
            if any(b2 is not b and math.hypot(tx_ - b2['x'], tz_ - b2['z']) < b2.get('r', max(b2.get('w', 0), b2.get('d', 0)) / 2) * 1.12 + 0.9 for b2 in L['buildings']):
                continue
            yaw_out = yy
            break
        else:
            print('WARN door off island', b['house'])
    seed = rnd.randrange(1000)
    if b['kind'] == 'hut':
        thr = hut(vis, (b['x'], gy, b['z']), b['r'], yaw_out, lod=LOD, seed=seed)
        col_ring(walls, b['x'], b['z'], b['r'] * 1.12, gy - 0.2, gy + 3.2, 20)
    else:
        lyaw = math.atan2(math.cos(yaw_out), math.sin(yaw_out))   # local +z faces yaw_out
        thr = lodge(vis, (b['x'], gy, b['z']), b['w'], b['d'], lyaw, lod=LOD, seed=seed)
        cy, sn = math.cos(lyaw), math.sin(lyaw)
        hw, hd = b['w'] / 2 + 0.2, b['d'] / 2 + 0.2
        cs = [(-hw, -hd), (hw, -hd), (hw, hd), (-hw, hd), (-hw, -hd)]
        col_strip(walls, [(b['x'] + x * cy + z * sn, gy - 0.2, b['z'] - x * sn + z * cy) for x, z in cs], 3.4)
    # plank path from the door steps to the ring deck
    ringp = (o['x'] + math.cos(yaw_out) * (o['r'] - 1.7), o['z'] + math.sin(yaw_out) * (o['r'] - 1.7))
    L_ = math.hypot(ringp[0] - thr[0], ringp[1] - thr[2])
    if L_ > 0.6 and b['kind'] == 'hut':
        cx_, cz_ = (ringp[0] + thr[0]) / 2, (ringp[1] + thr[2]) / 2
        nb = max(2, int(L_ / 0.34))
        for k in range(nb):
            t = (k + 0.5) / nb
            board(vis, (thr[0] + (ringp[0] - thr[0]) * t, gy + 0.05, thr[2] + (ringp[1] - thr[2]) * t), (1.2, 0.08, 0.3), 'planks', yaw=yaw_out + math.pi / 2, seed=seed + k)
    if b['house']:
        doors[b['house']] = {'door': [round(thr[0], 2), round(thr[2], 2)], 'into': [round(-math.cos(yaw_out), 3), round(-math.sin(yaw_out), 3)], 'y': round(gy, 2)}

print('STAGE', 'ushes, reeds, lilies', vis.tris, fol.tris)
# ---------------------------------------------------------------- trees, bushes, reeds, lilies
dropped = 0
for i, (x, z, h, cr) in enumerate(L['trees']):
    d, o = near_island((x, z))
    # keep the ring decks and the space round the houses clear for walking
    rc = math.hypot(x - o['x'], z - o['z'])
    on_deck = o.get('kind') != 'plaza' and o['r'] - 2.6 < rc < o['r'] + 1.0
    by_house = any(math.hypot(x - b['x'], z - b['z']) < b.get('r', max(b.get('w', 0), b.get('d', 0)) / 2) * 1.12 + 1.3 for b in L['buildings'])
    if on_deck or by_house:
        # move it out to the marsh just off the bank (a willow leaning over the
        # water), turning along the bank until it's clear of the walkways
        dropped += 1
        a0 = math.atan2(z - o['z'], x - o['x'])
        for k in range(30):
            a = a0 + (k + 1) // 2 * 0.09 * (1 if k % 2 else -1)
            x2, z2 = o['x'] + math.cos(a) * (o['r'] + 2.3), o['z'] + math.sin(a) * (o['r'] + 2.3)
            if all(seg_dist(x2, z2, pts2[j], pts2[j + 1]) > 2.6 for _, pts2, _ in walks for j in range(len(pts2) - 1)) and \
                    all(math.hypot(x2 - o2['x'], z2 - o2['z']) > o2['r'] + 1.8 for o2 in L['islands']):
                x, z = x2, z2
                break
        d, o = near_island((x, z))
    gy = (o['y'] + 0.12) if d < 0 else WY
    if o['name'] == 'PLAZA' and math.hypot(x - o['x'], z - o['z']) < 2:
        gy = o['deck_y'] + 0.1      # the old council tree on its islet in the pool
    tree(vis, (x, gy, z), h, cr, lod=LOD, seed=40 + i, willow=(i % 3 != 2), fol=fol)
    col_ring(walls, x, z, 0.35 + h * 0.03, gy - 0.3, gy + 3.0, 8)
print('STAGE', ' lilies on the water', vis.tris, fol.tris, 'trees moved to the bank', dropped)
# bushes and reeds around every island bank, lilies on the water
for o in L['islands']:
    n = int(o['r'] * 1.1 * LOD)
    for k in range(n):
        a = rnd.uniform(0, TAU)
        rr = o['r'] + rnd.uniform(1.0, 1.8)
        if any(abs(((a - e + math.pi) % TAU) - math.pi) < 0.35 for e in entries[o['name']]):
            continue
        reeds(fol, (o['x'] + math.cos(a) * rr, WY, o['z'] + math.sin(a) * rr), n=7, h=1.5, spread=0.7, seed=k + int(o['r'] * 10), lod=LOD)
    if o.get('kind') != 'plaza':
        for k in range(max(2, int(o['r'] * 0.6 * LOD))):
            a = rnd.uniform(0, TAU)
            rr = o['r'] - 2.4 - rnd.uniform(0, 0.8)
            p = (o['x'] + math.cos(a) * rr, o['y'] + 0.1, o['z'] + math.sin(a) * rr)
            if any(math.hypot(p[0] - b['x'], p[2] - b['z']) < (b.get('r', 3.5) + 1.4) for b in L['buildings']):
                continue
            blob(fol, p, rnd.uniform(0.6, 1.0), 'leaves_dark', squash=0.6, seed=rnd.randrange(999), detail=1, amp=0.35)
    for k in range(int(o['r'] * 1.2 * LOD * LOD)):
        a = rnd.uniform(0, TAU)
        rr = o['r'] + rnd.uniform(2.2, 5.0)
        lily(vis, (o['x'] + math.cos(a) * rr, WY + 0.02, o['z'] + math.sin(a) * rr), r=rnd.uniform(0.3, 0.6), seed=k)
print('STAGE', '# marsh hummocks', vis.tris, fol.tris)
# marsh hummocks (the SE marsh and the north pond of the original)
for (x, z, r) in L.get('hummocks', []):
    blob(fol, (x, WY - 0.2, z), r, 'grass', squash=0.25, seed=int(x * 7 + z), detail=1, amp=0.2)
    reeds(fol, (x, WY, z), n=8, h=1.4, spread=r * 0.8, seed=int(x + z), lod=LOD)

print('STAGE', '---- finish + export', vis.tris, fol.tris)
# ---------------------------------------------------------------- finish + export
ob = vis.finish(smooth_angle=True)
bpy.context.view_layer.objects.active = ob
ob.select_set(True)
try:
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(38))
except Exception as e:
    print('smooth', e)
fo = fol.finish(smooth_angle=True)      # foliage: fully smooth
print('VIS TRIS', vis.tris, 'FOLIAGE TRIS', fol.tris, 'materials', len(vis.mats))
size = int(os.environ.get('FROG_TEXSIZE', '1024'))
for im in bpy.data.images:
    if im.size[0] > size:
        im.scale(size, size)
bpy.ops.object.select_all(action='DESELECT')
ob.select_set(True)
fo.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, NAME + '.glb'), export_format='GLB', use_selection=True, export_apply=True, export_yup=True,
                          export_image_format='JPEG', export_jpeg_quality=85)
if os.environ.get('FROG_COL', '1') == '1':
    wo = walk.finish()
    wl = walls.finish()
    print('WALK TRIS', walk.tris, 'WALL TRIS', walls.tris)
    bpy.ops.object.select_all(action='DESELECT')
    wo.select_set(True)
    wl.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, 'frogtown_v2_col.glb'), export_format='GLB', use_selection=True, export_apply=True, export_yup=True, export_materials='NONE')
    json.dump({'doors': doors, 'water_y': WY, 'islands': {k: {'x': v['x'], 'z': v['z'], 'r': v['r'], 'deck_y': round(v['deck_y'], 3)} for k, v in ISL.items()}}, open(os.path.join(OUT, 'frogtown_v2_layout.json'), 'w'), indent=1)
if os.environ.get('FROG_BLEND'):
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, NAME + '.blend'))
print('done')
