> SUPERSEDED CONTROL INSTRUCTIONS — historical snapshot, archived 2026-09-27.
> Active controls: ../../HOVAGI_CONTROLS_CURRENT.md (repository path: docs/HOVAGI_CONTROLS_CURRENT.md).
> Supersession applies to controls only; unrelated project history is retained.
> Source: https://docs.google.com/document/d/1P65FNvDEyclRDbmObaWWy4Dl4L_yyFYTTcu0Zh0yBtE/edit

﻿MG BUILD 07 SPEC — AIM STICK, FACILITY ROOMS, COMMS, CHARACTERS
Chronicle Clash MG 3D (repo: houawanych-pixel/chronicle-clash-mg3d). Written 2026-09-24.
Build on current main = e5e045b (Build 06, live). Do not touch castle-rpg-testbed.
References: Master GDD v2.0, Mobile Controls & HUD spec, VR Training spec (all in Master Documents), plus the user's images: "HOVAGI // Outer Reach Facility Wireframe", the Agi/Operative 07 character sheet, and the HOVAGI poster with Kai (Raven) / Ayame (Sakura) character sheets, camera styles, drones and equipment (the user sends these to the builder directly).


A. AIM STICK + GRENADE AIMING (top priority — user request)
1. Tap AIM -> first-person aiming (as now) AND the right side of the screen turns into an ANALOG AIM STICK (visible ring + knob, bottom-right area above FIRE). Pushing it moves the crosshair / view: left-right = turn, up-down = look up/down (full pitch range so you can shoot a drone high above or a dog low on the ground). Speed scales with how far you push (slow near center for fine aim, faster at the edge). Keep gentle aim-assist near drones/enemies.
2. FIRE stays available while aiming. RELOAD stays.
3. Tap AIM again (label changes to EXIT AIM) to leave aiming; the aim stick disappears and the normal buttons return.
4. Keep drag-to-look as a secondary option, but the stick is the primary.
5. Sniper / binoculars: same stick, slower sensitivity when zoomed.
6. GRENADES (frag, chaff) and other thrown items: with a throwable equipped, AIM shows a THROW ARC preview + landing marker. The aim stick adjusts direction and distance (up = farther). FIRE throws. Rocket launcher uses the aim stick + heat lock-on.
7. Sensitivity slider in pause/settings.


B. BUILD 06 REVIEW FIXES
1. RELOAD button label shows "LOAD" (cut off) — make it fit.
2. FULL SCREEN on phones: remove black side bars on wide phones (stretch aspect "expand" or equivalent), anchor HUD to real screen edges + safe areas, no overlap at 16:9, 19.5:9, 20:9.
3. DIFFICULTY RAMP in training stages 01->11 (currently nothing scales): guard count, speed, vision range/angle, suspicion speed, drone count, shorter radio/backup times, time limits. 11 ELITE clearly hardest. Tests proving values increase.


C. FACILITY ROOMS FROM THE OUTER REACH WIREFRAME (replace the 18 copies of one room)
Build the six wireframe sections as six real, distinct 3D areas (gray-box / VR style is fine, but real layouts, heights, doors and props — not squares):
1. EXTERIOR / INFILTRATION — sea + mountain/cliff terrain (one merged heightmap mesh), submerged hatch (underwater entry, uses swimming + oxygen), drainage pipe entry (crawl/swim), path up to the facility.
2. INGRESS & SECURITY HUB — blast door, main corridor, security hub room, ORANGE KEYCARD checkpoint (keycard pickup + locked door), security cameras with vision cones, patrol route, stairs/ladder down to L-1.
3. LIVING & SUPPORT QUARTERS — barracks, COMMON ROOM with the 2 card-playing backup guards (this is where backup comes from), lockers (hide), restrooms (vent access), ARMORY (weapon pickups), TACTICAL RANGE (shooting targets = weapons lab).
4. SUB-LEVEL 1 — R&D — robotics labs A/B, R&D core, SERVER ROOM (upload-virus objective at a terminal), terminals, freight elevator, cameras + patrol.
5. SUB-LEVEL 2 — MANUFACTURING & DETENTION — holding block (hostage cell), robotics assembly line, testing/storage bay (drones + mechanical dog spawn), PROTOTYPE CHAMBER (Drone Master / boss room), security control, upper catwalks (hang/shimmy/climb).
6. EXTRACTION — ventilation shaft (climb to surface), cargo rail bay (secondary route), helipad exit.
- Use the wireframe's scale (~50 m bar) and room arrangement as closely as practical; each section is its own selectable chamber and they connect in order (door/elevator/shaft = load next section).
- Every mechanic from Build 06 must have a natural place in these rooms (list the mapping in docs/).
- Keep a separate small "VR TEST LAB" chamber with every mechanic's fixtures, for quick testing.
- Training stages 01-11 should use parts of these sections with increasing difficulty (see B3).
- OBJECT BUDGET: < 300 MeshInstance3D per loaded section. Merge static geometry (walls, floors, terrain, repeated props -> merged meshes / MultiMesh). Only load one section at a time. Web must still draw (Build 04 went blank at ~1,150).


D. CHARACTER COMMS (codec-style)
1. When operatives talk, show a COMMS PANEL: portrait ID image of the speaker (left) and the other operative (right), name + codename, and SUBTITLE text at the bottom. Tap to advance / skip. Game pauses or slows during it (setting).
2. Portraits: crop from the user's character sheets (close-up panels) — Kai "Raven" and Ayame "Sakura" (and Agi, Operative 07, if the user confirms her role). Store as small textures (<= 256 px) so the web build stays light.
3. Triggers: entering each facility section, first alarm, keycard found, objective complete, low health, extraction. Write short placeholder lines in the tone of the posters ("Check your corners.", "Information is a weapon.") that the user can edit in one data file.


E. BETTER CHARACTER + ENEMY MODELS (stylized placeholders now, real models later)
1. Improve the procedural blockouts toward the concept art silhouettes: female operative (slim armored suit, long ponytail, dark suit with red accent lights); KAZE soldiers (helmet with red visor lights, armor, rifle); quad-rotor drones with red/white lights and spotlight; MECHANICAL MILITARY DOG (quadruped robot: body, head with sensor light, 4 jointed legs with a trot/run gait animation — replaces the current "dog drone" look).
2. MODEL IMPORT SLOT: support loading a rigged GLB humanoid (e.g. from Meshy image-to-3D with auto-rig, or a VRM/GLB from VRoid) as the player model, with a simple toon/cel shader, and fall back to the blockout if missing. Test one sample GLB on the web build for load size and frame rate, and report the size/FPS budget (target: player model < ~5 MB, keeps smooth on a mid-range phone).


F. ORDER + DELIVERY
Order: A (aim) + B1/B2 -> C sections 1-3 -> C sections 4-6 -> D comms -> E models -> B3 difficulty.
Checkpoint bundles to Drive after each step -> GitHub Deploy Manager updates branch "build07" (never main) -> Claude reviews each checkpoint. Keep all 258 existing checks passing (list any changed and why), add tests for every new item, run the web test and screenshot EVERY section at phone size. Report commit, results, and anything unfinished.