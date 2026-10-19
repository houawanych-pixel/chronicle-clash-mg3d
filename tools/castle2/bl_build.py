"""Build the Sky Citadel v2 in Blender from castle.pkl, then save .blend and export GLB.
Run: /opt/bpyenv/bin/python bl_build.py"""
import bpy, bmesh, pickle, math, os, sys
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
TEX = os.path.join(HERE, 'tex')
OUT = os.path.join(HERE, 'out')
os.makedirs(OUT, exist_ok=True)
PKL = os.environ.get('PKL', 'castle.pkl')
NAME = os.environ.get('NAME', '')
data = pickle.load(open(os.path.join(HERE, PKL), 'rb'))

# reset scene without read_homefile
for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)
for me in list(bpy.data.meshes):
    bpy.data.meshes.remove(me)

TILE = {'panel': (4.0, 3.0), 'stone': (4.0, 3.0), 'floor': (4.0, 3.0), 'gold': (2.0, 1.42), 'crystal': (3.0, 3.0), 'rock': (8.0, 8.0), 'dark': (4.0, 4.0)}
TEXNAME = {'panel': 'stone', 'stone': 'stone', 'floor': 'stone', 'gold': 'gold', 'crystal': 'crystal', 'rock': 'rock'}


def G2B(p):
    # game (x, y up, z front) -> Blender (x, -z, y); glTF export maps it back
    return (p[0], -p[2], p[1])


def img(name):
    path = os.path.join(TEX, name)
    im = bpy.data.images.get(name) or bpy.data.images.load(path)
    return im


def make_mat(key):
    m = bpy.data.materials.new('CC_castle_' + key)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes['Principled BSDF']
    if key == 'dark':
        bsdf.inputs['Base Color'].default_value = (0.03, 0.04, 0.06, 1)
        bsdf.inputs['Roughness'].default_value = 0.9
        return m
    t = TEXNAME[key]
    a = nt.nodes.new('ShaderNodeTexImage'); a.image = img(f'CC_castle_{t}_albedo.png')
    n = nt.nodes.new('ShaderNodeTexImage'); n.image = img(f'CC_castle_{t}_normal.png'); n.image.colorspace_settings.name = 'Non-Color'
    nm = nt.nodes.new('ShaderNodeNormalMap'); nm.inputs['Strength'].default_value = 1.0
    tint = {'stone': (0.70, 0.66, 0.58), 'floor': (0.78, 0.68, 0.52), 'panel': (0.40, 0.42, 0.50)}.get(key)
    if tint:
        mix = nt.nodes.new('ShaderNodeMix'); mix.data_type = 'RGBA'; mix.blend_type = 'MULTIPLY'
        mix.inputs['Factor'].default_value = 1.0
        mix.inputs['B'].default_value = (*tint, 1)
        nt.links.new(a.outputs['Color'], mix.inputs['A'])
        nt.links.new(mix.outputs['Result'], bsdf.inputs['Base Color'])
    else:
        nt.links.new(a.outputs['Color'], bsdf.inputs['Base Color'])
    nt.links.new(n.outputs['Color'], nm.inputs['Color'])
    nt.links.new(nm.outputs['Normal'], bsdf.inputs['Normal'])
    bsdf.inputs['Roughness'].default_value = {'panel': 0.9, 'stone': 0.85, 'floor': 0.8, 'gold': 0.35, 'crystal': 0.15, 'rock': 0.95}[key]
    bsdf.inputs['Metallic'].default_value = 0.85 if key == 'gold' else 0.0
    if key == 'crystal':
        nt.links.new(a.outputs['Color'], bsdf.inputs['Emission Color'])
        bsdf.inputs['Emission Strength'].default_value = 2.0
    return m


def uv_for(pts, mode, tile):
    import math as M
    n = Vector((0, 0, 0))
    P = [Vector(p) for p in pts]
    for i in range(len(P)):
        a, b = P[i], P[(i + 1) % len(P)]
        n += Vector(((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y)))
    if n.length > 0:
        n.normalize()
    tu, tv = tile
    if abs(n.y) > 0.7:
        return [(p.x / tu, p.z / tv) for p in P]
    if isinstance(mode, tuple):
        _, cx, cz = mode
        c = sum(P, Vector((0, 0, 0))) / len(P)
        rd = Vector((c.x - cx, 0, c.z - cz))
        if rd.length > 1e-6:
            rd.normalize()
            if abs(n.dot(rd)) < 0.5:
                mode = 'box'
    if isinstance(mode, tuple):
        _, cx, cz = mode
        r = sum(M.hypot(p.x - cx, p.z - cz) for p in P) / len(P)
        a0 = M.atan2(P[0].x - cx, P[0].z - cz)
        out = []
        for p in P:
            a = M.atan2(p.x - cx, p.z - cz)
            while a - a0 > M.pi: a -= 2 * M.pi
            while a - a0 < -M.pi: a += 2 * M.pi
            out.append((a * r / tu, p.y / tv))
        # keep u in a sane range
        k = M.floor(out[0][0])
        return [(u - k, v) for (u, v) in out]
    if abs(n.x) > abs(n.z):
        return [(p.z / tu, p.y / tv) for p in P]
    return [(p.x / tu, p.y / tv) for p in P]


def build_object(name, buckets):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new('UVMap')
    mats = []
    for key, polys in buckets.items():
        mats.append(key)
        mi = len(mats) - 1
        tile = TILE[key]
        for pts, mode in polys:
            if len(pts) < 3:
                continue
            uvs = uv_for(pts, mode, tile)
            vs = [bm.verts.new(G2B(p)) for p in pts]
            try:
                f = bm.faces.new(vs)
            except ValueError:
                continue
            f.material_index = mi
            for loop, uv in zip(f.loops, uvs):
                loop[uvl].uv = uv
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.004)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=0.002)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    for key in mats:
        me.materials.append(bpy.data.materials.get('CC_castle_' + key) or make_mat(key))
    for p in me.polygons:
        p.use_smooth = True
    return ob


vis = build_object(NAME or 'CC_castle_skycitadel', data['P'])
if NAME:
    for p in vis.data.polygons:
        p.use_smooth = False
    bpy.ops.object.select_all(action='DESELECT'); vis.select_set(True)
    for im in bpy.data.images:
        if im.size[0] > 1024:
            im.scale(1024, 1024)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, NAME + '.glb'), export_format='GLB', use_selection=True,
                              export_apply=True, export_yup=True, export_image_format='JPEG', export_jpeg_quality=80)
    print('prop exported', NAME)
    sys.exit(0)
# smooth by angle (keeps hard edges on architecture)
bpy.context.view_layer.objects.active = vis
vis.select_set(True)
try:
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
except Exception as e:
    print('smooth by angle failed', e)
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.object.mode_set(mode='OBJECT')

# collision mesh
me = bpy.data.meshes.new('CC_castle_skycitadel_col')
bm = bmesh.new()
for pts in data['COL']:
    vs = [bm.verts.new(G2B(p)) for p in pts]
    try:
        bm.faces.new(vs)
    except ValueError:
        pass
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.004)
bmesh.ops.triangulate(bm, faces=bm.faces)
bm.to_mesh(me); bm.free()
colob = bpy.data.objects.new('CC_castle_skycitadel_col-colonly', me)
colob.data.name = 'CC_castle_skycitadel_col'
bpy.context.scene.collection.objects.link(colob)

def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)
print('VIS TRIS', tris(vis), 'COL TRIS', tris(colob))

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, 'CC_castle_skycitadel_WIP_NOT_APPROVED.blend'))
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, 'CC_castle_skycitadel.glb'), export_format='GLB',
                          use_selection=True, export_apply=True, export_yup=True)
# visual-only copy for quick viewing
bpy.ops.object.select_all(action='DESELECT'); vis.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, 'CC_castle_skycitadel_vis.glb'), export_format='GLB',
                          use_selection=True, export_apply=True, export_yup=True)
# game copies: JPEG textures (desktop 2048, phone 1024) and the collision on its own
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, 'game_skycitadel.glb'), export_format='GLB',
                          use_selection=True, export_apply=True, export_yup=True, export_image_format='JPEG', export_jpeg_quality=85)
for im in bpy.data.images:
    if im.size[0] > 1024:
        im.scale(1024, 1024)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, 'game_skycitadel_lite.glb'), export_format='GLB',
                          use_selection=True, export_apply=True, export_yup=True, export_image_format='JPEG', export_jpeg_quality=80)
bpy.ops.object.select_all(action='DESELECT'); colob.name = 'CC_castle_skycitadel_col'; colob.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, 'game_skycitadel_col.glb'), export_format='GLB',
                          use_selection=True, export_apply=True, export_yup=True, export_materials='NONE')
print('done')
