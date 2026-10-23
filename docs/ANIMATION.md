# Motion-capture animation (retargeted clips)

The hero's idle, walk, run and sprint now come from real motion-capture clips instead of hand-made poses.

- Source clips: Mixamo (Adobe) — Running, Standard Walk, Idle, Sneaking Forward, Sword And Shield Crouch Idle,
  Roll, Dodging Back, Jump, Falling Idle — as collected in github.com/aaronsnoswell/3DCharacter.
  **Licence:** Mixamo animations are free to use in games for anyone with an Adobe account, but the raw FBX files
  may not be redistributed. The repo above has no licence of its own, so before shipping a store build the owner
  should download the same clips from mixamo.com with his own Adobe account and re-run the bake (same names).
  The raw FBX files are not in this repo; only the baked pose data is.
- Tool: `tools/anim/bake.gd` (run in a scratch Godot project that holds the FBX files) samples each clip at 30 fps
  and stores, per frame, each limb bone's direction (+X forward, +Y up, +Z right), the torso turn deltas and the
  hip rise. Because it stores directions, not bone rotations, it works between rigs with different rest poses
  (Mixamo T-pose -> Tripo A-pose). Output: `assets/anim/clips.json` (idle clips thinned to 15 fps).
- Player: `scripts/citadel/ClipPlayer.gd` samples / blends clips; `Fighter.loco_clip()` drives the hero: walk and
  run share one phase advanced by distance (feet match ground speed up to 2.3 strides/s), idle blends in at rest,
  sprint and tired add lean, and with the sword out the shield arm is carried across the body (Link-style).
- Check: `-- --autotest --anim-shots --shots=/dir` saves behind and side views of idle / walk / run / sprint.
- Also looked at: GDQuest 3D Mannequin (MIT code, CC-BY 4.0 art; Godot 3 project, 10 clips) and the
  Recreating_Zelda study project (its Godette character uses KayKit-style clips; no licence file for the model).
  The KayKit run is chunkier and suits these realistic characters less than Mixamo.

## Turning, starting and stopping (Link-inspired)
- `Fighter.loco_clip()` banks the hips into turns (yaw rate x 0.06, up to 0.3 rad, scaled by run speed) and leans
  forward when speeding up / back when stopping (acceleration x 0.012). Ideas from studying BotW's animation system
  design (speed blender, per-transition cross-fades, separate turn and brake actions); no Nintendo data is used.
