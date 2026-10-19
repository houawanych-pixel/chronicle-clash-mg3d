"""Chronicle Clash Sky Citadel v2 - geometry kit (pure python).

Game coordinates: x right, y up, z toward the front. Metres. Origin at the spike tip.
Every piece adds polygons to a material bucket. UV mode per polygon:
  ('cyl', cx, cz)  walls wrapped round a vertical axis (u = arc length, v = y)
  'box'            planar from the dominant axis
Collision pieces go to COL (walkable floors, walls, rails) as closed boxes / ramps.
"""
import math, random
import numpy as np

P = {}          # mat -> list of (pts, uvmode)
COL = []        # list of (pts list per face) triangles for collision: list of polygons
ROUTE = []      # route notes for the game
TAU = math.tau


# ---- plan warp: the castle is designed round, then warped to the guides' rounded-oval footprint.
WARP = None          # (cx, cz, k, n): superellipse, x radius 1, z radius k, exponent n
LOCAL = []           # round objects keep their shape: only their centre is warped
FINAL = [False]      # points already in final coordinates


def _interp(y, xs, ys):
    if y <= xs[0]:
        return ys[0]
    for i in range(len(xs) - 1):
        if y <= xs[i + 1]:
            f = (y - xs[i]) / (xs[i + 1] - xs[i])
            return ys[i] + (ys[i + 1] - ys[i]) * f
    return ys[-1]


# warp profile by height (from the guides): z radius factor k and z centre
WY = [0, 40, 56, 66, 84, 140]
WK = [0.85, 0.8, 0.714, 0.74, 0.88, 0.88]
WC = [-2.0, -1.0, 0.0, 1.0, 4.0, 4.0]


def wparams(y):
    return _interp(y, WY, WC), _interp(y, WY, WK), 3.0


def warp_t(dx, dz, k, n):
    rho = math.hypot(dx, dz)
    if rho < 1e-9:
        return 1.0
    s, c = abs(dx) / rho, abs(dz) / rho
    return (s ** n + (c / k) ** n) ** (-1.0 / n)


def warp(x, z, y=56.0):
    """Plan (designed round, centred on 0, 0) -> final. Radial superellipse squash about (0, cz(y))."""
    if WARP is None:
        return x, z
    cz, k, n = wparams(y)
    t = warp_t(x, z, k, n)
    return x * t, cz + z * t


def unwarp(x, z, y=56.0):
    if WARP is None:
        return x, z
    cz, k, n = wparams(y)
    dz = z - cz
    t = warp_t(x, dz, k, n)
    return x / t, dz / t


def T(p):
    x, y, z = p
    if FINAL[-1]:
        return (x, y, z)
    if LOCAL:
        lx, lz, ly = LOCAL[-1]
        wx, wz = warp(lx, lz, ly)
        return (wx + x - lx, y, wz + z - lz)
    wx, wz = warp(x, z, y)
    return (wx, y, wz)


class local:
    def __init__(self, x, z, y=56.0):
        self.c = (x, z, y)
    def __enter__(self):
        LOCAL.append(self.c)
    def __exit__(self, *a):
        LOCAL.pop()


class final:
    def __enter__(self):
        FINAL.append(True)
    def __exit__(self, *a):
        FINAL.pop()


def poly(mat, pts, uv='box'):
    pts = [T(tuple(map(float, p))) for p in pts]
    if isinstance(uv, tuple) and not LOCAL and not FINAL[-1]:
        ym = sum(p[1] for p in pts) / len(pts)
        wx, wz = warp(uv[1], uv[2], ym)
        uv = ('cyl', wx, wz)
    elif isinstance(uv, tuple) and LOCAL:
        lx, lz, ly = LOCAL[-1]
        wx, wz = warp(lx, lz, ly)
        uv = ('cyl', wx + uv[1] - lx, wz + uv[2] - lz)
    P.setdefault(mat, []).append((pts, uv))


def col(pts):
    COL.append([T(tuple(map(float, p))) for p in pts])


def polar(cx, cz, r, a, y):
    # angle a: 0 = +z (front), increasing toward +x (clockwise seen from above)
    return (cx + r * math.sin(a), y, cz + r * math.cos(a))


def quad_strip(mat, rows, uv, closed=False, colmode=False, flip=False):
    """rows: list of point lists (same length). Faces between consecutive rows."""
    for i in range(len(rows) - 1):
        A, B = rows[i], rows[i + 1]
        n = len(A)
        rng = range(n) if closed else range(n - 1)
        for j in rng:
            k = (j + 1) % n
            q = [A[j], A[k], B[k], B[j]]
            if flip:
                q = q[::-1]
            poly(mat, q, uv)
            if colmode:
                col(q)


# ----------------------------------------------------------------- lathe
def lathe(mat, prof, cx=0.0, cz=0.0, segs=64, a0=0.0, a1=TAU, uv=None, flip=False, colmode=False):
    """Revolve profile [(r, y), ...] (listed bottom to top, outward faces) round (cx, cz)."""
    full = abs((a1 - a0) - TAU) < 1e-6
    n = segs if full else max(2, int(segs * (a1 - a0) / TAU) + 1)
    angs = [a0 + (a1 - a0) * i / (n if full else n - 1) for i in range(n)]
    rows = [[polar(cx, cz, r, a, y) for a in angs] for (r, y) in prof]
    quad_strip(mat, rows, uv or ('cyl', cx, cz), closed=full, colmode=colmode, flip=not flip)


def disc(mat, cx, cz, r0, r1, y, segs=64, a0=0.0, a1=TAU, up=True, colmode=False, uv='box'):
    lathe(mat, [(r0, y), (r1, y)] if up else [(r1, y), (r0, y)], cx, cz, segs, a0, a1, uv=uv, colmode=colmode)


# ----------------------------------------------------------------- arches
def arch_curve(w, h_spring, h_top, n=10):
    """Pointed (gothic) arch outline from left spring to right spring, local (u, v), u centred."""
    half = w / 2
    rise = h_top - h_spring
    pts = []
    # two circular arcs meeting at the apex; radius from width and rise
    R = (half * half + rise * rise) / (2 * half) if rise > half else half
    for i in range(n + 1):
        t = i / n
        # left arc centred at (-half + R, h_spring)
        if rise > half:
            cxl = -half + R
            ang0 = math.pi
            ang1 = math.pi - math.asin(rise / R) if rise < R else math.pi / 2
            a = ang0 + (ang1 - ang0) * t
            pts.append((cxl + R * math.cos(a), h_spring + R * math.sin(a)))
        else:
            a = math.pi - (math.pi / 2) * t
            pts.append((half * math.cos(a), h_spring + rise * math.sin(a)))
    right = [(-u, v) for (u, v) in reversed(pts[:-1])]
    return pts + right


def tri_fan_concave(pts2d):
    """Ear-clip a simple polygon (list of (u,v), CCW). Returns triangles as index triples."""
    idx = list(range(len(pts2d)))
    area = sum(pts2d[i][0] * pts2d[(i + 1) % len(pts2d)][1] - pts2d[(i + 1) % len(pts2d)][0] * pts2d[i][1] for i in idx)
    if area < 0:
        idx.reverse()
    tris = []
    def inside(p, a, b, c):
        def s(p1, p2, p3):
            return (p1[0] - p3[0]) * (p2[1] - p3[1]) - (p2[0] - p3[0]) * (p1[1] - p3[1])
        d1, d2, d3 = s(p, a, b), s(p, b, c), s(p, c, a)
        return not ((d1 < 0 or d2 < 0 or d3 < 0) and (d1 > 0 or d2 > 0 or d3 > 0))
    guard = 0
    while len(idx) > 3 and guard < 10000:
        guard += 1
        for k in range(len(idx)):
            i0, i1, i2 = idx[k - 1], idx[k], idx[(k + 1) % len(idx)]
            a, b, c = pts2d[i0], pts2d[i1], pts2d[i2]
            cr = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
            if cr <= 1e-9:
                continue
            if any(inside(pts2d[j], a, b, c) for j in idx if j not in (i0, i1, i2)):
                continue
            tris.append((i0, i1, i2))
            idx.pop(k)
            break
        else:
            break
    if len(idx) == 3:
        tris.append(tuple(idx))
    return tris


class CylFrame:
    """Maps local wall coords (u = arc metres from angle a0, v = y, d = radial offset) onto a cylinder."""
    def __init__(self, cx, cz, r, a0, ru=None):
        self.cx, self.cz, self.r, self.a0 = cx, cz, r, a0
        self.ru = ru or r      # radius that turns arc metres into angle (shared by both faces of a wall)

    def __call__(self, u, v, d=0.0):
        a = self.a0 + u / self.ru
        return polar(self.cx, self.cz, self.r + d, a, v)


def arcade(cx, cz, r, thick, y0, y1, a0, a1, bays, open_w=0.55, spring=0.62, apex=0.86,
           mat='stone', trim='gold', doors=(), blind=(), sill=0.0, seg_per_bay=6, colmode=True, relief='out'):
    """Curved wall from a0 to a1 with `bays` arched openings.
    doors: bay indices whose opening goes to the floor (walk-through), others are windows from sill.
    blind: bay indices with no opening (solid wall with a shallow blind arch).
    Returns list of (bay index, centre angle) for doors."""
    span = (a1 - a0) * r
    bw = span / bays
    H = y1 - y0
    outer = CylFrame(cx, cz, r + thick / 2, a0, ru=r)
    inner = CylFrame(cx, cz, r - thick / 2, a0, ru=r)
    out = []
    for b in range(bays):
        u0, u1 = b * bw, (b + 1) * bw
        uc = (u0 + u1) / 2
        w = bw * open_w
        if b in blind:
            # solid bay, subdivided for curvature
            for fr, sgn in ((outer, 1), (inner, -1)):
                cols = [u0 + (u1 - u0) * i / seg_per_bay for i in range(seg_per_bay + 1)]
                rows = [[fr(u, y0 + H * t) for u in cols] for t in (0, 1)]
                quad_strip(mat, rows, ('cyl', cx, cz), flip=(sgn < 0), colmode=colmode)
            # blind arch relief: gold archivolt + a recessed dark-stone panel with a crystal
            ac = arch_curve(w, H * spring, H * apex, 8)
            fr_, sg = (outer, 1) if relief == 'out' else (inner, -1)
            pts = [fr_(uc + u, y0 + v, 0.12 * sg) for (u, v) in ac]
            for i in range(len(pts) - 1):
                p, q = pts[i], pts[i + 1]
                p2, q2 = fr_(uc + ac[i][0] * 1.12, y0 + ac[i][1] * 1.02, 0.12 * sg), fr_(uc + ac[i + 1][0] * 1.12, y0 + ac[i + 1][1] * 1.02, 0.12 * sg)
                poly(trim, [p, q, q2, p2] if sg > 0 else [q, p, p2, q2], ('cyl', cx, cz))
            panel = [(uc - w / 2, 0.0)] + [(uc + u, v) for (u, v) in ac[1:-1]] + [(uc + w / 2, 0.0)]
            for t in tri_fan_concave(panel):
                q3 = [fr_(panel[i][0], y0 + panel[i][1], 0.04 * sg) for i in t]
                poly('panel', q3[::-1] if sg > 0 else q3, ('cyl', cx, cz))
            if relief == 'in':
                pil(inner, u0, y0, y1, cx, cz, d=-0.45)
            continue
        door = b in doors
        base = 0.0 if door else sill
        ac = arch_curve(w, H * spring, H * apex, 10)
        # opening outline (local u relative to bay start, v from y0)
        hole = [(uc + u - u0, v) for (u, v) in ac]
        hole[0] = (hole[0][0], base)
        hole[-1] = (hole[-1][0], base)
        hole = [(uc - w / 2 - u0, base)] + [(uc + u - u0, v) for (u, v) in ac] + [(uc + w / 2 - u0, base)]
        # wall polygon = bay rectangle minus the opening: outline as one concave polygon
        if base <= 1e-6:
            outline = [(0, 0), hole[0]] + hole[1:-1][::-1][::-1] + [hole[-1], (bw, 0), (bw, H), (0, H)]
            # walk: bottom-left -> opening left foot -> up the arch -> right foot -> bottom-right -> top right -> top left
            outline = [(0, 0), (hole[0][0], 0)] + [(p[0], p[1]) for p in hole[1:-1]] + [(hole[-1][0], 0), (bw, 0), (bw, H), (0, H)]
        else:
            outline = None
        def emit_face(fr, flip):
            if base <= 1e-6:
                o = outline
                tris = tri_fan_concave(o)
                for t in tris:
                    q = [fr(u0 + o[i][0], y0 + o[i][1]) for i in t]
                    poly(mat, q[::-1] if flip else q, ('cyl', cx, cz))
                    if colmode:
                        col(q)
            else:
                # window: sill band below + concave part above
                rows = [[fr(u0 + bw * i / 3, y0 + vv) for i in range(4)] for vv in (0, base)]
                quad_strip(mat, rows, ('cyl', cx, cz), flip=flip, colmode=colmode)
                o = [(0, base), (hole[0][0], base)] + [(p[0], p[1]) for p in hole[1:-1]] + [(hole[-1][0], base), (bw, base), (bw, H), (0, H)]
                for t in tri_fan_concave(o):
                    q = [fr(u0 + o[i][0], y0 + o[i][1]) for i in t]
                    poly(mat, q[::-1] if flip else q, ('cyl', cx, cz))
                    if colmode:
                        col(q)
        emit_face(outer, False)
        emit_face(inner, True)
        # reveal (thickness) round the opening
        rv = [(uc - w / 2, base)] + [(uc + u, v) for (u, v) in ac[1:-1]] + [(uc + w / 2, base)]
        for i in range(len(rv) - 1):
            a, b2 = rv[i], rv[i + 1]
            poly(mat, [outer(a[0], y0 + a[1]), inner(a[0], y0 + a[1]), inner(b2[0], y0 + b2[1]), outer(b2[0], y0 + b2[1])], ('cyl', cx, cz))
        if not door:
            # window sill top
            poly(mat, [outer(uc - w / 2, y0 + base), outer(uc + w / 2, y0 + base), inner(uc + w / 2, y0 + base), inner(uc - w / 2, y0 + base)], 'box')
        # gold archivolt band round the opening (outside)
        band = [(uc + u, v) for (u, v) in ac]
        for i in range(len(band) - 1):
            (ua, va), (ub, vb) = band[i], band[i + 1]
            s = 1.0 + 0.5 / max(w, 0.1)
            pa, pb = outer(ua, y0 + va, 0.15), outer(ub, y0 + vb, 0.15)
            qa = outer(uc + (ua - uc) * s, y0 + va + 0.35 * (va - H * spring) / max(H * (apex - spring), 0.1) + 0.12, 0.15)
            qb = outer(uc + (ub - uc) * s, y0 + vb + 0.35 * (vb - H * spring) / max(H * (apex - spring), 0.1) + 0.12, 0.15)
            poly(trim, [pa, pb, qb, qa], ('cyl', cx, cz))
        # keystone crystal on doors
        if door:
            out.append((b, a0 + uc / r))
        # pilaster on the bay's left edge (chamfered, stands proud)
        pil(outer, u0, y0, y1, cx, cz)
    pil(outer, span, y0, y1, cx, cz)
    # top and bottom caps of the wall
    for y, up in ((y1, True), (y0, False)):
        disc(mat, cx, cz, r - thick / 2, r + thick / 2, y, segs=max(8, int(64 * (a1 - a0) / TAU)), a0=a0, a1=a1, up=up, colmode=colmode and up)
    return out


def pil(fr, u, y0, y1, cx, cz, w=0.9, d=0.45):
    """Chamfered pilaster with a base and capital, standing proud of a curved wall (d < 0: inner face)."""
    prof = [(-w / 2, 0.0), (-w / 2 + 0.15, d), (w / 2 - 0.15, d), (w / 2, 0.0)]
    for i in range(len(prof) - 1):
        (ua, da), (ub, db) = prof[i], prof[i + 1]
        q = [fr(u + ua, y0, da), fr(u + ub, y0, db), fr(u + ub, y1, db), fr(u + ua, y1, da)]
        poly('stone', q[::-1] if d > 0 else q, ('cyl', cx, cz))
    if d < 0:
        return
    # capital (gold) and base blocks
    for yy, hh in ((y1 - 0.6, 0.6), (y0, 0.5)):
        cap = [(-w / 2 - 0.15, 0), (-w / 2 - 0.15, d + 0.2), (w / 2 + 0.15, d + 0.2), (w / 2 + 0.15, 0)]
        m = 'gold' if yy > y0 else 'stone'
        for i in range(len(cap) - 1):
            (ua, da), (ub, db) = cap[i], cap[i + 1]
            poly(m, [fr(u + ua, yy, da), fr(u + ub, yy, db), fr(u + ub, yy + hh, db), fr(u + ua, yy + hh, da)][::-1], ('cyl', cx, cz))
        poly(m, [fr(u + c[0], yy + hh, c[1]) for c in cap], 'box')


# ----------------------------------------------------------------- mouldings
def cornice(cx, cz, r, y, a0=0.0, a1=TAU, segs=96, size=1.0, mat='gold'):
    """Classical cornice ring: cyma + fascia, projecting outward from wall radius r at height y."""
    s = size
    prof = [(r, y - 0.9 * s), (r + 0.25 * s, y - 0.8 * s), (r + 0.35 * s, y - 0.55 * s), (r + 0.6 * s, y - 0.35 * s),
            (r + 0.95 * s, y - 0.15 * s), (r + 1.05 * s, y), (r, y)]
    lathe(mat, prof[:-1], cx, cz, segs, a0, a1)
    disc('stone', cx, cz, r, r + 1.05 * s, y, segs, a0, a1)


def base_moulding(cx, cz, r, y, a0=0.0, a1=TAU, segs=96, size=1.0):
    s = size
    prof = [(r + 0.7 * s, y), (r + 0.7 * s, y + 0.35 * s), (r + 0.45 * s, y + 0.5 * s), (r + 0.3 * s, y + 0.75 * s), (r, y + 0.9 * s)]
    lathe('stone', prof, cx, cz, segs, a0, a1)


def corbel_ring(cx, cz, r, y, a0, a1, step=2.4, depth=1.4, h=1.6):
    """Row of stepped corbels (three stacked blocks, each projecting further) under a projecting deck."""
    n = max(1, int((a1 - a0) * r / step))
    for i in range(n + 1):
        a = a0 + (a1 - a0) * i / n
        fr = CylFrame(cx, cz, r, a)
        w = 0.7
        tiers = [(depth * 0.4, h * 0.34), (depth * 0.7, h * 0.33), (depth, h * 0.33)]
        yb = y - h
        for k, (d, hh) in enumerate(tiers):
            y0_, y1_ = yb + sum(t[1] for t in tiers[:k]), yb + sum(t[1] for t in tiers[:k + 1])
            ww = w * (0.8 + 0.1 * k)
            q = lambda u, v, dd: fr(u, v, dd)
            poly('stone', [q(-ww / 2, y0_, d), q(ww / 2, y0_, d), q(ww / 2, y1_, d), q(-ww / 2, y1_, d)][::-1], ('cyl', cx, cz))
            poly('stone', [q(-ww / 2, y0_, 0), q(-ww / 2, y0_, d), q(-ww / 2, y1_, d), q(-ww / 2, y1_, 0)][::-1], ('cyl', cx, cz))
            poly('stone', [q(ww / 2, y0_, d), q(ww / 2, y0_, 0), q(ww / 2, y1_, 0), q(ww / 2, y1_, d)][::-1], ('cyl', cx, cz))
            poly('stone', [q(-ww / 2, y0_, 0), q(ww / 2, y0_, 0), q(ww / 2, y0_, d), q(-ww / 2, y0_, d)][::-1], 'box')
        poly('gold', [fr(-w / 2, y - 0.02, depth + 0.02), fr(w / 2, y - 0.02, depth + 0.02), fr(w / 2, y - h * 0.3, depth + 0.02), fr(-w / 2, y - h * 0.3, depth + 0.02)][::-1], ('cyl', cx, cz))


# ----------------------------------------------------------------- floors, ramps, stairs, parapets
def deck(cx, cz, r0, r1, y0, a0, a1, y1=None, th=0.8, segs=None, mat='floor', edge='gold', steps=True, base=None):
    """Annular deck from a0 to a1. If y1 differs, it is a spiral ramp/stair (collision = smooth ramp,
    visuals = steps when steps=True). Top surface at y0..y1."""
    y1 = y0 if y1 is None else y1
    arc = (a1 - a0) * (r0 + r1) / 2
    n = segs or max(2, int(abs(arc) / 1.6) + 1)
    ys = [y0 + (y1 - y0) * i / n for i in range(n + 1)]
    angs = [a0 + (a1 - a0) * i / n for i in range(n + 1)]
    # collision: smooth top + underside
    for i in range(n):
        a, b = angs[i], angs[i + 1]
        col([polar(cx, cz, r0, a, ys[i]), polar(cx, cz, r1, a, ys[i]), polar(cx, cz, r1, b, ys[i + 1]), polar(cx, cz, r0, b, ys[i + 1])])
    sloped = abs(y1 - y0) > 0.05
    if sloped and steps:
        rise = 0.24
        ns = max(1, int(abs(y1 - y0) / rise))
        for k in range(ns):
            t0, t1 = k / ns, (k + 1) / ns
            a, b = a0 + (a1 - a0) * t0, a0 + (a1 - a0) * t1
            yt = y0 + (y1 - y0) * (t1 if y1 > y0 else t0)
            yb = min(y0, y1) - th
            sub = 3
            for j in range(sub):
                aa, bb = a + (b - a) * j / sub, a + (b - a) * (j + 1) / sub
                poly(mat, [polar(cx, cz, r0, aa, yt), polar(cx, cz, r1, aa, yt), polar(cx, cz, r1, bb, yt), polar(cx, cz, r0, bb, yt)][::-1], 'box')
            # riser
            ar = a if y1 > y0 else b
            yprev = y0 + (y1 - y0) * (t0 if y1 > y0 else t1)
            poly(mat, [polar(cx, cz, r0, ar, yprev), polar(cx, cz, r1, ar, yprev), polar(cx, cz, r1, ar, yt), polar(cx, cz, r0, ar, yt)], 'box')
        # stringer walls (outer and inner sides) as sloped band
        for rr, fl in ((r1, False), (r0, True)):
            rows = [[polar(cx, cz, rr, angs[i], ys[i] + 0.25) for i in range(n + 1)], [polar(cx, cz, rr, angs[i], (base if base is not None else ys[i] - th - 0.4)) for i in range(n + 1)]]
            quad_strip('stone', rows, ('cyl', cx, cz), flip=fl)
    else:
        rows = [[polar(cx, cz, r, a, ys[i]) for i, a in enumerate(angs)] for r in (r0, r1)]
        quad_strip(mat, rows, 'box')
        for rr, fl in ((r1, False), (r0, True)):
            rows = [[polar(cx, cz, rr, angs[i], ys[i]) for i in range(n + 1)], [polar(cx, cz, rr, angs[i], (base if base is not None else ys[i] - th)) for i in range(n + 1)]]
            quad_strip(edge if (rr == r1 and base is None) else 'stone', rows, ('cyl', cx, cz), flip=fl)
    # underside
    rows = [[polar(cx, cz, r, a, ys[i] - th - (0.4 if sloped else 0)) for i, a in enumerate(angs)] for r in (r1, r0)]
    quad_strip('stone', rows, 'box')


def parapet(cx, cz, r, ys, a0, a1, h=1.1, th=0.45, gaps=(), mat='stone', pin_every=4, lamp_every=12):
    """Railing wall following a deck edge (ys = (y_start, y_end)). gaps: list of (a, b) angle ranges left open."""
    y0, y1 = ys
    arc = abs(a1 - a0) * r
    n = max(2, int(arc / 2.0))
    for i in range(n):
        a, b = a0 + (a1 - a0) * i / n, a0 + (a1 - a0) * (i + 1) / n
        if any(min(g) - 1e-6 <= (a + b) / 2 <= max(g) + 1e-6 for g in gaps):
            continue
        ya, yb = y0 + (y1 - y0) * i / n, y0 + (y1 - y0) * (i + 1) / n
        ro, ri = r + th / 2, r - th / 2
        q = lambda rr, aa, yy: polar(cx, cz, rr, aa, yy)
        poly(mat, [q(ro, a, ya), q(ro, b, yb), q(ro, b, yb + h), q(ro, a, ya + h)], ('cyl', cx, cz))
        poly(mat, [q(ri, b, yb), q(ri, a, ya), q(ri, a, ya + h), q(ri, b, yb + h)], ('cyl', cx, cz))
        # coping (gold edged)
        poly('gold', [q(ri - 0.08, a, ya + h), q(ri - 0.08, b, yb + h), q(ro + 0.08, b, yb + h), q(ro + 0.08, a, ya + h)], 'box')
        col([q(ro, a, ya), q(ro, b, yb), q(ro, b, yb + h), q(ro, a, ya + h)])
        col([q(ri, b, yb), q(ri, a, ya), q(ri, a, ya + h), q(ri, b, yb + h)])
        # post every segment, a pinnacle every few, a crystal lamp now and then
        poly('stone', [q(ro + 0.12, a, ya), q(ro + 0.12, a + 0.4 / r, ya), q(ro + 0.12, a + 0.4 / r, ya + h + 0.25), q(ro + 0.12, a, ya + h + 0.25)], ('cyl', cx, cz))
        if pin_every and i % pin_every == 0:
            pinnacle(*q(r, a, ya + h), 0.32, 1.5)
        if lamp_every and i % lamp_every == lamp_every // 2:
            px, py, pz = q(r, a, ya + h)
            crystal_shard(px, py + 0.05, pz, 0.9, 0.16, seed=int(px * 13 + pz * 7))


# ----------------------------------------------------------------- towers, spires, crystals
def _tower(cx, cz, r, y0, y1, spire=8.0, crystal=True, windows=3, segs=20, roof='spire'):
    prof = [(r * 1.18, y0), (r * 1.18, y0 + 0.6), (r * 1.05, y0 + 1.0), (r, y0 + 1.4),
            (r, y1 - 2.2), (r * 1.05, y1 - 1.9), (r * 1.18, y1 - 1.2), (r * 1.25, y1 - 0.8), (r * 1.25, y1)]
    lathe('stone', prof, cx, cz, segs)
    # gold band and dark window slits
    lathe('gold', [(r * 1.02, (y0 + y1) * 0.5 - 0.25), (r * 1.02, (y0 + y1) * 0.5 + 0.25)], cx, cz, segs)
    for k in range(windows):
        a = TAU * k / windows + 0.4
        fr = CylFrame(cx, cz, r + 0.02, a)
        yy = y0 + (y1 - y0) * 0.62
        ac = arch_curve(0.9, 1.6, 2.2, 6)
        pts = [fr(u, yy + v - 1.6, 0.01) for (u, v) in [(-0.45, 0)] + ac[1:-1] + [(0.45, 0)]]
        for t in tri_fan_concave([(u, v) for (u, v) in [(-0.45, 0)] + ac[1:-1] + [(0.45, 0)]]):
            poly('dark', [pts[i] for i in t][::-1], ('cyl', cx, cz))
    if roof == 'spire':
        sp = [(r * 1.25, y1), (r * 1.1, y1 + 0.2), (r * 0.9, y1 + spire * 0.25), (r * 0.55, y1 + spire * 0.6), (r * 0.18, y1 + spire * 0.92), (0.02, y1 + spire)]
        lathe('stone', sp, cx, cz, segs)
        lathe('gold', [(r * 0.93, y1 + spire * 0.22), (r * 0.97, y1 + spire * 0.27)], cx, cz, segs)
        if crystal:
            crystal_shard(cx, y1 + spire - 0.3, cz, spire * 0.35, max(0.35, r * 0.3))
    disc('stone', cx, cz, 0, r * 1.25, y1, segs)
    disc('stone', cx, cz, 0, r * 1.18, y0, segs, up=False)


def _crystal_shard(x, y, z, h, w, tilt=(0.0, 0.0), sides=6, seed=0):
    rnd = random.Random(seed or int(x * 31 + y * 17 + z * 7))
    tx, tz = tilt
    def P_(dx, dy, dz):
        return (x + dx + dy * tx, y + dy, z + dz + dy * tz)
    ring = []
    for i in range(sides):
        a = TAU * i / sides + rnd.uniform(-0.15, 0.15)
        rr = w * rnd.uniform(0.8, 1.1)
        ring.append((rr * math.sin(a), rr * math.cos(a)))
    mid = h * 0.25
    top = P_(0, h, 0)
    bot = P_(0, -h * 0.18, 0)
    R = [P_(a, mid, b) for (a, b) in ring]
    R2 = [P_(a * 0.85, h * 0.72, b * 0.85) for (a, b) in ring]
    for i in range(sides):
        j = (i + 1) % sides
        poly('crystal', [R[i], R[j], R2[j], R2[i]], 'box')
        poly('crystal', [R2[i], R2[j], top], 'box')
        poly('crystal', [R[j], R[i], bot], 'box')


def crystal_cluster(x, y, z, size, n=5, down=False, seed=1):
    rnd = random.Random(seed)
    for k in range(n):
        h = size * rnd.uniform(0.5, 1.0)
        tx, tz = rnd.uniform(-0.45, 0.45), rnd.uniform(-0.45, 0.45)
        dx, dz = rnd.uniform(-size * 0.25, size * 0.25), rnd.uniform(-size * 0.25, size * 0.25)
        if down:
            crystal_down(x + dx, y, z + dz, h, h * 0.18, (tx, tz), seed=seed * 13 + k)
        else:
            crystal_shard(x + dx, y, z + dz, h, h * 0.16, (tx, tz), seed=seed * 13 + k)


def _crystal_down(x, y, z, h, w, tilt=(0, 0), seed=0):
    rnd = random.Random(seed)
    sides = 6
    ring = [(w * rnd.uniform(0.8, 1.1) * math.sin(TAU * i / sides), w * rnd.uniform(0.8, 1.1) * math.cos(TAU * i / sides)) for i in range(sides)]
    tip = (x + tilt[0] * h, y - h, z + tilt[1] * h)
    R = [(x + a, y, z + b) for (a, b) in ring]
    R2 = [(x + a * 0.85 + tilt[0] * h * 0.7, y - h * 0.7, z + b * 0.85 + tilt[1] * h * 0.7) for (a, b) in ring]
    for i in range(sides):
        j = (i + 1) % sides
        poly('crystal', [R[j], R[i], R2[i], R2[j]], 'box')
        poly('crystal', [R2[j], R2[i], tip], 'box')


# ----------------------------------------------------------------- rock
def rock_cone(cx, cz, prof, segs=48, seed=3, amp=1.6):
    """Faceted floating rock: lathe with noisy radius, facets kept sharp."""
    rnd = random.Random(seed)
    noise = [[rnd.uniform(-1, 1) for _ in range(segs)] for _ in prof]
    rows = []
    for k, (r, y) in enumerate(prof):
        row = []
        for i in range(segs):
            a = TAU * i / segs
            n = noise[k][i] * amp * min(1.0, r / 8.0)
            rr = max(0.2, r + n)
            row.append(polar(cx, cz, rr, a + rnd.uniform(-0.02, 0.02), y + rnd.uniform(-0.6, 0.6) * min(1, r / 6)))
        rows.append(row)
    quad_strip('rock', rows, ('cyl', cx, cz), closed=True, flip=True)
    return rows


def _stalactite(x, y, z, h, w, seed=0):
    rnd = random.Random(seed)
    sides = 5
    ring = [(x + w * rnd.uniform(0.7, 1.2) * math.sin(TAU * i / sides), y, z + w * rnd.uniform(0.7, 1.2) * math.cos(TAU * i / sides)) for i in range(sides)]
    mid = [(x + (p[0] - x) * 0.5 + rnd.uniform(-0.2, 0.2) * w, y - h * 0.55, z + (p[2] - z) * 0.5 + rnd.uniform(-0.2, 0.2) * w) for p in ring]
    tip = (x + rnd.uniform(-0.3, 0.3) * w, y - h, z + rnd.uniform(-0.3, 0.3) * w)
    for i in range(sides):
        j = (i + 1) % sides
        poly('rock', [ring[j], ring[i], mid[i], mid[j]], 'box')
        poly('rock', [mid[j], mid[i], tip], 'box')


def box(mat, c, size, yaw=0.0, colmode=False, top_mat=None):
    with local(c[0], c[2], c[1]):
        _box(mat, c, size, yaw, colmode, top_mat)


def _box(mat, c, size, yaw=0.0, colmode=False, top_mat=None):
    cx_, cy_, cz_ = c
    sx, sy, sz = [s / 2 for s in size]
    cs, sn = math.cos(yaw), math.sin(yaw)
    def P_(dx, dy, dz):
        return (cx_ + dx * cs + dz * sn, cy_ + dy, cz_ - dx * sn + dz * cs)
    v = [P_(dx, dy, dz) for dx in (-sx, sx) for dy in (-sy, sy) for dz in (-sz, sz)]
    F = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    for f in F:
        q = [v[i] for i in f]
        m = top_mat if (top_mat and f == (2, 3, 7, 6)) else mat
        poly(m, q, 'box')
        if colmode:
            col(q)


def straight_stair(a, b, width, mat='floor', th=0.6):
    """Straight stair from point a to b (floor points), visual steps + smooth collision ramp + side walls."""
    a = np.array(a, float); b = np.array(b, float)
    d = b - a; L = math.hypot(d[0], d[2]); u = np.array([d[0] / L, 0, d[2] / L]); s = np.array([-u[2], 0, u[0]])
    w = width / 2
    col([tuple(a - s * w), tuple(a + s * w), tuple(b + s * w), tuple(b - s * w)][::-1])
    ns = max(1, int(abs(d[1]) / 0.24))
    for k in range(ns):
        t0, t1 = k / ns, (k + 1) / ns
        p0 = a + d * t0; p1 = a + d * t1
        yt = p1[1] if d[1] > 0 else p0[1]
        q = [p0 - s * w, p0 + s * w, p1 + s * w, p1 - s * w]
        poly(mat, [(x, yt, z) for (x, _, z) in q][::-1], 'box')
        rr = p0 if d[1] > 0 else p1
        yp = p0[1] if d[1] > 0 else p1[1]
        poly(mat, [((rr - s * w)[0], yp, (rr - s * w)[2]), ((rr + s * w)[0], yp, (rr + s * w)[2]), ((rr + s * w)[0], yt, (rr + s * w)[2]), ((rr - s * w)[0], yt, (rr - s * w)[2])], 'box')
    for sg in (-1, 1):
        e = s * (w + 0.25) * sg
        rows = [[tuple(a + e + np.array([0, 1.1, 0])), tuple(b + e + np.array([0, 1.1, 0]))], [tuple(a + e - np.array([0, th + 0.6, 0])), tuple(b + e - np.array([0, th + 0.6, 0]))]]
        quad_strip('stone', rows, 'box', flip=(sg < 0))
        poly('gold', [tuple(a + e * 0.96 + np.array([0, 1.1, 0])), tuple(b + e * 0.96 + np.array([0, 1.1, 0])), tuple(b + e * 1.04 + np.array([0, 1.1, 0])), tuple(a + e * 1.04 + np.array([0, 1.1, 0]))], 'box')
        col([tuple(a + e), tuple(b + e), tuple(b + e + np.array([0, 1.1, 0])), tuple(a + e + np.array([0, 1.1, 0]))])
    poly('stone', [tuple(a - s * w - np.array([0, th + 0.6, 0])), tuple(a + s * w - np.array([0, th + 0.6, 0])), tuple(b + s * w - np.array([0, th + 0.6, 0])), tuple(b - s * w - np.array([0, th + 0.6, 0]))], 'box')


def disc_hole(mat, ox, oz, R, hx, hz, hr, y, segs=96, up=True, colmode=False, uv='box'):
    """Flat disc of radius R round (ox, oz) with a round hole (hx, hz, hr) fully inside it."""
    rows_in, rows_out = [], []
    for i in range(segs):
        a = TAU * i / segs
        d = (math.sin(a), math.cos(a))
        rows_in.append((hx + hr * d[0], y, hz + hr * d[1]))
        wx, wz = hx - ox, hz - oz
        b = d[0] * wx + d[1] * wz
        c = wx * wx + wz * wz - R * R
        t = -b + math.sqrt(max(0.0, b * b - c))
        rows_out.append((hx + t * d[0], y, hz + t * d[1]))
    rows = [rows_in, rows_out] if up else [rows_out, rows_in]
    quad_strip(mat, rows, uv, closed=True, colmode=colmode, flip=True)


def tower(cx, cz, *a, **k):
    with local(cx, cz, a[1] if len(a) > 1 else 56.0):
        return _tower(cx, cz, *a, **k)


def crystal_shard(x, y, z, *a, **k):
    with local(x, z, y):
        return _crystal_shard(x, y, z, *a, **k)


def crystal_down(x, y, z, *a, **k):
    with local(x, z, y):
        return _crystal_down(x, y, z, *a, **k)


def stalactite(x, y, z, *a, **k):
    with local(x, z, y):
        return _stalactite(x, y, z, *a, **k)


def pinnacle(x, y, z, w, h):
    """Small gothic pinnacle: square shaft, gold collar, pointed cap."""
    with local(x, z, y):
        b = [(x - w, z - w), (x + w, z - w), (x + w, z + w), (x - w, z + w)]
        for i in range(4):
            (ax, az), (bx, bz) = b[i], b[(i + 1) % 4]
            poly('stone', [(ax, y, az), (bx, y, bz), (bx, y + h * 0.45, bz), (ax, y + h * 0.45, az)][::-1], 'box')
            poly('gold', [(ax * 1.0, y + h * 0.45, az), (bx, y + h * 0.45, bz), (bx, y + h * 0.52, bz), (ax, y + h * 0.52, az)][::-1], 'box')
            poly('stone', [(ax, y + h * 0.52, az), (bx, y + h * 0.52, bz), (x, y + h, z)][::-1], 'box')
