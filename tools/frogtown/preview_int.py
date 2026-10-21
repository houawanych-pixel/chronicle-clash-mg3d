import bpy, sys, math
from mathutils import Vector
a=sys.argv[sys.argv.index('--')+1:]
for ob in list(bpy.data.objects): bpy.data.objects.remove(ob, do_unlink=True)
bpy.ops.import_scene.gltf(filepath=a[0])
for o in bpy.data.objects:
    if o.name.startswith('col'): o.hide_render=True
sc=bpy.context.scene; sc.render.engine='BLENDER_WORKBENCH'; sc.display.shading.light='STUDIO'; sc.display.shading.color_type='MATERIAL'; sc.display.shading.show_cavity=True
sc.render.resolution_x=1400; sc.render.resolution_y=900
cam=bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera=cam
cam.data.lens=16
# from just inside the door (game +z = blender -y), eye height
cam.location=Vector((0.3, -float(a[2]), 1.9))
cam.rotation_euler=(Vector((0,1.0,0.6))-cam.location).to_track_quat('-Z','Y').to_euler()
# hide roof faces? clip by camera is fine
sc.render.filepath=a[1]; bpy.ops.render.render(write_still=True)
