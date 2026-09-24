# Chronicle Clash MG 3D — Build 04: environment camera and crate climbing

Editable Godot 4.3 project, based on chronicle-clash-mg3d commit 34deef1. Only the MG gridded test room was changed. The separate castle-rpg-testbed project was not accessed or modified.

## Open on your Samsung in Godot
1. Download and extract this ZIP.
2. In the Godot Android editor, choose Import and select the extracted `chronicle-clash-mg3d/project.godot`.
3. Open the project and tap the editor's Run Project/play button. In the game, tap TAP TO START, then PLAY.
4. Use landscape orientation and the touchscreen controls. No keyboard is required.

This is source, not an APK. Run/import was verified with Godot 4.3 on Linux; this update has not been tested on physical Samsung hardware or exported to Android/Web. Previous APKs and the hosted website do not contain this update.

## Try the new features
- In the open area, the camera is overhead. Walk through the wide doorway on the right into the roofed room for centered follow view. Exit to return overhead.
- Camera changes blend over 0.4 seconds when clear. Collision-blocked sweeps cut to the safe destination. Roof entry is debounced by 0.12 seconds; exit by 0.20 seconds plus a 0.24-unit boundary margin.
- Inside, enter COVER against a wall and move sideways: the view opens ahead and the character shifts toward the trailing screen edge. Stop shuffling or leave cover to recenter. Ordinary movement has no reveal offset. Geometry may limit the reveal near obstructions.
- Face a marked waist-high crate and tap CLIMB. The character lifts up and moves onto the top over 0.65 seconds. Release the movement stick before moving again, so held input cannot immediately run off the crate. There are two outdoor crates and one indoor crate.
- Left stick moves; right stick aims and fires at its outer ring. FIRE also works as a separate hold button. COVER, CLIMB, RELOAD, KNOCK, CROUCH and REFILL are tap buttons.

## Verified build status
Godot 4.3 Compatibility renderer: 72 assertions passed (35 new feature checks, 24 room/combat checks, 13 touch regression checks). Actual rendered captures and logs are in `docs/`. `docs/BUILD04.md` is the current update specification and validation record; older milestone documents describe the baseline.

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
| Knock in cover | K | KNOCK |
| Reload | R | RELOAD |
| Crouch | C | CROUCH |
| Refill near console | F | REFILL |
| Pause | Esc / P | PAUSE |

Gamepad mappings: left stick move, right stick aim, RB fire, A cover, B crouch, X reload, Y climb, D-pad up refill, Start pause. Physical controller testing is pending.

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
- `docs/VALIDATION.md`, `docs/test-results.txt`: exact checks and limitations.
- `docs/screenshots/`: actual Godot captures.
- `tests/room_test.gd`: run with `godot --path . --script res://tests/room_test.gd`.

Some shared traversal/equipment source modules from Build 01 remain in the source tree for later reuse. Their mechanics are disabled in this milestone's command handler and are not offered by its UI or inventory. This is an implementation fork, not a replacement of the original ZIP.

## Re-exporting Android
Install the official Godot 4.3 Android export templates and configure Android SDK / Java SDK in the editor. Use the Samsung Android export preset. `build_support/debug.keystore` preserves this test build's signing identity for updates; its public debug credentials are alias `androiddebugkey`, password `android`. This is a development signing key, not a production release key. The key is excluded from game export.
