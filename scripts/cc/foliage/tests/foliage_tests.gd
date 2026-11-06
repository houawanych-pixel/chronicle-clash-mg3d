extends Node
## CC Unified Foliage Subsystem checks, in the ISLES world. Prints "FOLIAGE PASS/FAIL ..." and
## "FOLIAGE RESULT n/m". Run:
##   godot --path . -- --isles --foliage-test [--shots=/dir] [--quit-after-test]
const Palette = preload("res://scripts/cc/foliage/foliage_palette.gd")
const Store = preload("res://scripts/cc/foliage/foliage_store.gd")

var game: Node
var results: Array = []
var shots: String = ""

func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.trim_prefix("--shots=")
	run.call_deferred()

func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func check(name: String, ok: bool, info: String = "") -> void:
	results.append(ok)
	print("FOLIAGE ", "PASS " if ok else "FAIL ", name, "  ", info)

func shot(name: String) -> void:
	if shots.is_empty():
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [shots, name])

func place(pos: Vector3, yaw: float) -> void:
	var h: CharacterBody3D = game.hero
	h.global_position = pos
	h.velocity = Vector3.ZERO
	h.yaw = yaw
	h.state = "idle"
	game.cam_yaw = yaw
	game.cam_pos = pos

## Stand d metres from a point, facing it.
func look_at_point(p: Vector3, d: float, ang: float = 0.0) -> void:
	var field: Node3D = game.isles.field
	var sp: Vector2 = Vector2(p.x, p.z) + Vector2(sin(ang), cos(ang)) * d
	for k in 12:   # stand on land (never in the sea)
		var a2: float = ang + k * TAU / 12.0
		var q: Vector2 = Vector2(p.x, p.z) + Vector2(sin(a2), cos(a2)) * d
		if field.top_at(q.x, q.y) > 0.4 and absf(field.top_at(q.x, q.y) - field.top_at(p.x, p.z)) < 1.6:
			sp = q
			break
	var y: float = field.top_at(sp.x, sp.y) + 0.2
	var to: Vector3 = p - Vector3(sp.x, y, sp.y)
	place(Vector3(sp.x, maxf(y, 0.6), sp.y), atan2(-to.x, -to.z))

func card_info(st: SurfaceTool) -> Dictionary:
	var arr: Array = st.commit_to_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var up_n: bool = true
	for x: Vector3 in n:
		if x.y < 0.35:
			up_n = false
	return {"verts": v.size(), "quads": v.size() / 6, "up": up_n, "v": v}

func run() -> void:
	await wait(0.6)
	game.start_game()
	await wait(1.2)
	WeatherService.locked = true
	WeatherService.is_precipitating = false
	var isles: RefCounted = game.isles
	var fol: RefCounted = isles.foliage
	check("foliage subsystem is in the isles", fol != null and fol.mgr != null)
	if fol == null:
		finish()
		return
	var m: Node3D = fol.mgr
	var field: Node3D = isles.field
	await wait(0.6)
	var mat: ShaderMaterial = m.material
	check("one shared shader material with the foliage atlas and the biome palette", mat.shader != null and mat.get_shader_parameter("atlas") != null and (mat.get_shader_parameter("palette") as PackedColorArray).size() == 64)
	check("content placed: canopy leaves, flower beds, cliff vines", m.leaves.size() > 150 and m.flowers.size() > 25 and m.vines.size() > 10, "%d leaf cells, %d flowers, %d vines" % [m.leaves.size(), m.flowers.size(), m.vines.size()])
	check("three 2x2 flower groups fused into big snapping flowers", m.jaws.size() == 3, "%d" % m.jaws.size())
	check("all chunks drawn", m.meshes.size() > 3 and m.dirty.is_empty(), "%d chunk meshes" % m.meshes.size())

	# ---- leaves: crossed planes, young vs merged mature
	var young_key := Vector3i.ZERO
	var group_key := Vector3i.ZERO
	var found_y := false
	var found_g := false
	for key: Vector3i in m.leaves:
		if not found_y and not m.is_merged_leaf(key):
			young_key = key
			found_y = true
		if not found_g and m.is_merged_leaf(key):
			group_key = Vector3i(key.x >> 1, key.y, key.z >> 1)
			found_g = true
	check("canopies have single young cells and merged 2x2 mature clusters", found_y and found_g)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	m._young_leaves(st, young_key, m.leaves[young_key])
	var yi: Dictionary = card_info(st)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	m._mature_cluster(st, group_key, m.leaves[Vector3i(group_key.x * 2, group_key.y, group_key.z * 2)])
	var mi: Dictionary = card_info(st)
	# crossed planes, not cube faces: the cards cut through the cell centre and are not axis-aligned
	var vv: PackedVector3Array = yi.v
	var e1: Vector3 = (vv[1] - vv[0]).normalized()
	var e2: Vector3 = (vv[7] - vv[6]).normalized()
	var axis_aligned: bool = absf(e1.x) > 0.999 or absf(e1.z) > 0.999
	check("a young leaf cell is crossed cards (X), not six cube faces", int(yi.quads) == 3 and absf(e1.dot(e2)) < 0.2 and not axis_aligned, "%d cards, angle dot %.2f" % [yi.quads, e1.dot(e2)])
	check("leaf normals lean outward / upward (soft canopy light)", bool(yi.up) and bool(mi.up))
	var span_y: float = 0.0
	var span_m: float = 0.0
	for p: Vector3 in yi.v:
		span_y = maxf(span_y, Vector2(p.x, p.z).distance_to(Vector2(vv[0].x, vv[0].z)))
	var mv: PackedVector3Array = mi.v
	for p: Vector3 in mv:
		span_m = maxf(span_m, Vector2(p.x, p.z).distance_to(Vector2(mv[0].x, mv[0].z)))
	check("the merged cluster is bigger and fuller (more cards over the 4 cells)", int(mi.quads) > int(yi.quads) and span_m > span_y * 1.6, "%d vs %d cards, span %.2f vs %.2f m" % [mi.quads, yi.quads, span_m, span_y])
	check("mature clusters use the small dense leaf texture, young cells the bigger leaves", m.UV_MATURE != m.UV_YOUNG)
	var c_key := Vector3i(group_key.x * 2, group_key.y, group_key.z * 2)
	var tree_at: Vector3 = m._cell_pos(c_key.x, c_key.y, c_key.z)
	look_at_point(tree_at - Vector3(0, 3.0, 0), 5.5)
	await wait(0.8)
	await shot("01_canopy")
	# burn one of a 2x2 group: the rest go back to young; regrow: fused again
	m.spread_q.clear()
	m._burn_leaf(c_key)
	m.spread_q.clear()
	var sib := Vector3i(c_key.x + 1, c_key.y, c_key.z)
	check("burning one cell of a group breaks the mature cluster back into young cells", int(m.leaves[c_key].s) == m.BURNED and not m.is_merged_leaf(sib))
	WorldClock.advance(float(m.tuning.season_regrow_h) + 1.0)
	m.season_tick()
	check("after the season it regrows and the four fuse again", int(m.leaves[c_key].s) == m.INTACT and m.is_merged_leaf(sib))

	# ---- fire from the world's fire system (Ember fire / ChemistryService) and spreading
	var b0: int = m.count("leaf", m.BURNED)
	var lit: int = ChemistryService.ignite_at(tree_at, 0.4)
	await wait(2.0)
	var b1: int = m.count("leaf", m.BURNED)
	check("fire (ChemistryService.ignite_at) burns leaf cells", lit > 0 and b1 > b0, "lit %d, burned %d -> %d" % [lit, b0, b1])
	check("the fire spreads through the canopy", b1 > lit, "%d burned from %d lit" % [b1, lit])
	await shot("02_canopy_burned")
	WeatherService.is_precipitating = true
	var b2: int = m.count("leaf", m.BURNED)
	m.spread_q.clear()
	var none: int = ChemistryService.ignite_at(tree_at + Vector3(0.6, 0, 0), 0.4)
	check("no fire in the rain", none == 0 and m.count("leaf", m.BURNED) == b2)
	WeatherService.is_precipitating = false
	var r0: int = m.regrows
	WorldClock.advance(float(m.tuning.season_regrow_h) + 0.5)
	m.season_tick()
	check("every burnt leaf cell grows back after the season pass", m.count("leaf", m.BURNED) == 0 and m.regrows > r0, "%d regrown" % (m.regrows - r0))

	# ---- vines
	var vc: Dictionary = {}
	var vi: int = -1
	for i in m.vines.size():
		var c: Dictionary = m.vines[i]
		if int(c.len) >= 3 and (vi < 0 or int(c.len) > int(vc.len)):
			vc = c
			vi = i
	var full_len: int = int(vc.len) if vi >= 0 else 0
	if vi >= 0:   # cut it back to its anchor to watch it grow
		vc.len = 1
		vc.last = m.now_h()
		m.dirty[m.chunk_of(int(vc.ix), int(vc.iz))] = true
	check("found a cliff vine (hanging 3+ cells down a face)", vi >= 0, "%d cells" % full_len)
	if vi >= 0:
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		vc.len = 2
		var cells: Array = m.vine_cells(vc)
		vc.len = 1
		m._vine_quad(st, vc, cells[0], 0)
		var q: Dictionary = card_info(st)
		var d2: Vector2i = m.DIRS[int(vc.dir)]
		var w: Vector2 = m.host.cell_world(int(vc.ix), int(vc.iz))
		var face: float = (w.x + d2.x * field.STEP * 0.5) if d2.x != 0 else (w.y + d2.y * field.STEP * 0.5)
		var off_ok: bool = true
		for p: Vector3 in q.v:
			var coord: float = p.x if d2.x != 0 else p.z
			if absf(absf(coord - face) - float(m.tuning.vine_offset)) > 0.0005:
				off_ok = false
		check("a vine cell is ONE quad on the host face, 0.008 m off it", int(q.quads) == 1 and off_ok, "%d quad(s)" % q.quads)
		var top: Vector3 = m._cell_pos(int(vc.ix), int(vc.k), int(vc.iz))
		look_at_point(top - Vector3(0, 1.0, 0), 4.0, atan2(-d2.x, -d2.y))
		await wait(0.6)
		await shot("03_vines")
		var hp: Vector3 = m._cell_pos(int(vc.ix), int(vc.k), int(vc.iz))
		check("the vine face is CLIMBABLE for the climbing controller", m.climbable_at(Vector3(hp.x, hp.y - 1.0, hp.z)) and not m.climbable_at(hp + Vector3(6, 0, 6)))
		var ck: Vector2 = fol.climb_k(Vector3(hp.x, hp.y - 1.0, hp.z))
		check("climbing on vines costs less stamina and is quicker", ck.x < 1.0 and ck.y > 1.0, "drain x%.2f speed x%.2f" % [ck.x, ck.y])
		var l0: int = int(vc.len)
		WorldClock.advance(float(m.tuning.vine_spread_h) * 2.0 + 0.1)
		m.season_tick()
		check("an intact vine spreads down over the days", int(vc.len) > l0, "%d -> %d cells" % [l0, int(vc.len)])
		var mid: Vector3i = m.vine_cells(vc)[1]
		m.burn_sphere(m._cell_pos(mid.x, mid.y, mid.z), 0.1)
		check("fire cuts a vine where it burns (the top keeps hanging)", int(vc.len) == 1)
		WorldClock.advance(float(m.tuning.vine_spread_h) * 3.0)
		m.season_tick()
		check("a burnt vine waits for the season before it grows again", int(vc.len) == 1)
		WorldClock.advance(float(m.tuning.season_regrow_h) + float(m.tuning.vine_spread_h) * 2.0)
		m.season_tick()
		check("after the season the surviving top regrows downward", int(vc.len) >= 2, "%d cells" % int(vc.len))

	# ---- flowers and biome colours
	var by_biome: Dictionary = {}
	for key: Vector2i in m.flowers:
		var nm: String = isles.island_name(m.host.cell_world(key.x, key.y))
		var bi: int = int(m.flowers[key].b)
		by_biome[nm] = Palette.BIOMES[bi]
	check("each isle's flowers take its biome (no per-planet block types)", by_biome.get("HOME ISLE", "") == "verdant" and by_biome.get("MIST ISLE", "") == "bluegreen" and by_biome.get("DUNE ISLE", "") == "yellow", str(by_biome))
	var blue: Array = Palette.row("bluegreen")
	var yel: Array = Palette.row("yellow")
	var shell_blue: Color = blue[Palette.SHELL_A]
	check("blue-green planet: blue diamond shell, white core, green stem, blue-and-green grass", shell_blue.b > shell_blue.r + 0.3 and blue[Palette.CORE] == Color.WHITE and (blue[Palette.STEM] as Color).g > (blue[Palette.STEM] as Color).r and (blue[Palette.GRASS_A] as Color).b > 0.6 and (blue[Palette.GRASS_B] as Color).g > 0.6)
	var ga: Color = yel[Palette.GRASS_A]
	var gb: Color = yel[Palette.GRASS_B]
	check("yellow planet: yellow-and-purple grass, shell in its yellow / purple, white core", ga.r > 0.8 and ga.g > 0.7 and ga.b < 0.4 and gb.b > gb.g and (yel[Palette.SHELL_A] as Color).r > 0.9 and (yel[Palette.SHELL_B] as Color).b > 0.7 and yel[Palette.CORE] == Color.WHITE)
	var single: Vector2i = Vector2i.ZERO
	for key: Vector2i in m.flowers:
		if not m.flower_group_whole(Vector2i(key.x >> 1, key.y >> 1)) and isles.island_name(m.host.cell_world(key.x, key.y)) == "MIST ISLE":
			single = key
			break
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	m._single_flower(st, single, m.flowers[single])
	var arrf: Array = st.commit_to_arrays()
	var slots: Dictionary = {}
	for u: Vector2 in (arrf[Mesh.ARRAY_TEX_UV2] as PackedVector2Array):
		slots[int(round(u.y)) % 16] = true
	check("a single flower is 3D: diamond shell facets, a white core, a stalk and lower-cut grass", slots.has(Palette.SHELL_A) and slots.has(Palette.SHELL_B) and slots.has(Palette.CORE) and slots.has(Palette.STEM) and slots.has(Palette.GRASS_A) and slots.has(Palette.GRASS_B) and (arrf[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 200)
	var fp: Vector3 = m._flower_pos(single)
	look_at_point(fp, 2.2)
	await wait(0.5)
	await shot("04_flowers_mist")

	# ---- the big snapping flower
	var g: Vector2i = m.jaws.keys()[0]
	var maw: Dictionary = m.jaws[g]
	var mn: Node3D = maw.node
	var h: CharacterBody3D = game.hero
	h.hp = h.max_hp if "max_hp" in h else 100.0
	look_at_point(mn.global_position, 6.0)
	await wait(0.6)
	check("it idles open while nothing is near", String(maw.state) == "idle" and (maw.upper as Node3D).rotation.x > 0.5, "state %s upper %.2f hero-dist %.1f" % [maw.state, (maw.upper as Node3D).rotation.x, h.global_position.distance_to(mn.global_position)])
	await shot("05_maw_open")
	var hp0: float = h.hp
	var bites0: int = m.bites
	look_at_point(mn.global_position, 1.5)
	await wait(0.2)
	var tele: bool = String(maw.state) == "tele"
	await wait(float(m.tuning.snap_telegraph_s) * 0.6)
	await shot("06_maw_telegraph")
	await wait(float(m.tuning.snap_telegraph_s) + float(m.tuning.snap_shut_s))
	check("a target close by: it pulls back (telegraph), then snaps its shell shut", tele and m.bites > bites0, "tele %s, bites %d, state %s, dist %.2f" % [tele, m.bites - bites0, maw.state, h.global_position.distance_to(mn.global_position)])
	check("the bite hits (damage)", h.hp < hp0, "hp %.0f -> %.0f" % [hp0, h.hp])
	check("after the bite it stays shut a moment (cooldown)", String(maw.state) == "cool" and (maw.upper as Node3D).rotation.x < 0.1)
	look_at_point(mn.global_position, 6.0)
	await wait(float(m.tuning.snap_cooldown_s) + 0.6)
	check("then it reopens", String(maw.state) == "idle" and (maw.upper as Node3D).rotation.x > 0.5, "state %s" % maw.state)
	look_at_point(mn.global_position, 7.0)
	# fire: the big flower burns; the bed grows back as single flowers that fuse again
	var fk := Vector2i(g.x * 2, g.y * 2)
	m.spread_q.clear()
	isles.explode(m._flower_pos(fk))
	m.spread_q.clear()
	await wait(0.3)
	check("a bomb's fire burns the big flower (it is gone)", not m.jaws.has(g) and int(m.flowers[fk].s) == m.BURNED)
	await shot("07_maw_burned")
	WorldClock.advance(float(m.tuning.season_regrow_h) + 0.5)
	m.season_tick()
	await wait(0.3)
	var whole: bool = m.flower_group_whole(g)
	check("the wild bed sprouts back and re-fuses into the snapping flower", whole == m.jaws.has(g) and m.count("flower", m.BURNED) == 0, "whole %s jaw %s" % [whole, m.jaws.has(g)])

	# ---- world-clock catch-up on load (and the save file)
	var some: Array = []
	for key: Vector3i in m.leaves:
		if some.size() < 6:
			some.append(key)
	for key: Vector3i in some:
		m.leaves[key].s = m.BURNED
		m.leaves[key].t = m.now_h()
	fol.leave()
	var snap: Dictionary = Store.get_snapshot("isles")
	check("leaving keeps the burnt state with its world times", (snap.get("leaves", []) as Array).size() >= 6)
	ok_save(snap)
	# the world is not loaded while a season passes; on load it catches up
	m.process_mode = Node.PROCESS_MODE_DISABLED
	for key: Vector3i in some:
		m.leaves[key].s = m.INTACT
	m.restore(snap)
	check("restored right away it is still burnt", int(m.leaves[some[0]].s) == m.BURNED)
	WorldClock.advance(float(m.tuning.season_regrow_h) + 1.0)
	m.restore(snap)
	m.process_mode = Node.PROCESS_MODE_INHERIT
	check("restored a season later it has caught up (grown back)", int(m.leaves[some[0]].s) == m.INTACT)
	finish()

func ok_save(snap: Dictionary) -> void:
	var path: String = "user://cc_save_foliage_test.json"
	SaveService.save_game(path)
	Store.worlds.clear()
	SaveService.load_game(path)
	check("the foliage state goes in the save file and comes back", (Store.get_snapshot("isles").get("leaves", []) as Array).size() == (snap.get("leaves", []) as Array).size())

func finish() -> void:
	var ok: int = results.count(true)
	print("FOLIAGE RESULT %d/%d" % [ok, results.size()])
	if "--quit-after-test" in OS.get_cmdline_user_args():
		get_tree().quit(0 if ok == results.size() else 1)
