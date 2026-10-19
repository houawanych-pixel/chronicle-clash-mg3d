## Floating fragment platforms (like the broken pieces hanging off the ruin in the guide's side view).
## All have a walkable top 4.0 (x, across) by 3.8 (z, along the jump) at y 0, centred on 0.
import pickle, math, sys, random
import kit
from kit import *
kit.WARP = None
W, Dp = 4.0, 3.8
rnd = random.Random(int(sys.argv[1]) * 7 + 3)

def slab_top(th=0.6):
    hx, hz = W / 2, Dp / 2
    box('floor', (0, -th / 2, 0), (W, th, Dp), top_mat='floor')
    # gold edge strip + cornice lip
    for sx in (-1, 1):
        box('gold', (sx * (hx + 0.05), -0.12, 0), (0.12, 0.22, Dp + 0.2))
    for sz in (-1, 1):
        box('gold', (0, -0.12, sz * (hz + 0.05)), (W + 0.2, 0.22, 0.12))
    box('stone', (0, -th - 0.25, 0), (W - 0.3, 0.5, Dp - 0.3))

def pier(x, z, top, length, w=0.8):
    # hanging square pier: shaft, gold band, pointed tip
    box('stone', (x, top - length / 2, z), (w, length, w))
    box('gold', (x, top - length * 0.35, z), (w + 0.12, 0.2, w + 0.12))
    y = top - length
    with local(x, z, y):
        for i in range(4):
            a = [(x - w / 2, z - w / 2), (x + w / 2, z - w / 2), (x + w / 2, z + w / 2), (x - w / 2, z + w / 2)]
            (ax, az), (bx, bz) = a[i], a[(i + 1) % 4]
            poly('stone', [(bx, y, bz), (ax, y, az), (x, y - w * 1.6, z)], 'box')

def arch_web(z0, z1, ytop, depth, thick=0.7, x=0.0):
    # pointed arch under the deck between two piers
    n = 10
    for i in range(n):
        t0, t1 = i / n, (i + 1) / n
        def yb(t):
            return ytop - depth * (1 - math.sin(math.pi * t) ** 0.7)
        za, zb = z0 + (z1 - z0) * t0, z0 + (z1 - z0) * t1
        for sx in (-1, 1):
            xx = x + sx * thick / 2
            q = [(xx, ytop, za), (xx, ytop, zb), (xx, yb(t1), zb), (xx, yb(t0), za)]
            poly('stone', q if sx > 0 else q[::-1], 'box')
        poly('stone', [(x - thick / 2, yb(t0), za), (x + thick / 2, yb(t0), za), (x + thick / 2, yb(t1), zb), (x - thick / 2, yb(t1), zb)], 'box')
        poly('gold', [(x - thick / 2 - 0.02, yb(t0) - 0.18, za), (x + thick / 2 + 0.02, yb(t0) - 0.18, za), (x + thick / 2 + 0.02, yb(t1) - 0.18, zb), (x - thick / 2 - 0.02, yb(t1) - 0.18, zb)][::-1], 'box')

def window(face_z, x, y, w=0.9, h=1.4):
    sg = 1 if face_z > 0 else -1
    ac = arch_curve(w, h * 0.55, h, 6)
    pts = [(x - w / 2, y)] + [(x + u, y + v) for (u, v) in ac[1:-1]] + [(x + w / 2, y)]
    for t in tri_fan_concave([(p[0], p[1]) for p in pts]):
        q = [(pts[i][0], pts[i][1], face_z + 0.02 * sg) for i in t]
        poly('dark', q if sg > 0 else q[::-1], 'box')

def broken_edge(z, y):
    # jagged broken stones along one end
    for k in range(5):
        x = -W / 2 + 0.4 + k * (W - 0.8) / 4
        h = rnd.uniform(0.4, 1.1)
        box('stone', (x, y - h / 2, z), (0.7, h, 0.5), yaw=rnd.uniform(-0.3, 0.3))

v = int(sys.argv[1])
if v == 0:      # broken arch span: deck on an arch between two hanging piers, one end broken
    slab_top()
    arch_web(-Dp / 2 + 0.4, Dp / 2 - 0.4, -1.1, 2.4)
    pier(0, -Dp / 2 + 0.4, -0.8, 4.2)
    pier(0, Dp / 2 - 0.4, -0.8, 3.0)
    broken_edge(Dp / 2 - 0.1, -0.9)
elif v == 1:    # ruined tower top: a square block with arched windows and a hanging spike
    slab_top(0.4)
    box('stone', (0, -1.8, 0), (W - 0.4, 2.8, Dp - 0.4))
    box('gold', (0, -0.5, 0), (W - 0.1, 0.18, Dp - 0.1))
    for fz in (Dp / 2 - 0.2, -(Dp / 2 - 0.2)):
        window(fz, -0.8, -2.8); window(fz, 0.8, -2.8)
    box('stone', (0, -3.6, 0), (W - 1.2, 1.0, Dp - 1.2))
    pier(0, 0, -4.1, 3.4, w=1.6)
    crystal_down(0, -7.0, 0, 1.4, 0.25, seed=11)
elif v == 2:    # bracket: deck on a big stepped corbel with a hanging column
    slab_top()
    for k, (d, h) in enumerate([(3.4, 0.9), (2.6, 0.9), (1.8, 0.9), (1.0, 1.2)]):
        y = -0.6 - 0.9 * k - h / 2
        box('stone', (0, y, -Dp / 2 + d / 2), (W - 0.6 - 0.3 * k, h, d))
        box('gold', (0, y + h / 2 - 0.05, -Dp / 2 + d + 0.02), (W - 0.6 - 0.3 * k, 0.1, 0.06))
    pier(1.2, Dp / 2 - 0.6, -0.8, 2.6, w=0.6)
    pier(-1.2, Dp / 2 - 0.6, -0.8, 1.8, w=0.6)
    crystal_down(0.0, -4.4, -Dp / 2 + 0.5, 1.2, 0.22, seed=12)
else:           # fallen keep fragment: two offset blocks, a little stair stub and two hanging spikes
    slab_top()
    box('stone', (0.3, -1.6, 0.2), (W - 0.6, 2.0, Dp - 0.8))
    box('stone', (-0.4, -3.2, -0.3), (W - 1.4, 1.4, Dp - 1.6))
    box('gold', (0.3, -0.62, 0.2), (W - 0.5, 0.14, Dp - 0.7))
    window(Dp / 2 - 0.2 + 0.2, 0.3, -2.4, 0.8, 1.1)
    pier(-1.0, -0.8, -3.8, 2.4, w=0.7)
    pier(0.9, 0.6, -2.6, 3.0, w=0.7)
    broken_edge(-Dp / 2 + 0.1, -0.9)
# glowing rune ring under every fragment
for i in range(24):
    a0, a1 = TAU * i / 24, TAU * (i + 1) / 24
    r0, r1, y = 2.5, 2.85, -1.6
    q = [(r0 * math.sin(a0), y, r0 * math.cos(a0)), (r1 * math.sin(a0), y, r1 * math.cos(a0)), (r1 * math.sin(a1), y, r1 * math.cos(a1)), (r0 * math.sin(a1), y, r0 * math.cos(a1))]
    poly('crystal', q, 'box'); poly('crystal', q[::-1], 'box')
pickle.dump({'P': kit.P, 'COL': []}, open(f'prop_frag{v}.pkl', 'wb'))
print('fragment', v, sum(len(x) for x in kit.P.values()))
