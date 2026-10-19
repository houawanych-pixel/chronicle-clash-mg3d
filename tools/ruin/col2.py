## Ruin collision for the 2x route: scale x2, keep only what is near the route
## (walls beside walkways, the core), drop the ruin floor under our walkways.
import trimesh, numpy as np, json, math
R=json.load(open('route.json'))
m=trimesh.load('/tmp/skyruin_col_1x.glb',force='mesh')
m.apply_scale(2.0)
C=m.triangles_center
boxes=[]   # (center, basis rows (3x3), half) oriented boxes
def obox(c,yaw,pitch,half):
    cy,sy=math.cos(yaw),math.sin(yaw); cp,sp=math.cos(pitch),math.sin(pitch)
    # local axes: x right, y up, z along (forward)
    fwd=np.array([sy*cp, sp, cy*cp]); right=np.array([cy,0,-sy]); up=np.cross(fwd,right)
    return (np.array(c,float), np.array([right,up,fwd]), np.array(half,float))
def inside(b,P):
    c,Bm,h=b; l=(P-c)@Bm.T; return np.all(np.abs(l)<h,axis=1)
near=[]; clear=[]
for p in R["pieces"]:
    if p["type"]=="walk":
        a=np.array(p["a"]); b=np.array(p["b"]); d=b-a; L=math.hypot(d[0],d[2]); w=p["width"]
        yaw=math.atan2(d[0],d[2]); pitch=math.atan2(d[1],L) if abs(d[1])>=0.25 else 0.0
        mid=(a+b)/2; rl=math.hypot(L,d[1])
        clear.append(obox(mid-[0,0.2,0],yaw,pitch,[w/2+0.15,0.8,rl/2+0.3]))
        near.append(obox(mid+[0,2.0,0],yaw,0,[w/2+7,8,L/2+7]))
    elif p["type"] in ("slab","pad"):
        c=np.array(p["pos"]); s=p["size"]
        clear.append(obox(c-[0,0.2,0],0,0,[s[0]/2+0.15,0.8,s[2]/2+0.15]))
        near.append(obox(c+[0,2.0,0],0,0,[s[0]/2+7,8,s[2]/2+7]))
for l in R["ladders"]:
    b=np.array(l["bottom"]); t=np.array(l["top"]); c=(b+t)/2
    near.append(obox(c,0,0,[5,(t[1]-b[1])/2+4,5]))
near.append(obox([0,112,-2],0,0,[22,10,16]))   # the core
keep=np.zeros(len(C),bool)
for b in near: keep|=inside(b,C)
drop=np.zeros(len(C),bool)
for b in clear: drop|=inside(b,C)
sel=keep&~drop
out=trimesh.Trimesh(m.vertices,m.faces[sel],process=False); out.remove_unreferenced_vertices()
out.export('/home/claude/chronicle-clash-mg3d/assets/ruin/skyruin_col.glb')
print('faces',len(C),'near',keep.sum(),'cleared',(keep&drop).sum(),'kept',sel.sum())
