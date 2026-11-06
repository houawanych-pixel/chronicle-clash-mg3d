extends Node3D
## CC Unified Foliage Subsystem: CC_LeafBlock, CC_VineBlock and CC_FlowerBlock on ONE shared
## chunk-foliage manager, ONE wind-sway shader (foliage.gdshader), ONE biome palette lookup
## (foliage_palette.gd) and ONE burn / regrow tick.
##
## Lifecycle, the same for all three (and nothing else: no watering, saplings, wilting):
##   INTACT  --fire-->  BURNED_CLEARED  --T_season_regrow (world clock)-->  INTACT (young)
## Burn times are world-clock hours, so foliage that was not loaded catches up when it is.
##
## CC_LeafBlock   crossed-plane cards (an X of tilted double-sided cards, never cube faces).
##                One cell = young leaves. A 2x2 group of intact cells on the world grid (even
##                cell coordinates, same layer) is drawn as ONE mature cluster instead (bigger
##                silhouette, smaller denser leaves). Burn one: the rest go back to young; when
##                all four are intact again they fuse again. All automatic in the mesher.
## CC_VineBlock   ONE quad on the face of its host block, 0.008 m off it (no z-fighting). Hangs
##                down from an anchor and spreads one cell down per vine_spread_h world hours to a
##                cap. Its face is CLIMBABLE (cheaper, quicker wall climbing). Fire cuts it where
##                it burns; the surviving top regrows downward after the season.
## CC_FlowerBlock a faceted diamond-shell flower with a white 3D core on a curved green stalk, in a
##                tuft of lower-cut grass; shell and grass take the biome's colours, the core stays
##                white and the stalk green. A 2x2 group fuses into a big snapping flower (the
##                Diamondmaw): idles open, notices a target, pulls back, snaps its shell shut
##                (bite), cools down, reopens.
##
## The host world is reached through `host` (an adapter object with cell_world(ix, iz),
## layer_y(k), solid(ix, iz, k), top(ix, iz), step).

const Palette = preload("res://scripts/cc/foliage/foliage_palette.gd")
const Store = preload("res://scripts/cc/foliage/foliage_store.gd")
const SHADER = preload("res://scripts/cc/foliage/foliage.gdshader")
const ATLAS_PATH: String = "res://assets/cc/foliage/foliage_atlas.png"

const INTACT := 0
const BURNED := 1
const CH := 24                     # cells per mesh chunk side (even: a 2x2 group never splits)

# atlas regions (UV rects)
const UV_YOUNG := Rect2(0.0, 0.0, 0.5, 0.5)
const UV_MATURE := Rect2(0.5, 0.0, 0.5, 0.5)
const UV_VINE := Rect2(0.0, 0.5, 0.5, 0.5)
const UV_GRASS := Rect2(0.5, 0.5, 0.25, 0.5)
const UV_WHITE := Rect2(0.82, 0.62, 0.12, 0.12)

var host: Object
var tuning: Resource
var material: ShaderMaterial
var world_id: String = "world"
var leaves: Dictionary = {}        # Vector3i(ix, k, iz) -> {s, t, b, c (canopy centre)}
var flowers: Dictionary = {}       # Vector2i(ix, iz) -> {s, t, b, k}
var vines: Array = []              # chains: {ix, iz, dir, k, len, cap, b, burned_at, last}
var by_chunk: Dictionary = {}      # Vector2i chunk -> {leaves: [], flowers: [], vines: []}
var meshes: Dictionary = {}        # Vector2i chunk -> MeshInstance3D
var dirty: Dictionary = {}
var jaws: Dictionary = {}          # Vector2i group -> big flower {node, head, upper, lower, state, t, ...}
var spread_q: Array = []           # [{kind, key, at}]
var target_fn: Callable            # -> Node3D (the snapping flowers bite it), or null
var fx_fn: Callable                # (pos: Vector3, col: Color) a burn puff
var _tick_t: float = 0.0
var _real: float = 0.0
# counts (tests)
var burns: int = 0
var regrows: int = 0
var bites: int = 0
var vine_grown: int = 0

const DIRS: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

func _init() -> void:
	tuning = load("res://data/cc/foliage/foliage_tuning.tres")
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("atlas", load(ATLAS_PATH))
	material.set_shader_parameter("palette", Palette.uniform_array())
	material.set_shader_parameter("sway_amount", float(tuning.sway_amount))
	Store.register_save()

func _ready() -> void:
	if ChemistryService.has_method("add_burnable"):
		ChemistryService.add_burnable(self)

func _exit_tree() -> void:
	if ChemistryService.has_method("remove_burnable"):
		ChemistryService.remove_burnable(self)

# ---------------------------------------------------------------- clock

## World-clock hours since day 1, 00:00 (the season timer runs on this).
static func now_h() -> float:
	return float(WorldClock.day - 1) * 24.0 + WorldClock.hour

# ---------------------------------------------------------------- placing

func chunk_of(ix: int, iz: int) -> Vector2i:
	return Vector2i(floori(float(ix) / CH), floori(float(iz) / CH))

func _bucket(ck: Vector2i) -> Dictionary:
	if not by_chunk.has(ck):
		by_chunk[ck] = {"leaves": [], "flowers": [], "vines": []}
	return by_chunk[ck]

func add_leaf(ix: int, k: int, iz: int, biome: String, centre: Vector3) -> void:
	var key := Vector3i(ix, k, iz)
	if leaves.has(key):
		return
	leaves[key] = {"s": INTACT, "t": -1.0, "b": Palette.biome_index(biome), "c": centre}
	var ck := chunk_of(ix, iz)
	(_bucket(ck).leaves as Array).append(key)
	dirty[ck] = true

func add_flower(ix: int, iz: int, biome: String) -> bool:
	var key := Vector2i(ix, iz)
	if flowers.has(key):
		return false
	flowers[key] = {"s": INTACT, "t": -1.0, "b": Palette.biome_index(biome), "k": int(host.top(ix, iz))}
	var ck := chunk_of(ix, iz)
	(_bucket(ck).flowers as Array).append(key)
	dirty[ck] = true
	return true

## A vine anchored on the face of the host block next to air cell (ix, iz) in direction dir
## (0 +x, 1 -x, 2 +z, 3 -z), its top at layer k.
func add_vine(ix: int, iz: int, dir: int, k: int, biome: String, start_len: int) -> void:
	var c: Dictionary = {"ix": ix, "iz": iz, "dir": dir, "k": k, "len": 0, "cap": int(tuning.vine_max_hang), "b": Palette.biome_index(biome), "burned_at": -1.0, "last": now_h()}
	vines.append(c)
	var ck := chunk_of(ix, iz)
	(_bucket(ck).vines as Array).append(vines.size() - 1)
	for i in start_len:
		if not _vine_can_grow(c):
			break
		c.len = int(c.len) + 1
	dirty[ck] = true

func _vine_can_grow(c: Dictionary) -> bool:
	if int(c.len) >= int(c.cap):
		return false
	var k: int = int(c.k) - int(c.len)
	var d: Vector2i = DIRS[int(c.dir)]
	if k < 1 or host.solid(int(c.ix), int(c.iz), k):     # air cell must be free
		return false
	if k < int(host.top(int(c.ix), int(c.iz))):          # (and above the ground below it)
		return false
	return host.solid(int(c.ix) + d.x, int(c.iz) + d.y, k)   # its host face must be there

## The vine cells of a chain, top first: [Vector3i(ix, k, iz)].
func vine_cells(c: Dictionary) -> Array:
	var out: Array = []
	for i in int(c.len):
		out.append(Vector3i(int(c.ix), int(c.k) - i, int(c.iz)))
	return out

# ---------------------------------------------------------------- fire

## Called by ChemistryService.ignite_at (Ember Arrows, fire sources) and by blasts: every intact
## foliage cell within r of p burns. Returns how many caught.
func burn_sphere(p: Vector3, r: float) -> int:
	var n: int = 0
	var st: float = float(host.step)
	for key: Vector3i in leaves.keys():
		if int(leaves[key].s) == INTACT and _cell_pos(key.x, key.y, key.z).distance_to(p) <= r + st * 0.5:
			_burn_leaf(key)
			n += 1
	for key: Vector2i in flowers.keys():
		var f: Dictionary = flowers[key]
		if int(f.s) == INTACT and _flower_pos(key).distance_to(p) <= r + st * 0.5:
			_burn_flower(key)
			n += 1
	for ci in vines.size():
		var c: Dictionary = vines[ci]
		var cells: Array = vine_cells(c)
		for j in cells.size():
			var v: Vector3i = cells[j]
			if _cell_pos(v.x, v.y, v.z).distance_to(p) <= r + st * 0.5:
				_burn_vine(ci, j)
				n += 1
				break
	return n

func _burn_leaf(key: Vector3i) -> void:
	var d: Dictionary = leaves[key]
	if int(d.s) != INTACT:
		return
	d.s = BURNED
	d.t = now_h()
	burns += 1
	dirty[chunk_of(key.x, key.z)] = true
	_puff(_cell_pos(key.x, key.y, key.z))
	if not WeatherService.is_precipitating:
		for dz in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var nk := Vector3i(key.x + dx, key.y + dy, key.z + dz)
					if nk != key and leaves.has(nk) and int(leaves[nk].s) == INTACT and randf() < float(tuning.burn_spread_chance):
						_queue("leaf", nk)

func _burn_flower(key: Vector2i) -> void:
	var f: Dictionary = flowers[key]
	if int(f.s) != INTACT:
		return
	f.s = BURNED
	f.t = now_h()
	burns += 1
	dirty[chunk_of(key.x, key.y)] = true
	_puff(_flower_pos(key))
	if not WeatherService.is_precipitating:
		for d: Vector2i in DIRS:
			var nk: Vector2i = key + d
			if flowers.has(nk) and int(flowers[nk].s) == INTACT and randf() < float(tuning.burn_spread_chance):
				_queue("flower", nk)

## Burn vine chain ci at segment j: it is cleared from there down; the top keeps hanging.
func _burn_vine(ci: int, j: int) -> void:
	var c: Dictionary = vines[ci]
	if j >= int(c.len):
		return
	var cells: Array = vine_cells(c)
	for i in range(j, cells.size()):
		var v: Vector3i = cells[i]
		_puff(_cell_pos(v.x, v.y, v.z))
	burns += 1
	c.len = j
	c.burned_at = now_h()
	dirty[chunk_of(int(c.ix), int(c.iz))] = true

func _queue(kind: String, key: Variant) -> void:
	var dl: Vector2 = tuning.burn_spread_delay
	spread_q.append({"kind": kind, "key": key, "at": _real + randf_range(dl.x, dl.y)})

func _puff(p: Vector3) -> void:
	if fx_fn.is_valid():
		fx_fn.call(p, Color("ff8a2a"))

# ---------------------------------------------------------------- ticking

func _process(dt: float) -> void:
	_real += dt
	material.set_shader_parameter("wind_dir", WeatherService.wind_vec.normalized() if WeatherService.wind_vec.length() > 0.05 else Vector3(1, 0, 0))
	material.set_shader_parameter("wind_strength", clampf(WeatherService.wind_vec.length() / 2.5, 0.4, 2.2))
	# fire spreading through the foliage
	for i in range(spread_q.size() - 1, -1, -1):
		var q: Dictionary = spread_q[i]
		if float(q.at) > _real:
			continue
		spread_q.remove_at(i)
		if WeatherService.is_precipitating:
			continue
		if q.kind == "leaf" and leaves.has(q.key):
			_burn_leaf(q.key)
		elif q.kind == "flower" and flowers.has(q.key):
			_burn_flower(q.key)
	_tick_t += dt
	if _tick_t >= 0.5:
		_tick_t = 0.0
		season_tick()
	_jaws_tick(dt)
	for ck: Vector2i in dirty.keys():
		draw_chunk(ck)
	dirty.clear()

## Regrowth and vine spreading, on the world clock (catches up any amount of elapsed time).
func season_tick() -> void:
	var now: float = now_h()
	var T: float = float(tuning.season_regrow_h)
	for key: Vector3i in leaves.keys():
		var d: Dictionary = leaves[key]
		if int(d.s) == BURNED and now - float(d.t) >= T:
			d.s = INTACT
			d.t = -1.0
			regrows += 1
			dirty[chunk_of(key.x, key.z)] = true
	for key: Vector2i in flowers.keys():
		var f: Dictionary = flowers[key]
		var top_now: int = int(host.top(key.x, key.y))
		if int(f.s) == INTACT and top_now != int(f.k):   # the ground under it was blasted away
			f.s = BURNED
			f.t = now
			dirty[chunk_of(key.x, key.y)] = true
		elif int(f.s) == BURNED and now - float(f.t) >= T:
			f.s = INTACT
			f.t = -1.0
			f.k = top_now
			regrows += 1
			dirty[chunk_of(key.x, key.y)] = true
	var step_h: float = float(tuning.vine_spread_h)
	for ci in vines.size():
		var c: Dictionary = vines[ci]
		# its host face blasted away: it is gone below there
		for i in int(c.len):
			var k: int = int(c.k) - i
			var dd: Vector2i = DIRS[int(c.dir)]
			if not host.solid(int(c.ix) + dd.x, int(c.iz) + dd.y, k) or host.solid(int(c.ix), int(c.iz), k):
				c.len = i
				dirty[chunk_of(int(c.ix), int(c.iz))] = true
				break
		if float(c.burned_at) >= 0.0:
			if now - float(c.burned_at) < T:
				continue
			c.last = float(c.burned_at) + T   # the season has passed: it grows again from then
			c.burned_at = -1.0
			regrows += 1
		var steps: int = int(floor((now - float(c.last)) / step_h))
		if steps <= 0:
			continue
		c.last = float(c.last) + steps * step_h
		for s in steps:
			if not _vine_can_grow(c):
				break
			c.len = int(c.len) + 1
			vine_grown += 1
			dirty[chunk_of(int(c.ix), int(c.iz))] = true

# ---------------------------------------------------------------- queries

func _cell_pos(ix: int, k: int, iz: int) -> Vector3:
	var w: Vector2 = host.cell_world(ix, iz)
	return Vector3(w.x, float(host.layer_y(k)) + float(host.step) * 0.5, w.y)

func _flower_pos(key: Vector2i) -> Vector3:
	var w: Vector2 = host.cell_world(key.x, key.y)
	return Vector3(w.x, float(host.layer_y(int(flowers[key].k))) + 0.3, w.y)

## Is there an intact vine on a wall face right by p (for the climbing controller)?
func climbable_at(p: Vector3, reach: float = 0.9) -> bool:
	var st: float = float(host.step)
	for c: Dictionary in vines:
		if int(c.len) <= 0:
			continue
		var w: Vector2 = host.cell_world(int(c.ix), int(c.iz))
		if absf(w.x - p.x) > reach + st or absf(w.y - p.z) > reach + st:
			continue
		for v: Vector3i in vine_cells(c):
			var cp: Vector3 = _cell_pos(v.x, v.y, v.z)
			if Vector2(cp.x - p.x, cp.z - p.z).length() < reach and absf(cp.y - (p.y + 1.0)) < 1.4:
				return true
	return false

func is_merged_leaf(key: Vector3i) -> bool:
	var g := Vector3i(key.x >> 1, key.y, key.z >> 1)
	for o: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var k2 := Vector3i(g.x * 2 + o.x, g.y, g.z * 2 + o.y)
		if not leaves.has(k2) or int(leaves[k2].s) != INTACT:
			return false
	return true

func flower_group_whole(g: Vector2i) -> bool:
	var k0: int = -999
	for o: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var k2 := Vector2i(g.x * 2 + o.x, g.y * 2 + o.y)
		if not flowers.has(k2) or int(flowers[k2].s) != INTACT:
			return false
		var kk: int = int(flowers[k2].k)
		if k0 != -999 and absi(kk - k0) > 1:
			return false
		k0 = kk
	return true

func count(kind: String, state: int) -> int:
	var n: int = 0
	if kind == "leaf":
		for d: Dictionary in leaves.values():
			n += 1 if int(d.s) == state else 0
	elif kind == "flower":
		for d: Dictionary in flowers.values():
			n += 1 if int(d.s) == state else 0
	return n

# ---------------------------------------------------------------- mesher

## Rebuild one chunk: young / mature leaf cards, vine quads, single flowers and the grass under
## the big flowers. The big flowers themselves are nodes (they move).
func draw_chunk(ck: Vector2i) -> void:
	var b: Dictionary = _bucket(ck)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_quads: int = 0
	# leaves
	var done: Dictionary = {}
	for key: Vector3i in b.leaves:
		var d: Dictionary = leaves[key]
		if int(d.s) != INTACT:
			continue
		var g := Vector3i(key.x >> 1, key.y, key.z >> 1)
		if is_merged_leaf(key):
			if done.has(g):
				continue
			done[g] = true
			n_quads += _mature_cluster(st, g, d)
		else:
			n_quads += _young_leaves(st, key, d)
	# vines
	for ci: int in b.vines:
		var c: Dictionary = vines[ci]
		var cells: Array = vine_cells(c)
		for j in cells.size():
			n_quads += _vine_quad(st, c, cells[j], j)
	# flowers
	var groups: Dictionary = {}
	for key: Vector2i in b.flowers:
		var f: Dictionary = flowers[key]
		if int(f.s) != INTACT:
			continue
		var g := Vector2i(key.x >> 1, key.y >> 1)
		if flower_group_whole(g):
			groups[g] = true
			continue
		n_quads += _single_flower(st, key, f)
	for g: Vector2i in groups:
		n_quads += _maw_grass(st, g)
	# big flowers in this chunk: make / keep / remove
	for g: Vector2i in jaws.keys():
		if chunk_of(g.x * 2, g.y * 2) == ck and not groups.has(g):
			(jaws[g].node as Node).queue_free()
			jaws.erase(g)
	for g: Vector2i in groups:
		if not jaws.has(g):
			_make_maw(g)
	var mi: MeshInstance3D = meshes.get(ck, null)
	if n_quads == 0:
		if mi != null:
			mi.queue_free()
			meshes.erase(ck)
		return
	var am: ArrayMesh = st.commit()
	if mi == null:
		mi = MeshInstance3D.new()
		mi.name = "Foliage_%d_%d" % [ck.x, ck.y]
		mi.material_override = material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		meshes[ck] = mi
	mi.mesh = am

## One card: centre c, half-axes r (width) and u (height); UV rect; palette slot; normal n;
## sway weights at its bottom and top edge.
func _card(st: SurfaceTool, c: Vector3, r: Vector3, u: Vector3, uv: Rect2, slot: float, n: Vector3, w0: float, w1: float, shade: float = 1.0) -> void:
	var p := [c - r - u, c + r - u, c + r + u, c - r + u]
	var t := [Vector2(uv.position.x, uv.end.y), Vector2(uv.end.x, uv.end.y), Vector2(uv.end.x, uv.position.y), uv.position]
	var w := [w0, w0, w1, w1]
	for i: int in [0, 1, 2, 0, 2, 3]:
		st.set_normal(n)
		st.set_uv(t[i])
		st.set_uv2(Vector2(w[i], slot))
		st.set_color(Color(shade, shade, shade))
		st.add_vertex(p[i])

func _tri(st: SurfaceTool, a: Vector3, b2: Vector3, c: Vector3, slot: float, wa: float, wb: float, wc: float, shade: float) -> void:
	var n: Vector3 = (b2 - a).cross(c - a).normalized()
	var uvc: Vector2 = UV_WHITE.get_center()
	for e: Array in [[a, wa], [b2, wb], [c, wc]]:
		st.set_normal(n)
		st.set_uv(uvc)
		st.set_uv2(Vector2(float(e[1]), slot))
		st.set_color(Color(shade, shade, shade))
		st.add_vertex(e[0])

func _hash(a: int, b2: int, c: int) -> float:
	var h: int = (a * 73856093) ^ (b2 * 19349663) ^ (c * 83492791)
	return float(posmod(h, 10007)) / 10007.0

func _bias_normal(p: Vector3, centre: Vector3) -> Vector3:
	var out: Vector3 = p - centre
	out.y = maxf(out.y, 0.0)
	return (out.normalized() * 0.55 + Vector3.UP * 0.8).normalized()

## A single cell: young leaves, an X of two tilted crossed cards plus one leaning card.
func _young_leaves(st: SurfaceTool, key: Vector3i, d: Dictionary) -> int:
	var c: Vector3 = _cell_pos(key.x, key.y, key.z)
	var h0: float = _hash(key.x, key.y, key.z)
	c += Vector3(h0 - 0.5, (h0 * 7.0 - floorf(h0 * 7.0)) - 0.5, (h0 * 13.0 - floorf(h0 * 13.0)) - 0.5) * 0.12
	var n: Vector3 = _bias_normal(c, d.c)
	var slot: float = Palette.slot(int(d.b), Palette.LEAF_YOUNG)
	var yaw: float = h0 * TAU
	var size: float = float(host.step) * 0.68
	for i in 2:
		var a: float = yaw + i * PI * 0.5
		var r := Vector3(cos(a), 0, sin(a)) * size
		var tilt: float = (h0 - 0.5) * 0.35 + (0.12 if i == 0 else -0.12)
		var u := Vector3(-sin(a) * tilt, 1.0, cos(a) * tilt).normalized() * size
		_card(st, c, r, u, UV_YOUNG, slot, n, 0.35, 1.0, 0.92 + 0.08 * i)
	var a2: float = yaw + PI * 0.25
	var r2 := Vector3(cos(a2), 0, sin(a2)) * size * 0.9
	var u2 := Vector3(-sin(a2), 0.0, cos(a2)) * size * 0.9 + Vector3.UP * size * 0.35
	_card(st, c + Vector3.UP * size * 0.2, r2, u2, UV_YOUNG, slot, n, 0.4, 1.0, 1.0)
	return 3

## A 2x2 group: one mature cluster over the four cells (bigger silhouette, smaller leaves).
func _mature_cluster(st: SurfaceTool, g: Vector3i, d: Dictionary) -> int:
	var c: Vector3 = (_cell_pos(g.x * 2, g.y, g.z * 2) + _cell_pos(g.x * 2 + 1, g.y, g.z * 2 + 1)) * 0.5
	var h0: float = _hash(g.x, g.y, g.z)
	var n: Vector3 = _bias_normal(c, d.c)
	var slot: float = Palette.slot(int(d.b), Palette.LEAF_MATURE)
	var s: float = float(host.step)
	var yaw: float = h0 * TAU
	for i in 3:   # a star of three crossed cards
		var a: float = yaw + i * PI / 3.0
		var r := Vector3(cos(a), 0, sin(a)) * s * 1.35
		var tilt: float = ((h0 * (i + 3)) - floorf(h0 * (i + 3)) - 0.5) * 0.3
		var u := Vector3(-sin(a) * tilt, 1.0, cos(a) * tilt).normalized() * s * 0.95
		_card(st, c, r, u, UV_MATURE, slot, n, 0.3, 1.0, 0.9 + 0.05 * i)
	for i in 2:   # two leaning cards fill the top and the underside
		var a2: float = yaw + PI / 6.0 + i * PI * 0.5
		var r2 := Vector3(cos(a2), 0, sin(a2)) * s * 1.25
		var u2 := Vector3(-sin(a2), 0.0, cos(a2)) * s * 1.1 + Vector3.UP * s * (0.45 if i == 0 else -0.25)
		_card(st, c + Vector3.UP * s * (0.25 if i == 0 else -0.15), r2, u2, UV_MATURE, slot, n, 0.35, 1.0, 1.0 if i == 0 else 0.8)
	return 5

## One vine segment: ONE quad on the host face, vine_offset off it. Top of the chain pinned.
func _vine_quad(st: SurfaceTool, c: Dictionary, v: Vector3i, j: int) -> int:
	var s: float = float(host.step)
	var d2: Vector2i = DIRS[int(c.dir)]
	var to_host := Vector3(d2.x, 0, d2.y)
	var nrm: Vector3 = -to_host
	var centre: Vector3 = _cell_pos(v.x, v.y, v.z) + to_host * (s * 0.5) + nrm * float(tuning.vine_offset)
	var r: Vector3 = Vector3.UP.cross(nrm).normalized() * s * 0.5
	var u: Vector3 = Vector3.UP * s * 0.5
	var slice: float = float(j % 4) * 0.25
	var uv := Rect2(UV_VINE.position.x, UV_VINE.position.y + UV_VINE.size.y * slice, UV_VINE.size.x, UV_VINE.size.y * 0.25)
	var cap: float = float(maxi(1, int(c.cap)))
	_card(st, centre, r, u, uv, Palette.slot(int(c.b), Palette.VINE), nrm, (j + 1) / cap * 0.5, j / cap * 0.5, 1.0)
	return 1

## A tuft of lower-cut grass: crossed short cards in the biome's two grass colours.
func _grass_tuft(st: SurfaceTool, base: Vector3, b2: int, size: float, seed_v: float, cards: int) -> int:
	for i in cards:
		var a: float = seed_v * TAU + i * PI / float(cards)
		var r := Vector3(cos(a), 0, sin(a)) * size
		var u := Vector3.UP * size * 0.55
		_card(st, base + Vector3.UP * size * 0.55, r, u, UV_GRASS, Palette.slot(b2, Palette.GRASS_A if i % 2 == 0 else Palette.GRASS_B), Vector3.UP, 0.0, 1.0, 1.0)
	return cards

## The diamond shell: kite-shaped facets round a cup, alternating the biome's two shell colours.
func _diamond_shell(st: SurfaceTool, head: Vector3, up: Vector3, fwd: Vector3, size: float, b2: int, petals: int, open: float, w: float) -> void:
	var side: Vector3 = up.cross(fwd).normalized()
	for i in petals:
		var a: float = TAU * float(i) / float(petals)
		var o: Vector3 = (fwd * cos(a) + side * sin(a)).normalized()
		var sd: Vector3 = up.cross(o).normalized()
		var p0: Vector3 = head
		var mid: Vector3 = head + o * size * (0.55 + 0.3 * open) + up * size * (0.55 - 0.15 * open)
		var p1: Vector3 = mid + sd * size * 0.42
		var p2: Vector3 = mid - sd * size * 0.42
		var p3: Vector3 = head + o * size * (0.85 + 0.55 * open) + up * size * (1.25 - 0.35 * open)
		var slot: float = Palette.slot(b2, Palette.SHELL_A if i % 2 == 0 else Palette.SHELL_B)
		_tri(st, p0, p1, mid, slot, w * 0.6, w, w, 0.82)
		_tri(st, p0, mid, p2, slot, w * 0.6, w, w, 0.95)
		_tri(st, p1, p3, mid, slot, w, w, w, 1.0)
		_tri(st, mid, p3, p2, slot, w, w, w, 0.88)

## The white inner piece: a faceted crystal (elongated octahedron).
func _core(st: SurfaceTool, at: Vector3, rad: float, hgt: float, b2: int, w: float) -> void:
	var slot: float = Palette.slot(b2, Palette.CORE)
	var top: Vector3 = at + Vector3.UP * hgt * 0.65
	var bot: Vector3 = at - Vector3.UP * hgt * 0.35
	var ring: Array = []
	for i in 6:
		var a: float = TAU * i / 6.0
		ring.append(at + Vector3(cos(a), 0, sin(a)) * rad)
	for i in 6:
		var p1: Vector3 = ring[i]
		var p2: Vector3 = ring[(i + 1) % 6]
		_tri(st, top, p2, p1, slot, w, w, w, 1.0 if i % 2 == 0 else 0.9)
		_tri(st, bot, p1, p2, slot, w, w, w, 0.8)

## A curved stalk: a 4-sided tube along a gentle S-curve.
func _stalk(st: SurfaceTool, base: Vector3, h: float, rad: float, bend: Vector3, slot: float, segs: int, coil: float = 0.0) -> Vector3:
	var pts: Array = []
	for i in segs + 1:
		var t: float = float(i) / segs
		var p: Vector3 = base + Vector3.UP * h * t + bend * sin(t * PI) * (1.0 - 0.3 * t)
		if coil > 0.0:
			p += Vector3(cos(t * TAU * 2.0), 0, sin(t * TAU * 2.0)) * coil * (1.0 - t * 0.5)
		pts.append(p)
	for i in segs:
		var a: Vector3 = pts[i]
		var b2: Vector3 = pts[i + 1]
		var ax: Vector3 = (b2 - a).normalized()
		var s1: Vector3 = ax.cross(Vector3.RIGHT if absf(ax.x) < 0.9 else Vector3.FORWARD).normalized() * rad
		var s2: Vector3 = ax.cross(s1).normalized() * rad
		var wa: float = float(i) / segs
		var wb: float = float(i + 1) / segs
		var ring: Array = [s1, s2, -s1, -s2]
		for k in 4:
			var q0: Vector3 = ring[k]
			var q1: Vector3 = ring[(k + 1) % 4]
			_tri(st, a + q0, a + q1, b2 + q1, slot, wa, wa, wb, 0.9)
			_tri(st, a + q0, b2 + q1, b2 + q0, slot, wa, wb, wb, 1.0)
	return pts[segs]

## A single flower cell.
func _single_flower(st: SurfaceTool, key: Vector2i, f: Dictionary) -> int:
	var w2: Vector2 = host.cell_world(key.x, key.y)
	var base := Vector3(w2.x, float(host.layer_y(int(f.k))), w2.y)
	var h0: float = _hash(key.x, int(f.k), key.y)
	var b2: int = int(f.b)
	var n: int = _grass_tuft(st, base, b2, 0.2, h0, 3)
	var bend := Vector3(cos(h0 * TAU), 0, sin(h0 * TAU)) * 0.05
	var head: Vector3 = _stalk(st, base, 0.36, 0.014, bend, Palette.slot(b2, Palette.STEM), 4)
	var fwd := Vector3(cos(h0 * 5.0), 0, sin(h0 * 5.0))
	_diamond_shell(st, head, Vector3.UP, fwd, 0.085, b2, 5, 0.6, 1.0)
	_core(st, head + Vector3.UP * 0.075, 0.028, 0.1, b2, 1.0)
	return n + 30

## The lower-cut grass bed under a big flower (2x2 cells).
func _maw_grass(st: SurfaceTool, g: Vector2i) -> int:
	var n: int = 0
	for o: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var key := Vector2i(g.x * 2 + o.x, g.y * 2 + o.y)
		var f: Dictionary = flowers[key]
		var w2: Vector2 = host.cell_world(key.x, key.y)
		var base := Vector3(w2.x, float(host.layer_y(int(f.k))), w2.y)
		n += _grass_tuft(st, base, int(f.b), 0.3, _hash(key.x, 3, key.y), 4)
	return n

# ---------------------------------------------------------------- the big snapping flower

func maw_head_pos(m: Dictionary) -> Vector3:
	return (m.head as Node3D).global_position

func _make_maw(g: Vector2i) -> void:
	var keys: Array = []
	var ksum: float = 0.0
	for o: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var key := Vector2i(g.x * 2 + o.x, g.y * 2 + o.y)
		keys.append(key)
		ksum = maxf(ksum, float(host.layer_y(int(flowers[key].k))))
	var w0: Vector2 = host.cell_world(g.x * 2, g.y * 2)
	var w1: Vector2 = host.cell_world(g.x * 2 + 1, g.y * 2 + 1)
	var b2: int = int(flowers[keys[0]].b)
	var node := Node3D.new()
	node.name = "Diamondmaw_%d_%d" % [g.x, g.y]
	add_child(node)
	node.global_position = Vector3((w0.x + w1.x) * 0.5, ksum, (w0.y + w1.y) * 0.5)
	# thick coiled stalk
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top: Vector3 = _stalk(st, Vector3.ZERO, 1.05, 0.065, Vector3(0.12, 0, 0.05), Palette.slot(b2, Palette.STEM), 10, 0.09)
	var stalk := MeshInstance3D.new()
	stalk.mesh = st.commit()
	stalk.material_override = material
	node.add_child(stalk)
	# head on a pivot: two jaw halves (the diamond shell split) hinged at the back, core ridge inside
	var head := Node3D.new()
	head.name = "Head"
	head.position = top
	node.add_child(head)
	var upper := _jaw(b2, true)
	var lower := _jaw(b2, false)
	head.add_child(upper)
	head.add_child(lower)
	jaws[g] = {"node": node, "head": head, "upper": upper, "lower": lower, "state": "idle", "t": 0.0, "open": 1.0, "b": b2, "bit": false}
	_pose_maw(jaws[g], 1.0, 0.0)

## One jaw: half of a big faceted diamond shell (4 kite facets) pointing forward (-Z), hinged at
## the head's back; the lower one carries the white core ridge.
func _jaw(b2: int, is_upper: bool) -> Node3D:
	var hinge := Node3D.new()
	hinge.name = "UpperJaw" if is_upper else "LowerJaw"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sgn: float = 1.0 if is_upper else -1.0
	var L: float = 0.62
	var Wd: float = 0.34
	var Hh: float = 0.2 * sgn
	# facets: back hinge (0,0,0), tip (0,0,-L), side corners (±Wd, 0, -L*0.45), crown (0, Hh, -L*0.45)
	var back := Vector3.ZERO
	var tip := Vector3(0, 0, -L)
	var lft := Vector3(-Wd, 0, -L * 0.45)
	var rgt := Vector3(Wd, 0, -L * 0.45)
	var crown := Vector3(0, Hh, -L * 0.5)
	var cr2 := Vector3(0, Hh * 0.6, -L * 0.12)
	var sa: float = Palette.slot(b2, Palette.SHELL_A)
	var sb: float = Palette.slot(b2, Palette.SHELL_B)
	_tri(st, back, lft, cr2, sa, 0.3, 0.3, 0.3, 0.85)
	_tri(st, back, cr2, rgt, sb, 0.3, 0.3, 0.3, 0.95)
	_tri(st, cr2, lft, crown, sb, 0.3, 0.3, 0.3, 1.0)
	_tri(st, cr2, crown, rgt, sa, 0.3, 0.3, 0.3, 0.9)
	_tri(st, crown, lft, tip, sa, 0.3, 0.3, 0.3, 0.92)
	_tri(st, crown, tip, rgt, sb, 0.3, 0.3, 0.3, 0.84)
	# serrated rim: small diamond teeth along the edge
	for i in 5:
		var t: float = float(i + 1) / 6.0
		for side: float in [-1.0, 1.0]:
			var e0: Vector3 = (back.lerp(lft if side < 0 else rgt, t * 2.0) if t < 0.5 else (lft if side < 0 else rgt).lerp(tip, (t - 0.5) * 2.0))
			var e1: Vector3 = e0 + Vector3(0, 0, -0.06)
			var tooth: Vector3 = e0 + Vector3(0, -0.07 * sgn, -0.03)
			_tri(st, e0, e1, tooth, Palette.slot(b2, Palette.CORE), 0.3, 0.3, 0.3, 1.0)
	if not is_upper:   # the white inner core ridge
		var cs: float = Palette.slot(b2, Palette.CORE)
		var r0 := Vector3(0, 0.02, -0.08)
		var r1 := Vector3(0, 0.02, -L * 0.8)
		var ridge := Vector3(0, 0.13, -L * 0.42)
		_tri(st, r0, Vector3(-0.07, 0.02, -L * 0.42), ridge, cs, 0.3, 0.3, 0.3, 0.9)
		_tri(st, r0, ridge, Vector3(0.07, 0.02, -L * 0.42), cs, 0.3, 0.3, 0.3, 1.0)
		_tri(st, ridge, Vector3(-0.07, 0.02, -L * 0.42), r1, cs, 0.3, 0.3, 0.3, 0.85)
		_tri(st, ridge, r1, Vector3(0.07, 0.02, -L * 0.42), cs, 0.3, 0.3, 0.3, 0.95)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = material
	hinge.add_child(mi)
	return hinge

## open 0 = shut, 1 = open; pull 0..1 = pulled back (the telegraph).
func _pose_maw(m: Dictionary, open: float, pull: float) -> void:
	(m.upper as Node3D).rotation.x = lerpf(0.0, 0.75, open) + 0.25 * pull
	(m.lower as Node3D).rotation.x = -lerpf(0.0, 0.32, open) - 0.1 * pull
	(m.head as Node3D).rotation.x = 0.35 * pull

func _jaws_tick(dt: float) -> void:
	var tg: Node3D = target_fn.call() if target_fn.is_valid() else null
	var ok_target: bool = tg != null and is_instance_valid(tg) and (not tg.has_method("alive") or tg.alive())
	for g: Vector2i in jaws:
		var m: Dictionary = jaws[g]
		var node: Node3D = m.node
		m.t = float(m.t) + dt
		var near: bool = false
		if ok_target:
			var dv: Vector3 = tg.global_position - node.global_position
			near = Vector2(dv.x, dv.z).length() < float(tuning.snap_radius) and absf(dv.y) < 2.2
			if near and m.state in ["idle", "tele"]:   # turn to face it
				var want: float = atan2(-dv.x, -dv.z)
				node.rotation.y = lerp_angle(node.rotation.y, want, minf(1.0, dt * 6.0))
		match String(m.state):
			"idle":
				m.open = move_toward(float(m.open), 1.0, dt * 2.0)
				_pose_maw(m, float(m.open) * (0.92 + 0.08 * sin(_real * 2.0 + g.x)), 0.0)
				if near:
					m.state = "tele"
					m.t = 0.0
			"tele":
				var k: float = clampf(float(m.t) / float(tuning.snap_telegraph_s), 0.0, 1.0)
				_pose_maw(m, 1.0 + 0.25 * k, k)
				if k >= 1.0:
					m.state = "snap"
					m.t = 0.0
					m.bit = false
			"snap":
				var k2: float = clampf(float(m.t) / float(tuning.snap_shut_s), 0.0, 1.0)
				_pose_maw(m, 1.0 - k2, 1.0 - k2)
				if k2 >= 1.0 and not bool(m.bit):
					m.bit = true
					var bite: Vector3 = (m.head as Node3D).global_position - node.global_basis.z * 0.45
					if ok_target and tg.global_position.distance_to(bite) < float(tuning.snap_reach) + 0.6:
						bites += 1
						if tg.has_method("damage"):
							tg.damage(float(tuning.snap_damage), bite, 0.35)
					m.state = "cool"
					m.t = 0.0
			"cool":
				_pose_maw(m, 0.0, 0.0)
				if float(m.t) >= float(tuning.snap_cooldown_s):
					m.state = "idle"
					m.t = 0.0

# ---------------------------------------------------------------- saving (with world timestamps)

## Burn states and vine lengths with their world-clock times (placement itself is rebuilt from the
## world seed). Loading it and ticking catches up on any time that passed.
func snapshot() -> Dictionary:
	var lv: Array = []
	for key: Vector3i in leaves:
		var d: Dictionary = leaves[key]
		if int(d.s) != INTACT:
			lv.append([key.x, key.y, key.z, int(d.s), float(d.t)])
	var fl: Array = []
	for key: Vector2i in flowers:
		var f: Dictionary = flowers[key]
		if int(f.s) != INTACT:
			fl.append([key.x, key.y, int(f.s), float(f.t)])
	var vn: Array = []
	for c: Dictionary in vines:
		vn.append([int(c.len), float(c.burned_at), float(c.last)])
	return {"leaves": lv, "flowers": fl, "vines": vn, "saved_at": now_h()}

func restore(d: Dictionary) -> void:
	for e: Array in d.get("leaves", []):
		var key := Vector3i(int(e[0]), int(e[1]), int(e[2]))
		if leaves.has(key):
			leaves[key].s = int(e[3])
			leaves[key].t = float(e[4])
	for e: Array in d.get("flowers", []):
		var key := Vector2i(int(e[0]), int(e[1]))
		if flowers.has(key):
			flowers[key].s = int(e[2])
			flowers[key].t = float(e[3])
	var vn: Array = d.get("vines", [])
	for i in mini(vn.size(), vines.size()):
		vines[i].len = int(vn[i][0])
		vines[i].burned_at = float(vn[i][1])
		vines[i].last = float(vn[i][2])
	for ck: Vector2i in by_chunk:
		dirty[ck] = true
	season_tick()   # catch up on the time that passed while it was not loaded
