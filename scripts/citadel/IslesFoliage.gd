extends RefCounted
## The CC foliage subsystem (scripts/cc/foliage) placed in the ISLES world:
##   - canopy trees on Home Isle and Mist Isle: leaf cells (young at the edges, mature 2x2
##     clusters inside), on a trunk;
##   - vines hanging down Crag Isle's cliff faces (climbable, spreading down over the days);
##   - flower beds: Home Isle (verdant), Mist Isle (blue-green), Dune Isle (yellow / purple),
##     Crag Isle (highland), each with one 2x2 group that fuses into a big snapping flower.
## Bombs burn foliage too (and Ember fire through ChemistryService). Burnt foliage grows back
## after the season (world clock); its state is kept for the next visit and in the save.

const Manager = preload("res://scripts/cc/foliage/foliage_manager.gd")
const Store = preload("res://scripts/cc/foliage/foliage_store.gd")

## The ISLES block ground seen by the foliage manager.
class Host extends RefCounted:
	var f: Node3D
	var step: float
	func _init(field: Node3D) -> void:
		f = field
		step = f.STEP
	func cell_world(ix: int, iz: int) -> Vector2:
		return Vector2(-f.HALF + (ix + 0.5) * f.STEP, -f.HALF + (iz + 0.5) * f.STEP)
	func layer_y(k: int) -> float:
		return f.ly(k)
	func solid(ix: int, iz: int, k: int) -> bool:
		return f.solid(f.idx(ix, iz), k)
	func top(ix: int, iz: int) -> int:
		return f.top[f.idx(ix, iz)]

const CANOPY_TREES: Array = [[Vector2(-3, -4), "verdant"], [Vector2(15, -3), "verdant"], [Vector2(-12, 16), "verdant"], [Vector2(-13, -47), "bluegreen"], [Vector2(-3, -51), "bluegreen"]]
## flower beds: centre, radius, biome, where the 2x2 big flower stands (or none)
const BEDS: Array = [
	[Vector2(-9, 16), 3.2, "verdant", Vector2(-10, 16)],
	[Vector2(-5, -44), 3.0, "bluegreen", Vector2(-4, -42)],
	[Vector2(-45, 37), 3.0, "yellow", Vector2(-46, 39)],
	[Vector2(47, -9), 2.2, "highland", null],
]
const CRAG: Vector2 = Vector2(48, -6)

var isles: RefCounted
var game: Node
var field: Node3D
var mgr: Node3D
var host: Host
var trunks: Array = []
var rng := RandomNumberGenerator.new()

func _init(i: RefCounted) -> void:
	isles = i
	game = i.game
	field = i.field

func build(root: Node3D) -> void:
	rng.seed = 2207
	host = Host.new(field)
	mgr = Manager.new()
	mgr.name = "Foliage"
	mgr.host = host
	mgr.world_id = "isles"
	mgr.target_fn = func() -> Node3D: return game.hero
	mgr.fx_fn = func(p: Vector3, c: Color) -> void: game.fx.sparks(p, c, 6, 3.0)
	root.add_child(mgr)
	for t: Array in CANOPY_TREES:
		canopy_tree(t[0], t[1])
	for b: Array in BEDS:
		flower_bed(b[0], b[1], b[2], b[3])
	crag_vines()
	var snap: Dictionary = Store.get_snapshot("isles")
	if not snap.is_empty():
		mgr.restore(snap)

## Keep the state (with its world-clock times) for the next visit and the save.
func leave() -> void:
	if mgr != null and is_instance_valid(mgr):
		Store.keep("isles", mgr.snapshot())

func cell(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x + field.HALF) / field.STEP), floori((p.y + field.HALF) / field.STEP))

## A canopy tree: a tapered trunk and an ellipsoid of leaf cells round its crown.
func canopy_tree(at: Vector2, biome: String) -> void:
	if not field.is_land(at.x, at.y):
		return
	var g: float = field.top_at(at.x, at.y)
	var trunk_h: float = 2.7
	var centre := Vector3(at.x, g + trunk_h + 0.55, at.y)
	trunks.append(make_trunk(Vector3(at.x, g, at.y), trunk_h + 0.4, biome))
	var rx: float = 1.75
	var ry: float = 0.95
	var c0: Vector2i = cell(at)
	var s: float = field.STEP
	var cells: int = int(ceil(rx / s)) + 1
	for dz in range(-cells, cells + 1):
		for dx in range(-cells, cells + 1):
			var ix: int = c0.x + dx
			var iz: int = c0.y + dz
			var w: Vector2 = host.cell_world(ix, iz)
			for k in range(field.kof(centre.y - ry), field.kof(centre.y + ry) + 1):
				var y: float = field.ly(k) + s * 0.5
				var q := Vector3((w.x - centre.x) / rx, (y - centre.y) / ry, (w.y - centre.z) / rx)
				if q.length() + rng.randf_range(-0.08, 0.12) <= 1.0:
					mgr.add_leaf(ix, k, iz, biome, centre)

## The trunk: a tapered eight-sided column, bark coloured (solid, so Lance can't walk through).
func make_trunk(base: Vector3, h: float, biome: String) -> Node3D:
	var P = load("res://scripts/cc/foliage/foliage_palette.gd")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var slot: float = P.slot(P.biome_index(biome), P.BARK)
	var segs: int = 4
	for i in segs:
		var y0: float = h * i / segs
		var y1: float = h * (i + 1) / segs
		var r0: float = lerpf(0.26, 0.13, float(i) / segs)
		var r1: float = lerpf(0.26, 0.13, float(i + 1) / segs)
		var lean0 := Vector3(sin(i * 0.9) * 0.05, 0, cos(i * 1.3) * 0.05)
		var lean1 := Vector3(sin((i + 1) * 0.9) * 0.05, 0, cos((i + 1) * 1.3) * 0.05)
		for k in 8:
			var a0: float = TAU * k / 8.0
			var a1: float = TAU * (k + 1) / 8.0
			var p00 := Vector3(cos(a0) * r0, y0, sin(a0) * r0) + lean0
			var p01 := Vector3(cos(a1) * r0, y0, sin(a1) * r0) + lean0
			var p10 := Vector3(cos(a0) * r1, y1, sin(a0) * r1) + lean1
			var p11 := Vector3(cos(a1) * r1, y1, sin(a1) * r1) + lean1
			mgr._tri(st, p00, p10, p11, slot, 0.0, 0.0, 0.0, 0.8 + 0.2 * (k % 2))
			mgr._tri(st, p00, p11, p01, slot, 0.0, 0.0, 0.0, 0.8 + 0.2 * (k % 2))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mgr.material
	var body := StaticBody3D.new()
	body.name = "CanopyTrunk"
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.24
	cyl.height = h
	cs.shape = cyl
	cs.position.y = h * 0.5
	body.add_child(cs)
	body.add_child(mi)
	mgr.add_child(body)
	body.global_position = base
	return body

## A bed of single flowers (spaced so they never form 2x2 by chance) and one planned 2x2 group.
func flower_bed(c: Vector2, r: float, biome: String, maw: Variant) -> void:
	var taken: Dictionary = {}
	if maw != null:
		var m: Vector2i = cell(maw)
		m = Vector2i(m.x - posmod(m.x, 2), m.y - posmod(m.y, 2))   # on the world grid
		var ok: bool = true
		for o: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			var w: Vector2 = host.cell_world(m.x + o.x, m.y + o.y)
			if not field.is_land(w.x, w.y):
				ok = false
		if ok:
			for o: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				mgr.add_flower(m.x + o.x, m.y + o.y, biome)
			for dz in range(-2, 4):
				for dx in range(-2, 4):
					taken[Vector2i(m.x + dx, m.y + dz)] = true
	var tries: int = 0
	var placed: int = 0
	while placed < 9 and tries < 80:
		tries += 1
		var a: float = rng.randf() * TAU
		var p: Vector2 = c + Vector2(cos(a), sin(a)) * sqrt(rng.randf()) * r
		var ci: Vector2i = cell(p)
		if taken.has(ci) or not field.is_land(p.x, p.y) or field.rock[field.cell_at(p.x, p.y)] != 0:
			continue
		if mgr.add_flower(ci.x, ci.y, biome):
			placed += 1
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					taken[ci + Vector2i(dx, dz)] = true

## Vines down Crag Isle's cliffs: anchors at the top of each tall face, spaced out.
func crag_vines() -> void:
	var c0: Vector2i = cell(CRAG)
	var R: int = int(15.0 / field.STEP)
	var cands: Array = []
	var dirs: Array = Manager.DIRS
	for dz in range(-R, R + 1):
		for dx in range(-R, R + 1):
			var ix: int = c0.x + dx
			var iz: int = c0.y + dz
			for di in 4:
				var d: Vector2i = dirs[di]
				# (ix, iz) is the air column, (ix + d) the cliff it hangs on
				var hi: int = field.top[field.idx(ix + d.x, iz + d.y)]
				var lo: int = field.top[field.idx(ix, iz)]
				if hi - lo >= 3 and field.rock[field.idx(ix + d.x, iz + d.y)] == 0 and field.ly(lo) > -0.5:
					cands.append([hi - lo + rng.randf(), ix, iz, di, hi])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))   # the tallest faces first
	var used: Dictionary = {}
	var made: int = 0
	for cnd: Array in cands:
		if made >= 34:
			break
		var ix: int = cnd[1]
		var iz: int = cnd[2]
		if used.has(Vector2i(ix, iz)):
			continue
		mgr.add_vine(ix, iz, cnd[3], int(cnd[4]) - 1, "highland", rng.randi_range(1, 3))
		made += 1
		for oz in range(-3, 4):
			for ox in range(-3, 4):
				used[Vector2i(ix + ox, iz + oz)] = true

## Climbing on vines: cheaper and a little quicker ([drain k, speed k]).
func climb_k(p: Vector3) -> Vector2:
	if mgr != null and mgr.climbable_at(p):
		return Vector2(float(mgr.tuning.vine_climb_drain_k), float(mgr.tuning.vine_climb_speed_k))
	return Vector2.ONE
