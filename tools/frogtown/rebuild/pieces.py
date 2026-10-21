"""Frogtown v2 building pieces: stilt huts, long lodges, marsh trees, boardwalks,
islands, the plaza, reeds and lily pads. All take a Builder (rkit) and a detail
level LOD (1.0 desktop, ~0.55 phone)."""
import math, random
from mathutils import Vector
from rkit import *

WATER_Y = -3.3
DECK_T = 0.14


def segs(n, lod):
    return max(6, int(round(n * lod)))

# ---------------------------------------------------------------- stilt hut


def hut(bd, c, r, door_yaw, lod=1.0, seed=0, roof_tint='thatch', walls='reed', floor_y=0.75):
    """Round frog-folk stilt hut. c = (x, ground_y, z); r = wall radius (m).
    door_yaw: angle (rad, from +x toward +z) the door faces. Returns the door
    threshold point (on the ground, outside the steps)."""
    rnd = random.Random(seed)
    x0, gy, z0 = c
    fy = gy + floor_y
    n = segs(20, lod)
    # stilts and the floor platform
    for i in range(segs(8, lod)):
        a = i / segs(8, lod) * TAU + 0.2
        px, pz = x0 + math.cos(a) * r * 0.92, z0 + math.sin(a) * r * 0.92
        sweep(bd, [(px, gy - 0.6, pz), (px, fy - 0.05, pz)], lambda u: 0.13 - 0.03 * u, 'wood', sides=6)
    lathe(bd, [(r * 1.12, fy - DECK_T), (r * 1.14, fy - 0.02), (r * 1.1, fy)], 'planks_dark', at=(x0, 0, z0), segs=n)
    ring_flat(bd, (x0, 0, z0), 0.0, r * 1.1, fy, 'planks', segs=n)
    # woven wall with a door gap, posts and lashing bands
    gap = math.atan2(0.62, r)
    a0, a1 = door_yaw + gap, door_yaw + TAU - gap
    wall_h = 2.25
    lathe(bd, [(r, fy), (r * 1.02, fy + wall_h * 0.5), (r * 0.98, fy + wall_h)], walls, at=(x0, 0, z0), segs=n, a0=a0, a1=a1, wobble=0.01, seed=seed)
    lathe(bd, [(r - 0.08, fy + wall_h), (r * 1.02 - 0.08, fy + wall_h * 0.5), (r - 0.08, fy)], 'reed', at=(x0, 0, z0), segs=n, a0=a0, a1=a1)
    for k in range(segs(10, lod)):
        a = a0 + (a1 - a0) * k / (segs(10, lod) - 1)
        px, pz = x0 + math.cos(a) * (r + 0.05), z0 + math.sin(a) * (r + 0.05)
        sweep(bd, bez((px, fy - 0.05, pz), (px, fy + wall_h + 0.15, pz), (rnd.uniform(-0.04, 0.04), 0, rnd.uniform(-0.04, 0.04)), 3), lambda u: 0.1 - 0.02 * u, 'wood', sides=6)
    for yb in ((0.55, 1.75) if lod > 0.7 else ()):
        pts = [(x0 + math.cos(a0 + (a1 - a0) * i / n) * (r * 1.03 + 0.04), fy + yb, z0 + math.sin(a0 + (a1 - a0) * i / n) * (r * 1.03 + 0.04)) for i in range(n + 1)]
        sweep(bd, pts, 0.035, 'rope', sides=4, cap=False)
    # door frame: two posts, a bone arch over them, a hide curtain inside
    dx, dz = math.cos(door_yaw), math.sin(door_yaw)
    tx, tz = -dz, dx
    for s in (-1, 1):
        px, pz = x0 + dx * (r + 0.08) + tx * s * 0.62, z0 + dz * (r + 0.08) + tz * s * 0.62
        sweep(bd, [(px, fy - 0.05, pz), (px, fy + 2.05, pz)], 0.11, 'wood', sides=6)
    l0 = (x0 + dx * (r + 0.12) - tx * 0.78, fy + 1.95, z0 + dz * (r + 0.12) - tz * 0.78)
    l1 = (x0 + dx * (r + 0.12) + tx * 0.78, fy + 1.95, z0 + dz * (r + 0.12) + tz * 0.78)
    sweep(bd, bez(l0, l1, (dx * 0.1, 0.55, dz * 0.1), 8), lambda u: 0.09 + 0.05 * math.sin(u * math.pi), 'shell', sides=6)
    cx_, cz_ = x0 + dx * (r - 0.05), z0 + dz * (r - 0.05)
    curtain = []
    for k in range(4):
        y = fy + 1.95 - k * 0.65
        curtain.append([(cx_ + tx * (j - 3) / 3 * 0.6 + dx * 0.04 * math.sin(j * 1.7 + k), y, cz_ + tz * (j - 3) / 3 * 0.6 + dz * 0.04 * math.sin(j * 1.7 + k)) for j in range(7)])
    bd.grid(curtain, [[(j / 6, k / 3) for j in range(7)] for k in range(4)], 'cloth')
    # round shell windows (dark glass + shell rim) left and right of the door
    for s in (-1, 1):
        a = door_yaw + s * 1.25
        wx, wz = x0 + math.cos(a) * (r * 1.03 + 0.02), z0 + math.sin(a) * (r * 1.03 + 0.02)
        nx, nz = math.cos(a), math.sin(a)
        rim = []
        for i in range(13):
            t = i / 12 * TAU
            rim.append((wx - nz * math.cos(t) * 0.38, fy + 1.35 + math.sin(t) * 0.38, wz + nx * math.cos(t) * 0.38))
        sweep(bd, rim, 0.06, 'shell', sides=5, cap=False)
        bd.poly([(wx - nz * math.cos(i / 10 * TAU) * 0.34 + nx * 0.01, fy + 1.35 + math.sin(i / 10 * TAU) * 0.34, wz + nx * math.cos(i / 10 * TAU) * 0.34 + nz * 0.01) for i in range(10)], [(0, 0)] * 10, 'dark')
    # three-tier thatch roof with ragged fringes and a carved finial
    ry = fy + wall_h
    tiers = [(r * 1.38, ry - 0.25, r * 0.86, ry + 1.25), (r * 1.0, ry + 0.85, r * 0.5, ry + 2.35), (r * 0.62, ry + 2.0, 0.08, ry + 3.6)]
    for ti, (rb, yb, rt, yt) in enumerate(tiers):
        def fr(i, k, ti=ti):
            # ragged bottom edge: each segment dips a little differently
            return 1.0 + (0.05 * math.sin(i * 2.3 + ti) if k == 0 else 0.0)
        prof = [(rb, yb), (rb * 0.93 + rt * 0.07, yb + (yt - yb) * 0.18), (rb * 0.55 + rt * 0.45, yb + (yt - yb) * 0.6), (rt, yt)]
        lathe(bd, prof, roof_tint, at=(x0, 0, z0), segs=segs(24, lod), wobble=0.025, seed=seed + ti, rjit=fr)
        # underside lip (the thatch has thickness at the eave)
        lathe(bd, [(rb * 0.86, yb + 0.22), (rb, yb)], 'thatch', at=(x0, 0, z0), segs=segs(24, lod), wobble=0.025, seed=seed + ti, flip=True)
    sweep(bd, bez((x0, ry + 3.4, z0), (x0, ry + 4.4, z0), (0.15, 0, 0), 4), lambda u: 0.08 * (1 - 0.5 * u), 'wood', sides=6)
    fan_shell(bd, (x0, ry + 4.2, z0), 0.55, 'shell', ribs=7, spread=140, depth=0.3, tilt=-70, yaw=door_yaw - math.pi / 2, thick=0.04, steps=4)
    # steps from the door down to the ground
    sx, sz = x0 + dx * (r * 1.1 + 0.35), z0 + dz * (r * 1.1 + 0.35)
    nsteps = max(1, int(round(floor_y / 0.25)))
    for k in range(nsteps):
        y = fy - (k + 1) * floor_y / (nsteps + 1)
        board(bd, (sx + dx * k * 0.32, y, sz + dz * k * 0.32), (1.3, 0.1, 0.32), 'planks', yaw=math.atan2(dx, dz) + math.pi / 2, seed=seed * 7 + k)
    # a lantern on the right door post
    lx, lz = x0 + dx * (r + 0.3) + tx * 0.75, z0 + dz * (r + 0.3) + tz * 0.75
    lathe(bd, [(0.04, 0), (0.15, 0.06), (0.18, 0.2), (0.13, 0.33), (0.04, 0.38)], 'lantern', at=(lx, fy + 1.55, lz), segs=8, cap_top=True)
    return (x0 + dx * (r * 1.1 + 0.35 + nsteps * 0.32 + 0.4), gy, z0 + dz * (r * 1.1 + 0.35 + nsteps * 0.32 + 0.4))

# ---------------------------------------------------------------- long lodge


def lodge(bd, c, w, d, yaw, lod=1.0, seed=0, floor_y=0.8, banner='cloth_blue'):
    """Rectangular long lodge on stilts with a steep two-tier thatch roof and
    crossed horn ridge ends. Door on local +z. Returns the door threshold."""
    x0, gy, z0 = c
    cy, sn = math.cos(yaw), math.sin(yaw)

    def T(x, y, z):
        return (x0 + x * cy + z * sn, y, z0 - x * sn + z * cy)
    fy = gy + floor_y
    hw, hd = w / 2, d / 2
    # stilts
    for x in [-hw + 0.3 + i * (w - 0.6) / max(1, segs(4, lod) - 1) for i in range(segs(4, lod))]:
        for z in (-hd + 0.3, 0.0, hd - 0.3):
            sweep(bd, [T(x, gy - 0.6, z), T(x, fy - 0.05, z)], lambda u: 0.15 - 0.03 * u, 'wood', sides=6)
    # floor: boards across the width
    nb = int(w / 0.35)
    for i in range(nb):
        x = -hw - 0.3 + (i + 0.5) * (w + 0.6) / nb
        board(bd, T(x, fy - 0.06, 0), ((w + 0.6) / nb - 0.02, 0.12, d + 0.6), 'planks', yaw=yaw, seed=seed * 31 + i)
    # walls: wattle panels between timber posts; door gap in the middle of +z
    wall_h = 2.4
    corners = [(-hw, -hd), (hw, -hd), (hw, hd), (-hw, hd)]
    for k in range(4):
        (ax, az), (bx, bz) = corners[k], corners[(k + 1) % 4]
        L = math.hypot(bx - ax, bz - az)
        npan = max(1, int(L / 1.6))
        for p in range(npan):
            u0, u1 = p / npan, (p + 1) / npan
            px0, pz0 = ax + (bx - ax) * u0, az + (bz - az) * u0
            px1, pz1 = ax + (bx - ax) * u1, az + (bz - az) * u1
            mid_door = k == 2 and abs((px0 + px1) / 2) < 0.9
            if not mid_door:
                q = [T(px0, fy, pz0), T(px1, fy, pz1), T(px1, fy + wall_h, pz1), T(px0, fy + wall_h, pz0)]
                bd.poly(q, [(0, 0), (L / npan / 1.6, 0), (L / npan / 1.6, wall_h / 1.6), (0, wall_h / 1.6)], 'reed')
                bd.poly(list(reversed(q)), [(0, 0)] * 4, 'reed')
            sweep(bd, [T(px0, fy - 0.05, pz0), T(px0, fy + wall_h + 0.2, pz0)], 0.13, 'wood', sides=6)
        sweep(bd, [T(ax, fy + wall_h, az), T(bx, fy + wall_h, bz)], 0.12, 'wood', sides=6)
    # door frame + bone arch + curtain
    for s in (-1, 1):
        sweep(bd, [T(s * 0.8, fy - 0.05, hd + 0.05), T(s * 0.8, fy + 2.15, hd + 0.05)], 0.12, 'wood', sides=6)
    sweep(bd, bez(T(-1.0, fy + 2.05, hd + 0.1), T(1.0, fy + 2.05, hd + 0.1), (0, 0.6, 0), 8), lambda u: 0.1 + 0.06 * math.sin(u * math.pi), 'shell', sides=6)
    cur = [[T(-0.75 + j * 0.25, fy + 2.0 - k * 0.66, hd - 0.02 + 0.04 * math.sin(j * 1.9 + k)) for j in range(7)] for k in range(4)]
    bd.grid(cur, [[(j / 6, k / 3) for j in range(7)] for k in range(4)], 'cloth')
    # roof: steep two-tier thatch, hipped ends, ridge with crossed horns
    ry = fy + wall_h
    for tier, (ov, y0, rise) in enumerate([(1.1, ry - 0.3, 2.1), (0.45, ry + 1.4, 1.9)]):
        ex = hw + ov
        ez = hd + ov
        top_z = 0.25
        top_x = max(0.3, hw - 1.2 - tier * 0.6)
        yb, yt = y0, y0 + rise
        for sgn in (-1, 1):   # long slopes
            rows = [[T(x, yb, sgn * ez) for x in (-ex, -ex / 2, 0, ex / 2, ex)], [T(x, yt, sgn * top_z) for x in (-top_x, -top_x / 2, 0, top_x / 2, top_x)]]
            bd.grid(rows, [[(i * ex / 2 / 2.6, 0) for i in range(5)], [(i * ex / 2 / 2.6, rise / 2.6 * 1.3) for i in range(5)]], 'thatch', flip=sgn > 0)
        for sgn in (-1, 1):   # hipped ends
            tri = [T(sgn * ex, yb, -ez), T(sgn * ex, yb, ez), T(sgn * top_x, yt, top_z), T(sgn * top_x, yt, -top_z)]
            bd.poly(tri if sgn > 0 else list(reversed(tri)), [(0, 0), (ez * 2 / 2.6, 0), (ez / 2.6 + 0.1, rise / 2.6 * 1.3), (ez / 2.6 - 0.1, rise / 2.6 * 1.3)], 'thatch')
        # ragged eave fringe
        for sgn in (-1, 1):
            for i in range(segs(10, lod)):
                x = -ex + (i + 0.5) * 2 * ex / segs(10, lod)
                board(bd, T(x, yb - 0.05, sgn * (ez + 0.02)), (2 * ex / segs(10, lod) + 0.05, 0.12, 0.25), 'thatch', yaw=yaw, seed=seed + i * 3 + tier)
    ytop = ry + 1.4 + 1.9
    sweep(bd, [T(-hw + 0.2, ytop + 0.1, 0), T(hw - 0.2, ytop + 0.1, 0)], 0.18, 'thatch', sides=6)
    for sgn in (-1, 1):
        for side in (-1, 1):
            sweep(bd, bez(T(sgn * (hw - 0.3), ytop - 0.1, 0), T(sgn * (hw + 0.2), ytop + 1.3, side * 0.7), (sgn * 0.2, 0.2, 0), 6), lambda u: 0.12 * (1 - 0.6 * u), 'shell', sides=6)
    # banner by the door, porch steps
    bd.grid([[T(1.25, fy + 2.1, hd + 0.2), T(1.75, fy + 2.1, hd + 0.2)], [T(1.25, fy + 0.6, hd + 0.25), T(1.75, fy + 0.5, hd + 0.25)]], [[(0, 0), (0.5, 0)], [(0, 1), (0.5, 1)]], banner)
    nsteps = max(1, int(round(floor_y / 0.25)))
    for k in range(nsteps):
        y = fy - (k + 1) * floor_y / (nsteps + 1)
        board(bd, T(0, y, hd + 0.5 + k * 0.32), (2.0, 0.1, 0.32), 'planks', yaw=yaw + math.pi / 2, seed=seed + 50 + k)
    for s in (-1, 1):
        lathe(bd, [(0.04, 0), (0.15, 0.06), (0.18, 0.2), (0.13, 0.33), (0.04, 0.38)], 'lantern', at=T(s * 1.05, fy + 1.6, hd + 0.3), segs=8, cap_top=True)
    return T(0, gy, hd + 0.9 + nsteps * 0.32)

# ---------------------------------------------------------------- marsh tree


def tree(bd, c, height, crown, lod=1.0, seed=0, willow=True, fol=None):
    """Marsh willow: flared roots, a leaning trunk, branches and drooping leaf clumps."""
    rnd = random.Random(seed)
    x0, gy, z0 = c
    lean = (rnd.uniform(-0.6, 0.6), rnd.uniform(-0.6, 0.6))
    base_r = 0.18 + height * 0.03
    top = (x0 + lean[0], gy + height * 0.72, z0 + lean[1])
    trunk = bez((x0, gy - 0.3, z0), top, (rnd.uniform(-0.5, 0.5), 0, rnd.uniform(-0.5, 0.5)), 6)
    sweep(bd, trunk, lambda u: base_r * (1.25 - 0.6 * u), 'bark', sides=segs(8, lod))
    for i in range(segs(5, lod)):
        a = i / segs(5, lod) * TAU + rnd.uniform(-0.3, 0.3)
        L = base_r * rnd.uniform(4.0, 6.0)
        sweep(bd, bez((x0, gy + 0.5, z0), (x0 + math.cos(a) * L, gy - 0.25, z0 + math.sin(a) * L), (math.cos(a) * L * 0.2, 0.35, math.sin(a) * L * 0.2), 4), lambda u: base_r * 0.55 * (1 - 0.75 * u), 'bark', sides=5)
    clumps = []
    for i in range(segs(4, lod)):
        a = i / segs(4, lod) * TAU + rnd.uniform(0, 1)
        L = crown * rnd.uniform(0.45, 0.75)
        tip = (top[0] + math.cos(a) * L, top[1] + rnd.uniform(0.2, 1.0), top[2] + math.sin(a) * L)
        sweep(bd, bez(top, tip, (0, 0.6, 0), 4), lambda u: base_r * 0.5 * (1 - 0.7 * u), 'bark', sides=5)
        clumps.append(tip)
    clumps.append((top[0], top[1] + crown * 0.45, top[2]))
    fb = fol or bd
    for k, p in enumerate(clumps):
        rr = crown * rnd.uniform(0.5, 0.68)
        blob(fb, p, rr, 'leaves' if k % 2 == 0 else 'leaves_dark', squash=0.62, seed=seed * 13 + k, detail=2 if (lod > 0.7 and crown > 1.5) else 1, amp=0.3, droop=0.6 if willow else 0.0)
    if willow:
        # hanging fringe: a ragged skirt of leaves under the crown
        def jag(i, k):
            return 1.0 + (0.12 * math.sin(i * 3.1 + seed) if k == 0 else 0.0)
        lathe(fb, [(crown * 0.95, top[1] - crown * 0.55), (crown * 1.0, top[1] - crown * 0.1), (crown * 0.7, top[1] + crown * 0.25)], 'leaves_dark', at=(top[0], 0, top[2]), segs=segs(14, lod), wobble=0.12, seed=seed, rjit=jag)

# ---------------------------------------------------------------- boardwalks


def boardwalk(bd, pts, y0, y1, width=2.3, lod=1.0, seed=0, rails=True, post_step=2.4, lanterns=False, clear=None):
    """Plank boardwalk along a polyline at heights y0 -> y1: deck with planks
    across (UV), side stringers, posts into the marsh with X braces, rope rails."""
    P = [Vector((p[0], 0, p[1])) for p in pts]
    total = sum((P[i + 1] - P[i]).length for i in range(len(P) - 1))
    hw = width / 2
    t = tile('planks')
    # sample along the line
    samples = []
    acc = 0.0
    for i in range(len(P) - 1):
        a, b = P[i], P[i + 1]
        L = (b - a).length
        n = max(2, int(L / 0.6))
        for k in range(n + (1 if i == len(P) - 2 else 0)):
            s = k / n
            p = a.lerp(b, s)
            dist = acc + L * s
            y = y0 + (y1 - y0) * (dist / total)
            d = (b - a).normalized()
            samples.append((Vector((p.x, y, p.z)), d, dist))
        acc += L
    left, right, uvl, uvr = [], [], [], []
    for p, d, dist in samples:
        side = Vector((-d.z, 0, d.x))
        left.append(tuple(p + side * hw))
        right.append(tuple(p - side * hw))
        uvl.append((width / t, dist / t))
        uvr.append((0.0, dist / t))
    bd.grid([right, left], [uvr, uvl], 'planks', flip=True)
    # deck edge / stringers
    for sgn, edge in ((1, left), (-1, right)):
        pts_e = [(e[0], e[1] - DECK_T * 0.6, e[2]) for e in edge]
        sweep(bd, pts_e, 0.09, 'planks_dark', sides=5, cap=True, squash=0.7)
    # posts, braces and rails
    n_posts = max(2, int(total / post_step) + 1)
    rail_pts = {1: [], -1: []}
    for k in range(n_posts):
        dist = total * k / (n_posts - 1)
        # find position
        acc = 0.0
        for i in range(len(P) - 1):
            L = (P[i + 1] - P[i]).length
            if dist <= acc + L + 1e-6:
                d = (P[i + 1] - P[i]).normalized()
                p = P[i].lerp(P[i + 1], (dist - acc) / L)
                break
            acc += L
        y = y0 + (y1 - y0) * dist / total
        side = Vector((-d.z, 0, d.x))
        for sgn in (1, -1):
            q = p + side * sgn * (hw - 0.05)
            sweep(bd, [(q.x, WATER_Y - 0.8, q.z), (q.x, y - 0.05, q.z)], 0.12, 'wood', sides=segs(6, lod), cap=lod > 0.7)
            if rails and not (clear and clear(q.x, q.z)):
                top = (q.x, y + 1.0, q.z)
                sweep(bd, [(q.x, y - 0.05, q.z), top], lambda u: 0.07 - 0.015 * u, 'wood', sides=5)
                rail_pts[sgn].append(top)
            elif rails:
                rail_pts[sgn].append(None)    # a crossing walkway: no post, no rope
        if k % 2 == 0 and lod > 0.7:
            a_ = p + side * (hw - 0.05)
            b_ = p - side * (hw - 0.05)
            sweep(bd, [(a_.x, y - 0.35, a_.z), (b_.x, WATER_Y + 0.3, b_.z)], 0.05, 'wood', sides=4)
            sweep(bd, [(b_.x, y - 0.35, b_.z), (a_.x, WATER_Y + 0.3, a_.z)], 0.05, 'wood', sides=4)
        if lanterns and k % 2 == 1:
            q = p + side * (hw + 0.05)
            lathe(bd, [(0.04, 0), (0.15, 0.06), (0.18, 0.2), (0.13, 0.33), (0.04, 0.38)], 'lantern', at=(q.x, y + 1.05, q.z), segs=8, cap_top=True)
    if rails and lod > 0.7:
        for sgn in (1, -1):
            rp = rail_pts[sgn]
            for i in range(len(rp) - 1):
                if rp[i] is None or rp[i + 1] is None:
                    continue
                a_, b_ = Vector(rp[i]), Vector(rp[i + 1])
                rope = [tuple(a_.lerp(b_, s) - Vector((0, 0.18 * 4 * s * (1 - s), 0))) for s in [j / 6 for j in range(7)]]
                sweep(bd, rope, 0.03, 'rope', sides=4, cap=False)
    return samples

# ---------------------------------------------------------------- islands and plaza


def island(bd, o, lod=1.0, seed=0, ring_w=2.0, entries=()):
    """A round marsh island: grassy top, a plank boardwalk ring along its edge
    (posts, rim beams) and mud banks down into the water."""
    x0, z0, r, y = o['x'], o['z'], o['r'], o['y']
    n = segs(56, lod)
    rnd = random.Random(seed)
    ri = r - ring_w
    # grass top: a gently domed disc (rings for a little height noise)
    rows, uvs = [], []
    for k, rr in enumerate([0.0, ri * 0.35, ri * 0.7, ri]):
        ring, ur = [], []
        for i in range(n):
            a = i / n * TAU
            hh = y + 0.12 * (1 - (rr / ri) ** 2) + (0.04 * math.sin(a * 5 + seed) if 0 < rr < ri else 0)
            px, pz = x0 + math.cos(a) * rr, z0 + math.sin(a) * rr
            ring.append((px, hh, pz))
            ur.append((px / tile('grass'), pz / tile('grass')))
        rows.append(ring)
        uvs.append(ur)
    bd.grid(rows, uvs, 'grass', close_u=True)
    # boardwalk ring (boards run radially) + inner kerb + outer rim beam
    deck_y = y + 0.22
    ring_flat(bd, (x0, 0, z0), ri, r, deck_y, 'planks', segs=n)
    lathe(bd, [(ri, y - 0.05), (ri, deck_y)], 'planks_dark', at=(x0, 0, z0), segs=n)
    lathe(bd, [(r + 0.05, deck_y - 0.3), (r + 0.08, deck_y - 0.02), (r, deck_y)], 'planks_dark', at=(x0, 0, z0), segs=n)
    # mud bank under the ring down to the water
    lathe(bd, [(r + 1.6 + rnd.uniform(0, 0.3), WATER_Y - 0.6), (r + 0.9, WATER_Y + 0.4), (r + 0.25, deck_y - 0.6), (r + 0.02, deck_y - 0.3)], 'mud', at=(x0, 0, z0), segs=n, wobble=0.06, seed=seed)
    # rim posts with a rope between (gaps where walkways join)
    n_posts = segs(int(TAU * r / 2.2), lod)
    tops = []
    for i in range(n_posts):
        a = i / n_posts * TAU
        blocked = any(abs(((a - e + math.pi) % TAU) - math.pi) < 0.22 + 1.4 / r for e in entries)
        px, pz = x0 + math.cos(a) * (r + 0.02), z0 + math.sin(a) * (r + 0.02)
        sweep(bd, [(px, WATER_Y - 0.6, pz), (px, deck_y + (0.9 if not blocked else 0.15), pz)], lambda u: 0.12 - 0.03 * u, 'wood', sides=segs(6, lod))
        tops.append(None if blocked else (px, deck_y + 0.85, pz))
    for i in range(n_posts if lod > 0.7 else 0):
        a_, b_ = tops[i], tops[(i + 1) % n_posts]
        if a_ and b_:
            A, Bv = Vector(a_), Vector(b_)
            sweep(bd, [tuple(A.lerp(Bv, s) - Vector((0, 0.15 * 4 * s * (1 - s), 0))) for s in [j / 5 for j in range(6)]], 0.03, 'rope', sides=4, cap=False)
    return deck_y


def plaza(bd, o, lod=1.0, entries=()):
    """The village plaza: a round plank deck with radial boards, a rim of posts,
    and a sunken shell-lined pool around the old council tree in the middle."""
    x0, z0, r, y = o['x'], o['z'], o['r'], o['y']
    n = segs(64, lod)
    deck_y = y + 0.22
    pool_r = 3.3
    ring_flat(bd, (x0, 0, z0), pool_r + 0.35, r, deck_y, 'planks', segs=n)
    # carved rings of darker boards (council circle)
    for rr in (5.3, 7.2):
        ring_flat(bd, (x0, 0, z0), rr - 0.12, rr + 0.12, deck_y + 0.012, 'planks_dark', segs=n)
    lathe(bd, [(r + 0.05, deck_y - 0.35), (r + 0.1, deck_y - 0.02), (r, deck_y)], 'planks_dark', at=(x0, 0, z0), segs=n)
    lathe(bd, [(r + 2.0, WATER_Y - 0.6), (r + 1.0, WATER_Y + 0.4), (r + 0.25, deck_y - 0.7), (r + 0.05, deck_y - 0.35)], 'mud', at=(x0, 0, z0), segs=n, wobble=0.05, seed=3)
    # pool kerb: stone ring with shells set in it, water a step down, an islet in the middle
    lathe(bd, [(pool_r + 0.35, deck_y), (pool_r + 0.3, deck_y + 0.35), (pool_r + 0.05, deck_y + 0.42), (pool_r - 0.1, deck_y + 0.3), (pool_r - 0.12, deck_y - 0.5)], 'stone', at=(x0, 0, z0), segs=n, wobble=0.02, seed=5)
    for i in range(segs(18, lod)):
        a = i / segs(18, lod) * TAU
        fan_shell(bd, (x0 + math.cos(a) * (pool_r + 0.18), deck_y + 0.4, z0 + math.sin(a) * (pool_r + 0.18)), 0.22, 'shell', ribs=5, spread=120, depth=0.3, tilt=-60, yaw=a + math.pi / 2, thick=0.03, steps=3)
    ring_flat(bd, (x0, 0, z0), 1.4, pool_r - 0.1, deck_y - 0.35, 'water', segs=n, radial_boards=False)
    lathe(bd, [(1.6, deck_y - 0.4), (1.3, deck_y - 0.05), (0.9, deck_y + 0.12), (0.001, deck_y + 0.18)], 'grass', at=(x0, 0, z0), segs=segs(16, lod), wobble=0.08, seed=9)
    # rim posts
    n_posts = segs(int(TAU * r / 2.2), lod)
    for i in range(n_posts):
        a = i / n_posts * TAU
        blocked = any(abs(((a - e + math.pi) % TAU) - math.pi) < 0.2 + 1.4 / r for e in entries)
        px, pz = x0 + math.cos(a) * (r + 0.02), z0 + math.sin(a) * (r + 0.02)
        sweep(bd, [(px, WATER_Y - 0.6, pz), (px, deck_y + (0.75 if not blocked else 0.12), pz)], lambda u: 0.13 - 0.03 * u, 'wood', sides=segs(6, lod))
        if not blocked and i % 2 == 0:
            lathe(bd, [(0.04, 0), (0.13, 0.05), (0.16, 0.18), (0.11, 0.3), (0.04, 0.34)], 'lantern', at=(px, deck_y + 0.78, pz), segs=8, cap_top=True)
    return deck_y

# ---------------------------------------------------------------- marsh dressing


def reeds(bd, c, n=12, h=1.6, spread=0.8, seed=0, lod=1.0):
    rnd = random.Random(seed)
    x0, y0, z0 = c
    for i in range(max(3, int(n * lod))):
        a = rnd.uniform(0, TAU)
        d = rnd.uniform(0, spread)
        bx, bz = x0 + math.cos(a) * d, z0 + math.sin(a) * d
        hh = h * rnd.uniform(0.6, 1.2)
        lean = (rnd.uniform(-0.35, 0.35), rnd.uniform(-0.35, 0.35))
        tip = (bx + lean[0], y0 + hh, bz + lean[1])
        # a flat, tapered blade (two-sided strip)
        path = bez((bx, y0 - 0.2, bz), tip, (lean[0] * 0.3, 0, lean[1] * 0.3), 4)
        sweep(bd, path, lambda u: 0.035 * (1 - u) + 0.004, 'leaves_dark' if i % 3 else 'leaves', sides=3, cap=False, squash=0.3)
        if i % 4 == 0:   # cattail head
            sweep(bd, [tip, (tip[0] + lean[0] * 0.05, tip[1] + 0.22, tip[2] + lean[1] * 0.05)], 0.04, 'bark', sides=5)


def lily(bd, c, r=0.45, seed=0):
    rnd = random.Random(seed)
    x0, y0, z0 = c
    a0 = rnd.uniform(0, TAU)
    pts = [(x0 + math.cos(a0 + 0.25 + t * (TAU - 0.5)) * r * (1 + 0.04 * math.sin(t * 9)), y0, z0 + math.sin(a0 + 0.25 + t * (TAU - 0.5)) * r * (1 + 0.04 * math.sin(t * 9))) for t in [k / 12 for k in range(13)]]
    pts.append((x0, y0, z0))
    bd.poly(list(reversed(pts)), [((p[0] - x0) / r * 0.5 + 0.5, (p[2] - z0) / r * 0.5 + 0.5) for p in reversed(pts)], 'lily')
