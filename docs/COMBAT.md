# Chronicle Clash — combat feel + enemy AI (arena)

Original code and names. Open: `/play/?arena` or the **ARENA** card on the title.
Round 1: CC_Lance vs one Briar Knight on patrol. Round 2: three Briar Knights + a Briar Archer.

## Controls (phone / keyboard)
Stick / WASD move · ATTACK / J (tap = light string, hold = charge, release = heavy spin) · DODGE / L or Space (stick sideways = side hop, otherwise backflip) · GUARD / K (hold; press just before a hit = parry) · LOCK / Tab · SPRINT / Shift · CROUCH / C · drag right side = camera · R restart.

## How it's built (`scripts/cc/combat/`, data in `data/cc/combat/`)
- **Moves** (`melee_move.gd`, `moves/*.tres`, 60 fps frames): light1–3 10/4/16 f (last hit 12/5/22, 18 dmg), heavy 22/6/26 f with 10 f hitstop and 25 stamina, flurry hit 3/2/3 f.
- **AnimationTree** (`combat_anim.gd`): every move is a real Animation with a method track calling `hit_start` / `hit_end` on the active frames and a root-motion position track for the lunge; a StateMachine holds all states, `locomote` is a BlendSpace2D. The tree is advanced by hand so hitstop freezes it exactly. The visible body is still the procedural rig (posed from the state + clip time); Mixamo / Tripo clips can be dropped into the same states later.
- **Hitbox** (`hitbox_driver.gd`): the Area3D is only on between hit_start and hit_end.
- **Feel**: hitstop on attacker + victim, spark + flash + sound on the impact frame, trauma camera shake (heavy > light), 8 f input buffer (a press in the last 8 f of recovery chains), dodge-cancel 2 f after the active frames, lock-on (camera keeps the target centred; attacks turn to it; 12° assist when not locked).
- **Defence**: guard takes 25 % damage; guard pressed ≤ 8 f before impact = parry (attacker stunned 40 f); side hop beats overheads and thrusts, backflip beats sweeps. A perfect dodge (inside a foe's just-avoid window, right direction) slows the world to 0.3 → ATTACK = flurry (one-hand 7, two-hand 4, spear 7 hits). `TimeDilation` autoload.
- **Enemy brain** (`cc_enemy.gd`, `enemy_profile.gd`, `briar_knight.tres`, `briar_archer.tres`): sight cone + line of sight, hearing (player noise × range: crouch 0.08, sprint 1.0), proximity. Roam → Notice (white ?) → Investigate → Battle (red !, alerts allies) → lose you → Forget → Roam. Battle: ring slot → wind-up telegraph (24 f, glows) → active → recover. Sneak strike ×6. Light hit staggers 12 f, heavy 30 f (interrupts the attack).
- **Group** (`group_tactics.gd`): even ring slots that keep each foe near its current angle; one melee attacker at a time with a gap between turns; archers keep 8–13 m with a 48 f draw.

## Test
`godot --path . res://scenes/systems/cc_combat_arena.tscn -- --combat-test --quit-after-test` → `CB RESULT 41/41 PASS`.

## Not done yet (P3)
Difficulty tiers, camps sleeping at night, horn alerts, picking up weapons; real attack animation clips.
