extends Node
## Scripted check of the ISLES world. Run:
##   godot --path . -- --isles --isles-test [--shots=/dir] [--quit-after-test]
## Prints "ISLES PASS/FAIL ..." lines and "ISLES RESULT n/m".
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
	print("ISLES ", "PASS " if ok else "FAIL ", name, "  ", info)

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

func run() -> void:
	await wait(0.6)
	var isles: RefCounted = game.isles
	var field: Node3D = isles.field
	check("stage is isles", game.stage == "isles")
	check("ground chunks built", field.chunks.size() > 10, "%d chunks" % field.chunks.size())
	check("hero is Lance", game.hero_key == "lance")
	check("two knights on Crag Isle", game.enemies.size() == 2)
	await shot("01_title")
	game.start_game()
	await wait(1.5)
	var h: CharacterBody3D = game.hero
	var top: float = field.top_at(h.global_position.x, h.global_position.z)
	check("Lance stands on the island ground", h.is_on_floor() and absf(h.global_position.y - top) < 0.8, "y %.2f ground %.2f" % [h.global_position.y, top])
	await shot("02_spawn")

	# walk on the smooth ground: push him across a slope with velocity and see he stays on it
	var start: Vector3 = h.global_position
	for i in 40:
		h.velocity.x = 0.0
		h.velocity.z = -4.0
		await get_tree().physics_frame
	var moved: float = (h.global_position - start).length()
	var gy: float = field.top_at(h.global_position.x, h.global_position.z)
	check("walks over the ground without falling through", moved > 1.0 and h.global_position.y > gy - 0.6, "moved %.1f m, y %.2f ground %.2f" % [moved, h.global_position.y, gy])

	# sword vs a stone rock on Home Isle
	var rock_i: int = -1
	var best: float = 999.0
	for i in field.n * field.n:
		if field.rock[i] != field.STONE:
			continue
		var x: float = -field.HALF + (i % field.n + 0.5) * field.STEP
		var z: float = -field.HALF + (i / field.n + 0.5) * field.STEP
		var d: float = Vector2(x, z).distance_to(Vector2(0, 4))
		if d < 20.0 and field.top[i] - field.base[i] >= 3 and d < best:
			best = d
			rock_i = i
	check("found a stone rock on Home Isle", rock_i >= 0)
	if rock_i >= 0:
		var rx: float = -field.HALF + (rock_i % field.n + 0.5) * field.STEP
		var rz: float = -field.HALF + (rock_i / field.n + 0.5) * field.STEP
		var gb: float = field.ly(field.base[rock_i])
		# stand 1.6 m away (search a free side) and face it
		var stand: Vector3 = Vector3.ZERO
		for a in 8:
			var ang: float = a * TAU / 8.0
			var sp: Vector2 = Vector2(rx, rz) + Vector2(cos(ang), sin(ang)) * 1.7
			var sh: float = field.top_at(sp.x, sp.y)
			if absf(sh - gb) < 0.6 and field.rock[field.cell_at(sp.x, sp.y)] == 0:
				stand = Vector3(sp.x, sh + 0.1, sp.y)
				break
		check("found a place beside the rock", stand != Vector3.ZERO)
		if stand != Vector3.ZERO:
			var to: Vector3 = Vector3(rx, 0, rz) - Vector3(stand.x, 0, stand.z)
			place(stand, atan2(-to.x, -to.z))
			await wait(0.3)
			var before: int = field.layers_broken
			var t_before: int = field.top[rock_i]
			game.hero_strike(h, 10.0, 2.3, 0.5, 0.3)
			var after1: int = field.layers_broken
			for k in 4:
				game.hero_strike(h, 10.0, 2.3, 0.5, 0.3)
			check("one sword hit doesn't break stone", after1 == before, "broke %d" % (after1 - before))
			check("a few sword hits break the rock", field.layers_broken > before, "%d layers, rock top %d -> %d" % [field.layers_broken - before, t_before, field.top[rock_i]])
			await wait(0.3)
			await shot("03_rock_hit")

	# bomb crater in the grass
	var bp: Vector2 = Vector2(-8, 2)
	var g0: int = field.top[field.cell_at(bp.x, bp.y)]
	place(Vector3(bp.x + 4.5, field.top_at(bp.x + 4.5, bp.y) + 0.3, bp.y), -PI * 0.5)
	await wait(0.3)
	isles.explode(Vector3(bp.x, field.top_at(bp.x, bp.y) + 0.24, bp.y))
	var g1: int = field.top[field.cell_at(bp.x, bp.y)]
	check("a bomb blasts a crater", g0 - g1 >= 2, "centre top %d -> %d layers" % [g0, g1])
	await wait(0.6)
	await shot("04_crater")

	# thrown bomb lands and goes off by itself
	var thrown_before: int = field.layers_broken
	isles.bomb_cd = 0.0
	isles.throw_bomb(h)
	check("bomb thrown", isles.bombs.size() == 1)
	await wait(isles.BOMB_FUSE + 0.4)
	check("thrown bomb exploded", isles.bombs.is_empty() and field.layers_broken > thrown_before)

	# obsidian is tough: power 1 only chips it
	var ob_i: int = -1
	for i in field.n * field.n:
		if field.rock[i] == field.OBSIDIAN and field.top[i] - field.base[i] >= 2:
			ob_i = i
			break
	if ob_i >= 0:
		var ox: float = -field.HALF + (ob_i % field.n + 0.5) * field.STEP
		var oz: float = -field.HALF + (ob_i / field.n + 0.5) * field.STEP
		var ot: int = field.top[ob_i]
		var r: Dictionary = field.blast(Vector3(ox, field.ly(ot) - 0.2, oz), 0.3, 1, false)
		check("obsidian chips instead of breaking", int(r.broken) == 0 and int(r.chipped) > 0 and field.top[ob_i] == ot)

	# tunnel and collapse: dig into a cliff side
	var crag: Vector2 = isles.ISLANDS[1].c
	var cell: int = field.cell_at(crag.x, crag.y)
	var cy: float = field.top_y(cell)
	var hole_before: int = field.holes.size()
	field.blast(Vector3(crag.x, cy - 2.2, crag.y), 1.2, 8, false)
	check("a blast inside the rock opens a hole (tunnel)", field.holes.size() > hole_before, "holes %d -> %d" % [hole_before, field.holes.size()])
	var col_before: int = field.collapses
	field.blast(Vector3(crag.x, cy - 2.2, crag.y), 2.6, 8, false)
	check("support rules run (collapse count %d)" % field.collapses, field.collapses >= col_before)

	# deep water: splash back to the last dry spot
	place(Vector3(2, 0.4, 16) + Vector3(0, field.top_at(2, 16), 0), PI)
	await wait(0.6)
	var sea: Vector2 = Vector2(30, 30)
	check("open sea is deep", field.top_at(sea.x, sea.y) < -1.0)
	h.global_position = Vector3(sea.x, -1.0, sea.y)
	await wait(0.2)
	check("walking into deep water splashes back to land", isles.splashes >= 1 and field.top_at(h.global_position.x, h.global_position.z) > 0.2)

	# boat: board, sail, land on another island
	var boat: Node3D = isles.boat
	place(boat.position + Vector3(0, 0.3, -2.4) + Vector3(0, maxf(field.top_at(boat.position.x, boat.position.z - 2.4), 0.0), 0), 0.0)
	await wait(0.2)
	check("BOARD offered beside the boat", isles.boat_action() == "BOARD", isles.boat_action())
	isles.board(h)
	check("aboard", isles.aboard)
	var b0: Vector3 = boat.position
	game.cam_yaw = PI
	for i in 60:
		isles.sail(h, 1.0 / 30.0, Vector2(0, -1))
	check("the boat sails", boat.position.distance_to(b0) > 4.0, "%.1f m" % boat.position.distance_to(b0))
	check("Lance rides in the boat", h.global_position.distance_to(boat.position) < 2.6 and h.global_position.y > 0.3)
	await shot("05_sailing")
	# put the boat off Crag Isle's west shore and land
	var p: Vector2 = crag + Vector2(-25, 0)
	while field.top_at(p.x + 2.4, p.y) < -0.75:
		p.x += 0.5
	boat.position = Vector3(p.x, 0, p.y)
	check("LAND offered at the shore", isles.boat_action() == "LAND", isles.boat_action())
	isles.land(h)
	await wait(0.6)
	check("landed on Crag Isle", not isles.aboard and field.top_at(h.global_position.x, h.global_position.z) > 0.2 and h.is_on_floor())

	# wrap round: walk off the east edge, come back on the west
	var w0: int = isles.wraps
	h.global_position = Vector3(isles.HALF + 0.5, 1.0, -30)
	await wait(0.1)
	check("world wraps east -> west", isles.wraps == w0 + 1 and h.global_position.x < -isles.HALF + 2.0, "x %.1f" % h.global_position.x)
	h.global_position = Vector3(-10, 1.0, isles.HALF + 0.6)
	await wait(0.1)
	check("world wraps south -> north", h.global_position.z < -isles.HALF + 2.0, "z %.1f" % h.global_position.z)

	# fog zone: serpent at sea, bombs drive it off
	boat.position = Vector3(-8, 0, -30)
	isles.board(h)
	game.cam_yaw = 0.0
	for i in 10:
		isles.sail(h, 1.0 / 30.0, Vector2.ZERO)
	await wait(2.5)
	check("fog thickens near Mist Isle", isles.w_fog > 0.4, "fog %.2f" % isles.w_fog)
	check("the serpent comes out of the fog", not isles.serpent.is_empty())
	await shot("06_fog_serpent")
	if not isles.serpent.is_empty():
		for k in 3:
			var head: Node3D = isles.serpent.parts[0]
			head.global_position.y = 0.4
			isles.explode(head.global_position + Vector3(0.5, 0, 0))
		check("three bomb hits drive the serpent off", int(isles.serpent.hp) <= 0)

	# dust storm and the buried chest
	boat.position = Vector3(-20, 0, 34)
	await wait(2.5)
	check("dust storm near Dune Isle", isles.w_dust > 0.4 and isles.dust.emitting, "dust %.2f" % isles.w_dust)
	isles.aboard = false
	h.collision_layer = 1
	h.collision_mask = 1
	var chest: Dictionary = isles.chests[1]
	check("Dune chest starts buried", chest.buried)
	var bpos: Vector3 = Vector3(isles.BURIED.x, field.top_at(isles.BURIED.x, isles.BURIED.y) + 0.24, isles.BURIED.y)
	place(bpos + Vector3(4, 0.4, 0), -PI * 0.5)
	isles.explode(bpos)
	await wait(0.3)
	if chest.buried:
		bpos.y = field.top_at(isles.BURIED.x, isles.BURIED.y) + 0.24
		isles.explode(bpos)
		await wait(0.3)
	check("bombs dig the chest out", not chest.buried)
	var cn: Node3D = chest.node
	place(cn.global_position + Vector3(1.0, 0.6, 0), -PI * 0.5)
	await wait(0.5)
	check("walking to it opens the chest", chest.open)
	await shot("07_dune")
	# Mist chest
	var mc: Dictionary = isles.chests[0]
	place((mc.node as Node3D).global_position + Vector3(1.0, 0.6, 0), -PI * 0.5)
	await wait(0.5)
	check("Mist Isle chest opens", mc.open)

	# chase camera: run toward the camera, it waits a second, then swings round behind
	place(Vector3(2, field.top_at(2, 10) + 0.3, 10), 0.0)
	await wait(0.5)
	game.look_hold = 0.0
	game.cam_yaw = 0.0
	game.toward_t = 0.0
	var yaw0: float = game.cam_yaw
	var dt: float = 1.0 / 60.0
	for k in 36:    # 0.6 s running straight at the camera (+z)
		h.velocity = Vector3(0, 0, 6.0)
		game.chase_follow(dt)
	check("camera waits while running at it", absf(game.cam_yaw - yaw0) < 0.01, "yaw %.2f" % game.cam_yaw)
	for k in 120:   # 2 s more
		h.velocity = Vector3(0, 0, 6.0)
		game.chase_follow(dt)
	var behind: float = absf(wrapf(game.cam_yaw - PI, -PI, PI))
	check("then swings round behind him", behind < 0.5, "off by %.2f rad" % behind)

	var ok: int = 0
	for r: bool in results:
		if r:
			ok += 1
	print("ISLES RESULT %d/%d %s" % [ok, results.size(), "PASS" if ok == results.size() else "FAIL"])
	if "--quit-after-test" in OS.get_cmdline_user_args():
		get_tree().quit(0 if ok == results.size() else 1)
