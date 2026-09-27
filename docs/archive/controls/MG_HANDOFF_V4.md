> SUPERSEDED CONTROL INSTRUCTIONS — historical snapshot, archived 2026-09-27.
> Active controls: ../../HOVAGI_CONTROLS_CURRENT.md (repository path: docs/HOVAGI_CONTROLS_CURRENT.md).
> Supersession applies to controls only; unrelated project history is retained.
> Source: https://docs.google.com/document/d/1HgFRkQhu1h0bjSgl0AyFuf8GKbTtI_UPO9AvbHXX8uA/edit

﻿MG BUILD HANDOFF v4 — EPISODE PLAN, ELEVATOR LOADING, CODEC, CONTROLS, KNOCKOUT
Chronicle Clash MG (HOVAGI) · Godot 4.3 · Web export (GitHub Pages, phones first) · Claude (reviewer) → Chat (builder)
Replaces Handoff v3. Map source: "HOVAGI Facility Map Bible v3" (Drive › HOVAGI › Facility — Layouts & Rooms).
DEPLOY RULES: branch → Claude review → user approval → Deploy Manager fast-forwards main. No force-push. Never touch castle-rpg-testbed.


============================================================
A. HOW WE BUILD: ONE PART AT A TIME
============================================================
Do NOT try to build the whole facility. Ship in parts. Each part = its own branch, its own Claude review, its own deploy.


PART 1  Foundation (no level art): texture-compression fix, character test room (all 8 assets), controls + icon HUD, auto-aim, KO/sleep, codec UI, elevator UI, WorldState + save, episode loader.
PART 2  Shared kit greybox (~50 props as simple boxes with correct sizes) + EP01 LANDFALL greybox, fully playable.
PART 3  EP02 TOP DECK + first real ELEVATOR RIDE into EP03 (proves pack loading on a phone).
PART 4  EP03 + EP04 (Level -1). → first "demo" to show people.
PART 5  Art pass on EP01–EP04 (swap greybox for kit meshes as Claude delivers them).
PART 6+ Two episodes per part: EP05–06, EP07–08 (boss 1), EP09–10 (mech boss), EP11–12 (finale).
Each part must stay playable on its own: title screen → continue → the newest episode.


============================================================
B. EPISODES (full list in Map Bible v3 §1)
============================================================
01 Landfall (L0) · 02 Top Deck (L0) · 03 Intake (L-1) · 04 Quarters (L-1) · 05 Research (L-2) · 06 Virus (L-2) · 07 Lockdown (L-3) · 08 The Forge + Boss 1 (L-3) · 09 Pressure (L-4) · 10 Hangar + Mech Boss (L-5) · 11 Cargo rail ride (L-6) · 12 Launch finale (L-7).
Each episode: 3 rooms (EP10 = 1 room), one objective, a save at the end, 10–20 min.


============================================================
C. LOADING — THE MGS ELEVATOR TRICK
============================================================
Rule: the player never sees a loading screen. Episodes change only inside a "mask": elevator, ladder climb, vent crawl, rail car tunnel.


ELEVATOR SEQUENCE (the MGS moment)
1. Player walks into the elevator → context button shows the elevator icon → tap.
2. FLOOR PANEL UI slides in (right side, like a real wall panel): big square buttons B1…B7, lit = unlocked (by keycard), dark = locked, current floor glows. Keycard colour strip on each locked button (orange/red/black).
3. Player taps a floor → button lights, "ding", doors close (1 s).
4. RIDE: interior stays on screen, floor counter ticks (B1 → B2), light strips slide past the door windows, gentle camera shake + hum. Minimum 6 s, max until loaded.
5. During the ride (hidden work):
   - HTTPRequest downloads epNN.pck if not cached (web is single-threaded; HTTPRequest is still async). Show nothing but a small "▼" arrow blinking on the floor counter while it downloads.
   - ProjectSettings.load_resource_pack("user://epNN.pck")
   - Load the episode root; add rooms ONE PER FRAME (spreads the hitch); free the old episode.
   - A CODEC CALL can fire during the ride (story beat) — covers longer downloads naturally.
6. "Ding" → doors open onto the new episode. Autosave.
Same pattern for ladders (screen fades on the climb), vents (crawl animation loops), the rail car (tunnel darkness).


Inside an episode: all 3 rooms are loaded; hide rooms not visible (VisibleOnScreenEnabler3D on each room root or manual door triggers) to keep draw calls down.


Web export: base.pck includes engine, UI, kit, cast, EP01 (target ≤ 40 MB). ep02–ep12 are separate .pck files next to index.html, downloaded on demand and cached in user://. vram_texture_compression/for_mobile = TRUE.


============================================================
D. CODEC / HOLO-CALL (from the Lance–Eliza mockup)
============================================================
The hero taps a wrist band → hologram call opens in the CENTER of the screen, ~1/3 of screen height, ~70% width. Game world keeps showing above/below (darkened 40%).
Layout: [caller portrait LEFT] [frequency + waveform bars CENTER, e.g. 140.85] [contact portrait RIGHT]; text box under the portraits, typewriter text, tap to advance, ▶ skip. Blue hologram tint + scanlines + small flicker on open/close.
Portraits: the character expression images (neutral, smile, angry, worried, shocked) — swap per line. The talking side's waveform animates.
Two kinds:
- STORY CALL: pauses the game (enemies freeze). Used in elevators and at objectives.
- FIELD CALL: small version (1/5 height, top-center), game keeps running — hints like "Snake-style" radio chatter.
Data: res://dialogue/epNN.json → [{speaker, portrait, expression, text}]. Codec button on the HUD opens the contact list (call saved-game / hint contacts).


============================================================
E. CONTROLS (MGS feel, icons)
============================================================
LEFT stick = move (light = sneak, full = run). Never fires.
RIGHT diamond: A COVER · B CROUCH (hold = crawl) · Y ITEM (hold = picker) · X ACTION (context: takedown / punch combo / drag / open / climb / elevator).
FIRE: tap = hip-fire while standing or running with AUTO-AIM (35° cone, pistol 15 m, rifle 25 m, no lock through walls or behind you). Hold = aim stance with laser lock, release to shoot.
AIM: precision first-person, no movement, aim friction only. Tranq headshot = instant sleep; body = 5 s stumble.
Alert phases: Normal → Caution → Alert (red "!") → Evasion → Caution → Normal.
PC keys: WASD, Space, C, Q, E, LMB, RMB.


============================================================
F. KNOCKOUT & SLEEP
============================================================
KO: stars orbit head, 25–35 s, wake ring. SLEEP: floating Zs, 45–60 s. Kick/damage wakes. Guards shake downed guards awake → Caution. Drag + hide in lockers (never found). Dog KO only; drone stun 20 s; bosses immune. WorldState saves every guard's state per episode.


============================================================
G. CAST (branch assets-kai → assets/characters/)
============================================================
kai (player; full clip set coming), ayame, agi, guard, guard_cyborg (also Boss 1 at 1.25 scale), boss_mech (speed 0.6), drone (code-animated parts), dog (code-animated legs). Never share one AnimationLibrary across rigs.


============================================================
H. PART 1 REVIEW TESTS (Claude checks these)
============================================================
- ≥ 30 FPS on the user's Samsung with 6 guards.
- Run + tap FIRE hits a guard 30° off-centre at 10 m; never locks through a wall.
- KO stars / sleep Zs / wake / shake-wake / locker hide survive a save + reload.
- Elevator: panel shows locked/unlocked floors; a test pack downloads during the ride; doors never open before the next area is ready; no frame over 250 ms while doors are open.
- Codec: story call pauses the world, field call doesn't; portraits swap expression per line.