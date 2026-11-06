extends RefCounted
## Biome palettes for the foliage shader. A planet / biome is a row of 16 role colours; the
## shader reads slot = biome * 16 + role. Adding a biome = adding a row (no new block types).
## The flower's inner core stays white and its stem green everywhere; its outer shell and the
## lower-cut grass round it follow the biome's grass / accent colours.

const LEAF_YOUNG := 0
const LEAF_MATURE := 1
const VINE := 2
const GRASS_A := 3
const GRASS_B := 4
const SHELL_A := 5
const SHELL_B := 6
const CORE := 7
const STEM := 8
const BARK := 9
const CHAR := 10

const BIOMES: Array = ["verdant", "bluegreen", "yellow", "highland"]

static func row(biome: String) -> Array:
	match biome:
		"bluegreen":   # blue-green planet: blue shell, blue-and-green grass
			return [Color("5fb07a"), Color("3f9468"), Color("4c9a6a"), Color("3d86e0"), Color("4fbf6a"), Color("2f74ef"), Color("5aa2ff"), Color.WHITE, Color("4a9a3c"), Color("6b5a48"), Color("3a3330")]
		"yellow":      # yellow planet: yellow-and-purple grass, shell in the same yellow / purple
			return [Color("a8b84a"), Color("8a9a38"), Color("8fa03e"), Color("f2cf3a"), Color("9a5ad6"), Color("ffd23c"), Color("a764e0"), Color.WHITE, Color("4f9a3a"), Color("7a6448"), Color("3a3330")]
		"highland":    # crag / highland: teal-grey grass, lavender accent
			return [Color("6c9a64"), Color("557f52"), Color("5e8a5a"), Color("6e9c80"), Color("9f8fd0"), Color("9a84e0"), Color("c2b5f2"), Color.WHITE, Color("4f8f42"), Color("6a5d52"), Color("3a3330")]
	# verdant (default): green planet, fresh greens, coral accent
	return [Color("5fa83e"), Color("3f8a2c"), Color("5ea544"), Color("6fbe45"), Color("b6d64a"), Color("ff7d6e"), Color("ffb07a"), Color.WHITE, Color("4a9a3c"), Color("6e5844"), Color("3a3330")]

static func biome_index(biome: String) -> int:
	return maxi(0, BIOMES.find(biome))

static func slot(biome: int, role: int) -> float:
	return float(biome * 16 + role)

## The shader's palette uniform: 4 biomes x 16 roles.
static func uniform_array() -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(64)
	for b in BIOMES.size():
		var r: Array = row(BIOMES[b])
		for k in 16:
			out[b * 16 + k] = r[k] if k < r.size() else Color.WHITE
	return out
