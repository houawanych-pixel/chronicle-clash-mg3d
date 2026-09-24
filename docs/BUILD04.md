# Build 04 — MG 3D camera and climb update

Source: Chronicle Clash — Project Status Log, Master Documents, section 1B, plus the user's explicit 2026-09-24 scope. Baseline: houawanych-pixel/chronicle-clash-mg3d @ 34deef1. No other game repository was modified.

## Delivered
- Roof detection by upward world-geometry ray; overhead outdoors and centered follow indoors.
- 0.4-second position/rotation/FOV transition with one perspective projection; 0.12-second entry and 0.20-second exit debounce plus 0.24-unit exit hysteresis.
- Swept sphere camera collision checks (radius 0.20) and hard cut to a clipped safe destination when a blend is obstructed.
- Follow-view reveal only during actual wall-hug lateral movement, mirrored by movement direction. Offset eases out when motion stops. Camera remains collision-constrained.
- CLIMB touch button, keyboard B, gamepad Y. Nearby marked crates 0.55–1.45 units above the feet can be climbed if landing capsule and both travel legs are clear.
- 0.65-second climb with a native blockout animation, capsule collision during motion, standing landing, and movement-release latch. No vaulting.
- Three waist-high crates, roofed room with doorway, and open-sky test space.

## Executed validation
Godot 4.3 stable, Linux, OpenGL Compatibility / Mesa llvmpipe. Each suite instantiates the real game scene; physics checks run across physics frames. Touch checks inject InputEventScreenTouch/Drag; the new CLIMB test finds the button produced by the rendered HUD.

- tests/update_test.gd: 35 passed, 0 failed. Roof selection, centered framing, obstructed sweep hard cut, geometry-free camera endpoint, doorway oscillation, exit debounce, both reveal directions, stationary/normal movement centering, unobstructed 0.4-second transition, three successful climbs, held-input retention, settled standing, distant/tall obstacle rejection, rendered CLIMB control and activation.
- tests/room_test.gd: 24 passed, 0 failed. Existing movement, cover, rig/animations, guard combat, ammunition/reload, mission completion, restart, pause and deferred-feature scope.
- tests/touch_test.gd: 13 passed, 0 failed. Existing two-stick interaction, fire ownership, reload, cover, pause and scaled phone coordinates.
- Editor import completed without script errors. Actual game screenshots inspected: indoor follow, open-sky crate top, indoor wall shuffle.

Run a suite with `godot --path . --script res://tests/update_test.gd` (substitute other suite names). Use a graphical display for the rendered HUD test. Test logs retain the software driver's unsupported-VSync warning.

## Limits
No physical Samsung, gamepad, Android export or web-browser test was performed for this update. The ZIP is editable source, not a new APK or a deployed website. Models and climb animation remain blockout quality; hands do not use inverse kinematics. Camera clearances and framing in every possible corner have not been exhaustively tested. The existing one-room pistol/guard scope is preserved; the earlier broader weapon/colossus wishlist is outside this update.
