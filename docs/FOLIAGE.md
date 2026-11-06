# Chronicle Clash — Unified Foliage Subsystem

Three block types — `CC_LeafBlock`, `CC_VineBlock`, `CC_FlowerBlock` — on ONE shared system:
one chunk-foliage manager (`scripts/cc/foliage/foliage_manager.gd`), one wind-sway shader
(`foliage.gdshader`), one biome palette lookup (`foliage_palette.gd`), one burn / regrow tick.
Numbers: `data/cc/foliage/foliage_tuning.tres`. Atlas: `assets/cc/foliage/foliage_atlas.png`
(made by `tools/foliage/make_atlas.py`, light greys tinted by the palette).

## Lifecycle (the only states)
`INTACT` → fire → `BURNED_CLEARED` → after `season_regrow_h` world-clock hours (T_season_regrow,
72 h by default) → `INTACT` again (young). No watering, saplings, wilting or other stages.
Burn times are world-clock hours (`WorldClock`), so a world that was not loaded catches up when it
is (`restore()` runs the season tick). The state is kept between visits and in the save file
(`foliage_store.gd`, SaveService key `foliage`).

Fire sources: anything that calls `ChemistryService.ignite_at` (Ember Arrows, fire) — foliage
managers register as burnables — and bombs in the Isles. Fire spreads cell to cell (not in rain).

## Leaves (`CC_LeafBlock`)
- Crossed-plane cards, never cube faces: an X of two tilted double-sided alpha-scissor cards plus a
  leaning card, jittered inside the cell; normals lean outward / upward for soft canopy light.
- One cell = young leaves (few bigger leaves, airy).
- 2x2 intact cells on the world grid (even cell coordinates, same layer) are drawn as ONE mature
  cluster: bigger silhouette, more cards, the small dense crisp leaf texture. Automatic in the
  mesher. Burn or break one: the rest go back to young; when all four are intact they fuse again.

## Vines (`CC_VineBlock`)
- ONE quad on the face of its host block, 0.008 m off it (no z-fighting at any distance).
- Hangs from an anchor and spreads one cell down every `vine_spread_h` world hours, up to
  `vine_max_hang` cells, while there is air below and a host face beside it.
- The vine face is CLIMBABLE: climbing on it costs `vine_climb_drain_k` of the stamina and is
  `vine_climb_speed_k` quicker (`climbable_at()`; used by the wall climb).
- Fire cuts it where it burns; the surviving top waits for the season, then grows down again.

## Flowers (`CC_FlowerBlock`)
- A faceted diamond-shell flower with a 3D white crystal core on a curved green stalk, in a tuft
  of lower-cut grass.
- Biome colours from the palette (no per-planet block types): the shell and the grass follow the
  biome; the core stays white and the stalk green. Blue-green planet: blue shell, blue-and-green
  grass. Yellow planet: yellow-and-purple grass and shell.
- 2x2 flowers on the world grid fuse into the Diamondmaw, a big snapping flower: idles open and
  sways, turns to a target inside `snap_radius`, pulls back (telegraph), snaps its shell halves shut
  (bite hit), stays shut for the cooldown, reopens. Fire burns it; the bed grows back as single
  flowers and fuses again when all four are back.

## In the ISLES (`scripts/citadel/IslesFoliage.gd`)
Canopy trees on Home Isle and Mist Isle, vines down Crag Isle's cliffs, flower beds on Home
(verdant), Mist (blue-green), Dune (yellow / purple) and Crag (highland), with a Diamondmaw on
Home, Mist and Dune.

## Test
```sh
xvfb-run -a godot --path . --audio-driver Dummy -- --isles --foliage-test --quit-after-test --shots=/abs/dir
```
`scripts/cc/foliage/tests/foliage_tests.gd`: 39 checks, prints `FOLIAGE RESULT n/m`.
