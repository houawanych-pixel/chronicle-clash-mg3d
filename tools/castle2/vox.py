## Voxel occupancy of the old sky ruin at game size (2x), 1 m: occ[y, x, z]
import trimesh, numpy as np
from scipy import ndimage as nd
m = trimesh.load('/tmp/ruin_m.glb', force='mesh')        # 1x metres design copy (uncarved)
m.apply_scale(2.0)
print(m.bounds)
P = 0.5
v = m.voxelized(pitch=P)
mat = v.matrix.astype(bool)
org = v.transform[:3, 3]
print('vox', mat.shape, org)
# dilate surface a little so thin walls close, then fill each horizontal slice
mat = nd.binary_dilation(mat, iterations=1)
out = np.zeros_like(mat)
for j in range(mat.shape[1]):           # trimesh axes: x, y, z
    sl = mat[:, j, :]
    sl = nd.binary_closing(sl, iterations=2)
    out[:, j, :] = nd.binary_fill_holes(sl)
np.save('/tmp/occ.npy', out)
np.save('/tmp/occ_org.npy', org)
print('filled', out.sum() * P ** 3, 'm3')
