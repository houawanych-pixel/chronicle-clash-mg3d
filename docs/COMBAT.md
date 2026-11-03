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

## Movement + camera + weapon classes (block 2)
- **CameraDirector** (`camera_director.gd`, `camera_tuning.tres`): Explore 4.2 m / FOV 52 / shoulder 0.45, LockOn, Bow ADS 1.6 m / FOV 42 (AIM button), Glide 6 m, Ride 6.5 m, Climb 3 m pitched up. A SpringArm3D probe from the shoulder shortens the arm against walls; modes blend in ~0.2 s; idle stick recentres behind you after 1.2 s.
- **Jump** (`jump_tuning.tres`): 2.0 m standing peak, running adds height and carries speed; coyote 8 f, buffer 8 f, air control. **Glider**: JUMP again in the air with ≥ 2.2 m below (drains stamina, folds at 0, cancels fall damage). **Fall damage**: none under 5 m, curve to 60 % at 20 m, KO at 30 m; a hard landing stuns and blocks climbing briefly. **Mantle**: walk into a waist-high ledge (0.5–1.3 m) and Lance vaults it.
- **Dodges**: locked on = side hop / backflip (the perfect-dodge ones); not locked = a roll toward the stick.
- **Climbing** (`climb_tuning.tres`, walls in group `cc_climbable`): push into the wall; 12 stamina/s moving, 2 still, 40 for a LEAP; empty = let go. In rain (`WeatherService`) the grip goes after 8–16 m: slip 2 m and −20 stamina (a climbing-speed buff doesn't stop it). Pulls up over the top.
- **Weapon classes** (`weapon_profile.gd`, `data/cc/combat/weapons/`, WEAPON button / Q): **Ironwood Blade** (one-hand: 3-hit, hold = spin charge that drains and auto-fires when empty, shield + parry, flurry 7), **Warden Greatblade** (two-hand: slower 3-hit, hold = keep spinning, release = slam, no guard, flurry 4), **Thornreach Spear** (5-thrust string, hold = rapid thrusts until you let go or run dry, no guard, flurry 8). Each has its own blade length, colour and swing pose.

Keyboard adds: Space jump / glide / leap, V aim, Q weapon.

## Test
- `godot --path . res://scenes/systems/cc_combat_arena.tscn -- --combat-test --quit-after-test` → `CB RESULT 41/41 PASS`
- `... -- --move-test --quit-after-test` → `MV RESULT 25/25 PASS`

Still to do in this block: bow ballistics, shield surfing, boomerang/rod, one heavy-action weapon (Titan Blade or Twin Fangs).

## Not done yet (P3)
Difficulty tiers, camps sleeping at night, horn alerts, picking up weapons; real attack animation clips.
