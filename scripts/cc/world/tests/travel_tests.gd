extends Node
## Swim / dive / skydive / shield surf / bow checks in the world slice. Prints "TR PASS/FAIL"
## and "TR RESULT n/m". Run: godot --path . res://scenes/systems/cc_world_slice.tscn -- --travel-test --quit-after-test

var world: Node3D
var results: Array[bool] = []
var shots: String = ""

func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.trim_prefix("--shots=")
	run.call_deferred()

func check(name: String, ok: bool, info: String = "") -> void:
	results.append(ok)
	print("TR ", "PASS " if ok else "FAIL ", name, "  ", info)

func ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func secs(s: float) -> void:
	await ticks(int(s * 60.0))

func shot(name: String) -> void:
	if shots.is_empty():
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [shots, name])

func pl() -> CharacterBody3D:
	return world.player

func fresh() -> void:
	world.start()
	await ticks(8)
	TimeDilation.release()

func place(p: Vector3, yaw: float = 0.0) -> void:
	pl().global_position = p
	pl().velocity = Vector3.ZERO
	pl().vy = 0.0
	pl().yaw = yaw
	pl().air_peak_y = p.y
	world.camera.cam_yaw = yaw

func run() -> void:
	await ticks(10)
	await swim_tests()
	await dive_tests()
	await surf_tests()
	await bow_tests()
	var ok: int = 0
	for r: bool in results:
		if r:
			ok += 1
	print("TR RESULT %d/%d %s" % [ok, results.size(), "PASS" if ok == results.size() else "FAIL"])
	WeatherService.apply("clear")
	TimeDilation.release()
	if "--quit-after-test" in OS.get_cmdline_user_args():
		get_tree().quit(0 if ok == results.size() else 1)

# ---------------------------------------------------------------- swimming

func swim_tests() -> void:
	await fresh()
	var p: CharacterBody3D = pl()
	var pond: Vector3 = world.POND
	place(Vector3(pond.x, 0.1, pond.z + 7.5), 0.0)       # on the south bank, facing the water
	await ticks(10)
	p.inp.move = Vector2(0, -1)
	for i in 180:
		await ticks(1)
		if p.state == "swim":
			break
	await secs(0.8)
	p.inp.move = Vector2.ZERO
	var surf_y: float = world.pond.surface_y()
	var feet_below: float = surf_y - p.global_position.y
	check("walking into deep water: swim, head above the surface", p.state == "swim" and absf(feet_below - float(p.tt.swim_float)) < 0.35 and p.sheathed, "%s, feet %.2f m under" % [p.state, feet_below])
	await shot("tr_01_swim")
	StaminaPool.refill()
	await secs(0.3)
	var s0: float = StaminaPool.value
	p.inp.move = Vector2(1, 0)
	await secs(1.0)
	var plain: float = s0 - StaminaPool.value
	p.inp.sprint = true
	var s1: float = StaminaPool.value
	await secs(1.0)
	var dash: float = s1 - StaminaPool.value
	check("plain swimming barely tires you; dashing drains ~25 / s", plain < 4.0 and absf(dash - 25.0) < 7.0, "%.1f vs %.1f per second" % [plain, dash])
	var drowned: Array = [false]
	p.drowned.connect(func() -> void: drowned[0] = true, CONNECT_ONE_SHOT)
	var hp0: float = p.hp
	for i in 400:
		await ticks(1)
		if drowned[0]:
			break
	p.inp.sprint = false
	p.inp.move = Vector2.ZERO
	await ticks(3)
	check("out of stamina in deep water: you go under, lose health, back on shore", drowned[0] and p.hp < hp0 and p.state == "locomote" and not p.in_deep_water())
	# swim to the bank and climb out
	await fresh()
	p = pl()
	place(Vector3(pond.x, -1.6, pond.z + 3.0), 0.0)
	await ticks(6)
	p.inp.move = Vector2(0, 1)          # toward the south bank (+z)
	var out: bool = false
	for i in 300:
		await ticks(1)
		if p.state == "locomote" and p.is_on_floor() and p.global_position.y > -0.2:
			out = true
			break
	p.inp.move = Vector2.ZERO
	check("swimming into the bank climbs out", out, "%s y %.2f" % [p.state, p.global_position.y])

# ---------------------------------------------------------------- skydive and dive

func dive_tests() -> void:
	await fresh()
	var p: CharacterBody3D = pl()
	var top: Vector3 = world.DIVE_TOWER + Vector3(0.8, 14.1, 0)
	place(top, -PI * 0.5)        # facing +x, out over the pond
	world.camera.cam_yaw = -PI * 0.5
	await ticks(6)
	var hp0: float = p.hp
	var saw_sky: bool = false
	var saw_dive: bool = false
	var dove: Array = [-1.0]
	p.dove.connect(func(h: float) -> void: dove[0] = h, CONNECT_ONE_SHOT)
	p.inp.move = Vector2(0, -1)
	for i in 400:
		await ticks(1)
		if p.state == "skydive":
			saw_sky = true
			if p.diving():
				saw_dive = true
		if i == 30:
			await shot("tr_02_skydive")
		if p.state == "swim":
			break
	p.inp.move = Vector2.ZERO
	check("off the cliff: skydive, then the head-first dive pose", saw_sky and saw_dive)
	check("a high dive into deep water: splash, no damage, swimming", float(dove[0]) > 10.0 and p.hp == hp0 and p.state == "swim", "dropped %.1f m, -%.0f hp" % [float(dove[0]), hp0 - p.hp])
	await secs(0.5)
	# skydive onto ground: still the fall-damage curve
	await fresh()
	p = pl()
	place(Vector3(0, 16, 14), 0.0)
	var got: Array = [-1.0, -1.0]
	p.landed.connect(func(h: float, d: float) -> void:
		got[0] = h
		got[1] = d, CONNECT_ONE_SHOT)
	var sky2: bool = false
	for i in 300:
		await ticks(1)
		if p.state == "skydive":
			sky2 = true
		if float(got[0]) >= 0.0:
			break
	var want: float = float(p.jt.fall_damage_frac(float(got[0]))) * p.max_hp
	check("skydiving onto the ground still hurts (fall curve)", sky2 and float(got[1]) > 0.0 and absf(float(got[1]) - want) < 0.5, "%.1f m, -%.0f" % [float(got[0]), float(got[1])])
	await secs(1.0)
	# steer, then open the glider out of the skydive
	await fresh()
	p = pl()
	place(Vector3(0, 30, 14), 0.0)
	for i in 120:
		await ticks(1)
		if p.state == "skydive":
			break
	var x0: float = p.global_position.x
	p.inp.move = Vector2(1, 0)
	await secs(0.8)
	var dx: float = p.global_position.x - x0
	p.inp.move = Vector2.ZERO
	p.press("jump")
	await ticks(3)
	check("skydive steers with the stick", dx > 2.5, "%.1f m sideways" % dx)
	check("JUMP opens the glider out of a skydive", p.state == "glide")
	await secs(4.0)

# ---------------------------------------------------------------- shield surf

func slope_top(surface: String) -> Vector3:
	for sl: Array in world.SLOPES:
		if sl[0] == surface:
			var at: Vector3 = sl[1]
			return at + Vector3(0, sin(deg_to_rad(20.0)) * 10.0 + 0.5, -4.2)
	return Vector3.ZERO

## Start surfing at the top of a slope, pointing downhill (+z). Returns speed after secs.
func surf_run(surface: String, run_s: float, rain: bool = false) -> float:
	await fresh()
	if rain:
		WeatherService.apply("rain")
	var p: CharacterBody3D = pl()
	place(slope_top(surface), PI)
	world.camera.cam_yaw = 0.0
	await ticks(10)
	p.inp.move = Vector2(0, 1)
	await ticks(12)
	p.inp.guard_held = true
	p.press("jump")
	await ticks(2)
	p.inp.move = Vector2.ZERO
	await secs(run_s)
	return Vector2(p.velocity.x, p.velocity.z).length()

func surf_tests() -> void:
	var g1: float = await surf_run("grass", 0.3)
	var p: CharacterBody3D = pl()
	var in_surf: bool = p.state == "surf"
	await secs(0.7)
	var g2: float = Vector2(p.velocity.x, p.velocity.z).length()
	check("GUARD + JUMP surfs; it speeds up downhill", in_surf and g2 > g1 + 1.0, "%.1f -> %.1f m/s" % [g1, g2])
	await shot("tr_03_surf")
	# flat: slows down
	await fresh()
	p = pl()
	place(Vector3(0, 0.1, 30), PI)
	world.camera.cam_yaw = 0.0
	await ticks(6)
	p.inp.move = Vector2(0, 1)
	p.inp.sprint = true
	await ticks(30)
	p.inp.guard_held = true
	p.press("jump")
	await ticks(2)
	p.inp.move = Vector2.ZERO
	p.inp.sprint = false
	var f1: float = Vector2(p.velocity.x, p.velocity.z).length()
	await secs(1.0)
	var f2: float = Vector2(p.velocity.x, p.velocity.z).length()
	check("on flat ground the surf slows down", p.state == "surf" and f2 < f1 - 0.8, "%.1f -> %.1f m/s" % [f1, f2])
	p.inp.guard_held = false
	# friction by surface, and rain makes it slicker
	var sn: float = await surf_run("snow", 1.0)
	var sn_life: float = 100.0 - pl().shield_life
	var gr: float = await surf_run("grass", 1.0)
	var rk: float = await surf_run("rock", 1.0)
	var rk_life: float = 100.0 - pl().shield_life
	check("snow is faster than grass, grass faster than rock", sn > gr + 0.3 and gr > rk + 0.3, "snow %.1f, grass %.1f, rock %.1f m/s" % [sn, gr, rk])
	check("rock wears the shield, snow doesn't", rk_life > 1.0 and sn_life < 0.5, "rock -%.1f, snow -%.1f" % [rk_life, sn_life])
	var wet: float = await surf_run("grass", 1.0, true)
	check("rain makes the surf slicker", wet > gr + 0.2, "%.1f vs %.1f m/s" % [wet, gr])
	WeatherService.apply("clear")
	# the shield gives out: tumble and a knock
	await surf_run("rock", 0.2)
	p = pl()
	p.shield_life = 0.5
	var hp0: float = p.hp
	await secs(0.6)
	check("a worn-out shield breaks: tumble + damage", not p.has_shield and p.state in ["tumble", "locomote"] and p.hp < hp0 and not p.rig.shield.visible, p.state)
	p.inp.guard_held = false
	await secs(1.0)

# ---------------------------------------------------------------- bow

func park_knight(at: Vector3) -> CharacterBody3D:
	var k: CharacterBody3D = world.knight
	k.global_position = at
	k.dummy = true
	k.brain_state = "battle"
	k.awareness = 1.0
	k.hp = 500.0
	k.max_hp = 500.0
	k.yaw = PI
	return k

func shoot(at: Vector3, kind: String = "arrow", hold_f: int = 40) -> void:
	var p: CharacterBody3D = pl()
	p.aiming = true
	p.arrow_type = kind
	p.aim_override = at
	p.inp.attack_held = true
	p.press("attack")
	await ticks(hold_f)
	p.inp.attack_held = false
	await ticks(2)
	p.aim_override = Vector3.INF

func bow_tests() -> void:
	await fresh()
	var p: CharacterBody3D = pl()
	place(Vector3(0, 0.1, 10), 0.0)
	var k: CharacterBody3D = park_knight(Vector3(0, 0.1, -20))
	await secs(0.6)
	p.aiming = true
	await ticks(3)
	check("aiming the bow puts the sword away and shows the bow", p.rig.sheathed and p.bow_node.visible)
	var h0: float = k.hp
	var arrows0: int = InventoryService.count("arrow")
	await shoot(k.global_position + Vector3.UP * 1.0)
	await secs(1.2)
	var body: float = h0 - k.hp
	check("a full draw drops onto a target 30 m away", body > 0.0 and InventoryService.count("arrow") == arrows0 - 1, "-%.0f" % body)
	h0 = k.hp
	await shoot(k.global_position + Vector3.UP * 1.68)
	await secs(1.2)
	var head: float = h0 - k.hp
	check("headshots do double", absf(head - body * 2.0) < 0.5, "head %.0f vs body %.0f" % [head, body])
	await shot("tr_04_bow")
	p.aiming = false
	# aerial slow-mo: aim mid-air
	await fresh()
	p = pl()
	place(world.DIVE_TOWER + Vector3(0.8, 14.1, 0), -PI * 0.5)
	world.camera.cam_yaw = -PI * 0.5
	await ticks(6)
	p.inp.move = Vector2(0, -1)
	for i in 120:
		await ticks(1)
		if not p.is_on_floor() and p.height_above_ground() > 6.0:
			break
	p.inp.move = Vector2.ZERO
	p.aiming = true
	p.inp.attack_held = true
	p.press("attack")
	await ticks(4)
	var slow: bool = TimeDilation.active()
	var st0: float = StaminaPool.value
	await ticks(30)
	var used: float = st0 - StaminaPool.value
	p.inp.attack_held = false
	await ticks(3)
	check("aiming in mid-air slows time and drains stamina", slow and used > 3.0 and not TimeDilation.active(), "-%.1f stamina" % used)
	p.aiming = false
	await secs(3.0)
	# ember arrows light grass, and fizzle in the rain
	for rain: bool in [false, true]:
		await fresh()
		p = pl()
		WeatherService.apply("rain" if rain else "clear", Vector3(0.1, 0, 0))
		var f: Node3D = world.field
		f.fuel.fill(1.0)
		f.state.fill(0)
		place(f.global_position + Vector3(-14, 0.1, 0), -PI * 0.5)
		world.camera.cam_yaw = -PI * 0.5
		await ticks(6)
		var fz: Array = [false]
		p.arrow_fired.connect(func(a: Node3D) -> void: fz[0] = bool(a.fire) and not bool(a.lit), CONNECT_ONE_SHOT)
		await shoot(f.global_position + Vector3(-2, 0.05, 0), "fire_arrow")
		await secs(1.0)
		var burning: int = ChemistryService.burning_count()
		if not rain:
			check("an Ember Arrow sets the grass alight", burning > 0, "%d cells" % burning)
		else:
			check("in rain an Ember Arrow fizzles out", fz[0] and burning == 0)
		WeatherService.apply("clear")
		p.aiming = false
