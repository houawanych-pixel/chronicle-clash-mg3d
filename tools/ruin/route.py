## Exterior climbing route for the 2x sky ruin -> route.json (+ trimmed collision).
import numpy as np, json, math, os, sys
os.environ['RUIN']='/tmp/ruin2.glb'
from check import *
from ladders import ladder_ok
SIL=np.load('/tmp/sil.npy')
def sil(theta_deg, y):
    a=int(((theta_deg%360)//3)); ys=range(max(0,int(y)-1), min(140,int(y)+5))
    return float(max(SIL[yy][(a+k)%120] for yy in ys for k in range(-6,7)))
def at(theta, r, y):
    t=math.radians(theta); return [r*math.sin(t), y, r*math.cos(t)]
R3=lambda p:[round(float(v),3) for v in p]
pieces=[]; bot=[]; ladders=[]; barriers=[]; knights=[]; problems=[]
def slab(p,size,trim=True,kind="slab"): pieces.append({"type":kind,"pos":R3(p),"size":size,"trim":trim})
def walk(a,b,w=3.2):
    pieces.append({"type":"walk","a":R3(a),"b":R3(b),"width":w})
    e1=walk_clear(a,b,heights=(0.6,1.3,2.0)); e2=head_clear(a,b,2.3)
    if e1 or e2: problems.append(("walk",R3(a),R3(b),e1[:2],e2[:2]))
def B(act,**k): d={"act":act}; d.update({kk:(R3(v) if isinstance(v,list) else v) for kk,v in k.items()}); bot.append(d)
def jump_step(b_end, a_end, nxt_a, nxt_b):
    d=np.array(b_end)-np.array(a_end); d[1]=0; d/=np.linalg.norm(d)
    take=list(np.array(b_end)-d*0.4); land=list(np.array(nxt_a)+(np.array(nxt_b)-np.array(nxt_a))*0.2)
    frm=list(np.array(b_end)-d*2.6)
    B("jump",p=take,to=land,**{"from":frm})

def plan_tier(th0, th1, y0, y1, chunk=11.0, gap=2.4, margin=2.2):
    ths=np.arange(th0, th1+0.01, 1.0)
    ylin=lambda t: y0+(y1-y0)*(t-th0)/(th1-th0)
    rs=np.array([sil(t, ylin(t))+margin for t in ths])
    from scipy.ndimage import maximum_filter1d, uniform_filter1d
    rs=uniform_filter1d(maximum_filter1d(rs,31,mode='nearest'),31,mode='nearest')
    rs=np.maximum(rs,[sil(t, ylin(t))+1.6 for t in ths])
    P=[at(t,r,ylin(t)) for t,r in zip(ths,rs)]
    L=[0.0]
    for i in range(1,len(P)): L.append(L[-1]+math.dist(P[i-1][::2],P[i][::2]))
    L=np.array(L); total=L[-1]
    def point(s):
        i=min(max(int(np.searchsorted(L,s)),1),len(L)-1)
        f=(s-L[i-1])/max(1e-6,L[i]-L[i-1]); return [P[i-1][k]+(P[i][k]-P[i-1][k])*f for k in range(3)]
    s=0.0; chunks=[]
    while s < total-0.5:
        e=min(total, s+chunk); chunks.append((point(s), point(e))); s=e+gap
    chunks[-1][1][1]=chunks[-1][0][1]   # last ledge flat: it meets the ladder foot cleanly
    return chunks, total
def tier(th0, th1, y0, y1, name, sec, pads=(1,3)):
    chunks,total=plan_tier(th0,th1,y0,y1)
    for i,(a,b) in enumerate(chunks):
        walk(a,b)
        if i in pads:
            m=[(a[j]+b[j])/2 for j in range(3)]
            L_=math.dist(a,b); u=[(b[j]-a[j])/L_ for j in range(3)]
            pieces.append({"type":"pad","a":R3([m[j]-u[j]*2.5 for j in range(3)]),"b":R3([m[j]+u[j]*2.5 for j in range(3)]),"size":[5.0,0.6,5.0],"pos":R3(m)})
            knights.append({"sec":sec,"pos":R3([m[0],m[1]+0.2,m[2]])})
        if i==0: B("walk",p=a)
        if i<len(chunks)-1: jump_step(b,a,chunks[i+1][0],chunks[i+1][1])
        else: B("walk",p=b)
    print(name,'chunks',len(chunks),'arc',round(total,1))
    return chunks

def ladder_pillar(end, prev, y_top, next_start=None):
    d=[end[0]-prev[0],0,end[2]-prev[2]]; n=math.hypot(d[0],d[2]); d=[d[0]/n,0,d[2]/n]
    rn=math.hypot(end[0],end[2]); rad=[end[0]/rn,0,end[2]/rn]
    for out in (0,1.5,3.0,4.5,6.0):
        E=[end[0]+rad[0]*out,end[1],end[2]+rad[2]*out]
        P=[E[0]+d[0]*3.0, y_top, E[2]+d[2]*3.0]
        bottom=[E[0]+d[0]*1.45, end[1], E[2]+d[2]*1.45]
        r=ladder_ok(bottom,P,d)
        bad=r['shaft'] or r['stepoff'] or walk_clear(end,[E[0]+d[0]*1.6,end[1],E[2]+d[2]*1.6])
        if next_start and not bad: bad=walk_clear(P,next_start)
        if not bad: break
    if bad: problems.append(("ladder",out,bad))
    pieces.append({"type":"pillar","pos":R3([P[0],end[1]-6.0,P[2]]),"top":y_top,"size":2.6})
    slab([P[0],y_top,P[2]],[3.6,0.6,3.6])
    if out>0: walk(end,E)
    walk(E,[E[0]+d[0]*1.6,end[1],E[2]+d[2]*1.6])
    ladders.append({"bottom":R3(bottom),"top":R3(P),"face":R3(d)})
    barriers.append({"pos":R3([E[0]+d[0]*0.25,end[1]+2.0,E[2]+d[2]*0.25]),"size":[3.6,4.0,0.4],"face":R3(d)})
    if out>0: B("walk",p=E)
    B("walk",p=[E[0]+d[0]*0.9,end[1],E[2]+d[2]*0.9])
    B("ladder",i=len(ladders)-1)
    return P

spawns=[]; goals=[]
# ---- 0 dock (stealth) + broken bridge
DOCK_Y=52.0
r0=sil(0,56)+2.2
first=at(0,r0,56.0)
dock=[0,DOCK_Y,first[2]+44.0]
slab(dock,[26,1.2,18]); pieces.append({"type":"dock_dressing","pos":R3(dock)})
z0=dock[2]-9.0; z1=first[2]+3.0
slab([0,56.0,first[2]+1.0],[6.0,0.6,4.0])
gaps=[[z0-11.0,z0-13.6],[z0-23.0,z0-25.6]]
pieces.append({"type":"bridge","z0":z0,"z1":z1,"y0":DOCK_Y,"y1":56.0,"gaps":gaps})
barriers.append({"pos":R3([0,DOCK_Y+2.0,z0-0.4]),"size":[5.4,4.0,0.4],"face":[0,0,-1]})
spawns.append(R3([0,DOCK_Y+0.3,dock[2]+5])); goals.append("Take out the dock guards")
for dx,dz in [(-7,-2),(7,-5),(0,-6.5)]: knights.append({"sec":0,"pos":R3([dx,DOCK_Y+0.2,dock[2]+dz]),"patrol":True})
B("walk",p=[0,DOCK_Y,z0-1.0])
ybr=lambda z: DOCK_Y+(56.0-DOCK_Y)*(z0-z)/(z0-z1)
for g in gaps: B("jump",p=[0,ybr(g[0]),g[0]+0.4],to=[0,ybr(g[1]),g[1]-1.2])
B("walk",p=[0,56.0,z1-1.5])
# ---- tiers
T=[("tier0",  0, 118, 56.0, 62.0, 1, "Cross the bridge and run the first ring"),
   ("tier1",128, 238, 74.0, 80.0, 2, "Climb and run the second ring"),
   ("tier2",248, 352, 92.0, 104.0, 3, "Climb to the third ring")]
tops=[74.0, 92.0, 119.4]
tier_starts=[]
for idx,((name,a0,a1,y0,y1,sec,goal),yt) in enumerate(zip(T,tops)):
    if idx>0:
        # previous ladder top -> this tier start walk was added; spawn here
        pass
    ch=tier(a0,a1,y0,y1,name,sec)
    if idx==0: spawns.append(R3([first[0],DOCK_Y+0.3+0,dock[2]-6]))  # bridge checkpoint on the dock side
    goals.append(goal)
    end=ch[-1][1]; prev=ch[-1][0]
    nxt=plan_tier(*T[idx+1][1:5])[0][0][0] if idx<2 else None
    P=ladder_pillar(end,prev,yt,next_start=nxt)
    if nxt:
        walk(P,nxt); B("walk",p=nxt)
        spawns.append(R3([P[0],yt+0.3,P[2]]))
    else:
        last_top=P
# ---- 4 sky stair (helix in front of the crown), crown
SUM0=119.4; CROWN_Y=139.0
spawns.append(R3([last_top[0],SUM0+0.3,last_top[2]])); goals.append("Run the sky stair to the crown")
HC=[0.0,0.0,27.0]; HR=10.0
h_start_ang=0.0   # angle measured around HC, 0 = +z (outer side)
entry=[HC[0]+HR*math.sin(0),SUM0,HC[2]+HR*math.cos(0)]
walk(last_top,entry); B("walk",p=entry)
segs=[]; ang=0.0; y=SUM0; seg_deg=32.0; gap_deg=13.0
NR=12; unit=(CROWN_Y-SUM0)/NR; rise=unit*0.8; gap_rise=unit*0.2
for i in range(NR+1):
    y2=y+rise if i<NR else y      # the last ledge is flat, level with the crown
    a_=[HC[0]+HR*math.sin(math.radians(ang)),y,HC[2]+HR*math.cos(math.radians(ang))]
    ang2=ang+seg_deg
    b_=[HC[0]+HR*math.sin(math.radians(ang2)),y2,HC[2]+HR*math.cos(math.radians(ang2))]
    segs.append((a_,b_)); ang=ang2+gap_deg; y=y2+gap_rise
for i,(a_,b_) in enumerate(segs):
    walk(a_,b_,3.0)
    if i<len(segs)-1: jump_step(b_,a_,segs[i+1][0],segs[i+1][1])
B("walk",p=segs[-1][1])
top_end=segs[-1][1]
print('helix segments',len(segs),'turns',round(ang/360,2),'end',R3(top_end))
# landing + bridge to the crown
land=[top_end[0],CROWN_Y,top_end[2]]
slab(land,[5.0,0.6,5.0],trim=False,kind="pad")
knights.append({"sec":4,"pos":R3([land[0],CROWN_Y+0.2,land[2]])})
crown_edge=[0,CROWN_Y,12.2]
walk(land,crown_edge,3.2); B("walk",p=crown_edge)
slab([0,CROWN_Y,9.4],[11.0,0.6,5.6])
knights.append({"sec":4,"pos":R3([2.5,CROWN_Y+0.2,9.6])})
spawns.append(R3([0,CROWN_Y+0.3,10.5])); goals.append("Clear the crown. Drop through the eye")
# the eye seal: a glowing wall along the crown's inner edge
barriers.append({"pos":[0,CROWN_Y+2.0,6.75],"size":[11.0,4.0,0.4],"face":[0,0,-1]})
B("walk",p=[0,CROWN_Y,8.0])
B("drop",p=[0,CROWN_Y,3.0],to=[0,105.0,3.0])
# ---- 5 core
CORE_Y=105.0
slab([0,CORE_Y,-2.0],[36,0.6,22])
spawns.append(R3([0,CORE_Y+0.3,6.0])); goals.append("Defeat the Dark Knight")
EYE=[-5.0,5.0,-1.0,7.0]   # x0,x1,z0,z1 of the open shaft over the core
# ---- validate the eye shaft
for x in (-3.5,0,3.5):
    for z in (0.5,3.0,5.5):
        r=ray([x,CROWN_Y-0.5,z],[0,-1,0],40)
        if r is None or abs((CROWN_Y-0.5-r)-CORE_Y)>0.8: problems.append(("eye",x,z,r))
# pads clear of the ruin (inner edges)
for p in pieces:
    if p["type"]=="pad":
        c=p["pos"]; s=p["size"][0]/2
        for dx,dz in [(s,s),(s,-s),(-s,s),(-s,-s)]:
            if head_clear([c[0]+dx,c[1],c[2]+dz],[c[0]+dx,c[1],c[2]+dz],2.3,1): problems.append(("pad",c,dx,dz))
route={"pieces":pieces,"ladders":ladders,"barriers":barriers,"bot":bot,"spawns":spawns,"goals":goals,
       "knights":knights,"dock":R3(dock),"core_y":CORE_Y,"crown_y":CROWN_Y,"eye":EYE}
json.dump(route,open('route.json','w'),indent=1)
print('pieces',len(pieces),'ladders',len(ladders),'knights',len(knights),'bot',len(bot),'sections',len(spawns))
print('spawns',spawns)
print('PROBLEMS',len(problems)); [print(' ',p) for p in problems]
