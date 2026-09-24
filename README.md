# Chronicle Clash MG 3D — Build 06 review testbed

Godot **4.3**, original 3D blockout models, touch-first landscape controls. One project contains **7 unlocked labs and 11 training stages**. This is a mechanics prototype, not the finished facility campaign.

**Review branch: `build06`. Do not merge or deploy to the live site until independent review.** Only `houawanych-pixel/chronicle-clash-mg3d` is in scope. Do not modify `castle-rpg-testbed`.

## Open and play

Extract the source ZIP and import `chronicle-clash-mg3d/project.godot` in Godot 4.3. On the Android editor, use its **Run Project** button; no F5 is needed. This ZIP is not an APK. Physical Samsung performance has not been tested.

Tap **PLAY**, then **PLAY** on the briefing. Pause → **CHAMBERS** selects any lab or stage. **TEST: ALL OPEN** is on by default. Toggle it for training unlocks. Pause → **CHECKLIST** shows verified and unfinished features. Use the cyan console to refill supplies; in the weapons range it also cycles normal/persistent jam drills.

## Controls

| Control | Touch | Keyboard / mouse |
|---|---|---|
| Move | Floating left stick; light tilt sneaks, full tilt runs | WASD / arrows; Alt sneaks, Shift runs |
| Stance | Tap CROUCH; move while crouched to crawl; tap again to stand | C |
| Context action | ACTION changes to climb, jump, knock, grab, hide, etc. | Space |
| Shoot / melee | FIRE; holster first for punch–punch–kick | J or left mouse |
| First-person aim | Tap AIM; drag empty right side to look | Right mouse or V; hold left mouse and drag empty right side to look |
| Reload / clear jam | LOAD beside weapon | R |
| Weapon | Tap slot to holster/draw; hold 0.45s for wheel | Tap/hold E |
| Item | Tap slot to use; hold 0.45s for wheel | Tap/hold Q |
| Pause | II | Esc / P |

Weapon/item wheels slow simulation to 20%. Sniper and binoculars share zoom buttons. Gun aim acquires nearby visible targets in third person; first-person aim is manual. A sword uses AIM as a short timed parry. A concealed player cannot fire from a locker.

Jump toward the tall ledge or bar to catch it. Left/right shimmies; up pulls onto a ledge; down drops. Poles support upward climbing. Hanging drains stamina and drops you at zero. For crates, face one and use CLIMB; crouch near one and use PUSH to push/pull, then RELEASE. CLIMB stands on top instead of vaulting over.

Holster near a guard's back for HOLD, then ACTION chokes or FIRE throws. Holster near a downed guard for DRAG, move, then ACTION releases. These actions use simple blockout animation.

C4's first item tap places a charge; the next detonates it. Chaff disables nearby visible drones for eight seconds. Rations restore health. Cloak drains energy and shooting exposes you. Rifle jams occur after 240–300 hot shots, not every few rounds.

In WATER LAB, walk into the pool. ACTION dives/surfaces; near the south edge it climbs out. While diving, first-person look pitch controls vertical swim direction. Oxygen depletes underwater and refills near the surface.

Gamepad mappings exist (left stick move, right stick look, A action, B stance, X reload, LB aim, RB fire, stick clicks for weapon/item, Start pause). Physical gamepad testing remains pending.

## Scope and evidence

See `docs/BUILD06.md` for the validation record, limitations and handoff. Per-suite runtime logs and rendered browser captures are under `docs/build06/`. The in-game verification manifest is `assets/verified_features.json`; the export preset includes it explicitly.

The source ZIP and Git bundle are review deliverables. They do not update GitHub or the live website automatically.
