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
| Pause | II (top left) | Esc / P |

The Dark Knight's leap sends out a red shockwave; jump or dodge through it.

## Characters
`assets/characters/` holds the owner's Tripo GLBs, reduced from ~2M to ~38k triangles with 1024 textures (`knight_lite` is ~17k for the minions). They have a 78-bone rig and no animation clips yet, so `scripts/citadel/Rig.gd` + `Poses.gd` pose the bones procedurally. The owner's Animation Library packs (Drive) use the same rig and can replace these poses once attached.

## Code
- `scripts/citadel/Citadel.gd` — world, flow, hero control, combat, lock-on, magic, camera
- `scripts/citadel/Fighter.gd` — shared body for hero, knights, boss, ally (AI state machines)
- `scripts/citadel/CitadelHUD.gd` — touch HUD (edge-anchored for wide phones)
- `scripts/citadel/AutoTest.gd` — scripted run
- `tools/` — `render_portraits.gd`, `pose_test.gd`, `inspect_models.gd` (not exported)

## Test
```
xvfb-run -a godot --audio-driver Dummy --rendering-driver opengl3 --path . -- --autotest --quit-after-test [--shots=/dir]
```
Expect `CITADEL RESULT 21/21 PASS`. The web build runs the same test with `?autotest`.
