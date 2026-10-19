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


## 2x scale and the outside route (Oct 2026)
- The ruin is shown at 2x: `MODEL_SCALE 142.7533`, offset doubled (Ruin.gd).
- Route design: `route.py` (in the work folder `art/skyruin`, needs trimesh with embree, scipy) samples the ruin's silhouette at 2x (`sil.npy`, radius per 3 degrees per metre of height), lays three rings of 11 m ledges 2.2 m outside it with 2.4 m jump gaps, puts a ladder column at each ring's end (pushed outward until the shaft and step-off are clear), a 13-ledge helix in front (centre (0, z 27), radius 10, 32 degree ledges, 13 degree gaps) to the crown at y 139, a seal on the crown's inner edge, and checks every walkway, pad and the eye shaft by ray casts. The last ledge of each ring and of the helix is flat so it meets the next piece without a lip (a character body can't step up a lip).
- Collision: `col2.py` scales the carved 45k collision x2, keeps only triangles within 7 m of a route piece, a ladder or the Core, and removes the ones in the 0.8 m band under each walkway.
- Phone model: `node lite.mjs skyruin.glb skyruin_lite.glb 0.4` (gltf-transform simplify with meshoptimizer, textures resized to 512).

## Sky Citadel v2: the rebuilt castle (Oct 2026, branch castle-v2, waiting for approval)
Built from code in Blender (bpy 4.2 as a Python module, no Tripo): `tools/castle2/`.
- `tex.py`: the owner's four textures (stone, gold trim, crystal, rock) made seamless at 2048 with bump and OpenGL normal maps, plus a 2x2 atlas.
- `kit.py`: the parts: lathe mouldings, arcades with pointed arches (doors, windows, blind arches), pilasters, cornices, stepped corbels, decks and spiral stairs (smooth collision ramp under visible steps), parapets with pinnacles and crystal lamps, towers with spires, crystals, floating rock with veins. The castle is designed round, then warped to the guides' rounded-oval footprint (superellipse, z factor by height).
- `castle.py`: the castle and its route: dock (52) -> base terrace (56) -> spiral stair -> gallery through drum A (62) -> balcony -> ladder -> terrace A (74) -> spiral stair -> gallery through drum B (80) -> balcony -> ladder -> terrace B (92) -> spiral stair -> gallery through drum C (104) -> balcony -> summit stair (119) -> crown stair -> crown (131) -> drop through the eye -> Core arena (105). Writes `route2.json` (gates, checkpoints, knights, ladders, bot moves).
- `bl_build.py`: Blender meshes, materials, collision (`-colonly` in the full GLB, plain in the game copy), .blend, GLBs.
- `game_sync.sh`: build, copy into `assets/ruin2/`, run the route test. `run_all.sh` renders the six ortho views and overlays them on the guides.
