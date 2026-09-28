import numpy as np,json,trimesh
from scipy.spatial import cKDTree
from scipy.ndimage import median_filter,binary_closing,binary_dilation,distance_transform_edt
from pathlib import Path
root=Path(__file__).resolve().parents[1]
selected=[[0,1,2,3,4,8],[0,1,2,4,5],[0,1,2,3,5],[0,1,2,3],[0,2,3,4,5],[0,1,2]]
for stage in range(1,7):
 a=np.load(root/f'build_support/grid{stage}.npz'); h=a['h']; coords=a['coords'];N=len(coords)
 comps=[];visited=set()
 for x,z in zip(*np.where(np.isfinite(h))):
  if (x,z) in visited:continue
  visited.add((x,z));comp=[(int(x),int(z))];q=0
  while q<len(comp):
   u,v=comp[q];q+=1
   for dx,dz in [(1,0),(-1,0),(0,1),(0,-1)]:
    c,e=u+dx,v+dz
    if not(0<=c<N and 0<=e<N) or (c,e) in visited:continue
    if np.isfinite(h[c,e]) and abs(h[c,e]-h[u,v])<.65:comp.append((c,e));visited.add((c,e))
  comps.append(comp)
 comps.sort(key=len,reverse=True)
 groups=[np.array(comps[k]) for k in selected[stage-1]]
 mask=np.zeros_like(h,bool)
 for g in groups:mask[g[:,0],g[:,1]]=True
 # Connect disconnected generated thresholds with explicit ramps. Prefer short horizontal links.
 connected=groups[0];remaining=groups[1:];bridges=[]
 while remaining:
  best=None
  for gi,g in enumerate(remaining):
   ds,idx=cKDTree(connected*.5).query(g*.5,k=1)
   rise=abs(h[g[:,0],g[:,1]]-h[connected[idx,0],connected[idx,1]])
   cost=ds+rise*1.3
   k=int(np.argmin(cost));item=(float(cost[k]),gi,connected[idx[k]],g[k])
   if best is None or item[0]<best[0]:best=item
  _,gi,p,q=best; y0=h[tuple(p)];y1=h[tuple(q)];direction=(q-p).astype(float);distance=np.linalg.norm(direction);direction/=max(distance,1)
  # Extend into both floors to keep steep broken step joins below a 40 degree slope.
  extra=max(2,(abs(y1-y0)/.65-distance*.5)/1.)
  start=p-direction*extra;end=q+direction*extra
  a3=[float(coords[0]+start[0]*.5),float(y0+.12),float(coords[0]+start[1]*.5)]
  b3=[float(coords[0]+end[0]*.5),float(y1+.12),float(coords[0]+end[1]*.5)]
  bridges.append([a3,b3])
  for x in range(max(0,int(min(start[0],end[0])-3)),min(N,int(max(start[0],end[0])+4))):
   for z in range(max(0,int(min(start[1],end[1])-3)),min(N,int(max(start[1],end[1])+4))):
    t=np.clip(np.dot(np.array([x,z])-start,end-start)/max(np.sum((end-start)**2),.1),0,1)
    if np.linalg.norm(np.array([x,z])-(start+t*(end-start)))<=2.5:
     mask[x,z]=True;h[x,z]=(1-t)*y0+t*y1+.06
  connected=np.concatenate([connected,remaining.pop(gi)])
 # Expand collision footprint half a meter for capsule clearance; keep navigation centered on original floor.
 nav_mask=mask.copy()
 expanded=binary_dilation(mask,iterations=1)
 _,nearest=distance_transform_edt(~mask,return_indices=True)
 h[expanded & ~mask]=h[tuple(nearest[:,expanded & ~mask])]
 mask=expanded
 # Build cell-centered tiles, weld/smooth vertices. Edge walls constrain to visible floor footprint.
 cells=np.argwhere(mask); vh={}; count={}
 for x,z in cells:
  for u,v in [(x,z),(x+1,z),(x,z+1),(x+1,z+1)]:
   vh[u,v]=vh.get((u,v),0)+h[x,z];count[u,v]=count.get((u,v),0)+1
 for k in vh:vh[k]/=count[k]
 verts=[];faces=[];walls=[]
 def vtx(k):return [float(coords[0]+k[0]*.5-.25),float(vh[k]+.10),float(coords[0]+k[1]*.5-.25)]
 for x,z in cells:
  corners=[(x,z),(x+1,z),(x+1,z+1),(x,z+1)];ps=[vtx(k) for k in corners];off=len(verts);verts.extend(ps);faces.extend([[off,off+2,off+1],[off,off+3,off+2]])
  for ni,(dx,dz) in enumerate([(0,-1),(1,0),(0,1),(-1,0)]):
   nx,nz=x+dx,z+dz
   if 0<=nx<N and 0<=nz<N and mask[nx,nz]:continue
   a,b=ps[ni],ps[(ni+1)%4];walls.append([a,b])
 json.dump({'step':.5,'offset':float(coords[0]),'size':N,'cells':[[int(x),int(z),round(float(h[x,z]+.12),3)] for x,z in np.argwhere(nav_mask)],'bridges':bridges,'walls':walls},open(root/f'assets/stages/nav{stage}.json','w'))
 mesh=trimesh.Trimesh(vertices=verts,faces=faces,process=True);mesh.export(root/f'assets/stages/floor{stage}.glb')
 print(stage,len(cells),'bridges',bridges)
