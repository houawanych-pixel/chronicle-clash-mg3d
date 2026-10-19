from check import *
import numpy as np
def ladder_ok(b,t,face):
    b=np.array(b,float); t=np.array(t,float); f=np.array(face,float)
    out={}
    out['shaft']=shaft_clear(b[0],b[2],b[1],t[1]+1.9,0.3)
    # step-off at the top: from above the bottom point to the landing
    out['stepoff']=walk_clear([b[0],t[1],b[2]],[t[0],t[1],t[2]],heights=(0.4,1.1,1.8))
    out['top_floor']=floor(t[0],t[2],t[1]+0.5)
    out['wall_dist']=ray([b[0],b[1]+1.0,b[2]],list(f),3)
    return out
if __name__=='__main__':
    import sys
    for line in sys.stdin:
        line=line.strip()
        if line: print(line,'=>',eval(line))
