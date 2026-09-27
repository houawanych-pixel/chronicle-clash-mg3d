# HOVAGI Stage 01 design addendum v1.0

Date: 2026-09-27. Active requirement: user's Important Addendum.
Required controls: HOVAGI Controls v1.0 (HOVAGI_CONTROLS_CURRENT.md).
Status: design requirements recorded; stage implementation and playtests pending.

Stage 01 is not a straight hallway. Each section provides at least two practical approaches where geometry permits: guarded direct path and a stealth, vent, elevation, darkness, distraction, keycard or system-bypass alternative. Choices need readable clues and meaningful tradeoffs.

## Progression and required observable changes

The following seven encounter beats follow the user's progression example. They are design beats, not a silent replacement of the Map Bible's three-room EP01 structure.

| Beat | Challenge | Route choices | Visible facility response |
|---|---|---|---|
| 1 | Movement, one forgiving patrol, obvious cover | Direct cover route or sheltered edge | Patrol responds to a taught distraction |
| 2 | Two guards with overlapping vision | Timed direct crossing or side passage | Distraction draws a guard away |
| 3 | Camera/light puzzle and tighter timing | Watch camera sweep or cut local power | Local lights/camera indicator shut off; disabled camera cannot detect |
| 4 | Stairs, catwalks and mutual guard coverage | Lower cover route or elevated bypass | Traversal reaches a clearly connected landing |
| 5 | Access restriction and useful backtracking | Retrieve access card or bypass local terminal | Lock indicator changes; previously blocked shortcut opens |
| 6 | Stealth + traversal + system interaction | Timed guarded route or machinery-enabled path | Machinery physically changes traversable space |
| Final | Strongest combined security in this stage | At least two demonstrated valid solutions where practical | Objective state, access change and exit/save feedback agree |

Difficulty comes from placements, overlapping patrols, timing, access rules, route knowledge, puzzle dependencies and resource pressure—not merely more health. Reward observation, patience, planning, stealth and tool use.

Puzzle families: power routing, terminals, keycards/access levels, switches, shutters, cameras, blind spots, light/darkness, sound, patrol timing, traversal and environmental hazards.
Every puzzle needs a visible clue, actionable interaction, understandable response, usable alternate route where practical, and a recovery path. Persistent changes must survive backtracking/save reload. Do not trap the player by consuming the sole required item or disabling the only exit.

## Map compatibility

Latest inspected Map Bible v3 assigns EP01 Landfall three rooms: Water Access → Vehicle Bay → Security Gatehouse; steal the orange keycard at the Gatehouse console. Its baseline is three soldiers and one dog.
Keep those room identities/objective. If Stage 01 means EP01, fit progression beats into subareas and patrol phases within these rooms; do not inflate it to the whole facility or silently apply every suggested enemy count as a new mandate. Record any departure from the episode map/enemy budget explicitly before implementation.
Power/camera teaching here can be a small local circuit; EP03 remains the episode for disabling the camera network.

## Implementation acceptance

Document each section's entrances/exits, elevations, cover, patrol routes, sightlines, route tradeoffs, puzzle state transitions and connection back to the main route.
Prove at least two complete solutions to the final encounter and avoid mandatory combat where a stealth solution is promised.
Verify stairs/catwalks physically connect, alternate routes are traversable, and puzzle changes affect collision/detection rather than just visuals.
Test each route in the running build with HOVAGI Controls v1.0 at phone width; physical Samsung validation is a separate required result.
Follow Map Bible v3 episode budgets: environment <=90k triangles, <=350 nodes, <=120 visible draw calls, <=6 active guards, <=1024 textures and <=25 MB episode pack. Retain merged geometry and existing web-render safeguards.
Report the exact implementation commit, selected control version, route test results, screenshots and outstanding work. No completed-stage or passed-control claim is made by this document.
