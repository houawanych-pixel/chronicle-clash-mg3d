"""Preview renders of the Frogtown v2 glb (workbench, textured) with a water plane."""
import bpy, sys, math
from mathutils import Vector
args = sys.argv[sys.argv.index('--') + 1:]
src, outp = args[0], args[1]
wy = -1.3
for ob in list(bpy.data.objects): bpy.data.objects.remove(ob, do_unlink=True)
bpy.ops.import_scene.gltf(filepath=src)
bpy.ops.mesh.primitive_plane_add(size=160, location=(0, 0, wy))
w = bpy.context.active_object
m = bpy.data.materials.new('w'); m.use_nodes = True
m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (0.16, 0.36, 0.33, 1)
w.data.materials.append(m)
sc = bpy.context.scene
sc.render.engine = 'BLENDER_WORKBENCH'; sc.display.shading.light = 'STUDIO'; sc.display.shading.color_type = 'TEXTURE'
sc.display.shading.show_cavity = True; sc.display.shading.show_shadows = True
sc.render.resolution_x = 1600; sc.render.resolution_y = 1000
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera = cam
shots = {
 'top': ((0, 0, 90), (0, 0, 0), 'ORTHO', 90),
 'aerial': ((30, -55, 40), (0, -2, 0), 'PERSP', 26),
 'plaza': ((6, -14, 5), (-6, 1, 1.5), 'PERSP', 22),     # blender coords: y = -game z
 'south': ((-14, -8, 4), (-4, -17, 2), 'PERSP', 22),
 'se': ((6, -4, 4.5), (18, -18, 2.5), 'PERSP', 22),
 'nw': ((-12, 6, 5), (-25, 20, 3), 'PERSP', 22),
}
for name, (loc, look, kind, lens) in shots.items():
    if len(args) > 2 and name not in args[2].split(','):
        continue
    cam.data.type = kind
    if kind == 'ORTHO':
        cam.data.ortho_scale = lens
    else:
        cam.data.lens = lens
    cam.location = Vector(loc)
    cam.rotation_euler = (Vector(look) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = f'{outp}_{name}.png'
    bpy.ops.render.render(write_still=True)
