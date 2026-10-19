import trimesh, numpy as np, sys, json
import os
m=trimesh.load(os.environ.get('RUIN','/tmp/ruin_m.glb'),force='mesh'); R=m.ray
def ray(o,d,maxd):
    loc,ri,ti=R.intersects_location(np.array([o],float),np.array([d],float),multiple_hits=False)
    if len(loc)==0: return None
    dist=np.linalg.norm(loc[0]-o); return dist if dist<=maxd else None
def floor(x,z,y):  # nearest floor at or below y+1
    loc,ri,ti=R.intersects_location(np.array([[x,y+1.0,z]]),np.array([[0,-1,0]]),multiple_hits=True)
    ys=sorted([L[1] for L,t in zip(loc,ti) if m.face_normals[t][1]>0.5 and L[1]<=y+1.0],reverse=True)
    return ys[0] if ys else None
def walk_clear(a,b,heights=(0.6,1.3,2.0)):
    a=np.array(a,float); b=np.array(b,float); bad=[]
    for h in heights:
        for off in (-0.9,0,0.9):
            d=b-a; L=np.linalg.norm(d); u=d/L; side=np.array([-u[2],0,u[0]])
            o=a+side*off+[0,h,0]; e=b+side*off+[0,h,0]; dd=e-o
            r=ray(o,dd/np.linalg.norm(dd),np.linalg.norm(dd))
            if r is not None: bad.append((h,off,round(r,1)))
    return bad
def head_clear(a,b,need=2.3,n=8):
    a=np.array(a,float); b=np.array(b,float); bad=[]
    for t in np.linspace(0,1,n):
        p=a+(b-a)*t; r=ray(p+[0,0.1,0],[0,1,0],need)
        if r is not None: bad.append((round(t,2),round(r,1)))
    return bad
def shaft_clear(x,z,y0,y1,rad=0.5):
    bad=[]
    for dx,dz in [(0,0),(rad,0),(-rad,0),(0,rad),(0,-rad)]:
        r=ray([x+dx,y0+0.2,z+dz],[0,1,0],y1-y0-0.2)
        if r is not None: bad.append((dx,dz,round(y0+0.2+r,1)))
    return bad
if __name__=='__main__':
    for line in sys.stdin:
        line=line.strip()
        if not line or line.startswith('#'): continue
        print(line, '=>', eval(line))
