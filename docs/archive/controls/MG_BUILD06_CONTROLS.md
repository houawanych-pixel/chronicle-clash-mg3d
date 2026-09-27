> SUPERSEDED CONTROL INSTRUCTIONS — historical snapshot, archived 2026-09-27.
> Active controls: ../../HOVAGI_CONTROLS_CURRENT.md (repository path: docs/HOVAGI_CONTROLS_CURRENT.md).
> Supersession applies to controls only; unrelated project history is retained.
> Source: https://docs.google.com/document/d/1TSUVgMOgKjXw5bcqSOIwJ_Ow0E_uUoLJS3yXi_Nxrjc/edit

﻿MG MOBILE CONTROLS & HUD — BUILD 06 SPEC
Chronicle Clash MG 3D (repo: houawanych-pixel/chronicle-clash-mg3d). Written 2026-09-24.
Build on current main (2e7ba63, Build 05). Do not touch castle-rpg-testbed.


ORDER CHANGE: Controls come first. The VR Training spec ("MG VR Training — Build 07 Spec") is now Build 07, because the training stages teach these controls.


WHY
User playtest: current touch controls are hard to use, text is too small to read on the phone, and there are too many buttons along the bottom. Target: Metal Gear Solid (MGS2) style controls adapted to touch — few buttons, context-sensitive action, toggles instead of held shoulder buttons. Target look = the user's concept art (HOVAGI / Chronicle Clash MG): HP + STA bars top-left, one objective, minimap top-right, a few big round buttons bottom-right, weapon panel with ammo. A mockup of this layout was made by Claude on a real Build 05 frame (the user will pass it along).


A. SIZE + READABILITY RULES (design resolution 1280x720; a phone shows it at ~0.55-0.7 scale)
- Body text >= 28 px, headings >= 34 px, button labels >= 22 px bold. Nothing smaller anywhere in gameplay HUD (menus too).
- Buttons: FIRE ~180 px diameter; ACTION/CROUCH/AIM ~110-130 px; RELOAD ~86 px. Touch hit areas at least 12 px larger than the visual. >= 16 px gaps.
- Respect phone safe areas (notch / rounded corners).
- Remove from gameplay HUD: the long hint line at the bottom, the 4-line checklist (replace with ONE objective line; tap it to expand the full list), and the bottom button row (COVER, CLIMB, RELOAD, FIRE, KNOCK, CROUCH, CRAWL, REFILL).
- Toast messages: short, >= 28 px, top-center.


B. LAYOUT (landscape)
- Top-left: HP bar + STA (stamina) bar, thick, with numbers; one objective line under them.
- Top-right: radar/minimap (enemies, drones, vision cones) + PAUSE button.
- Right edge under the radar: WEAPON slot (name + ammo) with a RELOAD button beside it, and ITEM slot (name + count) under it.
- Bottom-left: floating MOVE stick (appears where the thumb lands on the left half).
- Bottom-right cluster: FIRE (largest, corner), ACTION left of it, AIM above it, CROUCH between.


C. CONTROLS
1. MOVE stick, pressure-sensitive: light tilt (< ~50%) = silent sneak walk (no footstep noise); medium = walk; full tilt = RUN (footsteps heard by guards, drains stamina). Pushing into a wall = wall hug (automatic, as now) with the Build 05 Metal Gear cover camera + corner peek.
2. CROUCH (tap): crouch / stand toggle. While crouched, pushing the stick = drop PRONE and CRAWL (MGS style). Tap CROUCH while prone = stand up (only if there is room, as in Build 05). Vent crawl + first-person vent view stay.
3. ACTION (context button; its icon + label change to show what it will do):
   - JUMP (default; running jump goes farther)
   - CLIMB (facing a waist-high crate)
   - GRAB (mid-jump near a pole/bar/ledge)
   - KNOCK (while hugging a wall)
   - USE (at a console/door — replaces the REFILL button)
4. NEW — JUMP / GRAB / HANG (something Metal Gear didn't have): run + ACTION to jump; jumping near a pole, bar or ledge grabs it automatically. While hanging: stick LEFT/RIGHT = shimmy sideways, UP = pull yourself up (where there is a top), DOWN = drop. Hanging drains stamina; at 0 you drop. Add at least one pole/bar and one ledge to the test room.
5. FIRE: with a gun drawn = shoot. In third person it fires where you face with soft auto-target on the nearest visible enemy/drone within ~25 degrees. With weapon holstered (fists) = PUNCH, PUNCH, KICK combo; the 3rd hit knocks a guard down (stunned). Keep drone aim-assist.
6. AIM (tap on / tap off — phone version of holding R1): first-person aiming with the current gun (reticle / iron sights). Drag on the right side of the screen to look; the stick strafes slowly; FIRE shoots; tap AIM again to return to third person. SNIPER rifle and BINOCULARS use the same first-person view with a scope overlay, zoom + / - buttons and a distance readout.
7. RELOAD (tap). Also auto-reload when you FIRE with an empty magazine.
8. WEAPON slot (like MGS R2): tap = draw / holster (gun <-> fists). Long-press = weapon wheel (game slows to ~20%); tap a weapon to equip. Weapons now: pistol, sniper rifle (others later per the GDD).
9. ITEM slot (like MGS L2): tap = use equipped item (binoculars -> scope view; ration -> heal). Long-press = item wheel.
10. Remove the old right aim stick (twin-stick). Aiming is now facing + soft auto-target, or AIM mode for precision.
11. Keyboard / gamepad for desktop testing: WASD move, Shift run, Alt sneak, C crouch, Space action, J / left mouse fire, right mouse aim toggle, R reload, E weapon (hold = wheel), Q item (hold = wheel), Esc pause. Gamepad: MGS-like mapping.


D. KEEP
Everything from Build 05 (cameras, vent POV, drones, guards, climb), the Visuals.gd web fix, and < 300 3D objects.


E. TESTS
- All 112 existing checks still pass (update them only where the old touch layout is replaced; list every changed check and why).
- New tests: pressure tiers (sneak silent / run heard), crouch -> push = prone, ACTION context switching (jump/climb/grab/knock/use), jump-grab-hang, shimmy, pull-up, drop, stamina drain while hanging, punch-punch-kick knockdown, AIM toggle on/off, first-person look by drag, sniper/binocular scope + zoom, reload + auto-reload, weapon/item tap and long-press wheel, text-size rule (no HUD text < 22 px), buttons don't overlap at 1280x720 and at phone aspect ratios (19.5:9 and 20:9).
- Web: run tests/web_test.cjs + real-touch checks for the new buttons on desktop and phone size, and screenshots.


F. DELIVERY
Same as Build 05: git bundle + source zip to Drive; GitHub Deploy Manager publishes to a NEW branch "build06" (NOT main); Claude tests natively + on the web before it goes live. Report the commit, test results, and anything unfinished or unverified.