"""Frogtown: Tripo village -> game-ready tile.
Outputs (game coords, 1 unit = 1 m): frogtown.glb (desktop), frogtown_lite.glb (phone),
frogtown_col.glb (collision: 'land' + 'water' meshes), grid.npz (height + class samples)."""
import bpy, bmesh, math, os, sys, numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
OUT='/tmp/claude-0/sp/frog/out'; os.makedirs(OUT, exist_ok=True)
S=100.0
for ob in list(bpy.data.objects): bpy.data.objects.remove(ob, do_unlink=True)
bpy.ops.import_scene.gltf(filepath='/tmp/claude-0/sp/frog/frog_raw.glb')
src=[o for o in bpy.data.objects if o.type=='MESH'][0]
src.name='frog_src'
bpy.context.view_layer.objects.active=src; src.select_set(True)
src.scale=(S,S,S); bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
# base color image as numpy for classification
mat=src.data.materials[0]
img=None
for n in mat.node_tree.nodes:
    if n.type=='TEX_IMAGE' and 'Color' in n.image.name: img=n.image
W,H=img.size
px=np.array(img.pixels[:],dtype=np.float32).reshape(H,W,4)
def dup(name):
    o=src.copy(); o.data=src.data.copy(); o.name=name; bpy.context.scene.collection.objects.link(o); return o
def decimate(o, tris):
    me=o.data; cur=sum(len(p.vertices)-2 for p in me.polygons)
    m=o.modifiers.new('dec','DECIMATE'); m.ratio=min(1.0,tris/cur); m.use_collapse_triangulate=True
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active=o
    bpy.ops.object.modifier_apply(modifier='dec')
    print(o.name,'tris',sum(len(p.vertices)-2 for p in o.data.polygons))
full=dup('frogtown'); decimate(full, 110000)
lite=dup('frogtown_lite'); decimate(lite, 48000)
col=dup('col'); decimate(col, 60000)
bpy.data.objects.remove(src, do_unlink=True)
# classify collision faces: water vs land by base colour at the face UV centroid
def colour(o):
    me=o.data; uv=me.uv_layers.active.data
    out=[]
    for p in me.polygons:
        u=sum(uv[l].uv[0] for l in p.loop_indices)/p.loop_total; v=sum(uv[l].uv[1] for l in p.loop_indices)/p.loop_total
        x=int((u%1)*(W-1)); y=int((v%1)*(H-1)); out.append(px[y,x,:3])
    return np.array(out)
def is_water(c):
    r,g,b=c[...,0],c[...,1],c[...,2]
    return (b>r*1.25)&(g>r*1.15)&(b>0.18)&((b-g)>-0.12)
cc=colour(col); wm=is_water(cc)
print('water faces', wm.sum(), 'of', len(wm))
bm=bmesh.new(); bm.from_mesh(col.data); bm.faces.ensure_lookup_table()
wbm=bm.copy(); 
bmesh.ops.delete(bm, geom=[bm.faces[i] for i in range(len(wm)) if wm[i]], context='FACES')
wbm.faces.ensure_lookup_table()
bmesh.ops.delete(wbm, geom=[wbm.faces[i] for i in range(len(wm)) if not wm[i]], context='FACES')
land=bpy.data.objects.new('land', bpy.data.meshes.new('land')); bm.to_mesh(land.data); bm.free()
water=bpy.data.objects.new('water', bpy.data.meshes.new('water')); wbm.to_mesh(water.data); wbm.free()
for o in (land,water): bpy.context.scene.collection.objects.link(o)
bpy.data.objects.remove(col, do_unlink=True)
# height / class grid on the full mesh (0.5 m)
bmf=bmesh.new(); bmf.from_mesh(full.data); bmf.faces.ensure_lookup_table()
tree=BVHTree.FromBMesh(bmf)
uvl=bmf.loops.layers.uv.active
xs=np.arange(-50,50.01,0.5); n=len(xs)
hgt=np.full((n,n),np.nan,np.float32); cls=np.zeros((n,n),np.int8); rgb=np.zeros((n,n,3),np.float32)
for i,x in enumerate(xs):
    for j,y in enumerate(xs):
        loc,nor,idx,d=tree.ray_cast(Vector((x,y,50)),Vector((0,0,-1)))
        if loc is None: continue
        hgt[j,i]=loc.z
        f=bmf.faces[idx]
        u=sum(l[uvl].uv[0] for l in f.loops)/len(f.loops); v=sum(l[uvl].uv[1] for l in f.loops)/len(f.loops)
        c=px[int((v%1)*(H-1)),int((u%1)*(W-1)),:3]; rgb[j,i]=c
        cls[j,i]=1 if is_water(c) else (3 if nor.z<0.6 else 2)
# grid index [j,i]: j = blender y index, i = x index
np.savez(OUT+'/grid.npz', xs=xs, h=hgt, cls=cls, rgb=rgb)
bmf.free()
def export(objs, path, mats=True, jpeg=None):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    kw=dict(filepath=path, export_format='GLB', use_selection=True, export_apply=True, export_yup=True)
    if not mats: kw['export_materials']='NONE'
    if jpeg: kw.update(export_image_format='JPEG', export_jpeg_quality=jpeg)
    bpy.ops.export_scene.gltf(**kw)
# game copies: colour + normal only (no ORM), normal at 1024
for n in list(mat.node_tree.nodes):
    if n.type=='TEX_IMAGE' and 'ORM' in n.image.name:
        mat.node_tree.nodes.remove(n)
for im in bpy.data.images:
    if 'Normal' in im.name and im.size[0]>1024: im.scale(1024,1024)
    elif im.size[0]>2048: im.scale(2048,2048)
export([full], OUT+'/frogtown.glb', jpeg=85)
for im in bpy.data.images:
    if im.size[0]>1024: im.scale(1024,1024)
for n in list(mat.node_tree.nodes):
    if n.type in ('TEX_IMAGE','NORMAL_MAP') and 'Normal' in (n.image.name if n.type=='TEX_IMAGE' else 'Normal'):
        mat.node_tree.nodes.remove(n)
export([lite], OUT+'/frogtown_lite.glb', jpeg=80)
export([land,water], OUT+'/frogtown_col.glb', mats=False)
print('done')
