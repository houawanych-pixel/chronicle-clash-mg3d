# Chronicle Clash — ISLES (island test world)

A test world built on Homelancer's breakable block ground, at Lance size. Pick **ISLES** on the title (sixth card), or open the site with `?isles` on the end (`/play/?isles`). You play **Lance**.

## What's in it
- **World**: a 3 × 3 grid of 48 m tiles (144 m square) that **wraps round**, Pac-Man style. Walk, glide or sail off one edge and you come back on the opposite side. The seam is always open sea.
- **Islands** (built from scratch, from the seed): Home Isle (start, grass, boulders), Crag Isle (terraced cliffs, dark obsidian rocks, two knights on top), Dune Isle (deep sand), Mist Isle (in the fog), Gull Rock (a small islet).
- **Breakable ground** (`scripts/citadel/IsleBlocks.gd`): every 0.5 m cell is a column of 0.5 m layers.
  - Materials by tone, darker = tougher: **sand 1 hit, dirt 2, stone 4, obsidian 8**.
  - **Sword**: each swing hits the rock in front of Lance at body height (never the floor under him). Stone breaks after a few hits; obsidian only chips.
  - **BOMB** (button, key B): thrown ahead, bounces, goes off after 2 s. Blasts a round crater (power 4, 1.9 m), digs into walls (tunnels), hurts knights within 3 m and Lance if he stands too close.
  - Pieces left floating fall (support reach by material), loose sand pours downhill, broken layers fly out as rubble.
  - Steps up to 1 m are drawn as smooth slopes; bigger steps stay as cliffs you can climb. Collision is the same surface.
- **Sea**: walk into deep water and you splash back to the last dry spot (−5 health). Craters dug below sea level fill with water.
- **Boat**: moored off Home Isle's south beach. **BOARD** (button, key N) when beside it; steer with the stick; **LAND** appears when a shore is close. Elyza sits aboard. Bombs work from the boat.
- **Weather zones**: sea fog round Mist Isle, a dust storm round Dune Isle (fog thickens and the light dims as you get closer).
  - **Danger in the fog**: a sea serpent circles and lunges at the boat. Three bomb hits on its head drive it off for good.
  - **Rewards**: a chest on Mist Isle; a chest **buried** under Dune Isle's sand where four dark stones stand — bomb it out. Each chest refills health and gives +2 potions.
- Ledges, wall climbing and the glider are on here (as in the Sky Citadel and TRAINING).

## Where it came from
Ported from `homelancer-digital`, branch `planet-blocks-test` (`scripts/block_field.gd`, `docs/PLANET_BLOCKS.md`): cells and layers, holes, per-layer hit counts by material, tone rule, support and collapse, sand slump, rubble, chunked fused-surface drawing, remembered natural materials. Changed for Chronicle Clash: 0.5 m cells instead of 5 m, smooth slopes for small steps, the world wraps, islands instead of a planet. Not ported (yet): water/lava pockets, mining veins, molds, caves from the seed, fire, trees, the slanted skin.

## Performance
The ground round Lance is drawn at load (about 0.5 s on a desktop); the far islands are drawn a few chunks a frame after that. Only changed chunks are redrawn after a hit.

## Test
```sh
xvfb-run -a godot --path . --audio-driver Dummy -- --isles --isles-test --quit-after-test --shots=/abs/dir
```
`scripts/citadel/IslesTest.gd` checks 34 things (ground, sword vs stone and obsidian, bomb craters and tunnels, water splash, boat board/sail/land, wrap both ways, fog serpent, dust storm, buried and open chests) and prints `ISLES RESULT n/m`.

## Survival systems in the Isles (Nov 2026)
Built from the CC survival systems (`scripts/cc/survival/`, `docs/SURVIVAL.md`), placed by `scripts/citadel/IslesSurvival.gd`:
- **Trees** on Home Isle and Mist Isle: the sword chops them (a blade: about 8 swings for an oak). Stump stays, the log falls and rolls, wood goes in the bag.
- **Wildlife**: Mossback Does on Home Isle, a Bristle Boar below Crag Isle, Dune Hares on Dune Isle. Crouch to sneak (quiet), sprint is loud. A sword hit on an animal that hasn't noticed you, or near its head, does extra damage. Meat and trophies go in the bag.
- **Forage**: glowing herbs and mushrooms; walk over them to pick them up.
- **Camp pot** (south of the start): **COOK** (key O) picks the best mix from your bag and cooks it. **POTION** eats your best meal first (badge shows meals+potions).
- **Stormrunner bike**: **BIKE** (key M) summons it on land (not at sea, not inside the Mist Isle sanctum). Stick = throttle / brake / steer, JUMP jumps, hold GUARD to DRIFT, hold DODGE to WHEELIE, BOMB still works. The badge shows fuel. Empty tank: the button reads REFUEL (burns up to 5 wood / emberroot / sparkcoal).
- Placeholder: Lance has no riding pose yet, he stands on the bike.

## Foliage (Nov 2026)
Canopy leaves, cliff vines (climbable) and flower beds with the big snapping flower: see `docs/FOLIAGE.md`.
Bombs burn them for the visit; nothing is saved, so they are all back the next time.
