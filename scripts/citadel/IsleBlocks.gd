extends Node3D
## The breakable ground for the ISLES test world, ported from Homelancer's block ground
## (homelancer-digital, branch planet-blocks-test: scripts/block_field.gd, docs/PLANET_BLOCKS.md)
## and scaled from ship size down to Lance size.
##
## Same rules as Homelancer:
##   - the ground is columns of square cells cut into layers; only the changes (blasts) alter it;
##   - four materials shown by TONE, darker = tougher: sand 1 hit, dirt 2, stone 4, obsidian 8;
##   - a hit damages every layer inside its sphere; a layer breaks when its material's count is reached
##     (a blast from above digs a crater, one against a wall digs INTO it: tunnels and overhangs);
##   - anything left floating with nothing holding it falls (support reach by material);
##   - loose sand slumps downhill; broken layers fly out as rubble that rests, then sinks away;
##   - drawn as ONE fused surface: same-height neighbours share a face, walls only where it steps.
## Change for Chronicle Clash: one-layer steps are blended into smooth slopes (the BotW-style
## look the owner wants) while bigger steps stay as cliffs; collision is the same surface.
## Cells are 0.5 m (Homelancer: 5 m); the whole world is WORLD metres square and wraps round.

const STEP: float = 0.5            # cell side and layer height (Homelancer BLOCK_MIN)
const WORLD: float = 144.0         # 3 x 3 tiles of 48 m
const HALF: float = WORLD * 0.5
const Y0: float = -4.0             # bottom of layer 0 (bedrock: nothing digs below layer 1)
const KFLOOR: int = 1
const SEA_FLOOR: float = -3.5
const CH: int = 24                 # cells per mesh chunk side (12 m)
const HITS: Array = [0, 1, 2, 4, 8]                  # by material id: sand, dirt, stone, obsidian
const REACH: Array = [0, 0, 2, 6, 10]                # support reach in cells by material
const MAT_NAMES: Array = ["", "sand", "dirt", "stone", "obsidian"]
const SAND := 1
const DIRT := 2
const STONE := 3
const OBSIDIAN := 4
const RUBBLE_LIVE: int = 40

var n: int = int(WORLD / STEP)     # cells per side (288)
var nch: int = 0                   # chunks per side
var top := PackedInt32Array()      # layers [.., top) can be solid
var top0 := PackedInt32Array()     # the original top
var base := PackedInt32Array()     # top of the natural ground under a rock outcrop (= top0 where there is none)
var rock := PackedByteArray()      # material of a rock outcrop above base (0 = none)
var style := PackedByteArray()     # 0 sea, 1 grass island, 2 dune island, 3 crag island
var holes: Dictionary = {}         # cell -> [Vector2i(lo, hi)] air layers under the top, sorted
var dmg: Dictionary = {}           # cell -> {layer: hits}
var mats: Dictionary = {}          # cell -> {layer: material id} where the layer is not natural (fallen pieces)
var dirty: Dictionary = {}         # chunk index -> true
var chunks: Dictionary = {}        # chunk index -> {mesh: MeshInstance3D, body: StaticBody3D, shape}
var rubble: Array = []
var noise := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()
var material_ground: Material
var box_mesh: BoxMesh
var piece_mats: Dictionary = {}
# counts for the tests
var layers_broken: int = 0
var collapses: int = 0
var slumps: int = 0

const COLORS: Dictionary = {
	"grass": Color("78b84e"), "grass2": Color("5f9e3e"),
	"sand": Color("ead7a0"), "dirt": Color("8c5d3a"),
	"stone": Color("7f828c"), "obsidian": Color("2b2536"),
}

const GROUND_SHADER := """shader_type spatial;
render_mode cull_disabled;
varying float shade;
void vertex() {
	shade = UV.x;
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
	AO = shade;
	AO_LIGHT_AFFECT = 0.4;
}
"""

func _init() -> void:
	nch = int(ceil(float(n) / CH))
	noise.seed = 7
	noise.frequency = 0.06
	rng.seed = 11
	var sh := Shader.new()
	sh.code = GROUND_SHADER
	var sm := ShaderMaterial.new()
	sm.shader = sh
	material_ground = sm
	box_mesh = BoxMesh.new()
	box_mesh.size = Vector3.ONE

# ---------------------------------------------------------------- building

## islands: [{c: Vector2, r: float, h: float, style: int, rocks: int, dark: float}]
func build(islands: Array) -> void:
	var cells: int = n * n
	top.resize(cells)
	base.resize(cells)
	rock.resize(cells)
	style.resize(cells)
	rock.fill(0)
	style.fill(0)
	for iz in n:
		for ix in n:
			var x: float = -HALF + (ix + 0.5) * STEP
			var z: float = -HALF + (iz + 0.5) * STEP
			var y: float = SEA_FLOOR
			var st: int = 0
			for isl: Dictionary in islands:
				var c: Vector2 = isl.c
				var d: float = Vector2(x, z).distance_to(c) / float(isl.r)
				if d > 1.35:
					continue
				var wob: float = noise.get_noise_2d(x * 1.3, z * 1.3)
				d += wob * 0.18
				var shape: float = smoothstep(1.2, 0.05, d)
				var hh: float = float(isl.h) * shape + noise.get_noise_2d(x * 2.0 + 300.0, z * 2.0) * 1.1 * shape
				if int(isl.style) == 3:
					# crag: terraced, cliffy
					hh = floorf(hh / 1.6) * 1.6 + clampf(hh - floorf(hh / 1.6) * 1.6, 0.0, 0.5)
				var yy: float = lerpf(SEA_FLOOR, 0.6, smoothstep(1.35, 0.85, d)) + hh
				if yy > y:
					y = yy
					st = int(isl.style)
			var i: int = iz * n + ix
			top[i] = clampi(int(round((y - Y0) / STEP)), KFLOOR, 200)
			style[i] = st if y > -1.0 else 0
	base = top.duplicate()
	# rock outcrops: the breakable rocks
	for isl: Dictionary in islands:
		for r in int(isl.get("rocks", 0)):
			var a: float = rng.randf() * TAU
			var dist: float = rng.randf_range(0.15, 0.62) * float(isl.r)
			var c2: Vector2 = Vector2(isl.c) + Vector2(cos(a), sin(a)) * dist
			var dark: bool = rng.randf() < float(isl.get("dark", 0.0))
			add_rock(c2, rng.randf_range(0.7, 1.5), rng.randf_range(1.0, 2.6), OBSIDIAN if dark else STONE)
		for p: Vector2 in isl.get("fixed_rocks", []):
			add_rock(p, 1.1, 2.0, STONE)
	top0 = top.duplicate()
	for k in nch * nch:
		dirty[k] = true

func add_rock(c: Vector2, rad: float, hgt: float, m: int) -> void:
	var r2: int = int(ceil(rad / STEP)) + 1
	var cx: int = cell_x(c.x)
	var cz: int = cell_x(c.y)
	for dz in range(-r2, r2 + 1):
		for dx in range(-r2, r2 + 1):
			var d: float = Vector2(dx, dz).length() * STEP / rad
			d += noise.get_noise_2d(float(cx + dx) * 3.0, float(cz + dz) * 3.0) * 0.12
			if d > 1.0:
				continue
			var i: int = idx(cx + dx, cz + dz)
			if style[i] == 0:
				continue
			# a rounded boulder: steep but blended sides, not a box
			var add: int = int(round(hgt * (1.0 - d * d) / STEP))
			if add <= 0:
				continue
			top[i] = maxi(top[i], base[i] + add)
			rock[i] = m

# ---------------------------------------------------------------- cells and layers

func cell_x(x: float) -> int:
	return posmod(floori((x + HALF) / STEP), n)

func idx(ix: int, iz: int) -> int:
	return posmod(iz, n) * n + posmod(ix, n)

func cell_at(x: float, z: float) -> int:
	return idx(floori((x + HALF) / STEP), floori((z + HALF) / STEP))

func ly(k: int) -> float:          # bottom of layer k
	return Y0 + k * STEP

func kof(y: float) -> int:
	return floori((y - Y0) / STEP + 0.0001)

func solid(i: int, k: int) -> bool:
	if k < KFLOOR:
		return true
	if k >= top[i]:
		return false
	for hv: Vector2i in holes.get(i, []):
		if k >= hv.x and k < hv.y:
			return false
	return true

## Material id of layer k of cell i: fallen pieces keep their own, rocks are stone or obsidian,
## the natural ground goes sand / dirt / stone with depth (obsidian veins deep down), like Homelancer.
const MEMO_LAYERS: int = 48
var _memo := PackedByteArray()   # the natural material never changes: remembered, one byte a layer (as Homelancer)

func mat_k(i: int, k: int) -> int:
	if not mats.is_empty() and mats.has(i):
		var ov: Dictionary = mats[i]
		if ov.has(k):
			return ov[k]
	if rock[i] > 0 and k >= base[i]:
		return rock[i]
	if k >= 0 and k < MEMO_LAYERS:
		if _memo.is_empty():
			_memo.resize(n * n * MEMO_LAYERS)
		var slot: int = i * MEMO_LAYERS + k
		var mm: int = _memo[slot]
		if mm == 0:
			mm = mat_natural(i, k)
			_memo[slot] = mm
		return mm
	return mat_natural(i, k)

func mat_natural(i: int, k: int) -> int:
	var ix: int = i % n
	@warning_ignore("integer_division")
	var iz: int = i / n
	var d: float = (base[i] - k - 0.5) * STEP
	var a: float = noise.get_noise_3d(ix * 1.7, k * 2.3, iz * 1.7)
	var st: int = style[i]
	var surf_y: float = ly(base[i])
	if st == 2 or (st != 3 and surf_y < 0.9):
		# dunes and beaches: deep sand over stone
		return SAND if d < 2.2 else STONE
	if d < 0.6:
		return DIRT if st != 3 or a > -0.1 else STONE
	if d < 2.0:
		return DIRT if a > 0.05 else STONE
	var ob: float = noise.get_noise_3d(iz * 2.1 + 91.0, k * 3.0, ix * 2.1 - 43.0)
	if ob > lerpf(0.5, 0.15, clampf((d - 2.0) / 6.0, 0.0, 1.0)):
		return OBSIDIAN
	if a > 0.6:
		return SAND
	return STONE

func mat_name(i: int, k: int) -> String:
	return MAT_NAMES[mat_k(i, k)]

func spans(i: int) -> Array:
	var out: Array = []
	var start: int = 0
	for hv: Vector2i in holes.get(i, []):
		out.append(Vector2i(start, hv.x))
		start = hv.y
	out.append(Vector2i(start, top[i]))
	return out

func set_spans(i: int, sp: Array) -> void:
	var hl: Array = []
	for j in range(1, sp.size()):
		hl.append(Vector2i((sp[j - 1] as Vector2i).y, (sp[j] as Vector2i).x))
	top[i] = (sp[-1] as Vector2i).y
	if hl.is_empty():
		holes.erase(i)
	else:
		holes[i] = hl

## Break layer k of cell i (the top layer lowers the ground; a lower one opens a hole: a tunnel).
func cell_remove(i: int, k: int) -> void:
	var kt: int = top[i]
	if k >= kt or k < KFLOOR:
		return
	if mats.has(i):
		(mats[i] as Dictionary).erase(k)
		if (mats[i] as Dictionary).is_empty():
			mats.erase(i)
	var hl: Array = holes.get(i, [])
	if k == kt - 1:
		kt -= 1
		while not hl.is_empty() and (hl[-1] as Vector2i).y >= kt:
			kt = mini(kt, (hl[-1] as Vector2i).x)
			hl.pop_back()
		top[i] = kt
	else:
		var lo: int = k
		var hi: int = k + 1
		var keep: Array = []
		for hv: Vector2i in hl:
			if hv.y < lo or hv.x > hi:
				keep.append(hv)
			else:
				lo = mini(lo, hv.x)
				hi = maxi(hi, hv.y)
		keep.append(Vector2i(lo, hi))
		keep.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
		hl = keep
	if hl.is_empty():
		holes.erase(i)
	else:
		holes[i] = hl

## Put one layer of material m on top of cell i.
func cell_add_top(i: int, m: int) -> void:
	var k: int = top[i]
	top[i] = k + 1
	var ov: Dictionary = mats.get(i, {})
	ov[k] = m
	mats[i] = ov
	if dmg.has(i):
		(dmg[i] as Dictionary).erase(k)

# ---------------------------------------------------------------- queries

func top_y(i: int) -> float:
	return ly(top[i])

func top_at(x: float, z: float) -> float:
	return top_y(cell_at(x, z))

## Highest solid surface at or below y (+ a little), for things resting in craters and tunnels.
func ground_for(x: float, y: float, z: float) -> float:
	var i: int = cell_at(x, z)
	var k: int = mini(kof(y + 0.25), top[i])
	while k > KFLOOR:
		if solid(i, k - 1):
			return ly(k)
		k -= 1
	return ly(KFLOOR)

func is_solid(x: float, y: float, z: float) -> bool:
	return solid(cell_at(x, z), kof(y))

func is_land(x: float, z: float) -> bool:
	return top_at(x, z) > 0.15

func style_at(x: float, z: float) -> int:
	return style[cell_at(x, z)]

# ---------------------------------------------------------------- blasts

## A hit at p: every layer inside the sphere of radius r takes `power` hits; a layer breaks at its
## material's count. Returns {broken, chipped, mat}.
func blast(p: Vector3, r: float, power: int, effects: bool = true) -> Dictionary:
	var res: Dictionary = {"broken": 0, "chipped": 0, "mat": ""}
	var c0x: int = floori((p.x - r + HALF) / STEP)
	var c1x: int = floori((p.x + r + HALF) / STEP)
	var c0z: int = floori((p.z - r + HALF) / STEP)
	var c1z: int = floori((p.z + r + HALF) / STEP)
	var out: Array = []
	for cz in range(c0z, c1z + 1):
		for cx in range(c0x, c1x + 1):
			var rx0: float = -HALF + cx * STEP
			var rz0: float = -HALF + cz * STEP
			var dmin: float = Vector2(p.x - clampf(p.x, rx0, rx0 + STEP), p.z - clampf(p.z, rz0, rz0 + STEP)).length()
			if dmin >= r:
				continue
			var i: int = idx(cx, cz)
			var v: float = sqrt(r * r - dmin * dmin)
			var klo: int = maxi(kof(p.y - v + 0.01), KFLOOR)
			var khi: int = mini(kof(p.y + v - 0.01), top[i] - 1)
			if khi < klo:
				continue
			var dl: Dictionary = dmg.get(i, {})
			var broke: int = 0
			var touched: bool = false
			for k in range(khi, klo - 1, -1):
				if not solid(i, k):
					continue
				touched = true
				var m: int = mat_k(i, k)
				var hits: int = int(dl.get(k, 0)) + power
				if hits < HITS[m]:
					dl[k] = hits
					continue
				dl.erase(k)
				cell_remove(i, k)
				broke += 1
				out.append({"pos": Vector3(rx0 + STEP * 0.5, ly(k) + STEP * 0.5, rz0 + STEP * 0.5), "mat": m, "edge": dmin / r})
			if touched and broke == 0:
				res.chipped = int(res.chipped) + 1
			for k: int in dl.keys():
				if not solid(i, k):
					dl.erase(k)
			if dl.is_empty():
				dmg.erase(i)
			else:
				dmg[i] = dl
			if touched:
				mark(cx, cz)
	layers_broken += out.size()
	res.broken = out.size()
	if out.is_empty():
		return res
	res.mat = MAT_NAMES[int(out[0].mat)]
	settle(c0x - 8, c1x + 8, c0z - 8, c1z + 8)
	slump_area(c0x - 3, c1x + 3, c0z - 3, c1z + 3)
	if effects:
		out.shuffle()
		for j in mini(out.size(), 12):
			var b: Dictionary = out[j]
			var away: Vector3 = (b.pos as Vector3) - p
			away.y = 0
			var vel: Vector3 = away.normalized() * rng.randf_range(2.0, 6.0) + Vector3.UP * rng.randf_range(4.0, 9.0) * (1.0 - float(b.edge) * 0.5)
			piece(b.pos, STEP * rng.randf_range(0.5, 0.9), int(b.mat), vel)
	return res

func mark(cx: int, cz: int) -> void:
	# a cell's corners touch the neighbours' chunks too
	for dz in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			@warning_ignore("integer_division")
			var k: int = (posmod(cz + dz, n) / CH) * nch + posmod(cx + dx, n) / CH
			dirty[k] = true

## Support: a piece over a hole stays up only if it is joined sideways to grounded ground within its
## material's reach (sand 0 cells, dirt 2, stone 6, obsidian 10). Otherwise it falls onto what's under it.
func settle(cx0: int, cx1: int, cz0: int, cz1: int) -> void:
	for pass_i in 4:
		var moved: bool = false
		for cz in range(cz0, cz1 + 1):
			for cx in range(cx0, cx1 + 1):
				var i: int = idx(cx, cz)
				if not holes.has(i):
					continue
				var sp: Array = spans(i)
				var j: int = sp.size() - 1
				while j >= 1:
					var s: Vector2i = sp[j]
					if not supported(cx, cz, s):
						drop_span(i, sp, j)
						collapses += 1
						moved = true
						mark(cx, cz)
						sp = spans(i)
						j = sp.size() - 1
						continue
					j -= 1
		if not moved:
			return

func supported(cx: int, cz: int, s: Vector2i) -> bool:
	var reach: int = REACH[mat_k(idx(cx, cz), s.x)]
	var seen: Dictionary = {idx(cx, cz): true}
	var front: Array = [Vector2i(cx, cz)]
	for step_i in reach + 1:
		var nxt: Array = []
		for c: Vector2i in front:
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = c + d
				var qi: int = idx(q.x, q.y)
				if seen.has(qi):
					continue
				seen[qi] = true
				var qs: Array = spans(qi)
				for jj in qs.size():
					var o: Vector2i = qs[jj]
					if o.y <= s.x or o.x >= s.y:
						continue
					if jj == 0:
						return true    # touches grounded ground
					nxt.append(q)
					break
		front = nxt
		if front.is_empty():
			return false
	return false

func drop_span(i: int, sp: Array, j: int) -> void:
	var s: Vector2i = sp[j]
	var below: Vector2i = sp[j - 1]
	var cnt: int = s.y - s.x
	var ms: Array = []
	for k in range(s.x, s.y):
		ms.append(mat_k(i, k))
	var ov: Dictionary = mats.get(i, {})
	for k in range(s.x, s.y):
		ov.erase(k)
	for t in cnt:
		ov[below.y + t] = ms[t]
	mats[i] = ov
	dmg.erase(i)
	sp[j - 1] = Vector2i(below.x, below.y + cnt)
	sp.remove_at(j)
	# anything above keeps floating and is checked again
	set_spans(i, sp)
	if ov.is_empty():
		mats.erase(i)
	var c: Vector3 = Vector3(-HALF + (i % n + 0.5) * STEP, ly(below.y + cnt), -HALF + (i / n + 0.5) * STEP)
	if rubble.size() < RUBBLE_LIVE and rng.randf() < 0.35:
		piece(c + Vector3.UP * 0.4, STEP * 0.6, ms[0], Vector3(rng.randf_range(-1, 1), 1.0, rng.randf_range(-1, 1)))

## Loose sand pours downhill: a sand top more than two layers above a neighbour runs into it.
func slump_area(cx0: int, cx1: int, cz0: int, cz1: int) -> void:
	var todo: Array = []
	for cz in range(cz0, cz1 + 1):
		for cx in range(cx0, cx1 + 1):
			todo.append(Vector2i(cx, cz))
	var guard: int = 0
	while not todo.is_empty() and guard < 600:
		guard += 1
		var c: Vector2i = todo.pop_back()
		var i: int = idx(c.x, c.y)
		if holes.has(i) or top[i] <= KFLOOR:
			continue
		if mat_k(i, top[i] - 1) != SAND:
			continue
		var low: int = -1
		var low_k: int = top[i] - 2
		var low_c: Vector2i
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = c + d
			var qi: int = idx(q.x, q.y)
			if top[qi] < low_k and style[qi] != 0:
				low_k = top[qi]
				low = qi
				low_c = q
		if low < 0:
			continue
		cell_remove(i, top[i] - 1)
		cell_add_top(low, SAND)
		slumps += 1
		mark(c.x, c.y)
		mark(low_c.x, low_c.y)
		todo.append(c)
		todo.append(low_c)

# ---------------------------------------------------------------- rubble

func piece(pos: Vector3, sz: float, m: int, vel: Vector3) -> void:
	if rubble.size() >= RUBBLE_LIVE:
		var old: Dictionary = rubble.pop_front()
		if is_instance_valid(old.node):
			(old.node as Node).queue_free()
	var mi := MeshInstance3D.new()
	mi.mesh = box_mesh
	mi.material_override = piece_mat(m)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(sz, sz * rng.randf_range(0.6, 1.0), sz * rng.randf_range(0.7, 1.1))
	mi.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
	mi.name = "Rubble"
	add_child(mi)
	mi.position = pos
	rubble.append({"node": mi, "vel": vel, "spin": Vector3(rng.randfn(0, 4), rng.randfn(0, 4), rng.randfn(0, 4)), "rest": -1.0, "half": sz * 0.4})

func piece_mat(m: int) -> StandardMaterial3D:
	if piece_mats.has(m):
		return piece_mats[m]
	var mt := StandardMaterial3D.new()
	mt.albedo_color = (COLORS[MAT_NAMES[m]] as Color).darkened(0.15)
	mt.roughness = 1.0
	piece_mats[m] = mt
	return mt

func _process(dt: float) -> void:
	for j in range(rubble.size() - 1, -1, -1):
		var b: Dictionary = rubble[j]
		var nd: MeshInstance3D = b.node
		if not is_instance_valid(nd):
			rubble.remove_at(j)
			continue
		var half: float = b.half
		if float(b.rest) < 0.0:
			b.vel = (b.vel as Vector3) + Vector3.DOWN * 22.0 * dt
			nd.position += (b.vel as Vector3) * dt
			nd.rotation += (b.spin as Vector3) * dt
			var g: float = maxf(ground_for(nd.position.x, nd.position.y, nd.position.z), -0.2 if nd.position.y < 0.0 else -100.0)
			if nd.position.y - half <= g:
				nd.position.y = g + half
				b.rest = 0.0
		else:
			b.rest = float(b.rest) + dt
			if float(b.rest) > 2.5:
				nd.position.y -= dt * 0.6
			if float(b.rest) > 4.0:
				nd.queue_free()
				rubble.remove_at(j)
	if not dirty.is_empty():
		flush(3)

# ---------------------------------------------------------------- drawing

## Redraw changed chunks (at most `limit` per call; 0 = all).
func flush(limit: int = 0) -> void:
	var done: int = 0
	for k: int in dirty.keys():
		draw_chunk(k)
		dirty.erase(k)
		done += 1
		if limit > 0 and done >= limit:
			return

## Draw the chunks within `radius` of p now; the rest are drawn a few per frame (quicker start on phones).
func flush_near(p: Vector3, radius: float) -> void:
	for k: int in dirty.keys():
		@warning_ignore("integer_division")
		var cz: int = k / nch
		var cx: int = k % nch
		var c: Vector2 = Vector2(-HALF + (cx + 0.5) * CH * STEP, -HALF + (cz + 0.5) * CH * STEP)
		if c.distance_to(Vector2(p.x, p.z)) < radius + CH * STEP:
			draw_chunk(k)
			dirty.erase(k)

## Corner heights: a corner shared by four cells within one layer of each other is blended
## (smooth slope); otherwise each cell keeps its own flat top there (a cliff edge).
func corner_shared(vx: int, vz: int) -> float:
	var a: float = top_y(idx(vx - 1, vz - 1))
	var b: float = top_y(idx(vx, vz - 1))
	var c: float = top_y(idx(vx - 1, vz))
	var d: float = top_y(idx(vx, vz))
	var mn: float = minf(minf(a, b), minf(c, d))
	var mx: float = maxf(maxf(a, b), maxf(c, d))
	if mx - mn > STEP * 2.0 + 0.01:
		return NAN    # (Homelancer keeps every step square; here steps up to 1 m blend into slopes)
	return (a + b + c + d) * 0.25

func corners(ix: int, iz: int) -> Array:
	var own: float = top_y(idx(ix, iz))
	var out: Array = []
	for v: Vector2i in [Vector2i(ix, iz), Vector2i(ix + 1, iz), Vector2i(ix + 1, iz + 1), Vector2i(ix, iz + 1)]:
		var s: float = corner_c(v.x, v.y)
		out.append(own if is_nan(s) else s)
	return out

## Corner values for the chunk being drawn (one cell of border), so each is worked out once.
var _cc := PackedFloat32Array()
var _cc_x0: int = 0
var _cc_z0: int = 0
var _cc_w: int = 0
func cache_corners(cx0: int, cz0: int) -> void:
	_cc_x0 = cx0 - 1
	_cc_z0 = cz0 - 1
	_cc_w = CH + 3
	_cc.resize(_cc_w * _cc_w)
	for z in _cc_w:
		for x in _cc_w:
			_cc[z * _cc_w + x] = corner_shared(_cc_x0 + x, _cc_z0 + z)

func corner_c(vx: int, vz: int) -> float:
	var x: int = vx - _cc_x0
	var z: int = vz - _cc_z0
	if x >= 0 and z >= 0 and x < _cc_w and z < _cc_w:
		return _cc[z * _cc_w + x]
	return corner_shared(vx, vz)

func top_color(i: int) -> Color:
	var k: int = top[i] - 1
	var m: int = mat_k(i, k)
	var c: Color = COLORS[MAT_NAMES[m]]
	var natural: bool = top[i] == top0[i] and not (mats.get(i, {}) as Dictionary).has(k)
	if m == DIRT and natural and rock[i] == 0:
		var ix: int = i % n
		@warning_ignore("integer_division")
		var iz: int = i / n
		c = COLORS.grass.lerp(COLORS.grass2, clampf(noise.get_noise_2d(ix * 4.0, iz * 4.0) * 0.8 + 0.5, 0.0, 1.0))
	elif m == SAND and natural:
		c = c.lerp(Color("f3e6bd"), 0.25)
	var dl: Dictionary = dmg.get(i, {})
	if dl.has(k):
		c = c.lerp(Color.BLACK, 0.45 * float(dl[k]) / float(HITS[m]))
	return c

func layer_color(i: int, k: int) -> Color:
	var m: int = mat_k(i, k)
	var c: Color = COLORS[MAT_NAMES[m]]
	if m == DIRT:
		c = c.darkened(0.08)
	return c

func draw_chunk(ck: int) -> void:
	@warning_ignore("integer_division")
	var cz0: int = (ck / nch) * CH
	var cx0: int = (ck % nch) * CH
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	# all sea and nothing to draw: skip quickly
	var any_land: bool = false
	for iz in range(cz0 - 1, mini(cz0 + CH, n) + 1):
		for ix in range(cx0 - 1, mini(cx0 + CH, n) + 1):
			if top[idx(ix, iz)] > kof(SEA_FLOOR + 0.3) or holes.has(idx(ix, iz)):
				any_land = true
				break
		if any_land:
			break
	if any_land:
		cache_corners(cx0, cz0)
	for iz in range(cz0, mini(cz0 + CH, n) if any_land else cz0):
		for ix in range(cx0, mini(cx0 + CH, n)):
			draw_cell(ix, iz, verts, norms, cols, uvs)
	var old: Dictionary = chunks.get(ck, {})
	if verts.is_empty():
		if not old.is_empty():
			(old.mesh as Node).queue_free()
			(old.body as Node).queue_free()
			chunks.erase(ck)
		return
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uvs
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var faces := ConcavePolygonShape3D.new()
	faces.backface_collision = true
	faces.set_faces(verts)
	if old.is_empty():
		var mi := MeshInstance3D.new()
		mi.name = "Ground%d" % ck
		mi.material_override = material_ground
		add_child(mi)
		var body := StaticBody3D.new()
		body.name = "GroundBody%d" % ck
		body.add_to_group("isle_ground")
		var cs := CollisionShape3D.new()
		body.add_child(cs)
		add_child(body)
		old = {"mesh": mi, "body": body, "shape": cs}
		chunks[ck] = old
	(old.mesh as MeshInstance3D).mesh = am
	(old.shape as CollisionShape3D).shape = faces

func draw_cell(ix: int, iz: int, verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, uvs: PackedVector2Array) -> void:
	var i: int = idx(ix, iz)
	var ty: float = top_y(i)
	var has_holes: bool = holes.has(i)
	if ty < SEA_FLOOR + 0.3 and not has_holes:
		return
	var x0: float = -HALF + ix * STEP
	var z0: float = -HALF + iz * STEP
	var x1: float = x0 + STEP
	var z1: float = z0 + STEP
	# the four corner values (shared = blended slope; NaN = this cell's own flat top)
	var s0: float = corner_c(ix, iz)
	var s1: float = corner_c(ix + 1, iz)
	var s2: float = corner_c(ix + 1, iz + 1)
	var s3: float = corner_c(ix, iz + 1)
	var c0: float = ty if is_nan(s0) else s0
	var c1: float = ty if is_nan(s1) else s1
	var c2: float = ty if is_nan(s2) else s2
	var c3: float = ty if is_nan(s3) else s3
	var cave: float = 0.55 if has_holes else 1.0
	var tc: Color = top_color(i)
	quad(Vector3(x0, c0, z0), Vector3(x1, c1, z0), Vector3(x1, c2, z1), Vector3(x0, c3, z1), Vector3.UP, tc, tc, 1.0, verts, norms, cols, uvs)
	if has_holes:
		for hv: Vector2i in holes[i]:
			var yc: float = ly(hv.y)
			var yf: float = ly(hv.x)
			var cc: Color = layer_color(i, hv.y)
			quad(Vector3(x0, yc, z0), Vector3(x1, yc, z0), Vector3(x1, yc, z1), Vector3(x0, yc, z1), Vector3.DOWN, cc, cc, 0.45, verts, norms, cols, uvs)
			if hv.x > KFLOOR:
				var fc: Color = layer_color(i, hv.x - 1)
				quad(Vector3(x0, yf, z0), Vector3(x1, yf, z0), Vector3(x1, yf, z1), Vector3(x0, yf, z1), Vector3.UP, fc, fc, 0.6, verts, norms, cols, uvs)
	# sides: north, east, south, west (my edge corners, the neighbour's matching corners)
	side(i, idx(ix, iz - 1), Vector3(x0, 0, z0), Vector3(x1, 0, z0), c0, c1, s0, s1, Vector3.FORWARD, cave, verts, norms, cols, uvs)
	side(i, idx(ix + 1, iz), Vector3(x1, 0, z0), Vector3(x1, 0, z1), c1, c2, s1, s2, Vector3.RIGHT, cave, verts, norms, cols, uvs)
	side(i, idx(ix, iz + 1), Vector3(x1, 0, z1), Vector3(x0, 0, z1), c2, c3, s2, s3, Vector3.BACK, cave, verts, norms, cols, uvs)
	side(i, idx(ix - 1, iz), Vector3(x0, 0, z1), Vector3(x0, 0, z0), c3, c0, s3, s0, Vector3.LEFT, cave, verts, norms, cols, uvs)

func side(i: int, j: int, a: Vector3, b: Vector3, ma: float, mb: float, sa: float, sb: float, nrm: Vector3, cave: float,
		verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, uvs: PackedVector2Array) -> void:
	var my_top: int = top[i]
	var nb_top: int = top[j]
	var nb_y: float = ly(nb_top)
	# the neighbour's corners on this edge: shared ones match mine; otherwise its own flat top
	var na: float = nb_y if is_nan(sa) else sa
	var nb: float = nb_y if is_nan(sb) else sb
	var hi: bool = holes.has(i)
	var hj: bool = holes.has(j)
	var flat_upper: bool = false
	if hi:
		for hv: Vector2i in holes[i]:
			if hv.y > nb_top:
				flat_upper = true
	if not flat_upper and (ma > na + 0.01 or mb > nb + 0.01):
		var lo_a: float = minf(ma, na)
		var lo_b: float = minf(mb, nb)
		var ct: Color = layer_color(i, my_top - 1) * cave
		var cb: Color = layer_color(i, maxi(kof(minf(lo_a, lo_b)), KFLOOR)) * 0.82 * cave
		quad(Vector3(a.x, ma, a.z), Vector3(b.x, mb, b.z), Vector3(b.x, lo_b, b.z), Vector3(a.x, lo_a, a.z), nrm, ct, cb, 0.85, verts, norms, cols, uvs)
	# flat runs where this cell is solid and the neighbour is air (tunnels, holes, cliff faces with holes)
	if not flat_upper and not hi and not hj:
		return    # both solid all the way up to the lower top: nothing exposed
	var k_end: int = my_top if flat_upper else mini(my_top, nb_top)
	var run_lo: int = -1
	for k in range(KFLOOR, k_end + 1):
		var exposed: bool = k < k_end and solid(i, k) and not solid(j, k)
		if exposed and run_lo < 0:
			run_lo = k
		elif not exposed and run_lo >= 0:
			var yb: float = ly(run_lo)
			var yt: float = ly(k)
			quad(Vector3(a.x, yt, a.z), Vector3(b.x, yt, b.z), Vector3(b.x, yb, b.z), Vector3(a.x, yb, a.z), nrm, layer_color(i, k - 1) * 0.7, layer_color(i, run_lo) * 0.6, 0.5, verts, norms, cols, uvs)
			run_lo = -1

func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, want: Vector3, ctop: Color, cbot: Color, shade: float,
		verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, uvs: PackedVector2Array) -> void:
	var mid: float = (a.y + d.y) * 0.5 - 0.001
	tri(a, b, c, want, ctop, cbot, mid, shade, verts, norms, cols, uvs)
	tri(a, c, d, want, ctop, cbot, mid, shade, verts, norms, cols, uvs)

func tri(t0: Vector3, t1: Vector3, t2: Vector3, want: Vector3, ctop: Color, cbot: Color, mid: float, shade: float,
		verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, uvs: PackedVector2Array) -> void:
	var nn: Vector3 = (t1 - t0).cross(t2 - t0)
	if nn.length_squared() < 1e-8:
		return
	nn = nn.normalized()
	if nn.dot(want) < 0.0:
		nn = -nn
		var tmp: Vector3 = t1
		t1 = t2
		t2 = tmp
	var uv: Vector2 = Vector2(shade, 0)
	verts.append(t0)
	verts.append(t1)
	verts.append(t2)
	norms.append(nn)
	norms.append(nn)
	norms.append(nn)
	cols.append(ctop if t0.y >= mid else cbot)
	cols.append(ctop if t1.y >= mid else cbot)
	cols.append(ctop if t2.y >= mid else cbot)
	uvs.append(uv)
	uvs.append(uv)
	uvs.append(uv)
