# HOVAGI — Six Stage Mission / Prototype 01

A separate Godot 4.3 infiltration prototype using the six supplied GLB stage structures. This does not replace the detailed Stage 01 project.

## Play

Open the published game in a landscape browser. The first download is approximately 92 MB including the engine. A desktop keyboard is also supported. The browser needs WebGL 2. Checkpoints are local to that browser/device.

Open `project.godot` in Godot 4.3 to edit the source. The web folder can be served over HTTP; opening `index.html` directly as a local file is not supported.

## Mission

| Stage | Objective | Mechanic |
|---|---|---|
| 01 Exterior Infiltration | Disable scanner, recover L1, enter security | Patrol observation, access door |
| 02 Security Hub | Read maintenance log, isolate circuits, shut down lasers | B → A → C circuit order; errors reset safely |
| 03 Living Quarters | Search duty desk, recover L2, find transfer record | Exploration and credential progression |
| 04 Research / Development | Balance coolant and copy research | Coupled valves; L2 archive reader |
| 05 Manufacturing / Detention | Stop conveyor, release scientist, escort to lift | Timed service window and escort |
| 06 Extraction | Disable AA emitter, call helicopter, reach pickup | 35-second survival and extraction |

## Controls

- Touch: left stick moves. Light pressure sneaks; full pressure runs and uses stamina.
- Hold AIM: left stick controls first-person aim. FIRE is separate; aim movement and release do not shoot.
- WEAPON: tap to holster/draw; hold to choose. ITEM: tap to use; hold to choose.
- ACTION: nearby terminals, pickups, doors, context interactions, jump, or CQC when holstered.
- CROUCH then move to crawl; tap again to stand. Push against a wall to take cover; push away to leave. ACTION knocks in cover.
- Keyboard: WASD/arrows move, Shift runs, Alt sneaks, V aims, J fires, Space acts, R reloads, C crouches, hold E/Q for weapon/item selection, Esc pauses.
- Rations heal; chaff temporarily disables drones. Guards react to sight and noise, call by radio, investigate, and search.

## Editing

- `assets/stages/mission1.json` through `mission6.json`: stage names, briefings, start positions, objective locations, guard routes.
- `scripts/Campaign.gd`: objective prerequisites, card levels, puzzles, lasers, escort, checkpoints, stage transitions.
- `scripts/Player.gd`, `Lab.gd`, `Equipment.gd`: controls, locomotion, aiming, equipment, CQC.
- `scripts/Guard.gd` / `Drone.gd`: enemy behavior.
- `scripts/HUD.gd`: touch layout, mission briefing, puzzle UI.
- Original stage art is retained in its six named GLBs at a 64-meter stage width. Separate collision floors, boundary proxies, and service ramps repair rough generated transitions.
- `build_support/bake_maps.py` and `make_navigation.py` reproduce collision/navigation inputs (Python: trimesh, numpy, scipy, pyrender, rtree). Regeneration can require reviewing connections and objective positions again.

## Prototype limits

This is a graybox demo, not a finished or phone-certified release. Automated physics routes and progression checks pass; a hands-on browser/phone playthrough and frame-rate validation remain outstanding because this runtime blocked browser launch. Imported art still has warped geometry, baked-in static figures, and rough doorway details. Collision proxies may differ from that art at repaired thresholds. Guard animations are reused provisionally on Kai; the scientist and drones use graybox visuals. Full manual retopology, final terrain art, animation cleanup, mobile performance tuning, and combat balance remain iteration work.

The imported models were automatically simplified in the asset preparation pass; that is not a clean, manually authored quad retopology.
