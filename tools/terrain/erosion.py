import numpy as np
from numba import njit

@njit(cache=True)
def _grad(h, x, y):
    n = h.shape[0]
    ix = int(x); iy = int(y)
    fx = x - ix; fy = y - iy
    a = h[iy, ix]; b = h[iy, ix + 1]; c = h[iy + 1, ix]; d = h[iy + 1, ix + 1]
    gx = (b - a) * (1 - fy) + (d - c) * fy
    gy = (c - a) * (1 - fx) + (d - b) * fx
    z = a * (1 - fx) * (1 - fy) + b * fx * (1 - fy) + c * (1 - fx) * fy + d * fx * fy
    return gx, gy, z

@njit(cache=True)
def hydraulic(h, protect, n_drops, seed, cell,
              inertia=0.05, capacity=4.0, min_slope=0.01, deposit=0.3, erode=0.3,
              evaporate=0.015, gravity=4.0, max_steps=80, radius=3):
    """Droplet erosion (Lague-style). h in metres, cell = metres per pixel.
    protect: 0..1 per pixel, 1 = no erosion (water bodies, roads)."""
    np.random.seed(seed)
    n = h.shape[0]
    # brush
    offs = []
    ws = []
    tot = 0.0
    for dy in range(-radius, radius + 1):
        for dx in range(-radius, radius + 1):
            dd = np.sqrt(dx * dx + dy * dy)
            if dd <= radius:
                w = radius - dd
                offs.append((dx, dy)); ws.append(w); tot += w
    for i in range(len(ws)):
        ws[i] /= tot
    for _ in range(n_drops):
        x = np.random.random() * (n - 3) + 1
        y = np.random.random() * (n - 3) + 1
        dx = 0.0; dy = 0.0; speed = 1.0; water = 1.0; sed = 0.0
        for _s in range(max_steps):
            ix = int(x); iy = int(y)
            fx = x - ix; fy = y - iy
            gx, gy, z = _grad(h, x, y)
            gx /= cell; gy /= cell
            dx = dx * inertia - gx * (1 - inertia)
            dy = dy * inertia - gy * (1 - inertia)
            l = np.sqrt(dx * dx + dy * dy)
            if l == 0:
                break
            dx /= l; dy /= l
            x += dx; y += dy
            if x < 1 or y < 1 or x >= n - 2 or y >= n - 2:
                break
            if protect[int(y), int(x)] > 0.85:
                break
            _, _, nz = _grad(h, x, y)
            dz = nz - z
            cap = max(-dz / cell, min_slope) * speed * water * capacity
            p = 1.0 - protect[iy, ix]
            if sed > cap or dz > 0:
                amt = min(dz, sed) if dz > 0 else (sed - cap) * deposit
                sed -= amt
                h[iy, ix] += amt * (1 - fx) * (1 - fy)
                h[iy, ix + 1] += amt * fx * (1 - fy)
                h[iy + 1, ix] += amt * (1 - fx) * fy
                h[iy + 1, ix + 1] += amt * fx * fy
            else:
                amt = min((cap - sed) * erode, -dz) * p
                for k in range(len(offs)):
                    ox, oy = offs[k]
                    xx = ix + ox; yy = iy + oy
                    if xx >= 0 and yy >= 0 and xx < n and yy < n:
                        e = amt * ws[k] * (1.0 - protect[yy, xx])
                        h[yy, xx] -= e
                        sed += e
            speed = np.sqrt(max(speed * speed - dz * gravity, 0.0))
            water *= (1 - evaporate)
    return h

@njit(cache=True)
def thermal(h, protect, cell, talus_deg=38.0, iters=40, rate=0.25):
    n = h.shape[0]
    t = np.tan(talus_deg * np.pi / 180.0) * cell
    for _ in range(iters):
        d = np.zeros_like(h)
        for y in range(1, n - 1):
            for x in range(1, n - 1):
                hc = h[y, x]
                for oy in (-1, 0, 1):
                    for ox in (-1, 0, 1):
                        if ox == 0 and oy == 0:
                            continue
                        dist = 1.4142 if (ox != 0 and oy != 0) else 1.0
                        diff = hc - h[y + oy, x + ox]
                        if diff > t * dist:
                            m = (diff - t * dist) * rate * 0.125 * (1 - protect[y, x])
                            d[y, x] -= m
                            d[y + oy, x + ox] += m
        h += d
    return h
