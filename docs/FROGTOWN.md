# Frogtown (Crownfen Keep) — village tile

The frog-folk marsh village of Crownfen Keep (Mistfen, Elindor) as a **1x1 small
village tile** (up to 10 houses). Pick **FROGTOWN** on the title screen, or open
`/play/?frogtown` (add `&fps` for the frame counter, `&lite` to force phone mode).

Follows the owner's *Village Layout & House Interiors Plan v1.0* and the *Living
Village Simulation Build Brief v1.0* (Drive).

## How it's built

| Piece | File | Notes |
|---|---|---|
| Source model | `cc frogtown.glb` (Tripo, 24 MB, 1.9M tris) | **Never used in game.** Reference only. |
| Desktop model | `assets/frogtown/frogtown.glb` | ~110k tris, 2048 colour + 1024 normal |
| Phone model | `assets/frogtown/frogtown_lite.glb` | ~48k tris, 1024 colour, no normal map |
| Walk surface | `assets/frogtown/frogtown_walk.glb` | crack-free floor over boardwalks, plaza, decks (heightfield, gentle ramps) |
| Walls | `assets/frogtown/frogtown_walls.glb` | huts, rails, trunks: the decimated collision minus its floors (own layer, hero only) |
| Marsh | `assets/frogtown/frogtown_col.glb` (`water`) + a wading floor | falling in = splash, back to the last boardwalk spot |
| Nav mesh | `assets/frogtown/frogtown_nav.res` | prebaked (`-- --autotest --bake-frog-nav`) so phones don't bake |
| Landmarks | `assets/frogtown/frog_props.glb` | chief's shell dais, council drum, hunter request board, ancestor shell totem (+fire), flood gauge, sluice wheel, lantern posts, market stalls, door arches, bone/branch road gate, frog head + reed hat |
| Interiors | `assets/frogtown/int_hut.glb`, `int_lodge.glb` | reusable: hut x8 families, long hall x2 |
| House registry | `assets/frogtown/frogtown.json` | houses, villagers, spots, features, exits |

Build scripts are in `tools/frogtown/` (Blender as a Python module):
`build.py` (decimate + game copies + marsh split), `walk.py` (walk surface + walls),
`props.py`, `interiors.py`, `fkit.py` (lathe/sweep/fan/plank shapes — no plain primitives).

## House registry (`frogtown.json`)

Each house: `house_id` (stable save key, `CC_HOUSE_T11_Hnn`), `tile_id`, `zone_id`,
`shell_model` (the house is part of the Tripo model: exterior shell only),
`interior_model` (`INT_HUT` / `INT_LODGE`), `interior_dressing` (cloth colour + one
extra prop, so the same room looks different per family), `residents` (villager ids),
`interior_spawn`, `exterior_door_marker`, `door` (x, z), `access`
(`open` / `knock` / `locked_night` / `locked_story`), `story_flags`.

| House | Interior | Residents | Access |
|---|---|---|---|
| H01 Chief's Lodge | INT_LODGE | Chief Gullan, Mother Ribba | knock |
| H02 Reed Hut | INT_HUT | Tula, Pip-Pip | open |
| H03 Fisher's Hut | INT_HUT | Bogg | open |
| H04 Lotus Keeper's Hut | INT_HUT | Nim | open |
| H05 Herbalist's Hut | INT_HUT | Sedge | knock |
| H06 Drummer's Hut | INT_HUT | Thump | open |
| H07 Mire Family Hut | INT_HUT | Mire, Kreeka | open |
| H08 Trader's Hut | INT_HUT | Lilla | locked_night |
| H09 Reed Cutter's Hut | INT_HUT | Croak | open |
| H10 Hunt Lodge | INT_LODGE | Hunt Captain Varr | open |

## Doors

Walk into a door (or press **ENTER**, key **V**): the tile is saved and unloaded, the
house's interior is loaded, and only that house's residents who are home are made
(`Resident.gd`: cook at the hearth, eat, sleep in bed, children play, greet you or
shoo you out at night). Walk out (or **EXIT**) and you're back at that house's door,
facing out, with the village restored from the save.

## Villagers

13 frog-folk (`Villager.gd`, never the CC_ boss characters): 10 active on the tile
(chief on the dais, hunt captain at the board, drummer, lotus keeper at the totem,
two fishers, two reed gatherers, trader and herbalist at the market); 3 homekeepers
who are only ever inside. Placeholder bodies are the shared rig models with a frog
head, reed hats and a marsh-green wash, until the CC_VIL_ villager set exists.
Only one villager speaks at a time (bark lock in `Frogtown.request_bark`).

## Next tile hook

`exits` in the JSON: the bone/branch gate at the south boardwalk is `road_south ->
FROG_T12 (Reedgate Ward)`. `Frogtown.has_tile()` / `load_tile()` are the hooks for
2x2 / 3x3 villages; today the road says where it goes and turns you back.

## Performance

Phone mode loads the 48k-tri model, no normal map, no shadows, no dynamic lights on
the tile (two OmniLights on desktop: totem fire and the dais; one hearth light
inside). Villagers far from the camera skip their pose update.
