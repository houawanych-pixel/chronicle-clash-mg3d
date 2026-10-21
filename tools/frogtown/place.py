import numpy as np, json
d=np.load('/tmp/claude-0/sp/frog/out/grid.npz'); h=d['h']+3.5
def idx(x,z): return int(round((-z+50)/0.5)), int(round((x+50)/0.5))
def H(x,z):
    j,i=idx(x,z)
    return h[j,i] if 0<=j<h.shape[0] and 0<=i<h.shape[1] else np.nan
def flat(x,z,r=1.0):
    vs=[H(x+dx,z+dz) for dx in np.arange(-r,r+.01,.5) for dz in np.arange(-r,r+.01,.5)]
    vs=np.array(vs); 
    return (not np.isnan(vs).any()) and vs.max()-vs.min()<0.35, float(np.nanmedian(vs))
houses={"H01":(-26,-20),"H02":(-7,-24.5),"H03":(-2,-23),"H04":(12,-15),"H05":(15,-9.5),"H06":(20,-7.5),"H07":(-17,5),"H08":(-4,15),"H09":(-3.5,22),"H10":(16.5,18)}
P=np.array([-4.3,-4.3])
res={}
for k,(cx,cz) in houses.items():
    best=None
    for a in np.arange(0,360,5):
        dx,dz=np.cos(np.radians(a)),np.sin(np.radians(a))
        r=1.0; 
        while r<10:
            x,z=cx+dx*r,cz+dz*r
            ok,y=flat(x,z,0.75)
            if ok and -0.7<y<0.9: break
            r+=0.25
        if r>=10: continue
        x,z=cx+dx*r,cz+dz*r
        dist_p=np.hypot(x-P[0],z-P[1])
        score=r*1.0+dist_p*0.15
        if best is None or score<best[0]: best=(score,x,z,a,r)
    s,x,z,a,r=best
    ok,y=flat(x,z,0.75)
    res[k]={"center":[cx,cz],"door":[round(x,2),round(y,2),round(z,2)],"dir":[round(-np.cos(np.radians(a)),3),round(-np.sin(np.radians(a)),3)],"r":r}
    print(k,res[k])
# plaza + features
for name,(x,z) in {"plaza":(-4.3,-4.3),"dais":(-4.3,-10.5),"board":(2,-3),"drum":(-9.5,-1),"center_ring":(-4.3,-4.3),"pN":(-4,-9),"pE":(1.5,-4),"pW":(-10,-4),"pS":(-4,1.5)}.items():
    print(name, flat(x,z,1.0), H(x,z))
# walkway extremities: cells y in (-.6,.6) far out
ys,xs_=np.where((h>-0.6)&(h<0.6))
X=xs_*0.5-50; Z=-(ys*0.5-50)
for nm,v in {"E":X,"W":-X,"S":Z,"N":-Z,"SE":(X+Z),"SW":(Z-X),"NE":(X-Z),"NW":(-X-Z)}.items():
    i=np.argmax(v); print("far",nm, X[i],Z[i])
json.dump(res,open('/tmp/claude-0/sp/frog/out/doors.json','w'),indent=1)
