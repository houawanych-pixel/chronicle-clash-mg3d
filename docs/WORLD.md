# Chronicle Clash — world chemistry, weather, powers, durability (world slice)

Original code and names. Open: `/play/?world` or the **WORLD** card on the title. Scene: `res://scenes/systems/cc_world_slice.tscn`.
Layout: start in the middle · north a 10 m climbable cliff · east a grass field with a brazier on its upwind edge · south-west a pond · west **Frostpeak** (snow, −8 °C) · a metal crate and a wooden crate · a spare Warden Greatblade on the ground. Debug buttons top-left: RAIN / STORM / OMEN / CLEAR.

## Controls (adds to the arena's)
USE (E) uses the active power · POWER (F) cycles powers · THROW (T) throws the weapon in hand. Everything from the arena still works (jump, glide, climb, lock-on, three weapon classes).

## Systems
- **ChemistryService** (autoload, `scripts/cc/world/chemistry_service.gd`, `data/cc/chem/`): grass fields are 1 m fuel cells (`grass_field.gd`). Fire burns fuel and lights neighbours, much more often downwind (`WeatherService.wind_vec`). Rain puts burning cells out and refuses new fires. A fire column gives an open glider lift (`updraft_at`). In a thunderstorm a **metal** weapon draws lightning (crackle warning, then a 40 hp strike); wood (Ironwood Blade) is safe, and metal props nearby take the bolt instead. A shock in water reaches 8× as far. Frost pillars melt next to fire. Strike the brazier to tip it into the grass.
- **WeatherService** (autoload): climate regions (`climate_region.gd`, `data/cc/weather/`: temperate, frostpeak, stormcoast) are picked by the **player's** position (not the camera's) and the weather is rolled from their weights every `reroll_s`; signals `weather_changed(is_precipitating, is_thundering, wind_vec)`. Below 0 °C without `cold_resist` you lose 3 hp a second. Wind drifts the glider.
- **AbilityService** (autoload, `scripts/cc/abilities/`, `data/cc/abilities/ability_tuning.tres`): **Blast Orb (Sphere)** rolls, **Blast Orb (Cube)** sits; first USE places, second sets it off (radial push on props, damage, may light grass); a weapon strike sets one off too. Reload 2.5 s / 3.5 s after the blast. **Frost Pillar** rises from the water ahead (max 3, a 4th breaks the oldest), blocks movement, breaks after 3 hits, melts near fire. One power active at a time; reload bar on the HUD.
- **Durability + bags**: weapons live in `InventoryService.weapons` with their own life (100; −1 per hit that lands). The breaking hit does double damage; the weapon breaks and drops a stub; you switch to the next one (bare hands if none). The durability bar flashes under 20 %. THROW: double damage, the weapon is gone. Bags by category (`data/cc/inventory_caps.json`: Melee 4, Bow 3, Shield 3, Armor 20, Material 160, Food 60, Key 99); a full melee bag blocks a pickup and offers a swap. Enemies drop CC items (`briar_iron`, `briar_fletching`).

## Swim, dive, surf, bow (traversal pass)
Tuning: `data/cc/combat/traverse_tuning.tres`. The pond is now 4 m deep, with a 14 m climbable dive cliff on its west bank; three 20° slopes (grass by the start, snow in Frostpeak, rock to the north-east).
- **Swim**: deep water (> 1.4 m) and Lance swims with his head above the surface, weapon on his back. Plain swimming barely tires him; SPRINT or DODGE dashes (25 stamina/s). Out of stamina: he goes under, loses 20 hp and comes back on the last dry spot. Swim into the bank (or a climbable wall) to climb out.
- **Skydive and dive**: dropping more than 7 m he spreads out and skydives (steer with the stick, JUMP opens the glider). Close above water he goes head-first; a high dive into water at least 2.5 m deep is a splash, no damage. Hitting the ground still uses the fall-damage curve.
- **Shield surf**: hold GUARD and tap JUMP while moving. Downhill it speeds up, on flat it slows; snow and sand are slickest, then grass, then rock; rain makes it slicker. Rock wears the shield (sled wear), snow and sand don't; each landing from a hop costs a little. A worn-out shield breaks: Lance tumbles and takes a knock.
- **Bow**: AIM, then hold ATTACK (reads SHOOT) to draw and let go to fire. The shot is aimed at the centre of the screen with the arrow drop worked out, so a full draw lands on target at 30 m. Head hits do double. WEAPON while aiming switches Arrow / **Ember Arrow**: it sets grass alight where it lands, but fizzles out in rain. Aiming in mid-air slows time (stamina drains). Aiming puts the sword and shield away.

## Test
- `godot --path . res://scenes/systems/cc_world_slice.tscn -- --world-test --quit-after-test` → `WD RESULT 29/29 PASS`
- `... -- --travel-test --quit-after-test` → `TR RESULT 21/21 PASS`

## Not done yet (P2 / P3)
Iron Grasp and Time Pin, the wild mount (horse), Omen Night revival of a cleared camp (the OMEN button only forces the cooking crit today), towers / map fog / pins, NPC and camp schedules.
