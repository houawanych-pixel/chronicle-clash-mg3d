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
| Pause | II (beside the stats) | Esc / P |

## Stealth (ported from the MG build)
The three courtyard guards patrol with vision cones (shown on the floor and the map). Numbers match the old `Guard.gd`: 40° half-cone, suspicion rises 1.15/s in view and falls 0.3/s out of view, crouching cuts their range to 80% and crawling to 50%. Low planters hide you only when crouched. Walking upright makes footstep noise; crouching and crawling are silent. Knocks and pebbles send guards to INVESTIGATE, then SEARCH, then back to PATROL. Full suspicion raises the alarm and wakes guards within 14 m into sword combat. Attacking an unaware guard is a silent takedown. The top shows STEALTH: HIDDEN / SUSPICIOUS / ALERT.

Cover and crawl logic is from `Player.gd` (`toggle_cover`, cover slide with edge peek, wall-pressure entry, crawl). The wall-hug camera is the `EnvironmentCamera.gd` cover view. Change from the MG build: tapping CROUCH crouch-walks and holding it crawls (the MG build crawled as soon as you moved while crouched).

The Dark Knight's leap sends out a red shockwave; jump or dodge through it.

## Forest Escape (second stage)
Pick FOREST ESCAPE on the title. You play Lance; Eliza (just rescued) stays right behind you and crouches when you do. Three areas, each with a knight pair on patrol: the glade, the rocks, the tall grass, then the forest edge. Crouch or crawl inside tall grass and knights can't see you unless they are within 2 m. Boulders and trees are cover (wall hug works on them). Getting spotted brings two more knights in from behind (once per area). Break line of sight for about 5 s and an alerted guard goes back to searching. Knights will go for Eliza when she is closer; if she falls, the stage fails ("SHE WAS CAPTURED") and you retry from the checkpoint.

Blonde Lance is the hunter: longer, wider vision and he spots you in grass from 3 m. He fights when he finds you, breaks off at 66% and 33% health and reappears in the next area, and flees for good after that. Reaching the light at the far end wins ("ESCAPED THE FOREST").

Code: `scripts/citadel/Forest.gd` builds the stage and runs the hunter, reinforcements and lost-contact rules. `Citadel.gd` switches stages with `restart_with(hero, stage)`.

## Look and hit effects
Close over-the-shoulder camera (2.75 m, hero lower-left, pulls in when a wall is behind you), with extra contrast and saturation. Sword hits draw a crescent slash arc, an impact star with a light flash, spark streaks and a short freeze on hit (heavier on the combo finisher, plunge and dash). A combo counter shows on the right, and damage numbers pop bigger, with hits of 40+ in gold. Getting hit flashes red slash marks and a red screen edge. Parries get a big star, sparks and a longer freeze. Effects live in `scripts/citadel/Fx.gd`; `tools/fx_test.gd` renders them on a light and a dark floor.

## Phone performance mode
Turns on by itself on phones and touch screens (`?lite` forces it on, `?full` forces it off, `?fps` shows the frame rate in the top-left). In phone mode: no glow, no real-time sun shadows (soft blob shadows under characters instead), no extra point lights (crystals, boss aura, magic bolts; hit flashes become a soft additive glow sprite), light character models (`*_lite.glb`, ~17k triangles, 512 textures), half the particles and less forest grass. The web page draws phones at 65% of their pixel density (capped at 2x). On every device, forest trees are batched into 4 multimeshes and characters more than 38 m away skip bone posing.

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
Expect `CITADEL RESULT 51/51 PASS` (citadel, stealth and forest). The web build runs the same test with `?autotest`.
