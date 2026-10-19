"""Band footprints of the old sky ruin (game size): clean polygons per height band.
Writes massing.pkl: list of (y0, y1, MultiPolygon) in game x/z metres."""
import numpy as np, pickle
from scipy import ndimage as nd
from skimage import measure
from shapely.geometry import Polygon, MultiPolygon
from shapely.ops import unary_union

occ = np.load('/tmp/occ.npy')          # [ix, iy, iz] at 0.5 m
org = np.load('/tmp/occ_org.npy')
P = 0.5
EDGES = [0, 4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48, 52, 56, 59, 62, 66, 70, 74, 77, 80, 84, 88, 92, 96, 100, 104,
         108, 112, 116, 119, 123, 127, 131, 135, 139, 141]


def band_mask(y0, y1):
    j0 = int(round((y0 - org[1]) / P)); j1 = int(round((y1 - org[1]) / P))
    j0 = max(j0, 0); j1 = min(max(j1, j0 + 1), occ.shape[1])
    # a cell is solid in the band if it is solid in at least 40% of the band's layers
    frac = occ[:, j0:j1, :].mean(axis=1)
    m = frac >= 0.4
    m = nd.binary_closing(m, iterations=2)
    m = nd.binary_opening(m, iterations=1)
    from skimage.morphology import remove_small_holes
    m = remove_small_holes(m, area_threshold=int(40 / (P * P)))
    lab, n = nd.label(m)
    sizes = nd.sum(m, lab, range(1, n + 1))
    keep = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s * P * P >= 5.0])
    g = nd.gaussian_filter(keep.astype(float), 1.2)
    return g


def polys(g, tol=0.7):
    pad = np.pad(g, 2)
    out = []
    for c in measure.find_contours(pad, 0.5):
        c = measure.approximate_polygon(c, tolerance=tol / P)
        if len(c) < 4:
            continue
        pts = [(org[0] + (i - 2) * P, org[2] + (k - 2) * P) for i, k in c]
        pg = Polygon(pts)
        if not pg.is_valid:
            pg = pg.buffer(0)
        pg = pg.buffer(-0.55, join_style=2).buffer(0.0)
        if pg.area >= 5.0:
            out.append(pg)
    u = unary_union(out)
    if isinstance(u, Polygon):
        u = MultiPolygon([u])
    return u


bands = []
for y0, y1 in zip(EDGES[:-1], EDGES[1:]):
    g = band_mask(y0, y1)
    mp = polys(g)
    bands.append((y0, y1, mp))
    print(y0, y1, 'parts', len(mp.geoms), 'area %.0f' % mp.area, 'x %.1f..%.1f z %.1f..%.1f' % (mp.bounds[0], mp.bounds[2], mp.bounds[1], mp.bounds[3]) if not mp.is_empty else '')
pickle.dump(bands, open('massing.pkl', 'wb'))
