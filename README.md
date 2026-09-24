# Chronicle Clash MG — 3D Cover Prototype (Build 03 — Samsung Android touch controls)

A separate, one-room prototype following the approved change to fully 3D characters. This project replaces camera-facing sprites with articulated mesh characters, a 16-bone Skeleton3D, BoneAttachment3D and native AnimationPlayer clips. It is built in Godot; it does not use Konami's engine or assets. The earlier four-room sprite prototype is unchanged.

## Install on Samsung Android
The companion **Chronicle_Clash_MG_Android_Touch.apk** is the installable game. Download it on your phone, open it and follow Android's installation prompt. Then open **Chronicle Clash MG**, hold the phone sideways and tap **TAP TO START**, then **PLAY**. You do not need Godot or a keyboard to play the APK.

This ZIP contains the editable source if you want it; you do not need to extract/import the source to play the APK. The APK is a signed debug/test build for ARM64 and ARMv7. It has not been run on a physical Samsung device yet.

## Touch controls — no keyboard during play
Hold the phone sideways. Tap **TAP TO START**, then **PLAY**.
- Left stick: move relative to the current camera.
- Right stick: aim. Push to the outer ring to aim and fire with the same thumb.
- Release the right stick to stop firing. The last aim direction remains selected.
- Tap COVER / LEAVE COVER, RELOAD, KNOCK, CROUCH or REFILL. FIRE also works as a separate hold button.
- Tap PAUSE for resume, retry, sound and menu. Pausing clears all held touches.

You can move and aim/fire with two thumbs. Separate finger IDs prevent releasing one control from cancelling another. Controls scale with the screen and leave side margins on wide displays. Physical Samsung device testing is still pending.

## Open the source project on a desktop (optional)
1. Extract the ZIP.
2. In Godot 4.3 Project Manager, import the extracted `Chronicle_Clash_MG_3D/project.godot`.
3. Open it, wait for import, then press F5. Choose BEGIN TRAINING, then START ROOM.

This package is editable source, not an APK. No plugins or runtime downloads are required. Tested on Godot 4.3 Linux Compatibility; Android and physical gamepad testing are pending.

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
| Knock in cover | K | KNOCK |
| Reload | R | RELOAD |
| Crouch | C | CROUCH |
| Refill near console | F | REFILL |
| Pause | Esc / P | PAUSE |

Gamepad mappings: left stick move, right stick aim, RB fire, A cover, B crouch, X reload, D-pad up refill, Start pause. Physical controller testing is pending.

Aim at the guard's body, not the floor in front of it. Walls block bullets and vision. Reload transfers ammo only after the reload timer completes. The guard patrols, hears knocks, investigates, identifies the player, calls on the radio, and attacks. Reinforcement spawning is intentionally disabled for this single-guard test. Holding fire repeats pistol shots at a limited rate.

## What to judge
- Does normal movement feel responsive?
- Does pushing into a wall reliably change perspective?
- Is the character comfortably spaced from the wall in the lower view?
- Can you peek around either edge without losing orientation?
- Are pistol aim/recoil/reload poses readable?

## Model and animation status
These are original **3D blockout characters**, assembled from simple meshes attached to bones. They have actual depth and cast shadows. They are not finished skinned character models, motion capture, or final Chronicle Clash character art. The ready/walk/aim/recoil/cover/shuffle/reload/crouch clips are authored in `scripts/Avatar.gd` and blend through AnimationPlayer transitions. A magazine appears in the left hand during reloading; hand-to-weapon contact still needs art polish. The meshes remain rigid within each bone segment; continuous skinned deformation is the next asset milestone.

## Files
- `scripts/Avatar.gd`: native 3D rig, mesh assembly and animation clips.
- `scripts/Player.gd`: physical movement and cover, reused from Build 01 with 3D presentation.
- `scripts/Guard.gd`: reusable guard behavior and 3D presentation.
- `scripts/Game.gd`, `HUD.gd`, `Data.gd`, `Equipment.gd`: one-room configuration, camera, input, pistol and HUD.
- `docs/PRD_3D_Milestone.md`: revised scope and acceptance gates.
- `docs/VALIDATION.md`, `docs/test-results.txt`: exact checks and limitations.
- `docs/screenshots/`: actual Godot captures.
- `tests/room_test.gd`: run with `godot --path . --script res://tests/room_test.gd`.

Some shared traversal/equipment source modules from Build 01 remain in the source tree for later reuse. Their mechanics are disabled in this milestone's command handler and are not offered by its UI or inventory. This is an implementation fork, not a replacement of the original ZIP.

## Re-exporting Android
Install the official Godot 4.3 Android export templates and configure Android SDK / Java SDK in the editor. Use the Samsung Android export preset. `build_support/debug.keystore` preserves this test build's signing identity for updates; its public debug credentials are alias `androiddebugkey`, password `android`. This is a development signing key, not a production release key. The key is excluded from game export.
