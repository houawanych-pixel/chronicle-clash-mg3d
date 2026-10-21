"""Frogtown walk surface: a clean, crack-free floor over the boardwalks, decks,
plaza and hut floors, for the hero's feet and the villagers' navigation mesh.
The Tripo model's boardwalks are separate planks with gaps, and decimation
leaves cracks; this samples the game model on a 0.25 m grid (the lowest
upward-facing surface above the marsh in each column), closes plank-sized gaps,
and writes a light mesh: out/frogtown_walk.glb (object 'walk', game units,
model lift NOT applied - Frogtown.gd lifts it like the model).
Run: /opt/bpyenv/bin/python walk.py"""
import bpy, bmesh, numpy as np, os
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def _shifts(a, fillv):
    pad = np.pad(a, 1, constant_values=fillv)
    h, w = a.shape
    return [pad[1 + dj:1 + dj + h, 1 + di:1 + di + w] for dj in (-1, 0, 1) for di in (-1, 0, 1)]


def dilate(m):
    return np.logical_or.reduce(_shifts(m, False))


def erode(m):
    return np.logical_and.reduce(_shifts(m, True))


def conv3(a):
    return np.add.reduce(_shifts(a, 0.0))

OUT = '/tmp/claude-0/sp/frog/out'
SRC = os.path.join(OUT, 'frogtown.glb')
LIFT = 3.5
FLOOR_MIN = -2.6 - LIFT     # ignore the marsh lowlands (they sit under the water)
STEP = 0.25
for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)
bpy.ops.import_scene.gltf(filepath=SRC)
ob = [o for o in bpy.data.objects if o.type == 'MESH'][0]
bm = bmesh.new()
bm.from_mesh(ob.data)
bm.transform(ob.matrix_world)
tree = BVHTree.FromBMesh(bm)
xs = np.arange(-50, 50 + 1e-6, STEP)
n = len(xs)
H = np.full((n, n), np.nan, np.float32)
for i, x in enumerate(xs):
    for j, y in enumerate(xs):          # Blender y = -game z
        top = 30.0
        low = None
        for k in range(10):
            loc, nor, idx, d = tree.ray_cast(Vector((x, y, top)), Vector((0, 0, -1)), top - FLOOR_MIN)
            if loc is None:
                break
            if nor.z > 0.6 and loc.z > FLOOR_MIN:
                # a floor: keep it if there's head room above it (not inside a roof)
                low = loc.z
            top = loc.z - 0.03
        if low is not None:
            H[j, i] = low
valid = ~np.isnan(H)
# close plank gaps (up to ~0.5 m) but not real water gaps
closed = erode(dilate(valid)) | valid
fill = np.where(valid, H, 0.0)
w = valid.astype(np.float32)
k = np.ones((3, 3), np.float32)
s = conv3(fill)
c = conv3(w)
avg = np.where(c > 0, s / np.maximum(c, 1e-6), np.nan)
Hc = np.where(valid, H, avg)
Hc[~closed] = np.nan
# smooth plank bumps, steps and short stairs into gentle ramps (only between
# neighbours less than STEP_MAX apart, so hut walls and tree roots stay put)
STEP_MAX = 0.62
FLOOD_MAX = 0.24      # ~44 deg over one 0.25 m cell: what feet and the nav mesh can climb
sm = Hc.copy()
for _ in range(16):
    pad = np.pad(sm, 1, constant_values=np.nan)
    acc = np.zeros_like(sm)
    cnt = np.zeros_like(sm)
    for dj in (-1, 0, 1):
        for di in (-1, 0, 1):
            nb = pad[1 + dj:1 + dj + n, 1 + di:1 + di + n]
            ok = ~np.isnan(nb) & (np.abs(nb - sm) < STEP_MAX)
            acc += np.where(ok, nb, 0)
            cnt += ok
    sm = np.where(cnt > 0, acc / np.maximum(cnt, 1), sm)
Hc = np.where(np.isnan(Hc), np.nan, sm)
# Keep only floors you can walk to from the plaza (steps under STEP_MAX):
# drops hut roofs, tree crowns and other surfaces nobody can reach.
from collections import deque
seed_x, seed_z = -1.2, -2.6                 # game coords, east side of the plaza
si = int(round((seed_x + 50) / STEP))
sj = int(round((-seed_z + 50) / STEP))
best = None
for dj in range(-8, 9):
    for di in range(-8, 9):
        jj, ii = sj + dj, si + di
        if not np.isnan(Hc[jj, ii]) and abs(Hc[jj, ii] + LIFT) < 0.8:
            best = (jj, ii)
            break
    if best:
        break
reach = np.zeros_like(Hc, dtype=bool)
q = deque([best])
reach[best] = True
while q:
    j0, i0 = q.popleft()
    for dj, di in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        j1, i1 = j0 + dj, i0 + di
        if 0 <= j1 < n and 0 <= i1 < n and not reach[j1, i1] and not np.isnan(Hc[j1, i1]) and abs(Hc[j1, i1] - Hc[j0, i0]) < FLOOD_MAX:
            reach[j1, i1] = True
            q.append((j1, i1))
Hc[~reach] = np.nan
print('walk cells', int((~np.isnan(Hc)).sum()), 'of', n * n)
# build quads for walkable cells, skip steep cell joins (steps stay steps: walls do that job)
me = bpy.data.meshes.new('walk')
wb = bmesh.new()
vid = {}
def vert(j, i):
    key = (j, i)
    if key not in vid:
        vid[key] = wb.verts.new((xs[i], xs[j], float(Hc[j, i]) + 0.02))
    return vid[key]
for j in range(n - 1):
    for i in range(n - 1):
        q = [Hc[j, i], Hc[j, i + 1], Hc[j + 1, i + 1], Hc[j + 1, i]]
        if any(np.isnan(v) for v in q):
            continue
        if max(q) - min(q) > 0.34:
            continue
        try:
            wb.faces.new([vert(j, i), vert(j, i + 1), vert(j + 1, i + 1), vert(j + 1, i)])
        except ValueError:
            pass
bmesh.ops.recalc_face_normals(wb, faces=wb.faces)
for f in wb.faces:
    if f.normal.z < 0:
        f.normal_flip()
wb.to_mesh(me)
wb.free()
wo = bpy.data.objects.new('walk', me)
bpy.context.scene.collection.objects.link(wo)
bpy.ops.object.select_all(action='DESELECT')
wo.select_set(True)
bpy.context.view_layer.objects.active = wo
m = wo.modifiers.new('d', 'DECIMATE')
m.decimate_type = 'DISSOLVE'
m.angle_limit = 0.06
bpy.ops.object.modifier_apply(modifier='d')
m = wo.modifiers.new('t', 'TRIANGULATE')
bpy.ops.object.modifier_apply(modifier='t')
print('walk tris', len(wo.data.polygons))
bpy.data.objects.remove(ob, do_unlink=True)
# Walls: the collision mesh minus its floors and the low plank/step edges that the
# walk surface now covers (they'd trip the hero and split the nav mesh).
bpy.ops.import_scene.gltf(filepath=os.path.join(OUT, 'frogtown_col.glb'))
land = [o for o in bpy.data.objects if o.type == 'MESH' and o.name.startswith('land')][0]
lb = bmesh.new()
lb.from_mesh(land.data)
lb.transform(land.matrix_world)
def walk_h(x, y):
    i = int(round((x + 50) / STEP))
    j = int(round((y + 50) / STEP))
    if 0 <= i < n and 0 <= j < n:
        return Hc[j, i]
    return np.nan
# distance (in cells) from each walk cell to the edge of the walk area
inner = ~np.isnan(Hc)
depth = np.zeros(Hc.shape, np.int32)
cur = inner.copy()
for k in range(1, 6):
    cur = erode(cur)
    depth[cur] = k
drop = []
for f in lb.faces:
    c = f.calc_center_median()
    wh = walk_h(c.x, c.y)
    if np.isnan(wh):
        continue
    top = max(v.co.z for v in f.verts)
    bot = min(v.co.z for v in f.verts)
    ci = int(round((c.x + 50) / STEP))
    cj = int(round((c.y + 50) / STEP))
    if f.normal.z > 0.5:
        drop.append(f)       # any upward face (rail tops, sills): it would make a second floor layer
    elif depth[cj, ci] >= 3:
        drop.append(f)       # posts, stumps and shards standing inside an open walk area
    elif top < wh + 0.9:
        drop.append(f)       # floor, plank edge or low step under the walk surface
    elif bot > wh + 1.9:
        drop.append(f)       # overhead: roof eaves and tree crowns above the walk
bmesh.ops.delete(lb, geom=drop, context='FACES')
wm = bpy.data.meshes.new('walls')
lb.to_mesh(wm)
lb.free()
walls = bpy.data.objects.new('walls', wm)
bpy.context.scene.collection.objects.link(walls)
for o in list(bpy.data.objects):
    if o not in (wo, walls):
        bpy.data.objects.remove(o, do_unlink=True)
print('walls tris', sum(len(p.vertices) - 2 for p in walls.data.polygons), 'dropped', len(drop))
bpy.ops.object.select_all(action='DESELECT')
walls.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, 'frogtown_walls.glb'), export_format='GLB', use_selection=True, export_apply=True, export_yup=True, export_materials='NONE')
bpy.ops.object.select_all(action='DESELECT')
wo.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, 'frogtown_walk.glb'), export_format='GLB', use_selection=True, export_apply=True, export_yup=True, export_materials='NONE')
np.savez(os.path.join(OUT, 'walk_grid.npz'), xs=xs, h=Hc)
print('done')
