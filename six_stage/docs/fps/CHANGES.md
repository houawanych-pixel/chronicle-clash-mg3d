# HOVAGI v1.2 — First-person shooter mode (2026-10-22)

Owner request: keep the Metal Gear-style stealth game and add a first-person mode that plays like Call of Duty (option 3: switchable first-person view + better gunplay).

## What changed
- `scripts/Shooter.gd` (new): first-person view, ADS, spread/bloom, recoil + recovery, head shots, hit markers, first-person weapon models (pistol, rifle, SMG, sniper, rocket) built from extruded side profiles.
- `Game.gd`: VIEW command (O key / 1ST-3RD button), first-person aim ray from the eye, hip fire allowed in first person, AIM becomes ADS in first person, pad right stick looks.
- `EnvironmentCamera.gd`: "fps" view at eye height (1.62 m standing, 1.1 crouched, 0.42 prone), no smoothing lag; falls back to third person while climbing, hanging or on a rope.
- `Equipment.gd`: shots come from the eye in first person, spread applied, recoil kick, head shots (above 1.42 m on a guard) x3 damage, hit markers in both views.
- `HUD.gd`: crosshair that opens with spread, hit marker (white / gold head shot / red kill), HEADSHOT text, ammo count, ADS/HIP and 1ST/3RD buttons, sniper scope mask, desktop mouse-look.
- `Player.gd`: no automatic wall cover in first person. `Traversal.gd`: ADS slows you to a walk.

## Tests
- `tests/fps_shooter.gd`: 21/21 (view switch, eye camera, body hidden + gun shown, look and move together, hip fire, recoil kick and recovery, ADS zoom/spread/walk, automatic rifle and recoil climb, bloom, reload, body shot + hit marker, head shot kill, back to third person, old third-person AIM unchanged).
- Existing: campaign_controls 8/8, campaign_routes 70/70, campaign_stealth 6/6, stage01_clean 11/11.
- `tests/fps_shots.gd` takes screenshots (run under xvfb).

## Not verified
- On a real phone or with a real gamepad; mouse capture was not checked in a real browser.
- No gamepad button for VIEW yet (keyboard O or the touch button).
