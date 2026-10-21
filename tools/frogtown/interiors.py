"""Frogtown reusable interiors -> out/int_hut.glb, out/int_lodge.glb.
Each file: visual meshes, a 'col' mesh (floor + walls for collision), and named
empties for markers: Spawn_Door, Exit_Door, and interaction spots
(Spot_<kind>_<n>, kind = bed, seat, hearth, table, shelf, work, window, play).
Door is always on +z. Run: /opt/bpyenv/bin/python interiors.py"""
import bpy, bmesh, math, random, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fkit import *

OUT = os.environ.get('FROG_OUT', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'out'))


def reset():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)


def marker(name, p, yaw=0.0):
    e = bpy.data.objects.new(name, None)
    e.location = B(p)
    e.rotation_euler = (0, 0, yaw)
    bpy.context.scene.collection.objects.link(e)
    return e


def export(path):
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_apply=True, export_yup=True)


def bed_mat(bd, c, yaw, key='mat'):
    """Woven sleeping mat with a rolled pillow."""
    cy, sn = math.cos(yaw), math.sin(yaw)
    def T(x, y, z):
        return (c[0] + x * cy + z * sn, c[1] + y, c[2] - x * sn + z * cy)
    rows = []
    for k in range(6):
        z = -1.0 + k * 0.4
        rows.append([T(x, 0.08 + 0.03 * math.sin(k * 1.7 + x * 3), z) for x in (-0.55, -0.2, 0.2, 0.55)])
    bd.grid(rows, key)
    sweep(bd, [T(-0.45, 0.2, -0.85), T(0.45, 0.2, -0.85)], 0.13, 'cloth_teal', sides=7)
    sweep(bd, [T(-0.5, 0.1, 0.4), T(0.5, 0.12, 0.6)], 0.05, 'cloth_blue', sides=5)


def stool(bd, c, key='wood'):
    lathe(bd, [(0.2, 0.0), (0.14, 0.2), (0.12, 0.3), (0.24, 0.42), (0.26, 0.46)], key, at=c, segs=10, wobble=0.03)


def pot(bd, c):
    lathe(bd, [(0.12, 0), (0.28, 0.1), (0.32, 0.3), (0.24, 0.45), (0.26, 0.5)], 'pot', at=c, segs=10)


def jar(bd, c, h=0.3, key='stone'):
    lathe(bd, [(0.06, 0), (0.12, h * 0.3), (0.11, h * 0.75), (0.06, h * 0.9), (0.07, h)], key, at=c, segs=8)


def barrel(bd, c, h=0.9):
    lathe(bd, [(0.3, 0), (0.36, h * 0.25), (0.38, h * 0.5), (0.36, h * 0.75), (0.3, h)], 'wood', at=c, segs=12)
    for y in (0.12, h - 0.12):
        lathe(bd, [(0.33 + 0.04 * math.sin(y / h * math.pi), y - 0.03), (0.34 + 0.04 * math.sin(y / h * math.pi), y + 0.03)], 'wood_dark', at=c, segs=12, cap_top=False)


def hearth(bd, c, r=0.75):
    for i in range(9):
        a = i / 9 * math.tau
        lathe(bd, [(0.16, 0), (0.2, 0.1), (0.14, 0.2), (0.001, 0.24)], 'stone', at=(c[0] + math.cos(a) * r, c[1], c[2] + math.sin(a) * r), segs=6, wobble=0.15, seed=i)
    for i in range(5):
        a = i / 5 * math.tau
        lathe(bd, [(0.12, 0), (0.08, 0.22), (0.001, 0.45 + 0.1 * (i % 2))], 'fire', at=(c[0] + math.cos(a) * 0.18, c[1] + 0.02, c[2] + math.sin(a) * 0.18), segs=5, twist=0.5)
    for s in (-1, 1):   # pot hanger
        sweep(bd, [(c[0] + s * 0.7, c[1], c[2]), (c[0] + s * 0.25, c[1] + 1.3, c[2])], 0.04, 'wood_dark', sides=5)
    sweep(bd, [(c[0] - 0.3, c[1] + 1.28, c[2]), (c[0] + 0.3, c[1] + 1.28, c[2])], 0.035, 'wood_dark', sides=5)
    sweep(bd, [(c[0], c[1] + 1.28, c[2]), (c[0], c[1] + 0.85, c[2])], 0.012, 'rope', sides=4, cap=False)
    pot(bd, (c[0], c[1] + 0.35, c[2]))


def round_table(bd, c, r=0.7):
    lathe(bd, [(r * 0.95, 0.66), (r, 0.7), (r * 0.98, 0.76), (r * 0.9, 0.78)], 'wood_light', at=c, segs=16, wobble=0.04, seed=3)
    for i in range(3):
        a = i / 3 * math.tau
        sweep(bd, curve((c[0] + math.cos(a) * r * 0.5, c[1] + 0.66, c[2] + math.sin(a) * r * 0.5), (c[0] + math.cos(a) * r * 0.8, c[1], c[2] + math.sin(a) * r * 0.8), (0, 0, 0), 4), 0.05, 'wood_dark', sides=5)
    lathe(bd, [(0.1, 0.78), (0.14, 0.84), (0.13, 0.9)], 'shell', at=(c[0] + 0.2, c[1], c[2]), segs=8)


def shelf(bd, c, yaw, w=1.6):
    cy, sn = math.cos(yaw), math.sin(yaw)
    def T(x, y, z):
        return (c[0] + x * cy + z * sn, c[1] + y, c[2] - x * sn + z * cy)
    for y in (0.6, 1.2, 1.8):
        plank(bd, T(0, y, 0), (w, 0.05, 0.35), 'wood', yaw=yaw, seed=int(y * 10))
    for s in (-1, 1):
        sweep(bd, [T(s * w * 0.48, 0, 0), T(s * w * 0.48, 2.0, 0)], 0.04, 'wood_dark', sides=5)
    rnd = random.Random(int(c[0] * 10))
    for y in (0.63, 1.23, 1.83):
        for i in range(3):
            jar(bd, T(-w * 0.35 + i * w * 0.33 + rnd.uniform(-0.05, 0.05), y, 0), rnd.uniform(0.2, 0.35), rnd.choice(['stone', 'shell', 'red', 'pot']))


def herbs(bd, c, n=4):
    for i in range(n):
        x = c[0] + (i - n / 2) * 0.25
        sweep(bd, [(x, c[1], c[2]), (x, c[1] - 0.35, c[2])], 0.01, 'rope', sides=4, cap=False)
        lathe(bd, [(0.001, -0.7), (0.09, -0.55), (0.06, -0.35)], 'leaf', at=(x, c[1], c[2]), segs=6)


def lily_rug(bd, c, r=1.0):
    pts = []
    for i in range(20):
        a = math.radians(20 + i / 19 * 320)
        pts.append((c[0] + math.cos(a) * r, c[1] + 0.02, c[2] + math.sin(a) * r))
    pts.append((c[0], c[1] + 0.02, c[2]))
    bd.face(pts[::-1], 'leaf')


# ================================================================ INT_HUT (round stilt hut)
reset()
R = 4.2
bd = Builder('hut_shell')
disc_planks(bd, (0, 0, 0), 0.0, R + 0.05, 22, 'wood_light', seed=1)
# wall: lathe of a woven reed wall with a door gap at +z (angles around 90 deg)
seg = 36
gap = math.radians(24)
rows = []
for k, y in enumerate([0.0, 0.6, 1.2, 1.8, 2.3]):
    ring = []
    for i in range(seg + 1):
        a = math.pi / 2 + gap + (math.tau - 2 * gap) * i / seg
        rr = R + 0.06 * math.sin(i * 2.1 + k) + 0.05 * k * 0.3
        ring.append((math.cos(a) * rr, y, math.sin(a) * rr))
    rows.append(ring)
bd.grid(rows, 'reed')
# wall posts
for i in range(10):
    a = math.pi / 2 + gap + (math.tau - 2 * gap) * i / 9
    sweep(bd, curve((math.cos(a) * (R - 0.12), 0, math.sin(a) * (R - 0.12)), (math.cos(a) * (R - 0.25), 2.35, math.sin(a) * (R - 0.25)), (0, 0, 0), 3), lambda u: 0.11 - 0.03 * u, 'wood_dark', sides=6)
# door frame
for s in (-1, 1):
    a = math.pi / 2 + s * gap
    sweep(bd, [(math.cos(a) * R, 0, math.sin(a) * R), (math.cos(a) * R, 2.2, math.sin(a) * R)], 0.12, 'wood_dark', sides=6)
sweep(bd, curve((math.cos(math.pi / 2 - gap) * R, 2.2, math.sin(math.pi / 2 - gap) * R), (math.cos(math.pi / 2 + gap) * R, 2.2, math.sin(math.pi / 2 + gap) * R), (0, 0.35, 0.1), 6), 0.1, 'bone', sides=6)
# glowing doorway (reads as "outside")
dw = math.sin(gap) * R
bd.face([(-dw, 0.02, R + 0.25), (dw, 0.02, R + 0.25), (dw, 2.25, R + 0.25), (-dw, 2.25, R + 0.25)], 'sky')
# conical thatch roof seen from inside, with rafters and a centre post
rr = []
for k in range(7):
    v = k / 6
    r = (R + 0.4) * (1 - v) + 0.15 * v
    y = 2.3 + 3.2 * v ** 0.85
    rr.append([(math.cos(i / 24 * math.tau) * r, y, math.sin(i / 24 * math.tau) * r) for i in range(24)])
bd.grid([list(reversed(r)) for r in rr], 'thatch', close_u=True)
for i in range(12):
    a = i / 12 * math.tau
    sweep(bd, [(math.cos(a) * R, 2.3, math.sin(a) * R), (math.cos(a) * 0.15, 5.45, math.sin(a) * 0.15)], 0.06, 'wood_dark', sides=5)
lathe(bd, [(0.2, 0), (0.17, 1.0), (0.18, 3.0), (0.14, 5.5)], 'wood_dark', at=(0, 0, -1.6), segs=8, wobble=0.05)
# round window (shell frame) at -x
lathe(bd, [(0.45, 0), (0.55, 0.06)], 'shell', at=(-R + 0.05, 1.5, 0), segs=12, cap_top=False)
done_hut = bd.finish()
bd = Builder('hut_dressing')
hearth(bd, (0.0, 0.0, -0.2))
bed_mat(bd, (-2.4, 0.0, -1.6), math.radians(35))
bed_mat(bd, (2.4, 0.0, -1.6), math.radians(-35))
round_table(bd, (1.7, 0.0, 1.5), 0.62)
stool(bd, (2.5, 0.0, 1.9))
stool(bd, (1.0, 0.0, 2.2))
shelf(bd, (0.0, 0.0, -3.7), 0.0, 1.8)
barrel(bd, (-2.9, 0.0, 1.9))
herbs(bd, (-1.0, 2.25, -2.6), 5)
lily_rug(bd, (-1.2, 0.0, 1.2), 0.9)
bd.finish()
bd = Builder('col')
# floor disc + wall ring (collision only, kept simple)
pts = [(math.cos(i / 24 * math.tau) * (R + 0.2), 0, math.sin(i / 24 * math.tau) * (R + 0.2)) for i in range(24)]
bd.face(pts[::-1], 'stone')
ring_lo, ring_hi = [], []
for i in range(seg + 1):
    a = math.pi / 2 + gap + (math.tau - 2 * gap) * i / seg
    ring_lo.append((math.cos(a) * (R - 0.15), 0, math.sin(a) * (R - 0.15)))
    ring_hi.append((math.cos(a) * (R - 0.15), 2.6, math.sin(a) * (R - 0.15)))
bd.grid([ring_lo, ring_hi], 'stone')
# door plug a little outside so you can't walk away from the doorway
bd.face([(-dw - 0.3, 0, R + 0.6), (dw + 0.3, 0, R + 0.6), (dw + 0.3, 2.6, R + 0.6), (-dw - 0.3, 2.6, R + 0.6)], 'stone')
for (c, r) in [((0.0, -0.2), 0.95), ((1.7, 1.5), 0.7), ((-2.9, 1.9), 0.45), ((0.0, -1.6), 0.25)]:
    ring = [(c[0] + math.cos(i / 8 * math.tau) * r, 0, c[1] + math.sin(i / 8 * math.tau) * r) for i in range(9)]
    bd.grid([ring, [(p[0], 1.0, p[2]) for p in ring]], 'stone')
bd.finish()
marker('Spawn_Door', (0, 0, R - 1.0), math.pi)
marker('Exit_Door', (0, 0, R - 0.1))
marker('Spot_hearth_1', (0.0, 0, 0.95))
marker('Spot_bed_1', (-2.4, 0, -1.6))
marker('Spot_bed_2', (2.4, 0, -1.6))
marker('Spot_seat_1', (2.5, 0, 1.9))
marker('Spot_seat_2', (1.0, 0, 2.2))
marker('Spot_shelf_1', (0.0, 0, -2.9))
marker('Spot_window_1', (-3.3, 0, 0.0))
marker('Spot_play_1', (-1.2, 0, 1.2))
export(os.path.join(OUT, 'int_hut.glb'))

# ================================================================ INT_LODGE (long hall)
reset()
LX, LZ = 5.5, 3.6    # half extents
bd = Builder('lodge_shell')
for i in range(12):   # plank floor along z
    x = -LX + (i + 0.5) * (2 * LX / 12)
    plank(bd, (x, -0.04, 0), (2 * LX / 12 - 0.03, 0.08, 2 * LZ), 'wood_light', seed=i)
# log walls (with door gap on +z middle)
def wall_logs(a, b, n=5, key='wood'):
    for k in range(n):
        y = 0.22 + k * 0.42
        sweep(bd, [(a[0], y, a[1]), (b[0], y, b[1])], 0.22, key, sides=7)
wall_logs((-LX, -LZ), (LX, -LZ))
wall_logs((-LX, -LZ), (-LX, LZ))
wall_logs((LX, -LZ), (LX, LZ))
wall_logs((-LX, LZ), (-1.0, LZ))
wall_logs((1.0, LZ), (LX, LZ))
for k in range(5, 6):
    pass
sweep(bd, curve((-1.0, 2.2, LZ), (1.0, 2.2, LZ), (0, 0.4, 0), 6), 0.16, 'bone', sides=6)
bd.face([(-1.0, 0.02, LZ + 0.3), (1.0, 0.02, LZ + 0.3), (1.0, 2.3, LZ + 0.3), (-1.0, 2.3, LZ + 0.3)], 'sky')
# pitched thatch roof inside + tie beams
rows = []
for k in range(5):
    v = k / 4
    z = -LZ - 0.4 + v * (LZ + 0.4)
    y = 2.1 + v * 2.4
    rows.append([(x, y, z) for x in (-LX - 0.3, -LX / 2, 0, LX / 2, LX + 0.3)])
bd.grid(rows, 'thatch')
rows = []
for k in range(5):
    v = k / 4
    z = LZ + 0.4 - v * (LZ + 0.4)
    y = 2.1 + v * 2.4
    rows.append([(x, y, z) for x in (LX + 0.3, LX / 2, 0, -LX / 2, -LX - 0.3)])
bd.grid(rows, 'thatch')
for x in (-4, -1.4, 1.4, 4):
    sweep(bd, [(x, 2.2, -LZ), (x, 2.2, LZ)], 0.14, 'wood_dark', sides=6)
    sweep(bd, [(x, 2.2, 0), (x, 4.45, 0)], 0.1, 'wood_dark', sides=6)
sweep(bd, [(-LX, 4.45, 0), (LX, 4.45, 0)], 0.16, 'wood_dark', sides=6)
# gable ends
bd.face([(-LX, 2.0, -LZ), (-LX, 2.0, LZ), (-LX, 4.5, 0)], 'reed')
bd.face([(LX, 2.0, LZ), (LX, 2.0, -LZ), (LX, 4.5, 0)], 'reed')
bd.finish()
bd = Builder('lodge_dressing')
hearth(bd, (0.0, 0.0, -0.6), 0.9)
# long table and benches
for x in (-3.0,):
    pass
plank(bd, (-3.2, 0.75, 0.7), (3.0, 0.1, 0.9), 'wood_light', seed=70)
for s in (-1, 1):
    sweep(bd, [(-3.2 + s * 1.2, 0, 0.7), (-3.2 + s * 1.2, 0.72, 0.7)], 0.08, 'wood_dark', sides=6)
    plank(bd, (-3.2, 0.42, 0.7 + s * 0.8), (2.8, 0.08, 0.35), 'wood', seed=72 + s)
# sleeping alcoves with curtains on the back wall
for i, x in enumerate((-4.2, 2.6, 4.4)):
    bed_mat(bd, (x, 0.0, -2.7), math.radians(90))
    rows = []
    for k in range(4):
        y = 2.1 - k * 0.6
        rows.append([(x - 0.9 + 0.3 * j, y, -1.95 + 0.06 * math.sin(j * 1.4 + k)) for j in range(7)])
    bd.grid(rows, 'cloth_teal' if i % 2 == 0 else 'cloth_blue')
shelf(bd, (LX - 0.4, 0.0, 1.6), math.radians(90), 1.8)
barrel(bd, (-LX + 0.6, 0.0, 2.8))
barrel(bd, (-LX + 1.4, 0.0, 3.0), 0.7)
herbs(bd, (1.8, 2.1, 1.5), 6)
# chief / captain seat with a shell back (dressing differs by family in game)
lathe(bd, [(0.5, 0), (0.45, 0.4), (0.55, 0.48)], 'wood_dark', at=(-LX + 0.9, 0, -0.6), segs=12)
fan_shell(bd, (-LX + 0.55, 0.5, -0.6), 0.9, 'shell', ribs=9, spread=150, depth=0.25, tilt=-80, yaw=math.pi / 2, thick=0.05)
bd.finish()
bd = Builder('col')
bd.face([(-LX, 0, -LZ), (LX, 0, -LZ), (LX, 0, LZ), (-LX, 0, LZ)][::-1], 'stone')
def wall(a, b):
    bd.face([(a[0], 0, a[1]), (b[0], 0, b[1]), (b[0], 2.6, b[1]), (a[0], 2.6, a[1])], 'stone')
q = 0.15
wall((-LX + q, -LZ + q), (LX - q, -LZ + q)); wall((-LX + q, -LZ + q), (-LX + q, LZ - q)); wall((LX - q, -LZ + q), (LX - q, LZ - q))
wall((-LX + q, LZ - q), (-1.0, LZ - q)); wall((1.0, LZ - q), (LX - q, LZ - q)); wall((-1.2, LZ + 0.6), (1.2, LZ + 0.6))
for (c, sx, sz) in [((0.0, -0.6), 1.0, 1.0), ((-3.2, 0.7), 1.6, 1.3), ((-LX + 0.9, -0.6), 0.6, 0.6), ((LX - 0.4, 1.6), 0.3, 1.0)]:
    ring = [(c[0] - sx, 0, c[1] - sz), (c[0] + sx, 0, c[1] - sz), (c[0] + sx, 0, c[1] + sz), (c[0] - sx, 0, c[1] + sz), (c[0] - sx, 0, c[1] - sz)]
    bd.grid([ring, [(p[0], 1.0, p[2]) for p in ring]], 'stone')
bd.finish()
marker('Spawn_Door', (0, 0, LZ - 1.0), math.pi)
marker('Exit_Door', (0, 0, LZ - 0.1))
marker('Spot_hearth_1', (0.0, 0, 0.6))
marker('Spot_bed_1', (-4.2, 0, -2.7))
marker('Spot_bed_2', (2.6, 0, -2.7))
marker('Spot_bed_3', (4.4, 0, -2.7))
marker('Spot_seat_1', (-4.0, 0, 1.5))
marker('Spot_seat_2', (-2.4, 0, 1.5))
marker('Spot_seat_3', (-3.2, 0, -0.1))
marker('Spot_table_1', (-LX + 1.6, 0, -0.6))
marker('Spot_shelf_1', (LX - 1.2, 0, 1.6))
marker('Spot_work_1', (3.0, 0, 1.2))
export(os.path.join(OUT, 'int_lodge.glb'))
print('INTERIORS done')
