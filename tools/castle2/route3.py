"""Sky Citadel v3 routes: three ways from the dock to the summit.
  A  outer ledges: the proven exterior ring route (route.json v1): broken bridge, ring ledges with jumps, ladders.
  B  inner hall: through the front door, up a spiral stair inside the central tower (56 -> 74 -> 104),
     out over a broken-arch bridge to the Ring 2 hub, and out the front at the Core Floor hub.
  C  sky path: floating hover platforms (tiers A, B, C) and crystal launch pads.
All reconnect at the Ring 2 hub (H2, y 74) and the Core Floor hub (H3, y 102), then the sky stair to the crown.
Writes carve.pkl, pieces3.pkl (baked into the castle) and out/route3.json (for the game)."""
import json, math, pickle
import numpy as np
from shapely.geometry import Point, Polygon, LineString, box as sbox
from shapely import affinity

V1 = json.load(open('/home/claude/chronicle-clash-mg3d/assets/ruin/route.json'))
BANDS = pickle.load(open('massing.pkl', 'rb'))
D = math.radians
JUMP_GAP, JUMP_RISE = 2.4, 1.2           # what the hero clears with room to spare (flat ~4.9 m, +1 m ~4 m)
PLAT_R = 2.0                             # hover platform radius (4 m across)
issues = []


def solid(x, y, z, margin=0.0):
    for (y0, y1, g) in BANDS:
        if y0 <= y < y1 and not g.is_empty:
            return g.buffer(margin).contains(Point(x, z))
    return False


def clear_box(x, y, z, r, h=3.0):
    """No massing within r of (x, z) from y-1 to y+h."""
    for (y0, y1, g) in BANDS:
        if y1 > y - 1 and y0 < y + h and not g.is_empty:
            if g.distance(Point(x, z)) < r:
                return False
    return True


def ray_edge(cx, cz, a, y, rmax=70):
    """Distance from (cx, cz) along angle a (0 = +z) to where the massing at height y ends."""
    last = 0.0
    r = 0.5
    while r < rmax:
        if solid(cx + r * math.sin(a), y + 0.5, cz + r * math.cos(a)):
            last = r
        r += 0.25
    return last


# ------------------------------------------------------------------ hubs and v1 anchors
H2 = (42.697, 74.0, -26.091)              # ladder 1 top in v1 (Ring 2 hub)
LAD2 = V1['ladders'][2]
H3 = (-8.5, 102.152, 42.0)               # Core Floor hub: a landing by the summit ladder foot
SUMMIT = tuple(LAD2['top'])              # (-3.41, 119.4, 41.2): helix start
DOCK = V1['dock']                          # (0, 52, 92.86)
FIRST_LANDING = (0.0, 56.0, 49.864)

# ------------------------------------------------------------------ path B: carve + spiral tower
SH = (0.0, 8.0)                           # central tower shaft
SH_R, COL_R, ST_R0, ST_R1 = 8.3, 3.2, 3.5, 7.5
carve = []                                # (y_from, y_to, polygon)
carve.append((56, 104, Point(*SH).buffer(SH_R, 48)))


def corridor(a_deg, length, width, y_from, y_to, start=0.0):
    a = D(a_deg)
    p0 = (SH[0] + start * math.sin(a), SH[1] + start * math.cos(a))
    p1 = (SH[0] + length * math.sin(a), SH[1] + length * math.cos(a))
    poly = LineString([p0, p1]).buffer(width / 2, cap_style=2)
    carve.append((y_from, y_to, poly))
    return p0, p1


# exits: 56 to the front (0 deg), 74 toward H2, 104 toward the front-left (H3)
A74 = math.degrees(math.atan2(H2[0] - SH[0], H2[2] - SH[1])) % 360
A104 = math.degrees(math.atan2(H3[0] - SH[0], H3[2] - SH[1])) % 360
corridor(0.0, 60.0, 4.6, 56, 62)
corridor(A74, 70.0, 4.6, 74, 80)
corridor(A104, 60.0, 4.6, 104, 112, start=4.0)
e56 = ray_edge(SH[0], SH[1], 0.0, 56.0)
e74 = ray_edge(SH[0], SH[1], D(A74), 74.0)
e104 = ray_edge(SH[0], SH[1], D(A104), 104.0)
print('corridor exits (m from the tower):', round(e56, 1), round(e74, 1), round(e104, 1), 'angles', round(A74, 1), round(A104, 1))

# spiral: 56 at 8 deg -> 74 at A74 (+1 turn) -> landing -> 104 at A104 (+n turns)
a_start = 8.0
a74 = A74 + 360.0
while a74 - a_start < 360:
    a74 += 360
a74_end = a74 + 14.0
a104 = A104 + 360.0
while a104 - a74_end < 420:
    a104 += 360
mid_r = (ST_R0 + ST_R1) / 2
# headroom over the last turn of the stair below 104 (clear of the Core chamber, which is behind the tower)
sector = [(SH[0] + ST_R0 * 0.9 * math.sin(D(a)), SH[1] + ST_R0 * 0.9 * math.cos(D(a))) for a in np.arange(A104 - 95, A104 + 16, 5)]
sector += [(SH[0] + (ST_R1 + 0.6) * math.sin(D(a)), SH[1] + (ST_R1 + 0.6) * math.cos(D(a))) for a in np.arange(A104 + 15, A104 - 96, -5)]
carve.append((104, 108, Polygon(sector)))


def slope(dy, da):
    return math.degrees(math.atan2(dy, D(da) * mid_r))


print('spiral: 56->74 over %.0f deg (%.0f deg slope), 74->104 over %.0f deg (%.0f deg slope)' % (a74 - a_start, slope(18, a74 - a_start - 8), a104 - a74_end, slope(30, a104 - a74_end - 8)))
pieces = []                               # baked into the castle by castle3.py
pieces.append({'t': 'spiral', 'c': SH, 'r0': ST_R0, 'r1': ST_R1, 'y0': 56.0, 'y1': 74.0, 'a0': a_start, 'a1': a74 - 7})
pieces.append({'t': 'spiral', 'c': SH, 'r0': ST_R0, 'r1': ST_R1, 'y0': 74.0, 'y1': 74.0, 'a0': a74 - 7, 'a1': a74_end})
pieces.append({'t': 'spiral', 'c': SH, 'r0': ST_R0, 'r1': ST_R1, 'y0': 74.0, 'y1': 104.0, 'a0': a74_end, 'a1': a104 - 7})
pieces.append({'t': 'spiral', 'c': SH, 'r0': ST_R0, 'r1': ST_R1, 'y0': 104.0, 'y1': 104.0, 'a0': a104 - 7, 'a1': a104 + 10})
pieces.append({'t': 'column', 'c': SH, 'r': COL_R, 'y0': 56.0, 'y1': 104.5})


def pol(a, r, y, c=SH):
    return (c[0] + r * math.sin(D(a)), y, c[1] + r * math.cos(D(a)))


# walkway from the first landing (after the broken bridge) to the front door, at 56
door56 = (0.0, 56.0, SH[1] + e56)
pieces.append({'t': 'walk', 'a': (0.0, 56.0, FIRST_LANDING[2] - 2.0), 'b': (0.0, 56.0, door56[2] - 1.0), 'w': 4.0})
# broken-arch bridge from the 74 door to H2, with a jump gap in the middle
u74 = (math.sin(D(A74)), 0, math.cos(D(A74)))
p_out = (SH[0] + u74[0] * (e74 - 1.0), 74.0, SH[1] + u74[2] * (e74 - 1.0))
L74 = math.dist((p_out[0], p_out[2]), (H2[0], H2[2])) - 1.8
gap_mid = L74 * 0.5
g0, g1 = gap_mid - 1.1, gap_mid + 1.1
pt = lambda d: (p_out[0] + u74[0] * d, 74.0, p_out[2] + u74[2] * d)
pieces.append({'t': 'walk', 'a': pt(0.0), 'b': pt(g0), 'w': 3.6, 'arch': True})
pieces.append({'t': 'walk', 'a': pt(g1), 'b': pt(L74 + 0.6), 'w': 3.6, 'arch': True})
pieces.append({'t': 'broken', 'a': pt(g0), 'b': pt(g1)})
# bridge from the 104 door down to H3
u104 = (math.sin(D(A104)), 0, math.cos(D(A104)))
p104 = (SH[0] + u104[0] * (e104 - 1.0), 104.0, SH[1] + u104[2] * (e104 - 1.0))
pieces.append({'t': 'walk', 'a': p104, 'b': (H3[0] - u104[0] * 2.5, H3[1], H3[2] - u104[2] * 2.5), 'w': 3.6, 'arch': True})
pieces.append({'t': 'slab', 'c': H3, 'size': (7.0, 6.0)})

# ------------------------------------------------------------------ path C: hover platforms and crystal pads
plats = []   # {'pos', 'tier', 'pad': None | {'to', 'unlock'}}


def chain(p0, p1, n, tier):
    """n platforms from p0 to p1 (both platform centres), evenly spaced and rising."""
    out = []
    for i in range(n):
        t = i / (n - 1) if n > 1 else 0
        out.append({'pos': [p0[k] + (p1[k] - p0[k]) * t for k in range(3)], 'tier': tier})
    return out


def chain_auto(p0, p1, tier, start=None, max_gap=2.1, max_rise=1.0):
    """Fewest platforms from p0 to p1 (centres) keeping every gap and rise jumpable."""
    n = 2
    while True:
        ch = chain(p0, p1, n, tier)
        pts = ([start] if start else []) + [c['pos'] for c in ch]
        ok = True
        for i in range(len(pts) - 1):
            a, b = pts[i], pts[i + 1]
            ra = 1.0 if (start and i == 0) else PLAT_R
            gap = math.dist((a[0], a[2]), (b[0], b[2])) - ra - PLAT_R
            if gap > max_gap or b[1] - a[1] > max_rise:
                ok = False
        if ok or n > 14:
            return ch
        n += 1


def check_chain(ch, start=None, end=None, label=''):
    pts = ([start] if start else []) + [c['pos'] for c in ch] + ([end] if end else [])
    rep = []
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        ra = PLAT_R if (start is None or i > 0) else 1.0
        rb = PLAT_R if (end is None or i + 1 < len(pts) - 1) else 1.0
        gap = math.dist((a[0], a[2]), (b[0], b[2])) - ra - rb
        rise = b[1] - a[1]
        rep.append((round(gap, 2), round(rise, 2)))
        if gap > JUMP_GAP or rise > JUMP_RISE:
            issues.append((label, i, gap, rise))
    for c in ch:
        x, y, z = c['pos']
        if not clear_box(x, y, z, PLAT_R + 1.2, 3.5):
            issues.append((label, 'hits the castle', [round(v, 1) for v in c['pos']]))
    return rep


# Tier A: dock (right side) up to Ring 1 height, around the lower front-right body
tA = chain_auto((16.4, 52.9, 87.6), (34.0, 58.4, 55.0), 'A', start=(13.0, 52.0, 89.0), max_gap=2.3, max_rise=1.13)
repA = check_chain(tA, start=(13.0, 52.0, 89.0), label='tier A')
tA[-1]['pad'] = {'to': [H2[0], H2[1], H2[2]], 'unlock': 'ring1'}
# Tier B: Ring 2 hub -> right wing -> pad -> front -> pad -> Core Floor hub
tB1 = chain_auto((46.5, 74.9, -23.0), (54.0, 77.4, -8.0), 'B', start=(H2[0], H2[1], H2[2]), max_gap=2.2, max_rise=1.0)
repB1 = check_chain(tB1, start=(H2[0], H2[1], H2[2]), label='tier B right')
tB2 = chain_auto((-44.0, 91.0, 22.0), (-32.0, 92.8, 36.0), 'B', max_gap=2.3, max_rise=1.1)
repB2 = check_chain(tB2, label='tier B left')
tB1[-1]['pad'] = {'to': list(tB2[0]['pos']), 'unlock': 'ring2'}
tB2[-1]['pad'] = {'to': [H3[0], H3[1], H3[2]], 'unlock': 'ring2'}
# Tier C: Core Floor hub -> spire-top platforms out front -> pad to the summit
tC = chain_auto((-9.5, 103.1, 48.2), (4.0, 105.8, 57.0), 'C', start=(H3[0] - 1.0, H3[1], H3[2] + 1.6), max_gap=2.2, max_rise=1.0)
repC = check_chain(tC, start=(H3[0] - 1.0, H3[1], H3[2] + 1.6), label='tier C')
tC[-1]['pad'] = {'to': [SUMMIT[0], SUMMIT[1], SUMMIT[2]], 'unlock': 'core'}
plats = tA + tB1 + tB2 + tC
print('tier A gaps/rises', repA)
print('tier B right', repB1, 'tier B left', repB2)
print('tier C', repC)

# ------------------------------------------------------------------ hidden alcove (off the back ring ledges)
ALC = (8.0, 77.0, -42.0)
# ------------------------------------------------------------------ bot routes
v1bot = V1['bot']
def idx(act, n):
    c = 0
    for i, b in enumerate(v1bot):
        if b['act'] == act:
            if c == n:
                return i
            c += 1
l0, l1, l2, dr = idx('ladder', 0), idx('ladder', 1), idx('ladder', 2), idx('drop', 0)
A1 = v1bot[:l0 + 1]
A2 = v1bot[l0 + 1:l2] + [{'act': 'walk', 'p': [H3[0] + 1.5, H3[1], H3[2] - 1.0]}]
A3 = [{'act': 'walk', 'p': list(LAD2['bottom'])[:1] + [LAD2['bottom'][1]] + [LAD2['bottom'][2] + 0.2]}, v1bot[l2]]
S4 = v1bot[l2 + 1:]
def W(p):
    return {'act': 'walk', 'p': [round(v, 3) for v in p]}
B1 = v1bot[:4] + [W((0, 56, FIRST_LANDING[2] - 1)), W((0, 56, door56[2] - 2)), W((0, 56, SH[1] + ST_R1 + 0.6)), W(pol(a_start + 2, mid_r, 56.0))]
B1 += [W(pol(a, mid_r, 56.0 + 18.0 * (a - a_start) / (a74 - 7 - a_start))) for a in np.arange(a_start + 20, a74 - 7, 20)]
B1 += [W(pol(a74 - 5, mid_r, 74.0)), W(pol(A74 + 360, ST_R1 + 1.5, 74.0)), W(pt(1.0))]
B1 += [{'act': 'jump', 'p': [round(v, 3) for v in pt(g0 - 0.4)], 'to': [round(v, 3) for v in pt(g1 + 1.0)], 'from': [round(v, 3) for v in pt(g0 - 2.6)]}, W(pt(L74 - 0.5)), W(H2)]
B2 = [W(pt(L74 - 0.5)), {'act': 'jump', 'p': [round(v, 3) for v in pt(g1 + 0.4)], 'to': [round(v, 3) for v in pt(g0 - 1.0)], 'from': [round(v, 3) for v in pt(g1 + 2.6)]}, W(pt(1.0)), W(pol(A74 + 360, ST_R1 + 1.5, 74.0)), W(pol(a74_end + 2, mid_r, 74.0))]
B2 += [W(pol(a, mid_r, 74.0 + 30.0 * (a - a74_end) / (a104 - 7 - a74_end))) for a in np.arange(a74_end + 20, a104 - 7, 20)]
B2 += [W(pol(a104 - 5, mid_r, 104.0)), W(pol(A104 + 720, ST_R1 + 1.5, 104.0)), W(p104), W((H3[0], H3[1], H3[2]))]
def jumps(seq, start):
    out = []
    prev = start
    for c in seq:
        p = c['pos']
        d = [p[0] - prev[0], 0, p[2] - prev[2]]
        n = math.hypot(d[0], d[2]); d = [d[0] / n, 0, d[2] / n]
        take = [prev[0] + d[0] * (PLAT_R - 0.5 if prev is not start else 1.05), prev[1], prev[2] + d[2] * (PLAT_R - 0.5 if prev is not start else 1.05)]
        frm = [prev[0] - d[0] * 1.2, prev[1], prev[2] - d[2] * 1.2]
        out.append({'act': 'jump', 'p': [round(v, 3) for v in take], 'to': [round(v, 3) for v in p], 'from': [round(v, 3) for v in frm], 'plat': True})
        prev = p
    return out
C1 = [W((0.0, 52.0, 88.0)), W((12.0, 52.0, 89.0))] + jumps(tA, (12.0, 52.0, 89.0)) + [{'act': 'pad', 'p': tA[-1]['pos']}]
C2 = [W(H2)] + jumps(tB1, list(H2)) + [{'act': 'pad', 'p': tB1[-1]['pos']}] + jumps(tB2[1:], tB2[0]['pos']) + [{'act': 'pad', 'p': tB2[-1]['pos']}]
C3 = [W((H3[0] - 1.0, H3[1], H3[2] + 1.6))] + jumps(tC, (H3[0] - 1.0, H3[1], H3[2] + 1.6)) + [{'act': 'pad', 'p': tC[-1]['pos']}]

# ------------------------------------------------------------------ sections, knights, gates
spawns = [V1['spawns'][0], [H2[0], H2[1] + 0.3, H2[2]], [H3[0], H3[1] + 0.3, H3[2]], V1['spawns'][5], V1['spawns'][6]]
goals = ['Take out the dock guards', 'Reach the Ring 2 hub: ledges, the inner tower, or the sky path',
         'Reach the Core Floor hub', 'Climb to the crown. Drop through the eye', 'Defeat the Dark Knight']
kn = []
for k in V1['knights']:
    s = k['sec']
    if s == 0:
        kn.append(k)
    elif s == 4:
        kn.append({'sec': 3, 'pos': k['pos']})
    else:
        kn.append({'sec': 9, 'pos': k['pos'], 'free': True})      # on a path: appears when you get near, not required
kn += [{'sec': 1, 'pos': [H2[0] - 1.0, H2[1] + 0.2, H2[2] + 1.0]}, {'sec': 2, 'pos': [H3[0] - 1.5, H3[1] + 0.2, H3[2] + 1.0]}]
kn += [{'sec': 9, 'pos': list(pol(150, mid_r, 56.0 + 18.0 * (150 - a_start) / (a74 - 7 - a_start))), 'free': True}]
barriers = [V1['barriers'][0], None, None, V1['barriers'][4]]
pieces_v1 = [p for p in V1['pieces']]
route = dict(V1)
route.update({'version': 3, 'spawns': spawns, 'goals': goals, 'knights': kn, 'barriers': barriers,
              'bot': A1 + A2 + A3 + S4, 'paths': {'A1': A1, 'A2': A2, 'A3': A3, 'S4': S4, 'B1': B1, 'B2': B2, 'C1': C1, 'C2': C2, 'C3': C3},
              'platforms': plats, 'hubs': {'H2': list(H2), 'H3': list(H3), 'summit': list(SUMMIT)}, 'alcove': list(ALC)})
json.dump(route, open('out/route3.json', 'w'), indent=1)
pickle.dump({'carve': carve, 'pieces': pieces, 'H3': H3, 'alcove': ALC}, open('pieces3.pkl', 'wb'))
print('issues', len(issues)); [print(' ', i) for i in issues]
print('paths', {k: len(v) for k, v in route['paths'].items()}, 'platforms', len(plats))
