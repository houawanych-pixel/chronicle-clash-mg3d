import bpy, sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
for ob in list(bpy.data.objects): bpy.data.objects.remove(ob, do_unlink=True)
from rkit import *
from pieces import *
bd = Builder('test')
o = {'x': 0, 'z': 0, 'r': 9.0, 'y': 0.2}
island(bd, o, entries=(0.0,))
hut(bd, (-2.5, 0.32, -1.5), 3.0, math.radians(60), seed=1)
lodge(bd, (3.2, 0.32, 3.0), 4.5, 6.0, math.radians(-30), seed=2)
tree(bd, (4.0, 0.32, -4.5), 7.0, 2.6, seed=3)
boardwalk(bd, [(9.0, 0.0), (20.0, 0.0)], 0.42, 0.42, lanterns=True)
for i in range(6): reeds(bd, (10.5 + i * 1.6, -3.3, 2.6 + (i % 2)), seed=i)
for i in range(8): lily(bd, (12 + i * 0.9, -3.28, -2.5 - (i % 3) * 0.8), seed=i)
ob = bd.finish()
print('TRIS', bd.tris)
sc = bpy.context.scene
sc.render.engine = 'BLENDER_WORKBENCH'; sc.display.shading.light = 'STUDIO'; sc.display.shading.color_type = 'TEXTURE'
sc.display.shading.show_cavity = True
sc.render.resolution_x = 1400; sc.render.resolution_y = 900
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera = cam
cam.data.lens = 28
from mathutils import Vector
for name, loc, look in [('a', (14, -16, 9), (3, 0, 1.5)), ('b', (-8, 12, 4), (0, 0, 2.5))]:
    cam.location = Vector(loc); cam.rotation_euler = (Vector(look) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = f'/tmp/claude-0/sp/retopo/piece_{name}.png'; bpy.ops.render.render(write_still=True)
