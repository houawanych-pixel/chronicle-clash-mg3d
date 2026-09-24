# Chronicle Clash MG — 3D milestone PRD

Date: 24 September 2026. Status: first playable blockout; hands-on approval pending.

## Decision
Use actual 3D characters for the player and guards. Preserve the overhead stealth composition, close wall-contact camera, VR grid environment, and eventual Chronicle Clash visual identity. The established method is skeleton-driven 3D animation in Godot. This is not use of Metal Gear Solid 2's engine, assets or source code.

## Immediate deliverable
One room with one guard and one pistol. The player can walk, aim, enter and leave cover, shuffle and peek at corners, knock, fire and reload. The room can be reset and completed. Touch and desktop controls are present. A full four-room rebuild is explicitly outside this milestone.

## Functional acceptance
1. Character geometry retains volume through overhead and wall-contact camera changes; no billboarding or directional sprite replacement.
2. Walk and reload clips actually drive bone transforms. Mesh attachment follows the skeleton's rest pose.
3. Deliberate pressure into a wall enters cover. Collision prevents the body crossing the wall. Sideways movement reaches corner peeking.
4. Leaving cover restores the overhead camera. Animation and the camera remain independent systems.
5. Guard hearing/vision and pistol hits operate in the same 3D scene. Solid walls block visibility and shots.
6. Reloading has a visible pose sequence and transfers ammunition at completion only. Show count changes in the HUD.
7. Cover, knock, guard defeat and reload unlock extraction; replay returns to the same valid room.
8. User hands-on review determines whether movement, camera transitions, wall contact and aiming feel convincing. Automated checks cannot approve that feel.

## Visual acceptance
The current model is a structural 3D blockout, clearly labeled in the HUD. Simple meshes are rigidly attached to an articulated skeleton. This proves camera consistency and animation mechanics, not final art quality. Before final visual approval, replace the blockout with a clean, original skinned model matching the approved character direction, then refine animations, hand contact, weapon alignment, foot sliding and cover contact.

Retain teal/cyan player accents, amber guard accents, navy VR space and visible floor/block grids. Do not describe this build as matching every previously generated illustration.

## Deferred after this room is approved
The broader design still includes equipment expansion, rare rifle jams, stealth camouflage, more enemy animations, universal hookshot, climbing and a colossal encounter. Preserve the previous four-room PRD as the broader backlog. Restore these systems incrementally after this smaller 3D foundation passes review.

## Technical structure
Godot 4.3 Compatibility. CharacterBody3D for physical movement; Skeleton3D and BoneAttachment3D for this blockout; AnimationPlayer for native clips and transitions. A later production asset should use a skinned mesh on the same skeleton/animation concept. Existing environment, guard perception, pistol logic and cover rules are reused from the earlier prototype. This change addresses character presentation and limits the playable scope; it does not claim an entirely different engine or proven human playtest.

## Next review
Open the ZIP and play the room on the intended device. Evaluate the actual screenshots and runtime camera behavior. Record any sticking at cover edges, visual penetration, awkward aim changes, unreadable reload poses or input issues. Final 3D art and animation refinement follow that review; the four-room rebuild follows a successful foundation test.

## Samsung Android touch amendment — Build 03
The immediate interface target is landscape Android on a Samsung phone. Required: left movement stick; right aim stick with an outer-ring firing threshold; separate tap buttons for cover, reload, knock, crouch and refill; optional held-fire button; tap-only start, pause, resume, retry and completion navigation. No keyboard input is required once the game is launched. Independent touches, releases and pause cleanup must pass synthetic tests; physical device playtesting remains a separate gate.
