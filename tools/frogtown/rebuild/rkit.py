"""Frogtown v2 mesh kit (Blender bmesh) with UVs and textured materials.
Shapes are built from profiles, sweeps, fans and bevelled boards (no primitive
cubes / cylinders / spheres). GAME coordinates (x, y up, z); converted to Blender
(x, -z, y) when vertices are written. UVs are in metres / tile size."""
import bpy, bmesh, math, random, os
from mathutils import Vector, Matrix, noise

TAU = math.tau
TEX = os.environ.get('FROG_TEX', '/tmp/claude-0/sp/retopo/tex2')
# material: (texture base name or None, tile metres, base colour multiplier, roughness)
MATS = {
    'planks': ('frog_planks', 2.0, (1.0, 1.0, 1.0), 0.85),
    'planks_dark': ('frog_planks', 2.0, (0.62, 0.55, 0.5), 0.85),
    'thatch': ('frog_thatch', 2.6, (1.0, 1.0, 1.0), 0.95),
    'reed': ('frog_reed', 1.6, (1.0, 1.0, 1.0), 0.9),
    'bark': ('frog_bark', 1.6, (1.0, 1.0, 1.0), 0.95),
    'wood': ('frog_bark', 1.2, (0.85, 0.75, 0.65), 0.9),
    'grass': ('frog_grass', 5.0, (1.0, 1.0, 1.0), 0.95),
    'mud': ('frog_mud', 3.0, (1.0, 1.0, 1.0), 0.9),
    'leaves': ('frog_leaves', 2.4, (1.0, 1.0, 1.0), 0.9),
    'leaves_dark': ('frog_leaves', 2.4, (0.68, 0.78, 0.66), 0.9),
    'cloth': ('frog_cloth', 1.5, (1.0, 1.0, 1.0), 0.9),
    'cloth_blue': ('frog_cloth', 1.5, (0.55, 0.62, 1.25), 0.9),
    'shell': ('frog_shell', 1.0, (1.0, 1.0, 1.0), 0.45),
    'rope': ('frog_reed', 0.6, (0.9, 0.8, 0.6), 0.9),
    'stone': ('frog_mud', 2.0, (1.5, 1.45, 1.4), 0.9),
    'lantern': (None, 1.0, (1.0, 0.78, 0.42), 0.6),
    'dark': (None, 1.0, (0.05, 0.06, 0.05), 1.0),
    'water': (None, 1.0, (0.2, 0.45, 0.42), 0.15),
    'lily': ('frog_leaves', 0.8, (0.8, 1.05, 0.8), 0.6),
}
EMIT = {'lantern': 3.0}


def B(p):
    return Vector((p[0], -p[2], p[1]))


_mats = {}
_imgs = {}


def material(key):
    if key in _mats:
        return _mats[key]
    tex, tile, mult, rough = MATS[key]
    m = bpy.data.materials.new('CC_frog2_' + key)
    m.use_nodes = True
    m.use_backface_culling = False
    nt = m.node_tree
    bsdf = nt.nodes['Principled BSDF']
    bsdf.inputs['Roughness'].default_value = rough
    if tex:
        path = f'{TEX}/{tex}_albedo.png'
        im = _imgs.get(path) or bpy.data.images.load(path)
        _imgs[path] = im
        a = nt.nodes.new('ShaderNodeTexImage')
        a.image = im
        if mult != (1.0, 1.0, 1.0):
            mix = nt.nodes.new('ShaderNodeMix')
            mix.data_type = 'RGBA'
            mix.blend_type = 'MULTIPLY'
            mix.inputs['Factor'].default_value = 1.0
            mix.inputs['B'].default_value = (*mult, 1)
            nt.links.new(a.outputs['Color'], mix.inputs['A'])
            nt.links.new(mix.outputs['Result'], bsdf.inputs['Base Color'])
        else:
            nt.links.new(a.outputs['Color'], bsdf.inputs['Base Color'])
        npath = f'{TEX}/{tex}_normal.png'
        if os.environ.get('FROG_NORMALS', '1') == '1' and os.path.exists(npath):
            nim = _imgs.get(npath) or bpy.data.images.load(npath)
            _imgs[npath] = nim
            nim.colorspace_settings.name = 'Non-Color'
            n = nt.nodes.new('ShaderNodeTexImage')
            n.image = nim
            nm = nt.nodes.new('ShaderNodeNormalMap')
            nt.links.new(n.outputs['Color'], nm.inputs['Color'])
            nt.links.new(nm.outputs['Normal'], bsdf.inputs['Normal'])
    else:
        bsdf.inputs['Base Color'].default_value = (*mult, 1)
    if key in EMIT:
        bsdf.inputs['Emission Color'].default_value = (*mult, 1)
        bsdf.inputs['Emission Strength'].default_value = EMIT[key]
    _mats[key] = m
    return m


class Builder:
    """One mesh object; faces carry a material and UVs."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new('UVMap')
        self.mats = []
        self.tris = 0

    def mi(self, key):
        if key not in self.mats:
            self.mats.append(key)
        return self.mats.index(key)

    def poly(self, pts, uvs, key):
        try:
            vs = [self.bm.verts.new(B(p)) for p in pts]
            f = self.bm.faces.new(vs)
        except ValueError:
            return None
        f.material_index = self.mi(key)
        for l, uv in zip(f.loops, uvs):
            l[self.uv].uv = uv
        self.tris += len(pts) - 2
        return f

    def grid(self, rows, uvrows, key, close_u=False, flip=False):
        """rows[k][i] points; uvrows same shape. Quads between consecutive rows."""
        n = len(rows[0])
        m = n if close_u else n - 1
        for k in range(len(rows) - 1):
            for i in range(m):
                j = (i + 1) % n
                q = [rows[k][i], rows[k][j], rows[k + 1][j], rows[k + 1][i]]
                u = [uvrows[k][i], uvrows[k][j] if j else (uvrows[k][n - 1][0] + (uvrows[k][n - 1][0] - uvrows[k][n - 2][0]), uvrows[k][0][1]),
                     uvrows[k + 1][j] if j else (uvrows[k + 1][n - 1][0] + (uvrows[k + 1][n - 1][0] - uvrows[k + 1][n - 2][0]), uvrows[k + 1][0][1]),
                     uvrows[k + 1][i]]
                if flip:
                    q.reverse()
                    u.reverse()
                self.poly(q, u, key)

    def finish(self, smooth_angle=None, up_keys=('planks', 'planks_dark', 'grass', 'mud', 'lily', 'water')):
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=0.0005)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        up_idx = {self.mats.index(k) for k in up_keys if k in self.mats}
        for f in self.bm.faces:
            f.normal_update()
            if f.material_index in up_idx and f.normal.z < -0.7:
                f.normal_flip()
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        for k in self.mats:
            me.materials.append(material(k))
        for p in me.polygons:
            p.use_smooth = smooth_angle is not None
        return ob


def tile(key):
    return MATS[key][1]

# ---------------------------------------------------------------- generic shapes


def lathe(bd, prof, key, at=(0, 0, 0), segs=16, a0=0.0, a1=TAU, wobble=0.0, seed=0, cap_top=False, flip=False, rjit=None):
    """Surface of revolution. prof [(r, y)] bottom->top. UV: u = arc length, v = profile length."""
    rnd = random.Random(seed)
    full = abs(a1 - a0 - TAU) < 1e-6
    count = segs if full else segs + 1
    jit = [1.0 + rnd.uniform(-wobble, wobble) for _ in range(count)]
    t = tile(key)
    rows, uvs = [], []
    vacc = 0.0
    for k, (r, y) in enumerate(prof):
        if k:
            vacc += math.hypot(r - prof[k - 1][0], y - prof[k - 1][1])
        ring, ur = [], []
        rr0 = max(r, 0.05)
        for i in range(count):
            a = a0 + (a1 - a0) * i / segs
            rr = r * jit[i] * (rjit(i, k) if rjit else 1.0)
            ring.append((at[0] + math.cos(a) * rr, at[1] + y, at[2] + math.sin(a) * rr))
            ur.append(((a - a0) * rr0 / t, vacc / t))
        rows.append(ring)
        uvs.append(ur)
    bd.grid(rows, uvs, key, close_u=full, flip=not flip)
    if cap_top and prof[-1][0] > 1e-3:
        top = rows[-1]
        bd.poly(list(reversed(top)) if not flip else top, [((p[0] - at[0]) / t, (p[2] - at[2]) / t) for p in (reversed(top) if not flip else top)], key)
    return rows


def frames(path):
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


def sweep(bd, path, radius, key, sides=6, cap=True, squash=1.0, twist=0.0):
    fr = frames(path)
    t = tile(key)
    rows, uvs = [], []
    vacc = 0.0
    for k, (p, tg, n, b) in enumerate(fr):
        if k:
            vacc += (p - fr[k - 1][0]).length
        u_ = k / max(1, len(fr) - 1)
        r = radius(u_) if callable(radius) else radius
        ring, ur = [], []
        for i in range(sides):
            a = i / sides * TAU + twist * u_
            v = p + n * math.cos(a) * r + b * math.sin(a) * r * squash
            ring.append((v.x, v.y, v.z))
            ur.append((i / sides * TAU * max(r, 0.04) / t, vacc / t))
        rows.append(ring)
        uvs.append(ur)
    bd.grid(rows, uvs, key, close_u=True)
    if cap:
        for ring, rev in ((rows[0], True), (rows[-1], False)):
            pts = list(reversed(ring)) if rev else ring
            bd.poly(pts, [((p[0]) / t, (p[2]) / t) for p in pts], key)


def bez(a, b, bend=(0, 0, 0), n=8):
    A, Bv = Vector(a), Vector(b)
    M = (A + Bv) * 0.5 + Vector(bend)
    return [tuple(A * (1 - s) ** 2 + M * 2 * s * (1 - s) + Bv * s * s) for s in [i / n for i in range(n + 1)]]


def board(bd, c, size, key, yaw=0.0, bevel=0.025, seed=0, sag=0.0, along='z'):
    """Bevelled board (8-sided section lofted along local z). UV: v along the board."""
    rnd = random.Random(seed)
    sx, sy, sz = size
    hx, hy, hz = sx / 2, sy / 2, sz / 2
    e = min(bevel, hx * 0.45, hy * 0.45)
    prof = [(-hx + e, -hy), (hx - e, -hy), (hx, -hy + e), (hx, hy - e), (hx - e, hy), (-hx + e, hy), (-hx, hy - e), (-hx, -hy + e)]
    cy, sn = math.cos(yaw), math.sin(yaw)
    t = tile(key)
    rows, uvs = [], []
    steps = 2
    for k in range(steps + 1):
        z = -hz + sz * k / steps
        dyy = -sag * math.sin(math.pi * k / steps)
        ring, ur = [], []
        acc = 0.0
        for j, (x, y) in enumerate(prof):
            if j:
                acc += math.hypot(x - prof[j - 1][0], y - prof[j - 1][1])
            ring.append((c[0] + x * cy + z * sn, c[1] + y + dyy, c[2] - x * sn + z * cy))
            ur.append((acc / t, (z + hz) / t + seed * 0.37))
        rows.append(ring)
        uvs.append(ur)
    bd.grid(rows, uvs, key, close_u=True)
    for ring in (list(reversed(rows[0])), rows[-1]):
        bd.poly(ring, [(0, 0)] * len(ring), key)


def fan_shell(bd, at, radius, key, ribs=11, spread=150.0, depth=0.35, tilt=0.0, yaw=0.0, thick=0.05, steps=6):
    nu = ribs * 4
    rows_t, rows_b, uv = [], [], []
    for s in range(steps + 1):
        v = s / steps
        rt, rb, uvr = [], [], []
        for i in range(nu + 1):
            u = i / nu
            ang = math.radians(-spread / 2 + spread * u)
            corr = 1.0 + 0.035 * v * math.cos(u * ribs * TAU)
            r = radius * v * corr
            p = Vector((math.sin(ang) * r, depth * radius * (v ** 1.6) * (0.6 + 0.4 * math.cos(ang)) + 0.03 * radius * v * math.cos(u * ribs * TAU), math.cos(ang) * r))
            p = Matrix.Rotation(math.radians(tilt), 3, 'X') @ p
            p = Matrix.Rotation(yaw, 3, 'Y') @ p
            q = p + Vector((0, -thick, 0))
            rt.append((at[0] + p.x, at[1] + p.y, at[2] + p.z))
            rb.append((at[0] + q.x, at[1] + q.y, at[2] + q.z))
            uvr.append((u * ribs * 0.5, v))
        rows_t.append(rt)
        rows_b.append(rb)
        uv.append(uvr)
    bd.grid(rows_t, uv, key, flip=True)
    bd.grid(rows_b, uv, key)


def blob(bd, at, radius, key, squash=0.7, seed=0, detail=2, amp=0.28, droop=0.0):
    """Organic lumpy cluster (leaf clumps, bushes, hummocks): a displaced geodesic
    shell with a flattened underside. UV: box-projected."""
    tmp = bmesh.new()
    bmesh.ops.create_icosphere(tmp, subdivisions=detail, radius=1.0)
    rnd = random.Random(seed)
    off = Vector((rnd.uniform(-50, 50), rnd.uniform(-50, 50), rnd.uniform(-50, 50)))
    t = tile(key)
    pts = {}
    for v in tmp.verts:
        d = v.co.normalized()
        n_ = noise.noise(d * 1.7 + off) * 0.6 + noise.noise(d * 3.9 + off) * 0.4
        r = radius * (1.0 + amp * n_)
        y = d.z * r * squash
        if y < 0:
            y *= 0.45          # flatter underside
        y -= droop * max(0.0, 1.0 - abs(d.z)) * radius * 0.4
        pts[v.index] = (at[0] + d.x * r, at[1] + y, at[2] - d.y * r)
    for f in tmp.faces:
        ps = [pts[v.index] for v in f.verts]
        uvs = [((p[0] + p[2] * 0.7) / t, (p[1] + p[2] * 0.3) / t) for p in ps]
        bd.poly(ps, uvs, key)
    tmp.free()


def ring_flat(bd, at, r0, r1, y, key, segs=48, radial_boards=True, a0=0.0, a1=TAU, up=True):
    """Flat annulus (or disc if r0 == 0). UV: boards run radially (gaps along the radius)."""
    t = tile(key)
    full = abs(a1 - a0 - TAU) < 1e-6
    cnt = segs if full else segs + 1
    rows, uvs = [], []
    for r in (r0, r1):
        ring, ur = [], []
        for i in range(cnt):
            a = a0 + (a1 - a0) * i / segs
            ring.append((at[0] + math.cos(a) * r, y, at[2] + math.sin(a) * r))
            if radial_boards:
                ur.append((r / t, (a - a0) * (r0 + r1) * 0.5 / t))
            else:
                ur.append(((at[0] + math.cos(a) * r) / t, (at[2] + math.sin(a) * r) / t))
        rows.append(ring)
        uvs.append(ur)
    bd.grid(rows, uvs, key, close_u=full, flip=up)
