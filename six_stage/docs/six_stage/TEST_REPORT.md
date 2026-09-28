# Prototype 01 verification

## Passed

- 70 automated Godot checks: all six stage transitions; physical character movement from each stage start through every required objective; objective prerequisites; Level 1/Level 2 access; circuit failure recovery; coolant solution; unsafe/safe conveyor timing; scientist creation and escort completion; extraction timer; final victory.
- 8 control/checkpoint checks: aim movement does not fire; deliberate pistol FIRE produces one shot; held pistol FIRE does not repeat; releasing AIM does not fire; control ownership clears on release/pause; checkpoint reload preserves stage and access; retry rolls current objectives back while retaining prior cards; health depletion enters failure state.
- 6 stealth checks: visible detection/radio, hit interruption, nonlethal takedown, elevated wall cover, cover distraction, cover exit.
- Godot 4.3 script import and Web export.

## What these tests do not establish

Route checks drive the actual CharacterBody3D through its movement and collision code. Enemies are not advanced during those route checks, so the results verify routeability and progression rather than combat balance or a human stealth playthrough. Puzzles and extraction timing are tested through their normal state handlers with deterministic inputs.

Browser testing was attempted but Chromium could not launch because its required local socket was blocked. The available managed preview workflow also lacked its required browser-control skill. No successful rendered browser session or physical Samsung test is claimed. Phone readability, animation appearance, browser save persistence, loading behavior, performance, and combat difficulty need hands-on review.

Open issues: generated art/collision alignment at ramps; provisional animation retargeting; static people baked into stage art; simple scientist/drone visuals; final terrain not supplied as a separate 3D asset.
