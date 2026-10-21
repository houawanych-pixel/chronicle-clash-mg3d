"""Small mesh kit for Frogtown props and interiors (Blender bpy/bmesh).
Shapes are lathed profiles, swept tubes, fans and bevelled planks - no plain
primitive cubes/cylinders. Coordinates are GAME space (x, y up, z) and are
converted to Blender (x, -z, y) when vertices are made; glTF export maps back."""
import bpy, bmesh, math, random
from mathutils import Vector, Matrix

PAL = {
    'wood': (0.48, 0.33, 0.21), 'wood_dark': (0.29, 0.19, 0.12), 'wood_light': (0.66, 0.50, 0.33),
    'thatch': (0.71, 0.60, 0.29), 'thatch_dark': (0.52, 0.44, 0.20), 'moss': (0.35, 0.50, 0.22),
    'reed': (0.62, 0.62, 0.36), 'shell': (0.94, 0.89, 0.78), 'shell_pink': (0.93, 0.74, 0.66),
    'stone': (0.50, 0.50, 0.47), 'cloth_teal': (0.18, 0.50, 0.53), 'cloth_blue': (0.14, 0.25, 0.48),
    'gold': (0.85, 0.71, 0.36), 'hide': (0.80, 0.68, 0.50), 'rope': (0.70, 0.58, 0.38),
    'lantern': (1.0, 0.78, 0.42), 'fire': (1.0, 0.55, 0.15), 'paper': (0.93, 0.88, 0.74),
    'mat': (0.58, 0.55, 0.30), 'pot': (0.25, 0.24, 0.24), 'red': (0.62, 0.22, 0.16), 'leaf': (0.30, 0.55, 0.30),
    'water': (0.25, 0.55, 0.55), 'bone': (0.90, 0.86, 0.74), 'sky': (0.62, 0.80, 0.86),
}
EMIT = {'lantern': 2.5, 'fire': 4.0, 'sky': 0.35}


def B(p):
    return Vector((p[0], -p[2], p[1]))


class Builder:
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.mats = []

    def mi(self, key):
        if key not in self.mats:
            self.mats.append(key)
        return self.mats.index(key)

    def face(self, pts, key):
        vs = [self.bm.verts.new(B(p)) for p in pts]
        try:
            f = self.bm.faces.new(vs)
            f.material_index = self.mi(key)
            return f
        except ValueError:
            return None

    def grid(self, rows, key, close_u=False):
        """rows: list of rings/lines of points (same length). Quads between them."""
        n = len(rows[0])
        vr = [[self.bm.verts.new(B(p)) for p in r] for r in rows]
        idx = self.mi(key)
        m = n if close_u else n - 1
        for a in range(len(vr) - 1):
            for i in range(m):
                j = (i + 1) % n
                q = [vr[a][i], vr[a][j], vr[a + 1][j], vr[a + 1][i]]
                try:
                    f = self.bm.faces.new(q)
                    f.material_index = idx
                except ValueError:
                    pass
        return vr

    def finish(self, smooth=False):
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=0.0005)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        for k in self.mats:
            me.materials.append(material(k))
        for p in me.polygons:
            p.use_smooth = smooth
        return ob


_mat_cache = {}


def material(key):
    if key in _mat_cache:
        return _mat_cache[key]
    m = bpy.data.materials.new('CC_frog_' + key)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    c = PAL[key]
    b.inputs['Base Color'].default_value = (*c, 1)
    b.inputs['Roughness'].default_value = 0.85
    if key in EMIT:
        b.inputs['Emission Color'].default_value = (*c, 1)
        b.inputs['Emission Strength'].default_value = EMIT[key]
    if key == 'shell':
        b.inputs['Roughness'].default_value = 0.35
    if key == 'gold':
        b.inputs['Metallic'].default_value = 0.8
        b.inputs['Roughness'].default_value = 0.35
    _mat_cache[key] = m
    return m


# ---------------------------------------------------------------- shapes

def lathe(bd, prof, key, at=(0, 0, 0), segs=16, cap_top=True, cap_bot=False, wobble=0.0, seed=0, twist=0.0, sx=1.0, sz=1.0):
    """prof: [(radius, y)] bottom->top. Optional wobble (organic), twist (spiral), squash."""
    rnd = random.Random(seed)
    jit = [1.0 + rnd.uniform(-wobble, wobble) for _ in range(segs)]
    rows = []
    for k, (r, y) in enumerate(prof):
        ring = []
        for i in range(segs):
            a = i / segs * math.tau + twist * k
            rr = r * jit[i]
            ring.append((at[0] + math.cos(a) * rr * sx, at[1] + y, at[2] + math.sin(a) * rr * sz))
        rows.append(ring)
    bd.grid(rows, key, close_u=True)
    if cap_top and prof[-1][0] > 1e-4:
        bd.face(list(reversed(rows[-1])), key)
    if cap_bot and prof[0][0] > 1e-4:
        bd.face(rows[0], key)
    return rows


def frame_along(path):
    """Tangent frames (t, n, b) along a polyline path (game coords)."""
    P = [Vector(p) for p in path]
    out = []
    up = Vector((0, 1, 0))
    for i, p in enumerate(P):
        t = (P[min(i + 1, len(P) - 1)] - P[max(i - 1, 0)]).normalized()
        ref = up if abs(t.dot(up)) < 0.95 else Vector((1, 0, 0))
        n = t.cross(ref).normalized()
        b = n.cross(t).normalized()
        out.append((p, t, n, b))
    return out


def sweep(bd, path, radius, key, sides=6, cap=True, flat=1.0):
    """Tube along a path; radius is a float or function(u 0..1)."""
    fr = frame_along(path)
    rows = []
    for k, (p, t, n, b) in enumerate(fr):
        u = k / max(1, len(fr) - 1)
        r = radius(u) if callable(radius) else radius
        ring = []
        for i in range(sides):
            a = i / sides * math.tau
            v = p + n * math.cos(a) * r + b * math.sin(a) * r * flat
            ring.append((v.x, v.y, v.z))
        rows.append(ring)
    bd.grid(rows, key, close_u=True)
    if cap:
        bd.face(list(reversed(rows[0])), key)
        bd.face(rows[-1], key)


def curve(a, b, bend=(0, 0, 0), n=8):
    """Quadratic bezier from a to b, pulled by 'bend' at the middle."""
    A, Bv = Vector(a), Vector(b)
    M = (A + Bv) * 0.5 + Vector(bend)
    pts = []
    for i in range(n + 1):
        t = i / n
        p = A * (1 - t) ** 2 + M * 2 * t * (1 - t) + Bv * t * t
        pts.append(tuple(p))
    return pts


def plank(bd, c, size, key, yaw=0.0, bevel=0.03, seed=0, sag=0.0):
    """Bevelled, slightly irregular plank (8-sided cross-section loft)."""
    rnd = random.Random(seed)
    sx, sy, sz = size
    hx, hy, hz = sx / 2, sy / 2, sz / 2
    e = min(bevel, hx * 0.4, hy * 0.4)
    prof = [(-hx + e, -hy), (hx - e, -hy), (hx, -hy + e), (hx, hy - e), (hx - e, hy), (-hx + e, hy), (-hx, hy - e), (-hx, -hy + e)]
    rows = []
    N = 4
    cy, sn = math.cos(yaw), math.sin(yaw)
    for k in range(N + 1):
        z = -hz + sz * k / N
        dz = rnd.uniform(-0.01, 0.01)
        dyy = -sag * math.sin(math.pi * k / N)
        ring = []
        for (x, y) in prof:
            lx, ly, lz = x * (1 + rnd.uniform(-0.03, 0.03)), y + dyy, z + dz
            ring.append((c[0] + lx * cy + lz * sn, c[1] + ly, c[2] - lx * sn + lz * cy))
        rows.append(ring)
    bd.grid(rows, key, close_u=True)
    bd.face(list(reversed(rows[0])), key)
    bd.face(rows[-1], key)


def fan_shell(bd, at, radius, key, ribs=11, spread=150.0, depth=0.35, tilt=0.0, yaw=0.0, thick=0.05, steps=7):
    """Scallop shell: a ribbed fan, cupped, opening along +z then tilted/yawed."""
    rows_top, rows_bot = [], []
    nu = ribs * 4
    for s in range(steps + 1):
        v = s / steps
        rt, rb = [], []
        for i in range(nu + 1):
            u = i / nu
            ang = math.radians(-spread / 2 + spread * u)
            corr = 1.0 + 0.035 * v * math.cos(u * ribs * math.tau)
            r = radius * v * corr
            x = math.sin(ang) * r
            z = math.cos(ang) * r
            y = depth * radius * (v ** 1.6) * (0.6 + 0.4 * math.cos(ang)) + 0.03 * radius * v * math.cos(u * ribs * math.tau)
            p = Vector((x, y, z))
            p = Matrix.Rotation(math.radians(tilt), 3, 'X') @ p
            p = Matrix.Rotation(yaw, 3, 'Y') @ p
            q = p + Vector((0, -thick, 0))
            rt.append((at[0] + p.x, at[1] + p.y, at[2] + p.z))
            rb.append((at[0] + q.x, at[1] + q.y, at[2] + q.z))
        rows_top.append(rt)
        rows_bot.append(list(rb))
    bd.grid(rows_top, key)
    bd.grid([list(reversed(r)) for r in rows_bot], key)
    # rim strip
    bd.grid([rows_top[-1], rows_bot[-1]], key)


def disc_planks(bd, at, r_in, r_out, n, key, gap=0.02, thick=0.08, seed=0):
    """Round floor of radial plank wedges."""
    rnd = random.Random(seed)
    for i in range(n):
        a0 = i / n * math.tau + gap
        a1 = (i + 1) / n * math.tau - gap
        y = at[1] + rnd.uniform(-0.01, 0.01)
        pts_top = []
        for a in (a0, a1):
            pts_top.append((at[0] + math.cos(a) * r_in, y, at[2] + math.sin(a) * r_in))
        for a in (a1, (a0 + a1) / 2, a0):
            pts_top.append((at[0] + math.cos(a) * r_out, y, at[2] + math.sin(a) * r_out))
        top = pts_top
        bot = [(p[0], p[1] - thick, p[2]) for p in top]
        bd.face(top[::-1], key)
        for k in range(len(top)):
            j = (k + 1) % len(top)
            bd.face([top[k], top[j], bot[j], bot[k]], key)


def catenary(a, b, sag, n=10):
    A, Bv = Vector(a), Vector(b)
    pts = []
    for i in range(n + 1):
        t = i / n
        p = A.lerp(Bv, t)
        p.y -= sag * 4 * t * (1 - t)
        pts.append(tuple(p))
    return pts
