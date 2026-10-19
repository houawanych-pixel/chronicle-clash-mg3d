## Stronger brick relief: height map from the albedo (mortar and cracks sink), OpenGL normal map.
import numpy as np, sys
from PIL import Image, ImageFilter
def blur(a, r):
    return np.asarray(Image.fromarray(np.clip(a * 255, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r)), float) / 255
def make(name, strength, mortar_depth=0.55, src=None):
    g = np.asarray(Image.open(src or f'tex/CC_castle_{name}_albedo.png').convert('L'), float) / 255
    base = blur(g, 30)
    hp = g - base                                  # local detail (cracks, mortar darker / lighter)
    # mortar: thin lines that differ from the brick face; find them by a strong local edge response
    e = np.abs(g - blur(g, 3))
    mortar = np.clip((blur(e, 2) - 0.02) * 14, 0, 1)
    h = 0.5 + hp * 1.2 - mortar * mortar_depth
    h = blur(np.clip(h, 0, 1), 1.5)
    # bevel the brick edges: smooth the height a little more near mortar
    h = h * 0.75 + blur(h, 4) * 0.25
    Image.fromarray((np.clip(h, 0, 1) * 255).astype(np.uint8)).save(f'tex/CC_castle_{name}_bump.png')
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    nx, ny, nz = -dx, dy, np.ones_like(h)
    L = np.sqrt(nx * nx + ny * ny + nz * nz)
    n = np.stack([(nx / L + 1) / 2, (ny / L + 1) / 2, (nz / L + 1) / 2], -1)
    Image.fromarray((n * 255).astype(np.uint8)).save(f'tex/CC_castle_{name}_normal.png')
    # raking-light preview
    ld = np.array([-0.6, 0.5, 0.62]); ld /= np.linalg.norm(ld)
    shade = np.clip((nx * ld[0] + ny * ld[1] + nz * ld[2]) / L, 0, 1)
    alb = np.asarray(Image.open(f'tex/CC_castle_{name}_albedo.png').convert('RGB'), float) / 255
    prev = alb * shade[..., None] * 1.25
    Image.fromarray((np.clip(prev, 0, 1) * 255).astype(np.uint8)).crop((0, 0, 1024, 1024)).save(f'/tmp/claude-0/sp/bump_{name}.png')
make('stone', 9.0)
make('rock', 6.0, 0.3)
make('gold', 5.0, 0.2)
