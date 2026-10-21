import bpy, math, sys
from mathutils import Vector
for ob in list(bpy.data.objects): bpy.data.objects.remove(ob, do_unlink=True)
bpy.ops.import_scene.gltf(filepath='/tmp/claude-0/sp/frog/out/frogtown.glb')
sc=bpy.context.scene
sc.render.engine='BLENDER_WORKBENCH'; sc.display.shading.light='STUDIO'; sc.display.shading.color_type='TEXTURE'
cam=bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera=cam
def shot(name, loc, look, ortho=None, res=(1600,1600), lens=28):
    sc.render.resolution_x, sc.render.resolution_y = res
    if ortho: cam.data.type='ORTHO'; cam.data.ortho_scale=ortho
    else: cam.data.type='PERSP'; cam.data.lens=lens
    cam.location=loc; d=Vector(look)-Vector(loc); cam.rotation_euler=d.to_track_quat('-Z','Y').to_euler()
    sc.render.filepath=f'/tmp/claude-0/sp/frog/v_{name}.png'; bpy.ops.render.render(write_still=True)
# blender coords: x, y(=-z game), z up
shot('top', (0,0,60), (0,0,0), ortho=100, res=(2000,2000))
# obliques per quadrant from the plaza looking out (game quadrant names)
for name,(gx,gz) in {'nw':(-20,-18),'n':(-3,-22),'e':(16,-9),'w':(-30,-8),'sw':(-16,4),'s':(-4,16),'se':(16,18)}.items():
    # camera from plaza side, raised
    cx,cz=gx*0.35,gz*0.35
    shot(name,(cx,-cz,9),(gx,-gz,-1.5),res=(1400,900),lens=24)
