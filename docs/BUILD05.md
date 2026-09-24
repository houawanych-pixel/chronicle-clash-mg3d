# Build 05 — cover camera, crawl/vent, drones (review preview)

Baseline: `ea6cc3e` from `houawanych-pixel/chronicle-clash-mg3d`, including the merged-grid web rendering fix. Source of scope: current Chronicle Clash — Project Status Log, Master Documents, updated September 24, 2026, ~2:40am CT. Only the MG repo is changed. Do not merge/deploy to main before independent review.

## Implemented behavior

- Cover overrides the outdoor/indoor camera choice. Moving/peeking uses Build 03's values: FOV 58; focus player + up 1.2 + tangent 1.4 + peek 2; camera player + wall normal 5.5 - tangent 3 + up 2.8. Tangent follows cover_side. Stationary cover retains low-angle framing but removes lateral bias. Ordinary movement remains centered. Roof debounce, 0.4s transitions and swept-camera collision checks are retained; obstructions may clip the ideal framing or force a cut.
- CRAWL/STAND is a full-sized bottom touch action, keyboard Z, left-stick click. Prone capsule height 0.6, speed 1.1 m/s, guard detection range half of standing. Landing/standing capsule checks prevent standing into geometry, including through CROUCH or CLIMB. A native prone/crawl rig pose is included.
- Vent is 3.9m long, 1.4m clear width, 0.85m clear height. It passes through a new low opening in the roofed room's front wall, left of the normal doorway. Capsule collision and guard navigation prevent guard entry. Camera becomes first person at eye height 0.43 inside; own avatar is hidden. Backward movement preserves view direction; right aim stick turns POV. Exit restores third-person framing.
- Scout drone: yellow, visible searchlight, roughly one continuous second of detection raises an alarm and alerts the existing guard. It rearms after losing the target; it does not spawn reinforcements. Two 35-damage pistol hits down it.
- Attack drone: red, forward awareness and world-geometry sight checks, eight damage per shot, 1.2s cadence. Three pistol hits down it. Both drone types have patrol paths and fall onto collision geometry when destroyed, stop attacking, and are removed from the minimap's live targets.
- Aim assist picks a visible live drone within 12 degrees of the touch stick's horizontal bearing, up to 18m, and aims vertically at it. It cannot lock through walls/roofs. HUD shows DRONE LOCK. Minimap uses yellow/red square markers.
- Grid mesh merge implementation is unchanged. The initial room contains 160 MeshInstance3D nodes. Short-lived combat effects add transient nodes; initial scene budget gate is below 300.

## Validation

Native: Godot 4.3 stable, Linux, actual OpenGL Compatibility renderer under Xvfb / Mesa llvmpipe.

- `tests/room_test.gd`: 24 passed, 0 failed.
- `tests/touch_test.gd`: 13 passed, 0 failed.
- `tests/update_test.gd`: 35 passed, 0 failed (Build 04 camera/climb regressions).
- `tests/build05_test.gd`: 40 passed, 0 failed. Includes exact unobstructed cover camera coordinates, roofed/outdoor cover, peek offset, crawl capsule and speed, complete vent traversal, first-person eye/body visibility, blocked standing and bypass attempts, backward POV stability, guard visibility and exclusion, scout alarm timing, roof/vent occlusion, attack cadence/damage, aim cone rejection and real touch-aim pipeline, actual pistol ray hits, downed falling, and real rendered CRAWL touch activation.

Total: **112 native assertions**. Tests and raw logs are included. Godot editor import and Web release export succeeded. Software renderer emits an unsupported-VSync warning; that is not a game script failure.

Web: `tests/web_test.cjs` serves the Godot Web release export locally with cross-origin isolation headers, then launches Chromium 153 / SwiftShader through Playwright. It uses the same PCK/WASM, injecting command-line demo/diagnostic arguments through the HTML config only. It exercises real touch start/brief/play, CRAWL and STAND; captures cover, vent POV, prone and drone scenes at 1280x720 and 915x412. All 14 browser checks passed with no script/page errors; the rendered captures were visually inspected and show the 3D scene (not just the HUD). See `build05-browser-tests.txt` and `screenshots/build05_web_*` for the completed outcome and actual renders.

For native reruns: `xvfb-run -a godot --path . --script res://tests/build05_test.gd` (substitute the other suite names).
For web reruns: export `Web` to a local folder, install Playwright, then set `WEB_ROOT` to that folder, `CHROMIUM_BIN` to your Chromium executable, and run `node tests/web_test.cjs`. `WEB_TEST_OUTPUT` optionally selects the screenshot directory. The test server is temporary/local only.

## Limits and handoff

Physical Samsung hardware and real mobile-GPU performance are untested. A phone-sized Chromium viewport is not a physical-device test. No Android APK was exported. Models/animations are original blockout art; prone hands are not IK-locked to the floor. Browser captures establish scene rendering and selected touch flows, not exhaustive manual playtesting of every corner/combat combination.

Work is committed locally on `build05`. This session's GitHub push dry-run failed because there is no authenticated GitHub write credential. The Drive handoff therefore includes a source ZIP and a Git bundle so the authorized deploy bot can publish the exact commit to `build05`. Do not report the remote branch as published until that push succeeds. The existing Pages workflow triggers only on main and remains unchanged. The live site and castle-rpg-testbed were not modified.
