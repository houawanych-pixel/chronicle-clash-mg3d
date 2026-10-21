import bpy, sys, math
from mathutils import Vector
path=sys.argv[sys.argv.index('--')+1]; out=sys.argv[sys.argv.index('--')+2]; spread=float(sys.argv[sys.argv.index('--')+3])
for ob in list(bpy.data.objects): bpy.data.objects.remove(ob, do_unlink=True)
bpy.ops.import_scene.gltf(filepath=path)
obs=[o for o in bpy.data.objects if o.type=='MESH']
cols=4
for i,o in enumerate(obs):
    o.location=((i%cols)*spread, -(i//cols)*spread, 0)
sc=bpy.context.scene; sc.render.engine='BLENDER_WORKBENCH'; sc.display.shading.light='STUDIO'; sc.display.shading.color_type='MATERIAL'
sc.display.shading.show_cavity=True
sc.render.resolution_x=1600; sc.render.resolution_y=1100
cam=bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera=cam
rows=(len(obs)+cols-1)//cols
c=Vector(((cols-1)*spread/2, -(rows-1)*spread/2, 1.5))
cam.location=c+Vector((0,-spread*rows*1.1-4, spread*rows*0.75+3)); cam.data.lens=35
cam.rotation_euler=(c-cam.location).to_track_quat('-Z','Y').to_euler()
sc.render.filepath=out; bpy.ops.render.render(write_still=True)
