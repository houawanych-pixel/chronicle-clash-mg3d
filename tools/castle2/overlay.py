import sys
from PIL import Image, ImageChops
import numpy as np
G='/tmp/claude-0/sp/ortho/guides/CC_castle_%s_guides.png'; C='/tmp/claude-0/sp/ortho/clean/CC_castle_%s_clean.png'
out=sys.argv[1] if len(sys.argv)>1 else 'overlay'
tiles=[]
for v in ['front','back','left','right','top','bottom']:
    g=Image.open(G%v).convert('RGB'); n=Image.open(f'shots/{v}.png').convert('RGB')
    o=Image.blend(g,n,0.5); o.save(f'{out}_{v}.png')
    # silhouette compare
    bg=np.array([0.93*255]*3)
    mo=np.abs(np.asarray(Image.open(C%v).convert('RGB'),float)-bg).sum(2)>18
    mn=np.abs(np.asarray(n,float)-bg).sum(2)>18
    s=np.full(mo.shape+(3,),255,np.uint8); s[mo&mn]=(150,150,150); s[mo&~mn]=(220,40,40); s[~mo&mn]=(40,90,230)
    iou=(mo&mn).sum()/max(1,(mo|mn).sum())
    print(v,'overlap %.0f%%'%(iou*100),'missing %.0f%%'%(100*(mo&~mn).sum()/max(1,mo.sum())),'extra %.0f%%'%(100*(~mo&mn).sum()/max(1,mn.sum())))
    tiles.append((Image.blend(g,n,0.5).resize((640,640)),Image.fromarray(s).resize((640,640))))
sheet=Image.new('RGB',(640*6,1280),'white')
for i,(a,b) in enumerate(tiles): sheet.paste(a,(i*640,0)); sheet.paste(b,(i*640,640))
sheet.save(f'{out}_sheet.png')
