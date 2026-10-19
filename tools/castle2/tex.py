import numpy as np
from PIL import Image, ImageFilter
def seamless(a, ax_x=True, ax_y=True):
    H,W=a.shape[:2]; out=a.copy()
    def mk(n):
        t=np.linspace(0,1,n); m=np.clip(np.minimum(t,1-t)*4,0,1); return m*m*(3-2*m)
    if ax_x:
        r=np.roll(out,W//2,axis=1); m=mk(W)[None,:,None]; out=out*m+r*(1-m)
    if ax_y:
        r=np.roll(out,H//2,axis=0); m=mk(H)[:,None,None]; out=out*m+r*(1-m)
    return out
spec={ # name: crop box (x,y,w,h), seamless x?, seamless y?
 'stone':((5,5,632,474),False,False),
 'gold':((0,0,868,616),False,False),
 'rock':((0,0,639,640),False,True),
 'crystal':((0,0,720,720),True,True)}
for n,(box,sx,sy) in spec.items():
    im=Image.open(f'ref/{n}.jpg').convert('RGB')
    x,y,w,h=box; h=min(h,720-y)
    a=np.asarray(im.crop((x,y,x+w,y+h)),float)
    a=seamless(a,sx,sy)
    img=Image.fromarray(np.clip(a,0,255).astype(np.uint8)).resize((2048,2048),Image.LANCZOS)
    img.save(f'tex/CC_castle_{n}_albedo.png')
    g=np.asarray(img.convert('L'),float)/255
    # bump: dark mortar/cracks; high-pass + soft
    blur=np.asarray(Image.fromarray((g*255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(40)),float)/255
    hp=np.clip(0.5+(g-blur)*1.6,0,1)
    if n=='crystal': hp=1-hp*0.6
    b=Image.fromarray((hp*255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))
    b.save(f'tex/CC_castle_{n}_bump.png')
    h_=np.asarray(b,float)/255; s=4.0
    dx=(np.roll(h_,-1,1)-np.roll(h_,1,1))*s; dy=(np.roll(h_,-1,0)-np.roll(h_,1,0))*s
    nx=-dx; ny=dy; nz=np.ones_like(h_); L=np.sqrt(nx*nx+ny*ny+nz*nz)
    nm=np.stack([(nx/L+1)/2,(ny/L+1)/2,(nz/L+1)/2],-1)
    Image.fromarray((nm*255).astype(np.uint8)).save(f'tex/CC_castle_{n}_normal.png')
# atlas 2x2 at 2048: stone TL, gold TR, crystal BL, rock BR
for k in ['albedo','normal','bump']:
    at=Image.new('RGB' if k!='bump' else 'L',(2048,2048))
    for n,(px,py) in {'stone':(0,0),'gold':(1024,0),'crystal':(0,1024),'rock':(1024,1024)}.items():
        at.paste(Image.open(f'tex/CC_castle_{n}_{k}.png').resize((1024,1024),Image.LANCZOS),(px,py))
    at.save(f'tex/CC_castle_atlas_{k}.png')
# tiling check sheet
chk=Image.new('RGB',(2048,512))
for i,n in enumerate(['stone','gold','crystal','rock']):
    t=Image.open(f'tex/CC_castle_{n}_albedo.png').resize((256,256))
    for a in range(2):
        for b in range(2): chk.paste(t,(i*512+a*256,b*256))
chk.save('tex_check.png')
