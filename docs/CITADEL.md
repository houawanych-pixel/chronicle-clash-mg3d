# Chronicle Clash — Sky Citadel (sword demo)

The project now opens on the Sky Citadel. The old MG labs are still in the build: **MG LABS (OLD)** on the title and pause screens loads `scenes/main.tscn`.

## Stage
Courtyard guards → broken sky bridge (two gaps to jump) → plaza → Dark Knight throne hall. Glowing barriers open when a section is cleared. Falling costs 15 health and returns you to the bridge. Eliza follows the hero and heals once when health drops below half.

## Controls (touch / keyboard)
| Action | Touch | Keys |
|---|---|---|
| Move | Left stick (floating, anywhere on the left) | WASD / arrows |
| Look | Drag an empty part of the right side | — |
| Attack (3-hit combo; in the air = plunge) | ATTACK | J |
| Jump | JUMP | Space |
| Dodge (stick direction, one air dash) | DODGE | L |
| Guard / parry (block just before the hit) | hold GUARD | K / Shift |
| Mark an enemy (up to 3) | Tap the enemy | — |
| Charged dash through marks | Hold CHARGE, release | I |
| Seeking magic (to marks; stronger right after a charged dash) | MAGIC | U |
| Potion (3) | POTION | R |
| Crouch (quiet, harder to see) | tap CROUCH | C |
| Crawl | hold CROUCH | Z |
| Wall hug (slide along; low walls auto-crouch) | WALL HUG, or push into a wall out of combat | H |
| Peek round the edge | hold PEEK while hugging | Q |
| Distract (knock in cover, else throw a pebble) | DISTRACT | F |
| Draw / put away sword (back carry; ATTACK, GUARD or CHARGE also draw it) | DRAW / SHEATHE | X |
| Pause | II (beside the stats) | Esc / P |

## Stealth (ported from the MG build)
The three courtyard guards patrol with vision cones (shown on the floor and the map). Numbers match the old `Guard.gd`: 40° half-cone, suspicion rises 1.15/s in view and falls 0.3/s out of view, crouching cuts their range to 80% and crawling to 50%. Low planters hide you only when crouched. Walking upright makes footstep noise; crouching and crawling are silent. Knocks and pebbles send guards to INVESTIGATE, then SEARCH, then back to PATROL. Full suspicion raises the alarm and wakes guards within 14 m into sword combat. Attacking an unaware guard is a silent takedown. The top shows STEALTH: HIDDEN / SUSPICIOUS / ALERT.

Cover and crawl logic is from `Player.gd` (`toggle_cover`, cover slide with edge peek, wall-pressure entry, crawl). The wall-hug camera is the `EnvironmentCamera.gd` cover view. Change from the MG build: tapping CROUCH crouch-walks and holding it crawls (the MG build crawled as soon as you moved while crouched).

The Dark Knight's leap sends out a red shockwave; jump or dodge through it.

## Forest Escape (second stage)
Pick FOREST ESCAPE on the title. You play Lance; Eliza (just rescued) stays right behind you and crouches when you do. Three areas, each with a knight pair on patrol: the glade, the rocks, the tall grass, then the forest edge. Crouch or crawl inside tall grass and knights can't see you unless they are within 2 m. Boulders and trees are cover (wall hug works on them). Getting spotted brings two more knights in from behind (once per area). Break line of sight for about 5 s and an alerted guard goes back to searching. Knights will go for Eliza when she is closer; if she falls, the stage fails ("SHE WAS CAPTURED") and you retry from the checkpoint.

Blonde Lance is the hunter: longer, wider vision and he spots you in grass from 3 m. He fights when he finds you, breaks off at 66% and 33% health and reappears in the next area, and flees for good after that. Reaching the light at the far end wins ("ESCAPED THE FOREST").

Code: `scripts/citadel/Forest.gd` builds the stage and runs the hunter, reinforcements and lost-contact rules. `Citadel.gd` switches stages with `restart_with(hero, stage)`.

## Village (third stage, Phase 1)
Pick VILLAGE on the title (or open the site with `?village` on the end). The hero starts with his sword on his back and relaxed arms; DRAW pulls it over the shoulder. The village is a 3×3 grid of 40 m blocks; only the block you are in is loaded. Two are built so far: **Village Square** (centre) and **Mill Lane** (east of it). Walk off the road at a block edge and the next block loads behind a short fade. Each block has 6 villagers who never leave it (fence gaps at the roads have villager-only bars).

**Villagers** (`Villager.gd`) use placeholder bodies (the lite Lance, Eliza and Blonde Lance models, posed by the same rig). Jobs: woodcutter (axe at a tree), miner (pick at an ore rock), fisher (rod off the dock), farmer (hoe in a field), miller (goes inside the windmill), merchant (stall), elder (sits on a bench), wanderer (strolls and chats). After a work cycle they carry the load to the drop pile. They walk on a navigation mesh baked when the block loads, avoid each other, and recover if stuck (re-path, then snap back onto the mesh). Each tree, rock, dock spot, field, stall and seat (`WorkSpot.gd`) holds one villager at a time. Walk up to a villager and they stop, face you and say a line (no AI calls; lines are written per job), then go back to work.

**Day schedule** (game clock runs 2 minutes per real second, shown top-centre): sleep inside their own house before 6:00 and from 21:30; wake 6–7; work; lunch 12–13; work; socialise from 18:00. Sky and light follow the clock (dawn 5–7, dusk 19–21).

**Saving**: `user://village_save.json` (on the web, the browser's own storage). Autosaves every 20 s, on block change, and when the tab is hidden or closed. Returning within 5 game minutes puts everyone back exactly; longer, and villagers are placed where their schedule says they would be.

**Buildings**: `assets/village/village_kit.glb` is 13 buildings cut from the owner's Tripo village model (`cc village.glb` in Drive, 1.9M triangles, not in the repo), reduced and with 2048/1024 textures.

**Not in Phase 1**: Echo Vision conversations (must go through a server; no keys in the game), smarter guards, the other 7 blocks, and the owner's animation clips. LimboAI (behaviour trees) was not needed for these simple daily routines; it is worth another look for the guard AI phase.

Code: `Village.gd` (blocks, building, clock, save, block switching), `Villager.gd`, `WorkSpot.gd`, `VillageSave.gd`; tools and work poses added to `Rig.gd` / `Poses.gd`.

## Look and hit effects
Close over-the-shoulder camera (2.75 m, hero lower-left, pulls in when a wall is behind you), with extra contrast and saturation. Sword hits draw a crescent slash arc, an impact star with a light flash, spark streaks and a short freeze on hit (heavier on the combo finisher, plunge and dash). A combo counter shows on the right, and damage numbers pop bigger, with hits of 40+ in gold. Getting hit flashes red slash marks and a red screen edge. Parries get a big star, sparks and a longer freeze. Effects live in `scripts/citadel/Fx.gd`; `tools/fx_test.gd` renders them on a light and a dark floor.

## Phone performance mode
Turns on by itself on phones and touch screens (`?lite` forces it on, `?full` forces it off, `?fps` shows the frame rate in the top-left). Each build's game file gets its own name (`index.<commit>.pck`) so phones never keep running an old copy. In phone mode: no glow, no real-time sun shadows (soft blob shadows under characters instead), no extra point lights (crystals, boss aura, magic bolts; hit flashes become a soft additive glow sprite), light character models (`*_lite.glb`, ~17k triangles, 512 textures), half the particles and less forest grass. The web page draws phones at 65% of their pixel density (capped at 2x). On every device, forest trees are batched into 4 multimeshes and characters more than 38 m away skip bone posing.

## Characters
`assets/characters/` holds the owner's Tripo GLBs, reduced from ~2M to ~38k triangles with 1024 textures (`knight_lite` is ~17k for the minions). They have a 78-bone rig and no animation clips yet, so `scripts/citadel/Rig.gd` + `Poses.gd` pose the bones procedurally. The owner's Animation Library packs (Drive) use the same rig and can replace these poses once attached.

## Code
- `scripts/citadel/Citadel.gd` — world, flow, hero control, combat, lock-on, magic, camera
- `scripts/citadel/Fighter.gd` — shared body for hero, knights, boss, ally (AI state machines)
- `scripts/citadel/CitadelHUD.gd` — touch HUD (edge-anchored for wide phones)
- `scripts/citadel/AutoTest.gd` — scripted run
- `scripts/citadel/Patrol.gd` — guard patrol, vision cone, suspicion and noise (ported from `scripts/Guard.gd`)
- `tools/` — `render_portraits.gd`, `pose_test.gd`, `stance_test.gd`, `inspect_models.gd` (not exported)

## Test
```
xvfb-run -a godot --audio-driver Dummy --rendering-driver opengl3 --path . -- --autotest --quit-after-test [--shots=/dir]
```
Expect `CITADEL RESULT 72/72 PASS` (citadel, stealth, forest and village). Add `--lite` to run in phone mode. The web build runs the same test with `?autotest`.
