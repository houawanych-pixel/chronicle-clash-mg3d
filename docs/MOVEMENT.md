# Movement system (traversal v1)

Breath of the Wild-inspired traversal for Chronicle Clash — Sky Citadel, built on the existing hero controller. Nothing was rebuilt: combat, lock-on/marks, charge dash, block/parry, dodge/air dash, stealth, ladders, grapple and wall climbing all keep their code, and the new parts slot in front of them.

## How it fits together
- `Citadel.gd → hero_tick()` still runs the hero. It now calls `trav.stamina_tick()` (stamina rules) and `trav.pre_tick()` (new states) before the wall climb, ladders and grapple, and `trav.ground_move()` in place of the old instant velocity set.
- `Traverse.gd` holds everything new: sprint + acceleration, ledge catch / hang / shimmy / pull-up, glider, slope slide, exhaustion and the low-stamina warning.
- `Fighter.gd` skips gravity in `glide`, `ledge` and `pullup` and picks the new poses.
- `CitadelHUD.gd` shows the SPRINT button and renames shared buttons by context.
- `Trials.gd` is the TRAINING test course.

## States
Existing: `idle` (walk / run / sprint / jump / fall), `attack`, `plunge`, `block`, `dodge`, `dashchain`, `hurt`, `stagger`, `climb` (ladder), `wallclimb`, `grapple`, `launch`, plus stealth stances (crouch, crawl, cover) as flags.
New: `glide`, `ledge`, `pullup`, `slide`. Sprint is a flag on `idle`, so every combat check that looks for `idle` still works while sprinting.

Rules that keep states from clashing:
- The glider only opens in the air, 2.2 m or more above the ground, with stamina left and not tired.
- Ledges and walls are only grabbed from `idle` / `glide` — never during an attack, dodge, charge or stagger.
- Pull-up always ends in `idle` on the ground.
- Running out of stamina lets go of walls and ledges and folds the glider (a controlled fall).
- Attack, block or dodge end a sprint; ATTACK while gliding folds the glider into a plunge.

## Controls
| | Touch | Keyboard | Pad |
|---|---|---|---|
| Sprint | tap SPRINT (stays on while you keep moving; stops when you stop) | hold Ctrl | hold L3 |
| Glide / close | JUMP in the air (button reads GLIDE / CLOSE) | Space | A |
| Climb | JUMP at a wall (reads CLIMB) | Space | A |
| Ledge: up / shimmy / drop | push up or JUMP (CLIMB UP) · stick sideways · DODGE (DROP) | W / Space · A D · L | stick / A · stick · B |
| Drop off a wall | DODGE (reads DROP) | L | B |

The left stick and right-side camera drag are unchanged. Only one new button was added (SPRINT, shown only on the ground out of a fight); everything else is the existing JUMP and DODGE buttons changing their name and icon.

## Shield, spin attack, shield surf
- The hero carries a heater shield on the left forearm (on the back when the sword is sheathed). GUARD raises it in front; blocking and parrying work as before.
- Spin attack: keep ATTACK held after a swing (0.45 s), the sword charges (0.55 s, the ATTACK button fills and reads SPIN!), let go to spin and hit everything within 3.4 m all round (40 damage, staggers). A quick tap is still a normal swing.
- Shield surf: hold GUARD and tap JUMP (also from a slide) to hop on the shield. Slopes speed you up (up to 16 m/s), flat ground slows you, the stick steers, JUMP hops, letting go of GUARD or ATTACK steps off, a hard wall hit knocks you off. Not in the villages.

## Tuning (`data/movement.tres`)
Open it in the Godot inspector. Defaults: stamina 100, refill 28/s after a 0.6 s rest, tired until 30%, warning under 25%. Run 6.6 m/s, sprint 9.6 (12 stamina/s), tired 4.6; ground accel 48 / decel 60, air steering 20. Climb 2.3 m/s (11/s moving, 3/s holding, leap 18). Ledge hang 2/s, shimmy 1.7 m/s, reach 2.25 m, pull-up 0.55 s. Glider 7.5 m/s, sinks 3 m/s, 7 stamina/s. Slide on floors steeper than 37°.

## Animations
The hero GLBs (Blonde Lance, Lance) have a 78-bone rig and no clips yet, so every movement pose is procedural (`Poses.gd`), applied to the real rig. New placeholder poses: `sprint`, `glide`, `ledge_hang`, `pullup` (hang → elbows over → standing), `slide`, `land`. Clips to produce later (same rig, then swap in): sprint loop, jump start, fall loop, landing, climb idle, climb up, climb sideways, ledge grab, ledge hang idle, shimmy left/right, pull-up, glider open, glide loop, glider close, slide loop, tired walk.

## Tested (autotest, `--trials-only`, both hero GLBs)
Each line below is an autotest check that passes for Blonde Lance and for Lance on the TRAINING course:
- running speeds up smoothly and stops quickly
- sprint is faster and drains stamina; touch toggle and keyboard hold both work
- stamina pauses after exertion, then refills
- running out: tired, no sprint, slower; recovers at 30%
- jump works; no glider close to the ground
- a 2.6 m ledge is caught and vaulted; a 3.3 m smooth ledge is caught and held (no wall climb on smooth walls)
- shimmy along a ledge, can't shimmy off its end, push up to pull up, DODGE drops, zero stamina drops
- climb a stone wall up and sideways and over the top; DODGE drops off; climb the 14 m tower
- glider opens high up, sinks slowly, flies and steers, uses stamina, lands 50 m out with no damage and folds away; JUMP closes it; zero stamina folds it
- an 18° ramp is walked, a 42° slope is slid down
- after traversal: sword attack hits, dodge and block work, attacking while sprinting swings
- contextual labels: GLIDE, CLIMB, CLIMB UP, DROP, TIRED; SPRINT shows on the ground and hides on a ledge

The original suite (combat, stealth, forest, village, frogtown, sky ruin incl. the wall-climb checks) still passes.

## Known limits
- No camera changes for gliding or climbing yet (the existing follow camera is used).
- Overhangs stop a wall climb (as intended); there is no climbing on the underside.
- Sprinting is louder for guards (footstep noise 7.5 m instead of 4.5 m).
- Ledges and the glider are on in the Sky Citadel and TRAINING; slope sliding only in TRAINING for now (the sky ruin mesh has steep rubble and stair faces that threw the hero off the route in testing — it needs authored slide slopes first). Sprint works everywhere.
- Not yet checked by hand on a phone or with a real gamepad — the autotest drives the same inputs.
