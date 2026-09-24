# Build 06 — integrated mechanics review

## Source of truth

Based on MG 3D main `2e7ba6325596375e596c44198dfa9877d23cf49b`.

- Master GDD v2.0: https://docs.google.com/document/d/1um3OvA2kn2v6RDyRa0dzAJuASLi077_SrrciTDjqPc4/edit
- Mobile Controls & HUD Build 06: https://docs.google.com/document/d/1TSUVgMOgKjXw5bcqSOIwJ_Ow0E_uUoLJS3yXi_Nxrjc/edit
- VR training, folded into this integrated delivery: https://docs.google.com/document/d/1lRRMdj2CrAqIHgR72tMxsoKvteaRoqxRh95VaOsJUeY/edit
- Project Status Log: https://docs.google.com/document/d/1yAs-ht7Xb0Y1Y093IV95oGS5bK7bPVA9VZWloBJhaQI/edit

User authorized a larger integrated testbed, with controls first, incremental branch checkpoints, honest evidence, unlocked test chambers, and the existing merged-grid geometry safeguard.

## What is implemented

- Readable HUD, floating pressure stick, four large primary buttons, reload, tap/hold weapon and item wheels, toggle first-person aiming, zoom and minimap.
- Existing open-sky/roof camera switching, approximately 0.4s transitions, doorway hysteresis, obstructed-path cuts, Build03 wall-hug composition with directional reveal only during wall movement/peek, and first-person vent camera.
- Physical crawl clearance, crate climbs, jumps, automatic ledge/bar catches, shimmy/pull-up/drop, pole climbing, stamina, and movable crates with updated navigation footprints.
- Pistol, rifle, sniper, rocket launcher, SMG, dagger and sword; firing, muzzle flash, ejected cases, ammunition/reloads, rifle jam drill and automatic sidearm fallback on persistent clear failure.
- Punch–punch–kick, rear holds, choke, throw, body drag, dagger takedown, sword damage/parry. Blockout weapon meshes change with selection and disappear when holstered.
- Frag/chaff, directional claymores, place/detonate C4, heat-seeking rockets with visibility checks, cloak energy, rations and binoculars.
- Existing patrol awareness, noise investigation, radios, interruptible calls and drone detection. Marked shadow zones shorten guard sight. Two seated backup guards in STEALTH / BACKUP and training stage 09 respond to completed calls and return after 20 seconds without sight.
- Scout, attack, dog and kamikaze drone roles; a large fast-firing Drone Master prototype. Locker concealment can be discovered if guards know where you hid.
- Seven labs and eleven training stages, all open in test mode; sequential training unlocks and best-time/rank/alarms/kills persistence.
- Physical pool, surface/submerged movement, oxygen, drowning damage and a deck exit.

## Deliberate limitations / unfinished work

- Original simple 3D blockouts, reused room geometry and basic poses. No claim of final character art or final animation quality. There is no completed facility campaign, HALO sequence, two-operative persistence campaign or colossal boss/hookshot scenario in this MG lab delivery.
- Night/thermal switches are cosmetic color filters, not simulated night-vision lighting or heat silhouettes. The checklist marks optics UNFINISHED although first-person aiming and zoom pass.
- Drone Master currently has health, rapid fire and defeat logic. Boss phases, weak-point mechanics and special presentation are absent; checklist marks it UNFINISHED.
- Training stages reuse this test room with different objectives; handcrafted progression/difficulty tuning, a separate fully nonlethal weapon, inventory balance and detailed weapon-specific jam animations need further work. Some CQC actions share simple clips. The no-kill rank counts unconscious guards separately from killed guards.
- No physical Samsung, Android APK/export, controller-hardware or production GitHub Pages validation. Browser tests use Chromium with software WebGL at desktop and phone viewport sizes; they establish rendering and interaction, not real-phone frame rate or battery behavior.
- Some native suite runs report an intermittent ObjectDB/resource warning on process exit despite passing assertions. Logs retain it. This is not presented as a clean native teardown.
- GitHub writes are unavailable in this session (no GitHub write credentials). Local `build06` checkpoints and Drive Git bundles are supplied for the deploy bot. Main and the live site have not been changed.

## Verification protocol

Tests instantiate the actual scene in Godot 4.3 with OpenGL under Xvfb. They exercise real physics, rays, controls, cameras, game state and persistence. Browser checks export the project, serve it with COOP/COEP locally and send touch events to the actual WASM build. Screenshots are reviewed for visible room geometry and HUD.

The WORKING label means the listed runtime behavior passed its named test. It does not imply every aspect of a broad design feature is finished or certified on Samsung. The two UNFINISHED categories remain visible in the exported checklist.

## Intentional baseline test adaptations

All 112 previous assertions remain represented:

- Room/inventory counts now expect 18 selectable chambers and 7 weapons instead of one room / pistol only.
- Touch tests now verify independent movement/look/fire and the new ACTION layout rather than removed twin-stick outer-ring firing.
- CLIMB HUD lookup uses the contextual ACTION button. Crawl HUD lookup uses CROUCH plus movement, as specified.
- Drone/guard clearance fixtures moved from x=-12 to x=-14.5 because a new physical ledge occupies the old ray path. Detection ranges, line-of-sight, damage, cooldown and lock-angle thresholds were retained.
- The bar was moved away from the old exact cover-camera composition fixture; the original numeric camera assertion remains unchanged.

## Review and deployment handoff

Only use repository `houawanych-pixel/chronicle-clash-mg3d`. Fetch current origin/main, verify the bundle, fetch its build06 ref and fast-forward/create local build06. Push **build06 only**. Do not force-push, overwrite another branch or touch castle-rpg-testbed.

The bundle requires the main history through `2e7ba6325596375e596c44198dfa9877d23cf49b`; fetch that history before importing. It contains all Build06 checkpoint commits. The source ZIP is also independently importable in Godot 4.3.

Independent reviewer: import/run source, inspect native logs, export Web, run the browser harness, and test on a physical Samsung. In particular check thumb reach, long-press wheels, wall camera, crawl-to-stand clearance, climb landing, backup behavior, pool exit and sustained frame rate.

The existing Pages workflow triggers on main. Do not merge until review accepts the build. A source ZIP or green local tests are not evidence of successful live deployment.

## Final native validation

| Suite | Passed | Failed |
|---|---:|---:|
| arsenal | 17 | 0 |
| build05 | 40 | 0 |
| combat | 18 | 0 |
| controls | 20 | 0 |
| enemies | 39 | 0 |
| equipment | 22 | 0 |
| movement | 20 | 0 |
| room | 24 | 0 |
| swim | 10 | 0 |
| touch | 13 | 0 |
| update | 35 | 0 |

Total: **258 native assertions passed**, 0 failed. Intermittent exit-resource diagnostics remain in the logs as disclosed above.

## In-game evidence map

| Feature | Status | Evidence / limitation |
|---|---|---|
| Controls and HUD | WORKING | controls_test / touch_test |
| Environment and cover cameras | WORKING | update_test / build05_test |
| Pressure movement | WORKING | movement_test |
| Crawl and vent | WORKING | build05_test |
| Climb and jump | WORKING | update_test / movement_test |
| Hanging and shimmy | WORKING | movement_test |
| Pipe climbing | WORKING | movement_test |
| Push and pull crates | WORKING | movement_test |
| Shooting and reloading | WORKING | combat_test / equipment_test |
| CQC and dragging | WORKING | combat_test |
| Dagger and sword | WORKING | combat_test |
| Weapons and item wheels | WORKING | controls_test |
| Grenades and chaff | WORKING | equipment_test |
| C4 and claymores | WORKING | equipment_test |
| Heat-seeking rockets | WORKING | equipment_test |
| Cloak and rations | WORKING | equipment_test |
| Guard awareness and shadows | WORKING | build05_test / enemies_test |
| Card-table backup | WORKING | enemies_test |
| Aerial drones | WORKING | build05_test |
| Drone dogs and kamikaze | WORKING | enemies_test |
| Lockers and concealment | WORKING | enemies_test |
| Swimming and oxygen | WORKING | swim_test |
| Training and persistence | WORKING | enemies_test |
| First-person optics | UNFINISHED | Aim/zoom pass; sensor filters are cosmetic |
| Drone Master | UNFINISHED | Basic firing/defeat pass; boss phases absent |

## Rendered browser results

Full matrix: **21 checks passed** on Chromium, with no page or script errors: 1280×720 desktop, 915×412 phone and 844×390 phone. Each checks touch start, first-person toggle on/off, touch selection/rendering of backup, drone and water labs, and opening the exported checklist (25 entries present). Screenshots reviewed show the 3D room and readable HUD. Representative initial counts: baseline 171 meshes, backup 248, drone arena 183, water 184. All 18 chambers separately passed the native <300-mesh gate.

After separating the advanced drones’ initial spawn positions, a targeted phone browser pass is recorded separately in final-web-followup.txt. No other gameplay behavior changed after the full browser matrix.

Targeted follow-up: **5 phone browser checks passed**, no page/script errors, including the updated drone arena and the exported checklist. The room capture was inspected. Across the full matrix and this targeted follow-up, 26 browser assertions passed.
