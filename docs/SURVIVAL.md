# Chronicle Clash — survival systems (P0)

Original code and names. Data in `res://data/cc/`, scripts in `res://scripts/cc/survival/`, test map in `res://scenes/systems/`.

| Autoload | Job |
|---|---|
| InventoryService | stacked items (`items.json`) + unique meals |
| CookingService | 1–5 ingredients → one meal (`ingredients.json`, `cooking_tuning.tres`) |
| StaminaPool | one stamina meter (P1 movement will use it) |
| WorldClock | day/night; every 7th night 23:30–00:15 is an **Omen Night** (cooking always crits) |
| SaveService | writes inventory + clock to `user://cc_save.json` |

- **Trees** (`tree_node.gd`, `tree_resource.gd`, `data/cc/trees/*.tres`, tools in `data/cc/tools/`): damage = tool power × chop_mult by kind (axe 1.0, blade 0.4–0.5, blunt 0 = bounces). At 0 hp: stump stays, a RigidBody3D log tips away from the cutter and rolls, wood goes to the inventory.
- **Cooking** (`cooking_service.gd`, `cook_site.gd`): pot hearts = raw × 2; one buff family → timed buff (tier from potency, time from ingredients, cap 30:00); two families → Murky Stew (no buff); crit chance = best ingredient crit + 0/4/8/12/16 % by count; a crit adds hearts, a tier or time; Omen Night forces it. Campfire roast = raw × 1.5, never a buff.
- **Hunting** (`wildlife_agent.gd`, `wildlife.json`, `drop_tables.json`): Idle → Graze → (walk) → Alert → Flee → Dead. Sight cone shrinks when the hunter is quiet; hearing = range × noise. Head hits ×2, unaware ×2. Drops roll into the inventory; unaware kills roll extra.
- **Stormrunner bike** (`bike.gd`, `bike_tuning.tres`, `fuel.json`, `summon_zone.gd`): fuel only burns with throttle on the ground; a full tank = `tank_seconds` (300) at full throttle; empty = no drive; refuel ≤ 5 items, capped at 100 %; drift starts ≥ 13 m/s and ends ≤ 9 m/s; wheelie 2.2 s; jump every 1.2 s; summon refused inside zones tagged interior / sanctum / deep_water.
- **Horse**: next (taming + bond).

Test: `godot --path . res://scenes/systems/cc_survival_test.tscn -- --cc-test --quit-after-test` → `CC RESULT 43/43 PASS`.
