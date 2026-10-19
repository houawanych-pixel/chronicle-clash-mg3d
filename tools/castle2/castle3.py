"""Sky Citadel v3: the old ruin's real shape, band by band, rebuilt in clean stone.
massing.pkl (from massing.py) gives each height band's footprint polygons.
Run: python3 castle3.py -> castle.pkl (same format as castle.py) + out/route2.json"""
import math, pickle, random, json
import numpy as np
from shapely.geometry import Polygon, MultiPolygon, Point
from shapely.ops import unary_union
from shapely import affinity
import mapbox_earcut as earcut
import kit
from kit import *

kit.WARP = None
D = math.radians
rnd = random.Random(7)
BANDS = pickle.load(open('massing.pkl', 'rb'))
R3 = pickle.load(open('pieces3.pkl', 'rb'))
from shapely.geometry import box as sbox

CORE_Y, SUMMIT, CROWN_TOP = 105.0, 119.0, 139.0
EYE = (0.0, 3.0, 5.5)                      # x, z, r
CORE = (0.0, -0.5, 12.5, 8.5)              # x, z, rx, rz (old core floor x -12..12, z -8..8)
ROCK_TOP = 52.0


def as_list(g):
    if g.is_empty:
        return []
    if isinstance(g, Polygon):
        return [g]
    return [p for p in getattr(g, 'geoms', []) if isinstance(p, Polygon) and p.area > 0.5]


def ellipse(x, z, rx, rz, n=40):
    return affinity.scale(Point(x, z).buffer(1.0, n), rx, rz)


# ------------------------------------------------------------------ carve the core chamber and the eye
carved = []
for (y0, y1, mp) in BANDS:
    g = mp
    if y0 >= 104 and y1 <= SUMMIT:
        g = g.difference(ellipse(CORE[0], CORE[1], CORE[2], CORE[3]))
    if y0 >= SUMMIT:
        g = g.difference(Point(EYE[0], EYE[1]).buffer(EYE[2], 32))
    for (yf, yt, cp) in R3['carve']:
        if y0 >= yf and y1 <= yt:
            g = g.difference(cp)
    if y0 == 77:      # the hidden alcove behind the back-ring ledge
        g = g.difference(sbox(R3['alcove'][0] - 2.2, R3['alcove'][2] - 6.0, R3['alcove'][0] + 2.2, R3['alcove'][2] + 1.5))
    carved.append((y0, y1, g))
BANDS = carved


def tri_poly(poly):
    """Triangulate a shapely polygon (with holes): returns list of 2D triangles."""
    rings = [list(poly.exterior.coords)[:-1]] + [list(r.coords)[:-1] for r in poly.interiors]
    verts = np.array([p for r in rings for p in r], dtype=np.float64)
    ends = np.cumsum([len(r) for r in rings]).astype(np.uint32)
    idx = earcut.triangulate_float64(verts, ends)
    return [[tuple(verts[i]) for i in idx[k:k + 3]] for k in range(0, len(idx), 3)]


def cap(mat, poly, y, up=True, colmode=False):
    for t in tri_poly(poly):
        pts = [(x, y, z) for x, z in t]
        # earcut gives CCW in x/z; with y up, x right, z toward viewer, a top face must wind clockwise seen from above
        a = np.cross(np.subtract(pts[1], pts[0]), np.subtract(pts[2], pts[0]))
        if (a[1] > 0) != up:
            pts = pts[::-1]
        poly_(mat, pts, colmode)


def poly_(mat, pts, colmode=False):
    poly(mat, pts, 'box')
    if colmode:
        col(pts)


def ring_edges(ring, outward=True):
    c = list(ring.coords)[:-1]
    # make exterior CCW (in x,z with z flipped?) -> use signed area to orient normals outward
    area = sum(c[i][0] * c[(i + 1) % len(c)][1] - c[(i + 1) % len(c)][0] * c[i][1] for i in range(len(c))) / 2
    if (area > 0) != outward:
        c = c[::-1]
    return [(c[i], c[(i + 1) % len(c)]) for i in range(len(c))]


def wall_quad(mat, a, b, y0, y1, colmode=True, off=0.0):
    (ax, az), (bx, bz) = a, b
    q = [(ax, y0, az), (bx, y0, bz), (bx, y1, bz), (ax, y1, az)]
    poly_(mat, q, colmode)


def edge_normal(a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]
    L = math.hypot(dx, dz) or 1.0
    return (dz / L, -dx / L), L


def arch_window(a, b, y0, y1, u, w, mat='dark', depth=0.03):
    """Pointed arch opening painted as a dark inset with a gold archivolt, centred u metres along a->b."""
    (nx, nz), L = edge_normal(a, b)
    tx, tz = (b[0] - a[0]) / L, (b[1] - a[1]) / L
    H = y1 - y0
    base = y0 + H * 0.12
    ac = arch_curve(w, H * 0.5, H * 0.82, 7)
    pts2 = [(-w / 2, 0.0)] + ac[1:-1] + [(w / 2, 0.0)]
    def P3(du, v, d):
        return (a[0] + tx * (u + du) + nx * d, base + v, a[1] + tz * (u + du) + nz * d)
    for t in tri_fan_concave(pts2):
        poly(mat, [P3(pts2[i][0], pts2[i][1], depth) for i in t], 'box')
    for i in range(len(ac) - 1):
        (ua, va), (ub, vb) = ac[i], ac[i + 1]
        s = 1.18
        poly('gold', [P3(ua, va, depth + 0.02), P3(ub, vb, depth + 0.02), P3(ub * s, vb + 0.25, depth + 0.02), P3(ua * s, va + 0.25, depth + 0.02)], 'box')


def ledge(ring, y, out=0.45, h=0.45, mat='gold'):
    """Cornice ledge along a footprint ring at height y: projecting band with a sloped top."""
    for a, b in ring_edges(ring, True):
        (nx, nz), L = edge_normal(a, b)
        if L < 0.2:
            continue
        a2 = (a[0] + nx * out, a[1] + nz * out); b2 = (b[0] + nx * out, b[1] + nz * out)
        poly(mat, [(a2[0], y - h, a2[1]), (b2[0], y - h, b2[1]), (b2[0], y, b2[1]), (a2[0], y, a2[1])], 'box')
        poly('stone', [(a[0], y - h, a[1]), (b[0], y - h, b[1]), (b2[0], y - h, b2[1]), (a2[0], y - h, a2[1])], 'box')
        poly('stone', [(a2[0], y, a2[1]), (b2[0], y, b2[1]), (b[0], y + 0.12, b[1]), (a[0], y + 0.12, a[1])], 'box')


def spire_on(poly, y, crystal=True):
    c = poly.centroid
    r = max(1.0, min(4.5, math.sqrt(poly.area / math.pi)))
    h = min(r * 3.2, 139.5 - y)
    if h < 1.5:
        return y
    with local(c.x, c.y, y):
        lathe('stone', [(r * 1.05, y), (r * 0.95, y + h * 0.18), (r * 0.6, y + h * 0.55), (r * 0.22, y + h * 0.88), (0.03, y + h)], c.x, c.y, 12)
        lathe('gold', [(r * 0.97, y + h * 0.15), (r * 1.0, y + h * 0.2)], c.x, c.y, 12)
    if crystal:
        crystal_shard(c.x, y + h - 0.2, c.y, h * 0.3, max(0.3, r * 0.22), seed=int(c.x * 7 + c.y * 3))
    return y + h


WINDOW_BANDS = {62, 84, 96, 108, 119, 127}      # band bottoms that get tall arched windows
ARCADE_BANDS = {66, 70}                         # the wide ring-deck band: open arched halls
def pilaster(a, b, u, y0, y1, nx, nz, w=0.7, d=0.3):
    (_, _), L = edge_normal(a, b)
    tx, tz = (b[0] - a[0]) / L, (b[1] - a[1]) / L
    def P3(du, y, dd):
        return (a[0] + tx * (u + du) + nx * dd, y, a[1] + tz * (u + du) + nz * dd)
    poly('stone', [P3(-w / 2, y0, d), P3(w / 2, y0, d), P3(w / 2, y1, d), P3(-w / 2, y1, d)], 'box')
    poly('stone', [P3(-w / 2, y0, 0), P3(-w / 2, y0, d), P3(-w / 2, y1, d), P3(-w / 2, y1, 0)], 'box')
    poly('stone', [P3(w / 2, y0, d), P3(w / 2, y0, 0), P3(w / 2, y1, 0), P3(w / 2, y1, d)], 'box')
    poly('gold', [P3(-w / 2 - 0.1, y1 - 0.35, d + 0.08), P3(w / 2 + 0.1, y1 - 0.35, d + 0.08), P3(w / 2 + 0.1, y1, d + 0.08), P3(-w / 2 - 0.1, y1, d + 0.08)], 'box')


def facade(a, b, y0, y1, L, nx, nz):
    H = y1 - y0
    if L < 2.0 or H < 2.5:
        return
    # pilasters at both ends of every edge and every ~7 m
    n = max(1, int(L / 7.0))
    for k in range(n + 1):
        u = min(max(L * k / n, 0.4), L - 0.4)
        pilaster(a, b, u, y0, y1, nx, nz)
    if y0 in ARCADE_BANDS and L > 6.0:
        m = int(L / 5.0)
        for k in range(m):
            arch_window(a, b, y0 - (4 if y0 == 70 else 0), y1, (k + 0.5) * L / m, min(3.2, L / m * 0.62))
    elif y0 in WINDOW_BANDS and L > 4.5:
        m = max(1, int(L / 7.0))
        for k in range(m):
            arch_window(a, b, y0, y1 + (3 if H < 4 else 0), (k + 0.5) * L / m, 1.3)


def battlements(ring, y, step=1.6):
    for a, b in ring_edges(ring, True):
        (nx, nz), L = edge_normal(a, b)
        if L < 1.0:
            continue
        tx, tz = (b[0] - a[0]) / L, (b[1] - a[1]) / L
        k = 0.4
        while k < L - 0.6:
            c = (a[0] + tx * (k + 0.4) - nx * 0.25, a[1] + tz * (k + 0.4) - nz * 0.25)
            box('stone', (c[0], y + 0.45, c[1]), (0.8, 0.9, 0.5), yaw=math.atan2(tx, tz) + math.pi / 2)
            k += step


# ------------------------------------------------------------------ build the bands
stats = {'walls': 0}
for bi, (y0, y1, g) in enumerate(BANDS):
    parts = as_list(g)
    if not parts:
        continue
    above = BANDS[bi + 1][2] if bi + 1 < len(BANDS) else Polygon()
    below = BANDS[bi - 1][2] if bi > 0 else Polygon()
    rock = y1 <= ROCK_TOP
    mat = 'rock' if rock else 'stone'
    if rock:
        continue
    for pg in parts:
        # walls (outer ring outward, holes inward)
        rings = [(pg.exterior, True)] + [(r, False) for r in pg.interiors]
        for ring, outward in rings:
            for a, b in ring_edges(ring, outward):
                (nx, nz), L = edge_normal(a, b)
                if L < 0.05:
                    continue
                if rock:
                    # jagged rock: split long edges and push the middle out
                    n = max(1, int(L / 3.0))
                    pts = [(a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n) for k in range(n + 1)]
                    for k in range(n):
                        p, q = pts[k], pts[k + 1]
                        m = ((p[0] + q[0]) / 2 + nx * rnd.uniform(0.3, 1.4), (p[1] + q[1]) / 2 + nz * rnd.uniform(0.3, 1.4))
                        for (s_, t_) in ((p, m), (m, q)):
                            poly('rock', [(s_[0], y0, s_[1]), (t_[0], y0, t_[1]), (t_[0], y1, t_[1]), (s_[0], y1, s_[1])], 'box')
                        col([(p[0], y0, p[1]), (q[0], y0, q[1]), (q[0], y1, q[1]), (p[0], y1, p[1])])
                else:
                    wall_quad('stone', a, b, y0, y1)
                    H = y1 - y0
                    if outward:
                        facade(a, b, y0, y1, L, nx, nz)
                stats['walls'] += 1
        # exposed top (terrace / roof) and exposed bottom
        top = pg.difference(above) if not above.is_empty else pg
        for tp in as_list(top):
            if tp.area < 0.3:
                continue
            cap('rock' if rock else 'floor', tp, y1, up=True, colmode=True)
        bot = pg.difference(below) if not below.is_empty else pg
        for bp in as_list(bot):
            if bp.area < 0.3:
                continue
            cap('rock' if (rock or y0 <= ROCK_TOP + 4) else 'stone', bp, y0, up=False)
            if rock or y0 < 70:
                # hanging rock fins / stalactites under exposed undersides
                for k in range(max(1, int(bp.area / 30))):
                    pt = bp.representative_point() if k == 0 else Point(rnd.uniform(bp.bounds[0], bp.bounds[2]), rnd.uniform(bp.bounds[1], bp.bounds[3]))
                    if bp.contains(pt):
                        stalactite(pt.x, y0, pt.y, rnd.uniform(2.5, 7.0), rnd.uniform(0.8, 1.8), seed=int(pt.x * 31 + pt.y * 17 + y0))
        # gold cornice ledge where the band steps in above (a real terrace), a battlement on big terraces
        if not rock and y1 < 136 and top.area > 0.25 * pg.area:
            ledge(pg.exterior, y1, out=0.4, h=0.5)
            if top.area > 25 and y1 >= 60:
                battlements(pg.exterior, y1)
        # spires on small tops that end here (towers)
        if not rock and y1 >= 96 and pg.area < 80 and top.area > pg.area * 0.8:
            spire_on(pg, y1)

# ------------------------------------------------------------------ the rock mass: one lofted, jagged surface
NA = 72
def radial(g, a, cx=0.0, cz=0.0, rmax=60.0):
    r, last = 0.5, 0.0
    while r < rmax:
        if g.contains(Point(cx + r * math.sin(a), cz + r * math.cos(a))):
            last = r
        r += 0.5
    return last
rock_levels = [(y0, g) for (y0, y1, g) in BANDS if y1 <= ROCK_TOP + 4 and not g.is_empty]
levels = [0.0] + [(y0 + y1) / 2 for (y0, y1, g) in BANDS if y1 <= ROCK_TOP and not g.is_empty] + [ROCK_TOP + 0.5]
rings = []
for y in levels:
    if y <= 0.01:
        rings.append([(0.0, 0.0, 1.5)] * NA)
        continue
    band = min(BANDS, key=lambda b: abs((b[0] + b[1]) / 2 - y) if not b[2].is_empty else 1e9)
    if y >= ROCK_TOP:
        band = [b for b in BANDS if b[0] <= ROCK_TOP < b[1]][0]
    row = []
    for i in range(NA):
        a = TAU * i / NA
        r = radial(band[2], a, 0.0, 1.5)
        r = max(r, 0.6)
        if y < ROCK_TOP:
            r += rnd.uniform(-0.6, 1.2)
        row.append((r * math.sin(a), y + (rnd.uniform(-0.8, 0.8) if 1 < y < ROCK_TOP else 0.0), 1.5 + r * math.cos(a)))
    # smooth the ring a little so it reads as one mass
    sm = []
    for i in range(NA):
        p0, p1, p2 = row[i - 1], row[i], row[(i + 1) % NA]
        sm.append(((p0[0] + 2 * p1[0] + p2[0]) / 4, p1[1], (p0[2] + 2 * p1[2] + p2[2]) / 4))
    rings.append(sm)
for k in range(len(rings) - 1):
    A, B_ = rings[k], rings[k + 1]
    for i in range(NA):
        j = (i + 1) % NA
        q = [A[i], A[j], B_[j], B_[i]]
        poly('rock', q[::-1], 'box')
        col(q)
# rock fins: sharp blades sticking out of the mass
for i in range(18):
    a = TAU * i / 18 + rnd.uniform(-0.1, 0.1)
    k = rnd.randint(2, len(rings) - 3)
    p = rings[k][int(a / TAU * NA) % NA]
    nx, nz = math.sin(a), math.cos(a)
    L = rnd.uniform(2.5, 5.0); hgt = rnd.uniform(5, 10)
    tip = (p[0] + nx * L, p[1] - hgt * 0.4, p[2] + nz * L)
    s1 = (p[0] - nz * 1.2, p[1] + hgt * 0.5, p[2] + nx * 1.2); s2 = (p[0] + nz * 1.2, p[1] + hgt * 0.5, p[2] - nx * 1.2)
    s3 = (p[0], p[1] - hgt * 0.6, p[2])
    for tri in ((s1, s2, tip), (s2, s3, tip), (s3, s1, tip)):
        poly('rock', list(tri), 'box')

# the spike and crystal veins under the rock
lathe('rock', [(0.05, 0.0), (1.2, 2.5), (2.4, 5.0), (3.2, 8.0)], 0.0, 1.5, 7)
crystal_down(0.0, 3.0, 1.5, 6.0, 0.9, seed=77)
for v in range(9):
    a = TAU * v / 9 + 0.3
    for k, y in enumerate(range(10, 52, 6)):
        ys = [b for b in BANDS if b[0] <= y < b[1]]
        if not ys:
            continue
        g = ys[0][2]
        if g.is_empty:
            continue
        # walk outward along the ray to the footprint edge
        r = 1.0
        while g.contains(Point(r * math.sin(a), r * math.cos(a))) and r < 60:
            r += 0.5
        if r < 2:
            continue
        crystal_shard(r * math.sin(a), y, r * math.cos(a), 2.0 + 0.2 * k, 0.4, (math.sin(a) * 0.6, math.cos(a) * 0.6), seed=v * 50 + k)

# core chamber floor, arena rings, crystals
core_floor = ellipse(CORE[0], CORE[1], CORE[2], CORE[3])
cap('floor', core_floor, CORE_Y, True, colmode=True)
for rr in (0.35, 0.65, 0.95):
    ring_ = ellipse(CORE[0], CORE[1], CORE[2] * rr, CORE[3] * rr).exterior
    for a, b in ring_edges(ring_, True):
        (nx, nz), L = edge_normal(a, b)
        poly('gold', [(a[0], CORE_Y + 0.02, a[1]), (b[0], CORE_Y + 0.02, b[1]), (b[0] - nx * 0.3, CORE_Y + 0.02, b[1] - nz * 0.3), (a[0] - nx * 0.3, CORE_Y + 0.02, a[1] - nz * 0.3)][::-1], 'box')
for k in range(8):
    a = TAU * k / 8 + 0.2
    crystal_cluster(CORE[0] + (CORE[2] - 1.2) * math.sin(a), CORE_Y, CORE[1] + (CORE[3] - 1.2) * math.cos(a), 3.0, 4, seed=60 + k)

# ------------------------------------------------------------------ route pieces (inner tower, bridges, hub, alcove, details)
def chain_links(p0, p1, n=None):
    L = math.dist(p0, p1)
    n = n or max(2, int(L / 0.55))
    for i in range(n):
        t = (i + 0.5) / n
        c = [p0[k] + (p1[k] - p0[k]) * t for k in range(3)]
        a = (i % 2) * math.pi / 2
        with local(c[0], c[2], c[1]):
            for k in range(6):
                b0, b1 = TAU * k / 6, TAU * (k + 1) / 6
                r = 0.22
                q = lambda b, rr: (c[0] + rr * math.cos(b) * math.cos(a), c[1] + rr * math.sin(b) * 1.4, c[2] + rr * math.cos(b) * math.sin(a))
                poly('gold', [q(b0, r), q(b1, r), q(b1, r * 0.6), q(b0, r * 0.6)], 'box')


def inlay(a, b, side_off, w):
    # glowing crystal strip along a walkway edge
    d = np.subtract(b, a); L = math.hypot(d[0], d[2]); u = np.array([d[0] / L, 0, d[2] / L]); s_ = np.array([-u[2], 0, u[0]])
    for sg in (-1, 1):
        o = s_ * sg * (w / 2 - side_off)
        p = [np.add(a, o) + [0, 0.03, 0], np.add(b, o) + [0, 0.03, 0]]
        poly('crystal', [tuple(p[0] - s_ * 0.08), tuple(p[1] - s_ * 0.08), tuple(p[1] + s_ * 0.08), tuple(p[0] + s_ * 0.08)][::-1 if sg > 0 else 1], 'box')


def bridge(a, b, w, arch=False):
    a = np.array(a, float); b = np.array(b, float)
    dy = b[1] - a[1]
    if abs(dy) > 0.25:
        straight_stair(tuple(a), tuple(b), w)
    else:
        d = b - a; L = math.hypot(d[0], d[2]); u = np.array([d[0] / L, 0, d[2] / L]); s_ = np.array([-u[2], 0, u[0]])
        hw = w / 2
        top = [a - s_ * hw, a + s_ * hw, b + s_ * hw, b - s_ * hw]
        poly('floor', [tuple(p) for p in top][::-1], 'box'); col([tuple(p) for p in top])
        th = 0.9
        for sg in (-1, 1):
            e = s_ * (hw + 0.2) * sg
            rail = [a + e, b + e, b + e + [0, 1.05, 0], a + e + [0, 1.05, 0]]
            poly('stone', [tuple(p) for p in rail][::-1 if sg > 0 else 1], 'box'); col([tuple(p) for p in rail])
            poly('gold', [tuple(a + e * 0.95 + [0, 1.05, 0]), tuple(b + e * 0.95 + [0, 1.05, 0]), tuple(b + e * 1.08 + [0, 1.05, 0]), tuple(a + e * 1.08 + [0, 1.05, 0])], 'box')
            side = [a + s_ * hw * sg - [0, th, 0], b + s_ * hw * sg - [0, th, 0], b + s_ * hw * sg, a + s_ * hw * sg]
            poly('stone', [tuple(p) for p in side][::-1 if sg < 0 else 1], 'box')
        poly('stone', [tuple(p - [0, th, 0]) for p in top], 'box')
        if arch and L > 6:
            # arch underside: a shallow curved web under the deck
            n = 10
            for k in range(n):
                t0, t1 = k / n, (k + 1) / n
                y0_ = -th - 2.6 * math.sin(math.pi * t0) ** 0.6 * 0 - 0.4 - 2.2 * (1 - math.sin(math.pi * t0))
                y1_ = -th - 0.4 - 2.2 * (1 - math.sin(math.pi * t1))
                for sg in (-1, 1):
                    o = s_ * hw * 0.8 * sg
                    q = [a + d * t0 + o + [0, -th, 0], a + d * t1 + o + [0, -th, 0], a + d * t1 + o + [0, y1_, 0], a + d * t0 + o + [0, y0_, 0]]
                    poly('stone', [tuple(p) for p in q][::-1 if sg > 0 else 1], 'box')
            for t in (0.3, 0.7):
                p = a + d * t + [0, -th, 0]
                chain_links(tuple(p), tuple(p + [0, -5.0, 0]))
        inlay(tuple(a), tuple(b), 0.35, w)


for pc in R3['pieces']:
    t = pc['t']
    if t == 'spiral':
        cx, cz = pc['c']
        deck(cx, cz, pc['r0'], pc['r1'], pc['y0'], D(pc['a0']), D(pc['a1']), y1=pc['y1'], th=0.6, mat='floor', base=None)
        parapet(cx, cz, pc['r0'] + 0.25, (pc['y0'], pc['y1']), D(pc['a0']), D(pc['a1']), h=1.0, pin_every=0, lamp_every=6)
    elif t == 'column':
        cx, cz = pc['c']
        lathe('stone', [(pc['r'] * 1.25, pc['y0']), (pc['r'], pc['y0'] + 1.0), (pc['r'], pc['y1'] - 1.0), (pc['r'] * 1.25, pc['y1'])], cx, cz, 20, colmode=True)
        y = pc['y0'] + 4.0
        while y < pc['y1'] - 2:
            lathe('gold', [(pc['r'] * 1.04, y), (pc['r'] * 1.04, y + 0.3)], cx, cz, 20)
            crystal_shard(cx + pc['r'] * 1.02, y + 1.0, cz, 1.2, 0.25, seed=int(y))
            y += 6.0
    elif t == 'walk':
        bridge(pc['a'], pc['b'], pc['w'], pc.get('arch', False))
    elif t == 'broken':
        # jagged broken ends of the arch bridge, with a chain hanging across the gap
        for p, sg in ((pc['a'], 1), (pc['b'], -1)):
            for k in range(3):
                stalactite(p[0] + rnd.uniform(-1.2, 1.2), p[1] - 0.9, p[2] + rnd.uniform(-1.2, 1.2), rnd.uniform(1.5, 3.0), 0.6, seed=int(p[0] * 7 + k))
        chain_links((pc['a'][0], pc['a'][1] - 0.6, pc['a'][2]), (pc['b'][0], pc['b'][1] - 2.5, pc['b'][2]))
    elif t == 'slab':
        c = pc['c']; sx, sz = pc['size']
        hub = Polygon([(c[0] - sx / 2, c[2] - sz / 2), (c[0] + sx / 2, c[2] - sz / 2), (c[0] + sx / 2, c[2] + sz / 2), (c[0] - sx / 2, c[2] + sz / 2)])
        cap('floor', hub, c[1], True, colmode=True)
        cap('stone', hub, c[1] - 0.8, False)
        for a_, b_ in ring_edges(hub.exterior, True):
            wall_quad('stone', a_, b_, c[1] - 0.8, c[1], colmode=False)
        ledge(hub.exterior, c[1], out=0.3, h=0.4)
        for k in range(4):
            stalactite(c[0] + rnd.uniform(-sx / 3, sx / 3), c[1] - 0.8, c[2] + rnd.uniform(-sz / 3, sz / 3), rnd.uniform(3, 6), 1.0, seed=300 + k)

# the alcove: a lore crystal and a treasure chest
ax, ay, az = R3['alcove']
box('gold', (ax, ay + 0.45, az - 4.0), (1.6, 0.9, 1.0), colmode=True)
box('stone', (ax, ay + 0.95, az - 4.0), (1.7, 0.12, 1.1))
crystal_cluster(ax + 1.4, ay, az - 4.6, 2.2, 3, seed=444)
# emblem banners on big walls of the wing band (gold rod, blue cloth, gold emblem with a crystal)
def banner(x, y, z, nx, nz, h=7.0, w=2.2):
    tx, tz = -nz, nx
    o = 0.35
    P_ = lambda u, v, d=o: (x + tx * u + nx * d, y + v, z + tz * u + nz * d)
    poly('panel', [P_(-w / 2, -h), P_(w / 2, -h), P_(w / 2, 0), P_(-w / 2, 0)], 'box')
    poly('panel', [P_(-w / 2, -h), P_(0, -h - 0.9), P_(w / 2, -h)], 'box')
    poly('gold', [P_(-w / 2 - 0.3, -0.15, o + 0.05), P_(w / 2 + 0.3, -0.15, o + 0.05), P_(w / 2 + 0.3, 0.15, o + 0.05), P_(-w / 2 - 0.3, 0.15, o + 0.05)], 'box')
    poly('gold', [P_(0, -h * 0.25, o + 0.04), P_(0.6, -h * 0.4, o + 0.04), P_(0, -h * 0.55, o + 0.04), P_(-0.6, -h * 0.4, o + 0.04)], 'box')
    crystal_shard(x + nx * (o + 0.15), y - h * 0.45, z + nz * (o + 0.15), 0.7, 0.15, seed=int(x * 3 + z))
nb = 0
for (y0, y1, g) in BANDS:
    if y0 not in (62, 84, 96) or g.is_empty:
        continue
    for pg in as_list(g):
        for a_, b_ in ring_edges(pg.exterior, True):
            (nx, nz), L = edge_normal(a_, b_)
            if L > 9.0 and nb < 14 and (nb + int(a_[0])) % 3 == 0:
                m = ((a_[0] + b_[0]) / 2, (a_[1] + b_[1]) / 2)
                banner(m[0], y1 + 3.0 if y0 == 62 else y1, m[1], nx, nz)
                nb += 1
# floating rock chunks near tier A (decoration)
for i, (x, y, z) in enumerate([(24, 46, 76), (40, 49, 68), (30, 42, 60), (48, 54, 40), (14, 44, 66), (52, 47, 58)]):
    with local(x, z, y):
        rows = rock_cone(x, z, [(0.2, y - 6.0), (1.8, y - 3.5), (3.2, y - 1.2), (3.4, y)], segs=9, seed=900 + i, amp=0.6)
    cap('rock', Point(x, z).buffer(3.3, 6), y, True)
print('banners', nb)

data = {'P': kit.P, 'COL': kit.COL}
pickle.dump(data, open('castle.pkl', 'wb'))
n = sum(len(v) for v in kit.P.values())
print('polys', n, {k: len(v) for k, v in kit.P.items()}, 'col', len(kit.COL), stats)
