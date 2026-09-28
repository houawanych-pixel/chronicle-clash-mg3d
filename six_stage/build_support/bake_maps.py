import os
os.environ['PYOPENGL_PLATFORM']='egl'
import numpy as np,trimesh,pyrender,json
from pathlib import Path
from PIL import Image,ImageDraw
from scipy.ndimage import label
root=Path(__file__).resolve().parents[1]; out=root/'assets/stages'
r=pyrender.OffscreenRenderer(900,900)
for i,p in enumerate(sorted(out.glob('*.glb'))):
 s=trimesh.load(p,force='scene',process=False)
 # Meter scale: each stage is 64m wide, with original vertical proportions.
 s.apply_scale(64)
 scene=pyrender.Scene.from_trimesh_scene(s,bg_color=[.025,.045,.065,1],ambient_light=[.7,.7,.7])
 pose=np.eye(4);pose[:3,:3]=[[1,0,0],[0,0,1],[0,-1,0]];pose[:3,3]=[0,70,0]
 scene.add(pyrender.OrthographicCamera(xmag=34,ymag=34,znear=.01,zfar=100),pose=pose)
 scene.add(pyrender.DirectionalLight(color=np.ones(3),intensity=1.5),pose=pose)
 color,depth=r.render(scene)
 im=Image.fromarray(color);d=ImageDraw.Draw(im)
 for v in range(-30,31,5):
  px=(v+34)/68*900
  d.line((px,0,px,900),fill=(75,100,105),width=1);d.text((px+2,15),str(v),fill='white')
  d.line((0,px,900,px),fill=(75,100,105),width=1);d.text((10,px+2),str(v),fill='white')
 im.save(root/f'build_support/map{i+1}.png')
 # Ray hits include lower floors as well as wall tops. Clearance pruning keeps navigable floors.
 mesh=s.to_mesh()
 step=.5; coords=np.arange(-33.75,34,step); xx,zz=np.meshgrid(coords,coords,indexing='ij')
 origins=np.c_[xx.ravel(),np.full(xx.size,60.),zz.ravel()]; dirs=np.tile([0,-1,0],(len(origins),1))
 loc,ray,tri=mesh.ray.intersects_location(origins,dirs,multiple_hits=True)
 order=np.lexsort((-loc[:,1],ray));loc,ray,tri=loc[order],ray[order],tri[order]
 hits={}
 for pos,ri,ti in zip(loc,ray,tri): hits.setdefault(int(ri),[]).append((float(pos[1]),float(mesh.face_normals[ti,1])))
 heights=np.full(xx.shape,np.nan)
 for ri,hs in hits.items():
  for j,(y,n) in enumerate(hs):
   # Highest upward face with 1.65m headroom. Skip vertical/underside faces.
   above=next((ay for ay,an in reversed(hs[:j]) if ay-y>.10),100)
   if n>.65 and above-y>1.65:
    heights.flat[ri]=y;break
 # Components with <0.65m height differences; isolated props/wall tops are excluded.
 comps=[];visited=set()
 for x,z in zip(*np.where(np.isfinite(heights))):
  if (x,z) in visited:continue
  visited.add((x,z)); comp=[(x,z)];q=0
  while q<len(comp):
   a,b=comp[q];q+=1
   for dx,dz in [(1,0),(-1,0),(0,1),(0,-1)]:
    c,e=a+dx,b+dz
    if c<0 or e<0 or c>=len(coords) or e>=len(coords) or (c,e) in visited:continue
    if np.isfinite(heights[c,e]) and abs(heights[c,e]-heights[a,b])<.65:
     comp.append((c,e));visited.add((c,e))
  comps.append(comp)
 comps.sort(key=len,reverse=True)
 print(i+1,mesh.bounds.tolist(),'components',[(len(c),np.round(np.mean([heights[a,b] for a,b in c]),2)) for c in comps[:12]],flush=True)
 np.savez(root/f'build_support/grid{i+1}.npz',h=heights,coords=coords)
 colors=['#5dfbc4','#eacf62','#8daaff','#ff8aa9','#ae73ef','#ffffff']
 for k,c in enumerate(comps[:6]):
  for a,b in c:
   px=(coords[a]+34)/68*900;pz=(coords[b]+34)/68*900
   d.ellipse((px-2,pz-2,px+2,pz+2),fill=colors[k])
 im.save(root/f'build_support/nav{i+1}.png')
r.delete()
