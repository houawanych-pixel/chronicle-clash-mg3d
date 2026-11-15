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

## Fighting animation (real clips, Nov 2026)
Sword swings, block, getting hit, knockback and death no longer use code-made poses. They come from
animator-made clips in Quaternius' Universal Animation Library 1 & 2 (CC0, free for commercial games),
baked with `tools/anim/bake.gd -- --only=ual` (map "ual"; the bake also stores the sword direction from the
hand's knuckle line and the strike time = the frame the sword hand moves fastest).

| Game state | Clip |
|---|---|
| combo hit 1 / 2 / 3 | `ual_slash_a` / `ual_slash_b` / `ual_slash_c` (jump-spin finisher) |
| dash slash chain | `ual_slash_a` |
| charged spin | `ual_slash_c` |
| enemy wind-up / strike | `ual_sword_attack` (split at its strike frame) |
| block | `ual_block` (held at the guard frames) |
| hurt / stagger / dead | `ual_hit_chest` / `ual_knockback` / `ual_death` |

- `Fighter.fight_clip()` time-warps each swing so the clip's strike frame lands on the game's hit time
  (wind-up, snap, follow-through), as action games do; hit-stop still freezes on contact.
- Feet are planted after posing (lowest ankle back to its standing height) unless the clip is airborne.
- Also baked for later: `ual_heavy_combo`, `ual_combo`, `ual_dash_slash`, `ual_shield_idle`, `ual_shield_bash`,
  `ual_shield_break`, `ual_hit_head`, `ual_cast`, and village work clips `ual_chop`, `ual_harvest`, `ual_water`,
  `ual_carry`, `ual_sit`, `ual_talk`.
- Check pictures: `xvfb-run -a godot --rendering-driver opengl3 --path . -- --autotest --fight-shots --shots=/dir`.
- More motions (emotions, talking, waving, more sword styles): Mixamo with the owner's Adobe login, baked the same way.

## Movement clips in use (Nov 2026)
| Hero state | Clip |
|---|---|
| dodge | `ual_roll` (dive and tumble during the dash, the get-up plays after it) |
| jump (rising / in the air) | `ual_jump_start` blending into `ual_jump_air` |
| hard landing | `ual_jump_land` |
| pull-up over a ledge | `ual_mantle` |
| crouch / crouch walk | `ual_crouch_idle` / `ual_crouch_walk` |

Also baked (85 clips in all) and shared with Homelancer through its `scripts/anim_lib.gd`: pistol idle, aim
(up / middle / down), shoot and reload; talking, phone call, sitting and talking, leaning on a rail, arms folded,
nod, head shake, dance; walk, formal walk, jog, sprint, push; swim; eat, chest open, throw, kneel work (cooking),
pick up, interact, plant seeds, water, harvest; zombie walk and attack; hook punch.

## Still missing (get from Mixamo with the owner's free Adobe login)
Download each as FBX, "Without Skin", 30 fps, then bake with `tools/anim/bake.gd` (map "mixamo").
- Climbing: Climbing (wall), Hanging Idle, Braced Hang Shimmy (left and right), Braced Hang Hop Up, Climbing Ladder.
- Gliding / falling: Hard Landing, Skydiving.
- Bow: Standing Draw Arrow, Standing Aim Overdraw, Standing Aim Recoil.
- Sword extras: Sword And Shield Slash (several), Sword And Shield Impact, Great Sword spin / slash.
- Potion and cooking: Drinking, Kneeling / stirring.
- Rifle (Homelancer): Rifle Aiming Idle, Rifle Run, Rifle Walk, strafe left / right with rifle, Firing Rifle, Reloading, Dodging Left / Right.
- Emotes: Waving, Cheering, Laughing, Arguing, Thinking, Clapping, Salute, Shrugging, Looking Around.
