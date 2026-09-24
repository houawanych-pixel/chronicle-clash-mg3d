# Build 02 validation — 24 September 2026

24 integration assertions passed; zero failed. Engine: official Godot 4.3 Linux, OpenGL Compatibility through Mesa software rendering. The suite loads the real scene and runs physical movement frame by frame.

Checked: one room/one guard/pistol-only inventory; 16-bone Skeleton3D; head correctly positioned above torso by the rest pose; no Sprite3D; native walk/reload clips and actual bone rotation; physical wall pressure into cover; outside-wall collision; perspective cover camera; knock; corner shuffle/peek; overhead restoration; three pistol hits defeat the guard; shot ammo count; delayed reload transfer; correct reload clip selection; ammo conservation; all objectives; extraction and single-room replay; disabled deferred mechanics; held-input cleanup on pause.

Actual Godot captures were inspected. `cover.png` and `overhead.png` are scripted scene setups in the running engine. `reload.png` is a deterministic paused native-animation pose inspection so software-renderer timing does not skip the reload frame. None are image-generated concept renders. They are not evidence of a human playthrough.

## Limits
- Characters are articulated rigid-mesh blockouts, not final skinned models. The next art pass needs continuous deformation, better proportions, facial/hair detail and more polished hand/weapon contact.
- Cover shuffle uses a simple leg cycle; foot placement and sliding need refinement. Recoil/reload are short native clips rather than finished performance animation.
- Camera and aiming need hands-on review, especially when moving near cover corners. The single guard's perception and encounter difficulty have not been balanced with human playtests.
- Physical phone/gamepad testing, audio audition and device performance testing are pending.
- The test environment reports a software-driver V-Sync warning and a retained resource at shutdown. These diagnostics are included in test-results.txt. No gameplay script exception or assertion failure occurred in the final integration run.
- The larger equipment inventory, giant and grapple are not active in this milestone. Their shared source remains available for later integration.

The original four-room source project remains unchanged. Build 02 is a separate reviewable experiment in the approved 3D direction.

## Build 03 touch update
13 additional touchscreen assertions pass, covering tap-start and Play, independent sticks, inner-ring aim versus outer-ring fire, world aim direction, simultaneous movement/aim/separate fire, independent release, reload and cover taps, pause cleanup, and scaled coordinates. The original 24 integration checks also pass. This is synthetic input in Godot, not a physical Samsung playtest.

`touch_controls.png` shows the new two-thumb layout. Older screenshots remain in the folder as Build 02 references.

## Android APK export verification
Godot 4.3 exported and signed the Android debug APK successfully. Android SDK apksigner verified its v1/v2/v3 signatures. Manifest/package check: `com.chronicleclash.mg.training`, version 0.3-touch (3), minimum SDK 21, target SDK 34, launchable GodotApp activity, ARM64 + ARMv7 libraries. No Android permissions were listed by aapt. These are package checks, not a device installation or performance test.
