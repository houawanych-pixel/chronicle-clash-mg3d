# HOVAGI Controls v1.0 — current specification

Date: 2026-09-27 (America/Chicago).
Status: ACTIVE DESIGN REQUIREMENT from the user's Important Addendum; implementation and mobile validation PENDING.
This is the first explicit HOVAGI Controls semantic version found/assigned in this audit. Build numbers and Handoff v4 are not control-version numbers.
Repository: houawanych-pixel/chronicle-clash-mg3d.
Verified main at audit: e5e045bc87f60b59e1f95746c18ab6b0420565a1 (Build 06). This file does not claim that main implements v1.0.

## Authority and selection

The user's 2026-09-27 addendum governs Stage 01.
The Build 07.x aiming addendum documents separate left-stick aim and right FIRE, first-touch protection, single-shot weapons and weapon-specific zoom. It is the closest supporting control specification.
The newer MG Build Handoff v4 (2026-09-25) proposes FIRE hold → laser stance → release-to-shoot. It is a proposal, not evidence of an approved and tested implementation. No validating newer build was found in the inspected branches or PR collection. The exception allowing release-to-fire is therefore NOT activated.
The latest explicit user requirement changes the older tap-toggle AIM behavior to HOLD AIM; this is an intentional v1.0 revision, not a claim that an old build already did it.

## State and input contract

NORMAL: left stick moves the player. Preserve existing run-and-gun/auto-aim only where implemented; line of sight must block target acquisition through walls.
AIM: hold the right-side AIM button to enter precision mode. Left stick controls directional aim speed, including pitch, with slower fine adjustment near center and weapon-specific sensitivity. Movement stops while precision aiming; crouch remains available.
First aim touch acquires input only. Dragging, crossing the stick dead zone, and releasing a stick must never generate a shot.
FIRE is a separate, deliberate right-side button input after aim has been acquired. A FIRE touch already held when entering AIM must be released and pressed again before it can shoot in AIM.
Pistol/sniper: one new FIRE press = exactly one shot, even if held.
Automatic weapons: a new FIRE press starts fire; continued hold may repeat at weapon cadence.
Binoculars: FIRE disabled/hidden; no ammunition consumption.
Release AIM, explicit cancel, focus loss, touch cancellation, or pause: stop precision firing, remove aim overlays, restore normal movement mapping. Never fire on release. Clear held inputs and require a fresh movement contact to avoid a sudden run when the aim stick is remapped.
Keep touch ownership independent: a pointer started on AIM/stick must not become FIRE by sliding over it.
Use an aim dead zone plus drag threshold; document tuned values with the implementing version and touch test evidence. The stick has no firing path.

## Visuals and weapons

Show a small laser line/dot or restrained reticle aligned with the actual shot collision direction and first obstruction; never indicate a hit through intervening cover.
Preserve existing sniper/binocular zoom and add bounded weapon-specific sensitivity/FOV settings as needed. Do not claim cosmetic night/thermal filters as real sensors.
No giant arcade crosshair by default.
Enemy awareness lights: YELLOW = unaware/normal search; RED = detected/alert.
If grenade precision aiming is exposed, use a trajectory arc and landing marker; deliberate FIRE throws, never an aim drag/release.

## Mobile layout

Landscape, safe-area anchored. HP/STA and one objective top-left; minimap/pause top-right. Weapon/ammo and item slots remain readable.
Left side: movement stick in NORMAL, directional aim stick in AIM.
Right side: held AIM, separate large FIRE, RELOAD, CROUCH and contextual ACTION. Weapon/item pickers remain available without filling the screen with separate item buttons.
Sniper/binocular zoom controls appear only when relevant.
AIM + left aim stick + FIRE requires a three-contact reach test; do not silently replace HOLD AIM with toggle to solve ergonomics. If it fails phone testing, propose a versioned dedicated-aim-control layout allowed by the addendum.
At reference 1280x720 preserve the older readability targets (body 28 px, headings 34 px, labels 22 px minimum) and tune physical hit areas using phone testing. Check 16:9, 19.5:9 and 20:9.

## Superseded control sources

Historical copies are retained in docs/archive/controls/. Original Drive files are preserved and have NOT been renamed or moved by this documentation change.

| Source | Status for new Stage 01 control implementation | Reason |
|---|---|---|
| MG Mobile Controls & HUD — Build 06 | SUPERSEDED | Toggle aim, right drag-look and moving/strafe while aiming conflict |
| Original MG Build 07 Spec | SUPERSEDED | Right aim-stick proposal replaced by 07.x |
| MG Build 07.x aiming addendum | SUPERSEDED as active control source; retained as rationale | Separate FIRE retained; tap AIM/EXIT replaced by held AIM/release cancel |
| MG Build Handoff v4 §E | SUPERSEDED for controls | Release-to-shoot lacks verified approval evidence and conflicts with current addendum |
| Build 04/05/06 runtime notes and README controls | HISTORICAL / SUPERSEDED for future control design | Describe older builds; do not rewrite their test outcomes as v1.0 results |

Non-control portions of historical documents are not globally invalidated. Old builds remain runnable historical baselines, not v1.0 builds.

## Evidence audit

Drive searched for HOVAGI, MG and controls; the newly named HOVAGI folder returned no children. Read Build 06 controls, original Build 07, 07.x addendum, Handoff v4 and Map Bible v3.
GitHub branches found: main, build06, build05, assets-kai. Inspected their file trees; main/build06 are Build 06 and assets-kai has the same generation of docs. PR collection returned empty.
Read README.md, docs/BUILD06.md, docs/build06/HANDOFF.md at main's audited commit. Their phone viewport checks do not establish physical Samsung validation. No approved release-to-fire build was found in these sources.
Source links are preserved in archive snapshots. Findings are bounded to this audit, not proof that no other offline build exists.

## Mandatory validation before Stage 01 acceptance

All are PENDING for v1.0:
- First touch, aim drag and aim release: zero shots/ammo changes.
- One deliberate pistol/sniper press: exactly one shot; a held press remains one.
- Automatic hold: correct cadence; release/cancel stops immediately.
- Existing FIRE hold cannot leak into precision mode.
- Dead-zone jitter, drag across button bounds, pointer cancellation, pause/resume and focus loss: no unintended shots or movement.
- Laser endpoint agrees with actual bullet collision, including nearby cover, elevated drones and low targets.
- Binoculars cannot fire; zoom is bounded; weapon/item selections persist across aim transitions.
- Aim release restores movement; crouch works; no sticky inputs.
- Actual interaction with the running Web build at phone viewport sizes, including simultaneous contacts and thumb reach; save screenshots/results and exact commit.
- Physical Samsung test separately records device, FPS and control comfort. Browser emulation is not physical-device validation.

Every behavior change increments this version, archives the previous specification, and records implementation commit plus test results. Stage 01 must declare the version it implements.
