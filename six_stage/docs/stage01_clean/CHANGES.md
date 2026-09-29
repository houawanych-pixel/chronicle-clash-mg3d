# HOVAGI Stage 01 update — v1.1 (2026-09-28)

User playtest feedback: walking looked bad, camera too far/high, AIM had to be held, start screen too
wordy, map mesh lumpy/choppy, unclear where to go. Changes:

## Map (Stage 01)
- `build_support/clean_stage.py 1` rebuilds Stage 01 from the walkable-floor data as clean flat
  platforms: 152,174 → 6,418 triangles, split into 28 chunks (8 m) for culling. Collision = same surface.
- Only camera-visible faces are generated (tops, cliff faces, outer walls). Nothing underneath or inside.
- Metal Gear-style cutaway (`scripts/cutaway.gdshader`): geometry above the player's floor that blocks
  the camera is cut away, with a lit edge.
- The mashed staircase between the start corridor and the upper-left rooms is rebuilt as real stairs;
  bridge ramps are drawn as treads/risers (collision stays a smooth slope).
- Pathfinding no longer crosses sheer cliffs and prefers walkway centres.
- Originals kept: `nav1_source.json`, `mission1_source.json`, original S01 GLB (excluded from web export).
- Other five stages unchanged (same script can be run for each).

## Camera
- Close chase camera behind/above the player (6.2 m back, 4.4 m up), swings round lazily; keyboard and
  touch movement are camera-relative.

## Controls / UI
- AIM is a tap toggle; the button reads LOWER while aiming. FIRE shoots only while aiming (holstered
  FIRE = STRIKE still works); quick taps are latched so they never get lost.
- Title: HOVAGI + one big START. Briefing: stage name, "Follow the green light.", big GO.
- Green guide: light column + pulsing ring on the next objective, the current door glows green,
  on-screen marker with distance, arrow when off screen. Only the current objective is highlighted.

## Characters
- Model was facing backwards (glTF +Z vs game -Z): player and guards walked backwards. Fixed.
- Kai reused guard clips without retargeting (58/79 bones differ in rest pose) → leaning, bent limbs.
  Clips are now retargeted through both rest poses.
- Walk/run clips carried ~1.9 m of forward hip drift that snapped back every loop, and the run sat
  0.8 m to one side. Root motion stripped; playback speed matched to measured stride
  (walk 1.1 m/s, run 3.25 m/s — `tests/stride.gd`). Move speeds: sneak 1.4, walk 2.6, run 4.4 m/s.

## Verification
- Native: campaign routes 70/70, controls 8/8, stealth 6/6, `tests/stage01_clean.gd` 11/11.
- Browser: Chromium, Galaxy S24 landscape emulation (touch), SwiftShader software GPU. Loads with no
  console errors or failed requests; START→GO→play, stick movement, AIM/FIRE/LOWER verified.
- Not verified: a real phone, real frame rate (software GPU runs ~0.5 fps for old and new alike),
  full hands-on Stage 01 playthrough in the browser.
