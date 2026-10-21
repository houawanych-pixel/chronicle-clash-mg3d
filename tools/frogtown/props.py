"""Frogtown landmark props -> out/frog_props.glb (one object per prop, origin at its foot).
Run: /opt/bpyenv/bin/python props.py"""
import bpy, math, random, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fkit import *

OUT = os.environ.get('FROG_OUT', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'out'))
os.makedirs(OUT, exist_ok=True)
for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)
objs = []


def done(bd, smooth=False):
    objs.append(bd.finish(smooth))


def post(bd, base, h, r, key='wood_dark', seed=0, bend=(0, 0, 0), finial=True):
    path = curve(base, (base[0], base[1] + h, base[2]), bend, 6)
    sweep(bd, path, lambda u: r * (1.15 - 0.3 * u), key, sides=7)
    if finial:
        t = path[-1]
        lathe(bd, [(0.001, 0), (r * 1.5, r * 0.8), (r * 1.2, r * 1.8), (0.001, r * 2.6)], 'gold', at=t, segs=8)


# 1. Chief's dais under a great shell canopy -------------------------------------------
bd = Builder('chief_dais')
lathe(bd, [(3.2, 0), (3.2, 0.25), (2.9, 0.3), (2.9, 0.5), (2.4, 0.55), (2.4, 0.8)], 'stone', segs=20, wobble=0.03, seed=3)
disc_planks(bd, (0, 0.82, 0), 0.2, 2.35, 14, 'wood_light', seed=4)
for i in range(3):   # steps at the front (+z)
    plank(bd, (0, 0.13 + i * 0.27, 3.25 - i * 0.32), (2.2 - i * 0.3, 0.26, 0.36), 'wood', seed=10 + i)
# carved seat (shell back)
lathe(bd, [(0.55, 0.8), (0.6, 1.0), (0.5, 1.25), (0.62, 1.32)], 'wood_dark', at=(0, 0, -1.2), segs=12)
fan_shell(bd, (0, 1.3, -1.55), 1.0, 'shell_pink', ribs=9, spread=160, depth=0.25, tilt=-80, thick=0.06)
# two curved horn posts holding the canopy
for s in (-1, 1):
    sweep(bd, curve((s * 2.2, 0.8, -1.6), (s * 0.9, 5.6, -1.2), (s * 1.2, 0, 0.4), 10), lambda u: 0.2 * (1.0 - 0.45 * u), 'bone', sides=8)
fan_shell(bd, (0, 5.0, -2.3), 4.6, 'shell', ribs=13, spread=170, depth=0.32, tilt=-18, thick=0.12)
for i in range(5):   # hanging lanterns at the canopy rim
    a = math.radians(-60 + i * 30)
    p = (math.sin(a) * 3.4, 4.2, -2.3 + math.cos(a) * 3.0)
    sweep(bd, [(p[0], p[1] + 0.8, p[2]), (p[0], p[1] + 0.25, p[2])], 0.02, 'rope', sides=4, cap=False)
    lathe(bd, [(0.05, 0), (0.18, 0.08), (0.22, 0.22), (0.16, 0.38), (0.06, 0.44)], 'lantern', at=(p[0], p[1] - 0.2, p[2]), segs=8)
# blue Valcrest banners on the posts
for s in (-1, 1):
    bd.face([(s * 1.9, 3.2, -1.45), (s * 1.9, 1.4, -1.45), (s * 1.35, 1.2, -1.4), (s * 1.35, 3.0, -1.4)], 'cloth_blue')
done(bd)

# 2. Council drum ------------------------------------------------------------------------
bd = Builder('council_drum')
lathe(bd, [(0.62, 0.35), (0.78, 0.55), (0.82, 0.8), (0.78, 1.05), (0.68, 1.22)], 'wood', segs=18, wobble=0.02, seed=7)
lathe(bd, [(0.68, 1.22), (0.70, 1.25), (0.35, 1.29), (0.001, 1.3)], 'hide', segs=18, cap_top=False)
lathe(bd, [(0.62, 0.35), (0.6, 0.3), (0.001, 0.28)], 'hide', segs=18, cap_top=False)
for i in range(12):   # zig-zag lacing
    a0 = i / 12 * math.tau
    a1 = (i + 0.5) / 12 * math.tau
    sweep(bd, [(math.cos(a0) * 0.71, 1.2, math.sin(a0) * 0.71), (math.cos(a1) * 0.84, 0.8, math.sin(a1) * 0.84), (math.cos(a0 + math.tau / 12) * 0.64, 0.38, math.sin(a0 + math.tau / 12) * 0.64)], 0.018, 'rope', sides=4, cap=False)
for i in range(3):   # carved legs
    a = i / 3 * math.tau
    sweep(bd, curve((math.cos(a) * 0.55, 0.38, math.sin(a) * 0.55), (math.cos(a) * 0.85, 0.0, math.sin(a) * 0.85), (math.cos(a) * 0.15, 0.05, math.sin(a) * 0.15), 5), 0.07, 'wood_dark', sides=6)
sweep(bd, curve((0.55, 1.32, 0.3), (1.1, 1.0, 0.7), (0, 0.15, 0), 5), lambda u: 0.035 + 0.04 * u * u, 'wood_light', sides=6)
done(bd)

# 3. Hunter request board --------------------------------------------------------------
bd = Builder('request_board')
for s in (-1, 1):
    post(bd, (s * 1.3, 0, 0), 2.7, 0.11, seed=s, bend=(s * 0.05, 0, 0.05))
for i in range(5):
    plank(bd, (0, 0.95 + i * 0.3, 0.06), (2.5 + random.Random(i).uniform(-0.15, 0.1), 0.27, 0.07), 'wood_light' if i % 2 else 'wood', seed=20 + i)
# curved thatch hood
rows = []
for k in range(4):
    v = k / 3
    rows.append([(x, 2.95 - v * 0.45 + 0.12 * math.sin(v * math.pi), 0.06 + v * 0.75) for x in [-1.6 + 0.4 * i for i in range(9)]])
bd.grid(rows, 'thatch')
rnd = random.Random(5)
for i in range(7):   # pinned bounty notes
    cx, cy = rnd.uniform(-1.0, 1.0), rnd.uniform(1.0, 2.2)
    w, h, r = rnd.uniform(0.32, 0.45), rnd.uniform(0.38, 0.5), rnd.uniform(-0.2, 0.2)
    pts = [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]
    pts = [(cx + x * math.cos(r) - y * math.sin(r), cy + x * math.sin(r) + y * math.cos(r), 0.105) for x, y in pts]
    bd.face(pts, 'paper')
    lathe(bd, [(0.03, 0), (0.03, 0.02)], 'red', at=(cx, cy + h * 0.4, 0.11), segs=6)
done(bd)

# 4. Ancestor shell totem with a small fire --------------------------------------------
bd = Builder('shell_totem')
lathe(bd, [(1.4, 0), (1.45, 0.18), (1.1, 0.28), (0.95, 0.3)], 'stone', segs=16, wobble=0.06, seed=9)
prof = []
for k in range(15):
    y = 0.3 + k * 0.32
    r = 0.26 + 0.07 * math.sin(k * 1.3) + (0.06 if k % 4 == 0 else 0)
    prof.append((r, y))
lathe(bd, prof, 'wood_dark', segs=10, wobble=0.04, seed=11)
for k, (y, rad, yaw) in enumerate([(1.6, 0.8, 0.0), (2.7, 0.7, 2.1), (3.7, 0.6, 4.2)]):
    fan_shell(bd, (0, y, 0), rad, 'shell' if k != 1 else 'shell_pink', ribs=9, spread=140, depth=0.4, tilt=-35, yaw=yaw, thick=0.05)
# conch on top (spiral lathe)
cp = [(0.001, 0), (0.28, 0.12), (0.36, 0.3), (0.3, 0.5), (0.2, 0.7), (0.1, 0.85), (0.001, 0.98)]
lathe(bd, cp, 'shell_pink', at=(0, 5.05, 0), segs=12, twist=0.35)
# eyes of the ancestors: two gold bulbs
for s in (-1, 1):
    lathe(bd, [(0.001, -0.08), (0.09, 0), (0.001, 0.08)], 'gold', at=(s * 0.16, 4.4, 0.3), segs=8)
# fire bowl in front
lathe(bd, [(0.3, 0), (0.5, 0.12), (0.62, 0.32), (0.58, 0.36), (0.4, 0.24)], 'stone', at=(0, 0, 1.0), segs=12)
for i in range(4):
    a = i / 4 * math.tau
    lathe(bd, [(0.12, 0), (0.08, 0.25), (0.001, 0.5 + 0.12 * (i % 2))], 'fire', at=(math.cos(a) * 0.15, 0.3, 1.0 + math.sin(a) * 0.15), segs=6, twist=0.4)
done(bd)

# 5. Lantern post (hooked) and small string lantern -------------------------------------
bd = Builder('lantern_post')
path = curve((0, 0, 0), (0.55, 2.9, 0), (-0.25, 0.4, 0), 8) + curve((0.55, 2.9, 0), (0.85, 2.55, 0), (0.25, 0.35, 0), 4)[1:]
sweep(bd, path, lambda u: 0.09 * (1.2 - 0.6 * u), 'wood_dark', sides=6)
lathe(bd, [(0.25, 0), (0.3, 0.12), (0.22, 0.25)], 'stone', segs=8)
sweep(bd, [(0.85, 2.55, 0), (0.85, 2.3, 0)], 0.015, 'rope', sides=4, cap=False)
lathe(bd, [(0.04, 0), (0.17, 0.07), (0.21, 0.22), (0.15, 0.38), (0.05, 0.44)], 'lantern', at=(0.85, 1.85, 0), segs=8)
lathe(bd, [(0.05, 0.44), (0.12, 0.47), (0.001, 0.52)], 'wood_dark', at=(0.85, 1.85, 0), segs=8)
done(bd)
bd = Builder('string_lantern')
lathe(bd, [(0.03, 0), (0.11, 0.05), (0.13, 0.15), (0.1, 0.25), (0.03, 0.29)], 'lantern', segs=7)
done(bd)

# 6. Flood gauge -------------------------------------------------------------------------
bd = Builder('flood_gauge')
lathe(bd, [(0.55, 0), (0.6, 0.15), (0.35, 0.25)], 'stone', segs=10, wobble=0.05, seed=2)
cols = ['cloth_blue', 'paper', 'red', 'paper', 'gold', 'paper', 'red', 'paper']
for i, c in enumerate(cols):
    y0 = 0.25 + i * 0.42
    lathe(bd, [(0.13, y0), (0.13, y0 + 0.42)], c, segs=8, cap_top=False)
lathe(bd, [(0.13, 3.61), (0.2, 3.7), (0.001, 3.95)], 'gold', segs=8)
for i in range(9):   # notches
    y = 0.25 + i * 0.42
    plank(bd, (0.22, y, 0), (0.18, 0.04, 0.05), 'wood_dark', seed=40 + i)
# float ring (marks the water level)
lathe(bd, [(0.2, 1.1), (0.32, 1.14), (0.34, 1.24), (0.2, 1.28)], 'wood_light', segs=12, cap_top=False)
fan_shell(bd, (0, 4.0, 0), 0.4, 'shell', ribs=7, spread=150, depth=0.3, tilt=-75, thick=0.03)
done(bd)

# 7. Sluice wheel (frame + trough) and the wheel itself (spins in game) -------------------
bd = Builder('sluice_frame')
for s in (-1, 1):
    for z in (-1.2, 1.2):
        post(bd, (s * 0.8, -1.4, z), 4.3, 0.12, finial=(z > 0), bend=(0, 0, 0))
    plank(bd, (s * 0.8, 2.75, 0), (0.18, 0.2, 2.8), 'wood', seed=50 + s)
# trough feeding water onto the wheel top
plank(bd, (0, 2.35, -2.6), (1.0, 0.1, 2.8), 'wood_light', seed=55)
for s in (-1, 1):
    plank(bd, (s * 0.5, 2.5, -2.6), (0.08, 0.32, 2.8), 'wood', seed=56 + s)
bd.face([(-0.42, 2.42, -1.2), (0.42, 2.42, -1.2), (0.42, 2.42, -4.0), (-0.42, 2.42, -4.0)], 'water')
done(bd)
bd = Builder('sluice_paddles')
R = 2.2
for s in (-0.42, 0.42):
    ring_o = [(s, math.cos(a) * R, math.sin(a) * R) for a in [i / 24 * math.tau for i in range(25)]]
    sweep(bd, ring_o, 0.07, 'wood_dark', sides=6, cap=False)
for i in range(8):
    a = i / 8 * math.tau
    for s in (-0.42, 0.42):
        sweep(bd, [(s, 0, 0), (s, math.cos(a) * R, math.sin(a) * R)], 0.05, 'wood', sides=5)
for i in range(16):
    a = i / 16 * math.tau
    c = (0, math.cos(a) * (R - 0.15), math.sin(a) * (R - 0.15))
    rows = []
    for k in range(3):
        rr = R - 0.45 + k * 0.32
        da = 0.08 * (k - 1)
        rows.append([(x, math.cos(a + da) * rr, math.sin(a + da) * rr) for x in (-0.48, 0.0, 0.48)])
    bd.grid(rows, 'wood_light')
lathe(bd, [(0.14, -0.6), (0.14, 0.6)], 'wood_dark', segs=8, cap_top=True, cap_bot=True)
ob = bd.finish()
ob.rotation_euler = (0, 0, 0)
objs.append(ob)

# 8. Door arch (marks each hut door) and the big bone/branch exit gate -------------------
bd = Builder('door_arch')
for s in (-1, 1):
    sweep(bd, curve((s * 0.85, 0, 0), (s * 0.12, 2.7, 0), (s * 0.55, 0.2, 0.15), 10), lambda u: 0.09 * (1.0 - 0.6 * u), 'bone', sides=6)
lathe(bd, [(0.001, 0), (0.14, 0.06), (0.001, 0.12)], 'gold', at=(0, 2.68, 0), segs=8)
sweep(bd, [(0, 2.62, 0), (0, 2.3, 0.05)], 0.015, 'rope', sides=4, cap=False)
lathe(bd, [(0.04, 0), (0.13, 0.06), (0.16, 0.18), (0.11, 0.3), (0.04, 0.34)], 'lantern', at=(0, 1.95, 0.05), segs=8)
for s in (-1, 1):   # little reed tassels
    sweep(bd, curve((s * 0.62, 1.4, 0), (s * 0.7, 0.8, 0.05), (s * 0.05, 0, 0.05), 4), 0.03, 'reed', sides=4)
done(bd)
bd = Builder('exit_gate')
for s in (-1, 1):
    sweep(bd, curve((s * 2.6, 0, 0), (s * 0.4, 6.2, 0), (s * 1.8, 0.4, 0), 14), lambda u: 0.32 * (1.0 - 0.55 * u), 'bone', sides=8)
    for k in range(4):   # branch ribs
        y = 1.2 + k * 1.1
        x0 = s * (2.6 - 0.45 * k - 0.1 * k * k)
        sweep(bd, curve((x0, y, 0), (x0 + s * 0.9, y + 0.7, 0.3), (s * 0.2, 0.3, 0.3), 4), lambda u: 0.09 * (1 - 0.6 * u), 'wood_dark', sides=5)
lathe(bd, [(0.001, 0), (0.45, 0.25), (0.35, 0.6), (0.001, 0.75)], 'shell_pink', at=(0, 6.0, 0), segs=10, twist=0.3)
for i in range(7):
    t = i / 6
    x = -2.0 + 4.0 * t
    y = 4.3 + 1.3 * math.sin(math.pi * t)
    sweep(bd, [(x, y + 0.3, 0), (x, y, 0)], 0.015, 'rope', sides=4, cap=False)
    lathe(bd, [(0.03, 0), (0.11, 0.05), (0.13, 0.15), (0.1, 0.25), (0.03, 0.29)], 'lantern', at=(x, y - 0.3, 0), segs=7)
done(bd)

# 9. Market stall on stilts --------------------------------------------------------------
bd = Builder('market_stall')
for x in (-1.2, 1.2):
    for z in (-0.7, 0.7):
        post(bd, (x, 0, z), 2.5 if z < 0 else 2.2, 0.07, finial=False)
for i in range(4):
    plank(bd, (0, 0.92, -0.45 + i * 0.3), (2.6, 0.06, 0.28), 'wood_light', seed=60 + i)
plank(bd, (0, 0.6, 0.72), (2.6, 0.62, 0.08), 'wood', seed=65)
rows = []
for k in range(5):
    v = k / 4
    rows.append([(x, 2.55 - v * 0.55 - 0.1 * math.sin(v * math.pi), -0.9 + v * 2.0) for x in [-1.5 + 0.375 * i for i in range(9)]])
bd.grid(rows, 'cloth_teal')
for i, (x, z, c) in enumerate([(-0.8, 0.0, 'leaf'), (0.0, -0.2, 'red'), (0.8, 0.1, 'gold')]):
    lathe(bd, [(0.2, 0.95), (0.3, 1.05), (0.32, 1.2), (0.3, 1.25)], 'rope', at=(x, 0, z), segs=10)
    lathe(bd, [(0.25, 1.2), (0.18, 1.32), (0.001, 1.36)], c, at=(x, 0, z), segs=8)
done(bd)

# 10. Frog-folk head (placeholder villager look: worn over the shared rig's head bone)
bd = Builder('frog_head')
lathe(bd, [(0.001, -0.02), (0.16, 0.0), (0.24, 0.07), (0.25, 0.15), (0.2, 0.24), (0.1, 0.29), (0.001, 0.3)], 'leaf', segs=16, sx=1.0, sz=1.22)
# mouth band
lathe(bd, [(0.252, 0.085), (0.256, 0.1)], 'wood_dark', segs=16, sx=1.0, sz=1.225, cap_top=False)
for s in (-1, 1):   # bulging eyes on top, a little forward
    lathe(bd, [(0.001, 0), (0.075, 0.03), (0.085, 0.08), (0.06, 0.13), (0.001, 0.145)], 'moss', at=(s * 0.12, 0.2, 0.1), segs=10)
    lathe(bd, [(0.001, 0), (0.05, 0.02), (0.06, 0.06), (0.001, 0.08)], 'gold', at=(s * 0.12, 0.25, 0.155), segs=8)
    lathe(bd, [(0.001, 0), (0.025, 0.01), (0.001, 0.03)], 'pot', at=(s * 0.12, 0.27, 0.205), segs=6)
done(bd)
bd = Builder('reed_hat')
lathe(bd, [(0.42, 0), (0.4, 0.04), (0.18, 0.16), (0.04, 0.3), (0.001, 0.33)], 'thatch', segs=14, wobble=0.04, seed=8, cap_bot=True)
done(bd)

bpy.ops.object.select_all(action='DESELECT')
for o in objs:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, 'frog_props.glb'), export_format='GLB', use_selection=True, export_apply=True, export_yup=True)
print('PROPS', [(o.name, sum(len(p.vertices) - 2 for p in o.data.polygons)) for o in objs])
