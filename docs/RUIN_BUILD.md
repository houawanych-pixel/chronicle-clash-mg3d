# Sky ruin build notes

Source: owner's Tripo `cc_skyruin04.glb` (1.83M triangles, 4096 textures; kept by the owner, not in the repo).

1. `gltf-transform dequantize` (removes meshopt/quantization for Godot).
2. `gltf-transform simplify --ratio 0.055 --error 0.004` → 100k triangles (no weld, so texture seams stay intact), `resize 1024`.
3. Scale to 70 m tall: scale 71.3766, offset (-0.0948, 34.9848, -0.1971); front is +Z.
4. Collision copy: same mesh in metres, simplified to ~45k triangles (`fast-simplification`).
5. Carved passages (triangles with centres inside these boxes removed from both copies, metres):
   core clutter [-9.5,9.5]x[52.7,54.5]x[-3.2,3.6]; ladder 3 shaft [-0.2,2.4]x[44.6,52.2]x[-7.8,-6.1];
   core back entry [-0.2,2.6]x[52.65,55]x[-7.8,-3]; back ring headroom [-2.2,2.8]x[44.5,47.6]x[-11.6,-6.2];
   hollow span [-2,2]x[41.5,46.8]x[-9.6,4.6]; span end [-3.8,-1.6]x[44.5,47.6]x[-11.6,-6.6];
   upper ring path [-7.6,1.6]x[41.5,43.8]x[3,7.8]; ladder 2 shaft [-6.8,-5.2]x[35.3,43.4]x[10,11.4];
   deck path [-7.6,1.6]x[35.25,37.6]x[9.4,12.2].
6. Route checks: floor heights, ladder shafts and walkway clearance were tested against the mesh, then the in-game route bot (AutoTest `ruin_tests`) walks dock → core.

To swap in a new version of the ruin: repeat 1–5 with the same scale if its shape matches; if the shape changes, re-measure the floors and move the route pieces in `Ruin.gd`.
