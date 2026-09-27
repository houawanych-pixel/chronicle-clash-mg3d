> SUPERSEDED CONTROL INSTRUCTIONS — historical snapshot, archived 2026-09-27.
> Active controls: ../../HOVAGI_CONTROLS_CURRENT.md (repository path: docs/HOVAGI_CONTROLS_CURRENT.md).
> Supersession applies to controls only; unrelated project history is retained.
> Source: https://docs.google.com/document/d/1g07vO8zI1hpn8rR87ex5nSw18Rr4DVsV62WQQqkJwzU/edit

﻿MG BUILD 07.x — AIMING, LOADOUT & KAI INTEGRATION (ADDENDUM)
Received 2026-09-24 ~8:56pm CT from the user/Chat; reviewed by Claude. This addendum UPDATES the "MG Build 07 Spec — Aim Stick, Facility Rooms, Comms, Characters". Where they disagree, this addendum wins (see CLAUDE REVIEW DECISIONS).


=====================================================
VERSIONING
=====================================================
- Build 07 is the milestone. Rebuilds are 07.1, 07.2, 07.3 ... (branch names: build07-1, build07-2, ...). Don't jump to Build 08 for normal fixes.


=====================================================
LEFT ANALOG STICK
=====================================================
NORMAL MODE: left stick moves Kai.
AIM MODE (press AIM):
- Left stick switches from movement to aiming: up/down/left/right/diagonals; crosshair moves freely, aim direction rotates around Kai.
- Clear EXIT AIM control returns the stick to movement.
- Applies the equipped weapon's aim camera/FOV.


DO NOT FIRE ON FIRST TOUCH
- First touch on the stick in Aim Mode only takes aim control. Dragging moves the crosshair. Firing happens only by a deliberate press after aiming is established.
- Dead zone / movement threshold so a drag never registers as a shot.


FIRE BEHAVIOR
- Pistol: one press = one shot. Sniper: one press = one shot. Automatic rifle: hold to keep firing (only once aim is established).


=====================================================
AIM CAMERA / ZOOM (per weapon/tool)
=====================================================
- Pistol: small tactical zoom, standard crosshair, over-the-shoulder style, not excessive.
- Sniper: stronger scope zoom, multiple zoom levels, ZOOM IN / ZOOM OUT controls, tighter FOV.
- Binoculars: same zoom system as sniper, deeper zoom levels, observation only, no firing.
- Each weapon/tool defines: aim FOV, min FOV, max FOV, zoom steps or speed, reticle type, aim camera behavior.


=====================================================
WEAPON + ITEM SELECTION (Metal Gear style, two sides)
=====================================================
- ITEM/TOOL side: binoculars, grenades, utility, rations later.
- WEAPON side: pistol, rifle, sniper, more later.
- Selection stays until changed. HUD always shows current weapon and current item.
- Active weapon controls: model, ammo, fire mode, reticle, zoom, aim behavior, animation, sound, reload.
- No screen full of separate buttons.


GRENADE AIMING
- Uses the same aim system: show the throw arc + landing marker; the stick adjusts direction and distance. Mobile-friendly.


=====================================================
REAL KAI MODEL
=====================================================
- assets/characters/player.glb (Kai). Aim Mode tries clip "aim", firing "shoot", reloading "reload"; everything else uses the shared humanoid animation system.
- Missing clip -> Character Model Slot fallback (closest clip, log once, never break gameplay).


TARGET FLOW
Normal: left stick -> move Kai.
Press AIM -> Aim Mode, weapon's camera/FOV, left stick = aim.
First touch -> take aim only, no shot. Drag -> move crosshair.
Deliberate press -> fire. EXIT AIM -> normal camera, stick = movement.


BUILD GOAL (07.1)
Test real Kai + corrected aiming + left stick + aim/fire separation + weapon-dependent zoom + sniper/binocular zoom controls + weapon selection + item selection + grenade arc + Character Model Slot animations.


RULES (unchanged)
main stays Build 06 until a reviewed branch passes. Branch -> Claude review -> user approval -> Deploy Manager moves main. Never force-push. Never touch castle-rpg-testbed. < ~300 objects per loaded section. Always test the web build renders.


=====================================================
CLAUDE REVIEW DECISIONS (so the builder doesn't have to guess)
=====================================================
1. WHERE "FIRE" IS: the deliberate press is the big FIRE button on the RIGHT, not a tap on the left stick. Left thumb aims, right thumb fires. This gives the "never fire on first touch" guarantee for free (the stick can't fire at all), and a short tap on the stick can't be mistaken for a shot. Do NOT make a tap on the stick fire.
2. REPLACES THE RIGHT-SIDE AIM STICK from the original Build 07 spec. In Aim Mode the right side shows only: FIRE (big), EXIT AIM, RELOAD, and for sniper/binoculars ZOOM + / ZOOM −. Optional later: pinch-to-zoom.
3. MOVING WHILE AIMING: not in 07.1 (Metal Gear style: you stand/crouch still while aiming). Crouch still works in Aim Mode.
4. AIM STICK FEEL: stick controls aim SPEED (tilt = turn speed, like a gamepad), not absolute position; slower near center for fine aim; separate sensitivity per weapon (sniper scoped = slower). Keep pitch range for high drones and the low dog.
5. BINOCULARS: FIRE button hidden or disabled while binoculars are up.
6. GRENADES: in Aim Mode with grenade selected, stick sets direction + distance (push further = throw further); arc + landing marker drawn; FIRE button throws.
7. KAI'S CLIPS TODAY: only "kick" is in player.glb; "box_01/box_02" (punches), "dive", "defeat" are coming next, then idle/walk/run/sneak/crawl/aim/shoot/reload/hit from Tripo. Until "aim"/"shoot"/"reload" exist, the fallback must hold a sensible pose (idle), not T-pose.
8. TESTS the review will check: first touch in Aim Mode never fires; EXIT AIM always restores movement; pistol/sniper/binocular FOVs differ and stay in their min/max; FIRE disabled with binoculars; weapon/item choice persists across Aim Mode on/off; game loads with and without player.glb; web build draws at phone size.