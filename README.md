# Chronicle Clash MG 3D — Build 05 preview

Based on the web-fixed MG repo commit `ea6cc3e`. Intended for review on branch **build05** only; do not deploy or merge to main before independent review. The separate castle-rpg-testbed game is untouched.

## New in this build
- Restored Build 03 low-angle wall-hug camera outdoors and indoors: FOV 58, normal distance 5.5, height 2.8, trailing tangent distance 3, focus tangent 1.4, corner-peek focus 2. Side bias is active while sliding/peeking, recenters at rest. Environment transitions and collision safety remain.
- CRAWL / STAND touch button: prone movement at 1.1 m/s, 0.6m capsule, half guard sight range. Standing is blocked under a low ceiling. CROUCH is still a separate action.
- A 3.9m vent leads from the courtyard through the left side of the roofed room's front wall. Crawl in for first-person view. Move stick forward/back; right stick turns the view. Guards cannot fit or route through it.
- Yellow scout drone: searchlight detection raises an alarm after approximately one second; two pistol hits bring it down.
- Red attack drone: shoots for 8 damage at 1.2-second intervals when it sees you; three pistol hits bring it down.
- Both drones are on the minimap, respect wall/roof/vent occlusion, and fall when defeated. Point the aim stick within 12 degrees of a visible drone's horizontal bearing for automatic elevation/target lock (18m maximum).
- The merged grid geometry fix is retained. The room starts with 160 mesh instances, below the 300-object budget.

## Open the editable project
Extract the ZIP, import `chronicle-clash-mg3d/project.godot` into Godot 4.3, then run it. On Android use the editor's Run Project button and landscape orientation. Tap TAP TO START, then PLAY. This package is source, not an APK.

The live website is not changed by this package. Physical Samsung testing remains pending. See `docs/BUILD05.md` for the exact validation record.

## One-room goal
Enter cover, knock, defeat the single guard and reload the pistol. Then reach the green extraction ring. All four checklist items must be complete. Retry resets everything. The cyan console refills ammo.

## Controls
| Action | Keyboard / mouse | Touch |
|---|---|---|
| Move | WASD / arrows | Left stick |
| Aim | Mouse over world / guard | Right stick or tap world |
| Fire pistol | Left click or J | Push aim stick to outer ring, or hold FIRE |
| Cover / leave | Space, or deliberately push into wall | COVER / LEAVE |
| Shuffle / peek | Move sideways along wall to its edge | Move stick sideways |
| Climb onto crate | B | CLIMB |
| Crawl / stand | Z | CRAWL / STAND |
| Knock in cover | K | KNOCK |
| Reload | R | RELOAD |
| Crouch | C | CROUCH |
| Refill near console | F | REFILL |
| Pause | Esc / P | PAUSE |

Gamepad mappings: left stick move, right stick aim, RB fire, A cover, B crouch, X reload, Y climb, left-stick click crawl, D-pad up refill, Start pause. Physical controller testing is pending.

Aim at the guard's body, not the floor in front of it. Walls block bullets and vision. Reload transfers ammo only after the reload timer completes. The guard patrols, hears knocks, investigates, identifies the player, calls on the radio, and attacks. Reinforcement spawning is intentionally disabled for this single-guard test. Holding fire repeats pistol shots at a limited rate.

## What to judge
- Does normal movement feel responsive?
- Does entering the roofed room switch smoothly to follow view, or cut safely when obstructed?
- Is the character comfortably spaced from the wall in the lower view?
- Can you peek around either edge without losing orientation?
- Are pistol aim/recoil/reload poses readable?

## Model and animation status
These are original **3D blockout characters**, assembled from simple meshes attached to bones. They have actual depth and cast shadows. They are not finished skinned character models, motion capture, or final Chronicle Clash character art. The ready/walk/aim/recoil/cover/shuffle/reload/crouch clips are authored in `scripts/Avatar.gd` and blend through AnimationPlayer transitions. A magazine appears in the left hand during reloading; hand-to-weapon contact still needs art polish. The meshes remain rigid within each bone segment; continuous skinned deformation is the next asset milestone.

## Files
- `scripts/Avatar.gd`: native 3D rig, mesh assembly and animation clips.
- `scripts/Player.gd`: physical movement and cover, reused from Build 01 with 3D presentation.
- `scripts/Guard.gd`: reusable guard behavior and 3D presentation.
- `scripts/Game.gd`, `HUD.gd`, `Data.gd`, `Equipment.gd`: one-room configuration, input, pistol and HUD. Camera behavior is in `EnvironmentCamera.gd`.
- `docs/PRD_3D_Milestone.md`: revised scope and acceptance gates.
- `docs/BUILD05.md`: current scope, tests and limits. Older docs describe earlier builds.
- `docs/screenshots/`: actual Godot captures.
- `tests/room_test.gd`: run with `godot --path . --script res://tests/room_test.gd`.

Some shared traversal/equipment source modules from Build 01 remain in the source tree for later reuse. Their mechanics are disabled in this milestone's command handler and are not offered by its UI or inventory. This is an implementation fork, not a replacement of the original ZIP.

## Re-exporting Android
Install the official Godot 4.3 Android export templates and configure Android SDK / Java SDK in the editor. Use the Samsung Android export preset. `build_support/debug.keystore` preserves this test build's signing identity for updates; its public debug credentials are alias `androiddebugkey`, password `android`. This is a development signing key, not a production release key. The key is excluded from game export.
