## Small props built with the kit: hover platform and crystal launch pad (centred on 0, top at y 0).
import pickle, math, sys
import kit
from kit import *
kit.WARP = None
def octagon(r, y, mat, up=True):
    pts = [(r * math.sin(TAU * i / 8 + TAU / 16), y, r * math.cos(TAU * i / 8 + TAU / 16)) for i in range(8)]
    for i in range(8):
        tri = [(0, y, 0), pts[i], pts[(i + 1) % 8]]
        poly(mat, tri if not up else tri[::-1], 'box')
which = sys.argv[1]
if which == 'platform':
    octagon(2.0, 0.0, 'floor', True)
    lathe('gold', [(2.08, -0.25), (2.08, 0.04), (1.98, 0.04)], 0, 0, 8, a0=TAU / 16, a1=TAU / 16 + TAU)
    lathe('stone', [(1.75, -0.9), (2.05, -0.55), (2.05, -0.25)], 0, 0, 8, a0=TAU / 16, a1=TAU / 16 + TAU)
    rock_cone(0, 0, [(0.2, -4.2), (0.9, -3.0), (1.5, -1.9), (1.8, -0.9)], segs=9, seed=5, amp=0.3)
    crystal_down(0.0, -3.6, 0.0, 1.6, 0.3, seed=3)
    # rune ring under the platform (glowing)
    for i in range(24):
        a0, a1 = TAU * i / 24, TAU * (i + 1) / 24
        r0, r1 = 2.15, 2.55
        y = -1.2
        q = [(r0 * math.sin(a0), y, r0 * math.cos(a0)), (r1 * math.sin(a0), y, r1 * math.cos(a0)), (r1 * math.sin(a1), y, r1 * math.cos(a1)), (r0 * math.sin(a1), y, r0 * math.cos(a1))]
        poly('crystal', q, 'box'); poly('crystal', q[::-1], 'box')
        if i % 3 == 0:
            m = (a0 + a1) / 2
            poly('crystal', [(2.0 * math.sin(m - 0.05), y - 0.01, 2.0 * math.cos(m - 0.05)), (2.7 * math.sin(m), y - 0.01, 2.7 * math.cos(m)), (2.0 * math.sin(m + 0.05), y - 0.01, 2.0 * math.cos(m + 0.05))], 'box')
else:
    # crystal launch pad: gold hex frame with a glowing crystal plate and three upward shards
    for i in range(6):
        a0, a1 = TAU * i / 6, TAU * (i + 1) / 6
        poly('crystal', [(0, 0.12, 0), (1.2 * math.sin(a1), 0.12, 1.2 * math.cos(a1)), (1.2 * math.sin(a0), 0.12, 1.2 * math.cos(a0))], 'box')
    lathe('gold', [(1.45, 0.0), (1.45, 0.16), (1.2, 0.16)], 0, 0, 6)
    for k in range(3):
        a = TAU * k / 3
        crystal_shard(1.55 * math.sin(a), 0.1, 1.55 * math.cos(a), 1.3, 0.22, (math.sin(a) * 0.2, math.cos(a) * 0.2), seed=20 + k)
pickle.dump({'P': kit.P, 'COL': []}, open(f'prop_{which}.pkl', 'wb'))
print(which, sum(len(v) for v in kit.P.values()))
