extends Node
## World chemistry / weather / powers / durability checks. Prints "WD PASS/FAIL ..." and
## "WD RESULT n/m". Run: godot --path . res://scenes/systems/cc_world_slice.tscn -- --world-test --quit-after-test

var world: Node3D
var results: Array[bool] = []
var shots: String = ""
const BANNED: Array[String] = ["korok", "sheikah", "hylia", "hyrule", "zelda", "zonai", "goron", "rito", "gerudo", "zora", "magnesis", "stasis", "cryonis", "remote bomb", "master cycle", "bokoblin", "moblin", "lynel", "guardian", "rupee", "ganon"]

func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.trim_prefix("--shots=")
	run.call_deferred()

func check(name: String, ok: bool, info: String = "") -> void:
	results.append(ok)
	print("WD ", "PASS " if ok else "FAIL ", name, "  ", info)

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
	await ticks(6)
	var f: Node3D = world.field
	f.fuel.fill(1.0)
	f.state.fill(0)
	f.dirty = true
	await ticks(4)

func place(p: Vector3, yaw: float = 0.0) -> void:
	pl().global_position = p
	pl().velocity = Vector3.ZERO
	pl().vy = 0.0
	pl().yaw = yaw
	world.camera.cam_yaw = yaw

func run() -> void:
	await ticks(10)
	var chem0: Resource = ChemistryService.tuning
	var ab0: Resource = AbilityService.tuning
	await chemistry_tests()
	await weather_tests()
	await ability_tests()
	await durability_tests()
	ChemistryService.tuning = chem0
	AbilityService.tuning = ab0
	var ok: int = 0
	for r: bool in results:
		if r:
			ok += 1
	print("WD RESULT %d/%d %s" % [ok, results.size(), "PASS" if ok == results.size() else "FAIL"])
	WeatherService.apply("clear")
	if "--quit-after-test" in OS.get_cmdline_user_args():
		get_tree().quit(0 if ok == results.size() else 1)

# ---------------------------------------------------------------- chemistry

func side_counts() -> Array:
	var f: Node3D = world.field
	var east: int = 0
	var west: int = 0
	for c in f.nx * f.nz:
		if f.state[c] != 0:
			var p: Vector3 = f.cell_center(c)
			if p.x > f.global_position.x + 0.6:
				east += 1
			elif p.x < f.global_position.x - 0.6:
				west += 1
	return [east, west]

func chemistry_tests() -> void:
	await fresh()
	WeatherService.apply("clear", Vector3(3, 0, 0))
	var f: Node3D = world.field
	var lit: int = ChemistryService.ignite_at(f.global_position, 0.6)
	await secs(3.0)
	var sc: Array = side_counts()
	check("fire lights the grass and spreads downwind", lit > 0 and int(sc[0]) > int(sc[1]) * 2 and int(sc[0]) >= 6, "east %d vs west %d cells" % [int(sc[0]), int(sc[1])])
	await shot("wd_01_fire")
	WeatherService.apply("rain")
	await secs(0.6)
	var burning_after_rain: int = ChemistryService.burning_count()
	var touched: int = f.nx * f.nz - f.count_state(0)
	await secs(2.0)
	var touched2: int = f.nx * f.nz - f.count_state(0)
	check("rain puts it out and stops the spread", burning_after_rain == 0 and touched2 <= touched and ChemistryService.ignite_at(f.global_position + Vector3(8, 0, 8), 1.0) == 0, "burning %d" % burning_after_rain)
	WeatherService.apply("clear", Vector3(0.1, 0, 0))
	# updraft: an open glider over the fire rises
	await fresh()
	WeatherService.apply("clear", Vector3(0.1, 0, 0))
	ChemistryService.ignite_at(f.global_position, 2.5)
	await secs(0.5)
	place(f.global_position + Vector3(0, 6, 0))
	pl().go("glide")
	var y0: float = pl().global_position.y
	await secs(0.8)
	check("a fire column lifts the glider", pl().state == "glide" and pl().global_position.y > y0 + 0.5, "%.1f -> %.1f m" % [y0, pl().global_position.y])
	pl().go("locomote")
	await secs(1.0)
	# lightning: metal draws a warned strike, wood is safe
	var fast: Resource = ChemistryService.tuning.duplicate()
	fast.lightning_interval_s = 1.0
	fast.lightning_warn_s = 0.8
	for gear: String in ["warden_greatblade", "ironwood_blade"]:
		await fresh()
		ChemistryService.tuning = fast
		place(Vector3(0, 0.1, 14))
		pl().set_weapon_by_id(gear)
		var hp0: float = pl().hp
		var warned_me: Array = [false]
		var cb: Callable = func(_at: Vector3, t: Node3D) -> void:
			if t == pl():
				warned_me[0] = true
		ChemistryService.lightning_warn.connect(cb)
		WeatherService.apply("thunder")
		var hit_at: float = -1.0
		var warn_at: float = -1.0
		for i in 240:
			await ticks(1)
			if warned_me[0] and warn_at < 0.0:
				warn_at = i / 60.0
			if pl().hp < hp0 and hit_at < 0.0:
				hit_at = i / 60.0
				break
		ChemistryService.lightning_warn.disconnect(cb)
		WeatherService.apply("clear")
		if gear == "warden_greatblade":
			check("storm + metal weapon: warning, then a strike", warn_at >= 0.0 and hit_at > warn_at + 0.5, "warn %.1f s, hit %.1f s" % [warn_at, hit_at])
			await shot("wd_02_lightning")
		else:
			check("wooden weapon: no strike on Lance", not warned_me[0] and pl().hp == hp0)
	ChemistryService.tuning = load("res://data/cc/chem/world_tuning.tres")
	# shock in water reaches much further
	await fresh()
	var k: CharacterBody3D = world.knight
	await secs(0.6)    # let him settle into the pond
	var wet: Vector3 = Vector3(k.global_position.x + 3.0, world.pond.surface_y(), k.global_position.z)
	var r_wet: float = ChemistryService.shock_radius(wet, 1.0)
	var r_dry: float = ChemistryService.shock_radius(Vector3(0, 0.1, 20), 1.0)
	var khp: float = k.hp
	ChemistryService.shock(wet, 1.0, 10.0)
	var hit_wet: bool = k.hp < khp
	k.global_position = Vector3(10, 0.1, 20)
	await ticks(3)
	khp = k.hp
	ChemistryService.shock(Vector3(13, 0.1, 20), 1.0, 10.0)
	check("a shock in water reaches 8x further", r_wet == 8.0 and r_dry == 1.0 and hit_wet and k.hp == khp, "wet %.0f m, dry %.0f m" % [r_wet, r_dry])
	var text: String = ""
	for d: String in ["res://data/cc/chem", "res://data/cc/weather", "res://data/cc/abilities"]:
		var da: DirAccess = DirAccess.open(d)
		for fn: String in da.get_files():
			text += FileAccess.get_file_as_string(d + "/" + fn).to_lower()
	var bad: Array = []
	for w: String in BANNED:
		if text.contains(w):
			bad.append(w)
	check("no borrowed names in chemistry / weather / power data", bad.is_empty(), str(bad))

# ---------------------------------------------------------------- weather

func weather_tests() -> void:
	await fresh()
	var storm: Resource = load("res://data/cc/weather/stormcoast.tres")
	var snow: Resource = load("res://data/cc/weather/frostpeak.tres")
	var old: Resource = WeatherService.climate
	var wet: int = 0
	var snowy: int = 0
	WeatherService.climate = storm
	for i in 400:
		WeatherService.roll()
		if WeatherService.is_precipitating:
			wet += 1
	WeatherService.climate = snow
	for i in 400:
		WeatherService.roll()
		if WeatherService.is_snowing:
			snowy += 1
	WeatherService.climate = old
	check("weather rolls follow the climate weights", absf(wet / 400.0 - 0.75) < 0.08 and absf(snowy / 400.0 - 0.6) < 0.08, "stormcoast wet %d%%, frostpeak snow %d%%" % [wet / 4, snowy / 4])
	WeatherService.apply("clear")
	# cold
	for resist: bool in [false, true]:
		await fresh()
		pl().cold_resist = resist
		place(world.SNOW + Vector3(0, 0.2, 0))
		await secs(0.3)
		var h0: int = world.cold_hits
		await secs(2.2)
		var got: int = world.cold_hits - h0
		if not resist:
			check("Frostpeak without cold resist: freezing damage", WeatherService.temperature() < 0.0 and got >= 2, "%d ticks at %d°C" % [got, int(WeatherService.temperature())])
			await shot("wd_03_snow")
		else:
			check("with cold resist: no freezing damage", got == 0)
	pl().cold_resist = false
	# wind pushes the glider
	var drift: Array = []
	for wx: float in [4.0, -4.0]:
		await fresh()
		WeatherService.apply("clear", Vector3(wx, 0, 0))
		place(Vector3(0, 14, 10))
		pl().go("glide")
		var x0: float = pl().global_position.x
		await secs(1.0)
		drift.append(pl().global_position.x - x0)
		pl().go("locomote")
		await secs(1.5)
	check("wind drifts the glider its way", float(drift[0]) > 0.8 and float(drift[1]) < -0.8, "%+.1f / %+.1f m" % [float(drift[0]), float(drift[1])])
	WeatherService.apply("clear", Vector3(3, 0, 0))

# ---------------------------------------------------------------- powers

func ability_tests() -> void:
	await fresh()
	var crate: RigidBody3D = world.metal_crate
	place(crate.global_position + Vector3(0, -0.5, 2.6), 0.0)
	await ticks(4)
	AbilityService.active = "orb_sphere"
	var r1: String = AbilityService.use(pl())
	await secs(0.6)
	var r2: String = AbilityService.use(pl())
	await ticks(3)
	var cv: float = crate.linear_velocity.length()
	var r3: String = AbilityService.use(pl())
	check("Blast Orb: place, then set off; the crate is thrown", r1 == "placed" and r2 == "detonated" and cv > 2.0, "crate %.1f m/s" % cv)
	check("sphere reloads (can't place right away)", r3 == "reloading")
	await secs(2.6)
	check("sphere ready again after 2.5 s", AbilityService.use(pl()) == "placed")
	AbilityService.use(pl())
	await ticks(5)
	AbilityService.active = "orb_cube"
	AbilityService.use(pl())
	await secs(0.3)
	AbilityService.use(pl())
	await secs(3.0)
	var cube_mid: String = AbilityService.use(pl())
	await secs(0.7)
	var cube_late: String = AbilityService.use(pl())
	check("cube reloads in 3.5 s", cube_mid == "reloading" and cube_late == "placed", "%s / %s" % [cube_mid, cube_late])
	AbilityService.use(pl())
	await ticks(5)
	# blast lights grass
	var hot: Resource = AbilityService.tuning.duplicate()
	hot.orb_fire_chance = 1.0
	AbilityService.tuning = hot
	await fresh()
	AbilityService.tuning = hot
	place(world.field.global_position + Vector3(0, 0.1, 3), 0.0)
	AbilityService.active = "orb_cube"
	AbilityService.use(pl())
	await secs(0.4)
	place(world.field.global_position + Vector3(0, 0.1, 9), 0.0)
	AbilityService.use(pl())
	await ticks(4)
	check("a blast lights the grass around it", ChemistryService.burning_count() > 0, "%d cells" % ChemistryService.burning_count())
	AbilityService.tuning = load("res://data/cc/abilities/ability_tuning.tres")
	WeatherService.apply("rain")
	await secs(1.0)
	WeatherService.apply("clear")
	# struck orb goes off
	await fresh()
	place(Vector3(0, 0.1, 10), 0.0)
	AbilityService.active = "orb_cube"
	AbilityService.use(pl())
	await secs(0.8)
	var b0: int = AbilityService.blasts
	pl().start_move("light1")
	await secs(0.5)
	check("striking an orb sets it off", AbilityService.blasts == b0 + 1)
	# frost pillar
	await fresh()
	place(world.POND + Vector3(0, 0, 7.5), 0.0)
	AbilityService.active = "frost_pillar"
	var pr: String = AbilityService.use(pl())
	await secs(0.5)
	check("Frost Pillar rises from the water ahead", pr == "pillar" and AbilityService.pillars.size() == 1)
	var pil: Node3D = AbilityService.pillars[0]
	var pp: Vector3 = pil.global_position
	place(Vector3(pp.x, 0.1, pp.z + 2.2), 0.0)
	pl().inp.move = Vector2(0, -1)
	await secs(1.2)
	pl().inp.move = Vector2.ZERO
	var gap: float = Vector2(pl().global_position.x - pp.x, pl().global_position.z - pp.z).length()
	check("the pillar blocks the way", gap > 0.8, "%.2f m from its centre" % gap)
	await shot("wd_04_pillar")
	place(world.POND + Vector3(0, 0, 7.5), 0.0)
	for i in 3:
		await secs(0.7)
		pl().yaw = 0.25 * (i + 1)
		AbilityService.use(pl())
	await secs(0.3)
	check("at most 3 pillars (the oldest breaks)", AbilityService.pillars.size() == 3)
	var target: Node3D = AbilityService.pillars[1]
	world.brazier.global_position = target.global_position + Vector3(1.3, -target.global_position.y, 0)
	var gone: bool = false
	for i in 900:
		await ticks(1)
		if not is_instance_valid(target):
			gone = true
			break
	check("fire next to a pillar melts it away", gone)
	world.brazier.global_position = world.BRAZIER
	var names: Array = (AbilityService.tuning.names as Dictionary).values()
	var bad: Array = []
	for n: String in names:
		for w: String in BANNED:
			if n.to_lower().contains(w):
				bad.append(n)
	check("power names are CC names", bad.is_empty() and "Frost Pillar" in names and "Blast Orb (Sphere)" in names, str(names))

# ---------------------------------------------------------------- durability and bags

func durability_tests() -> void:
	await fresh()
	var k: CharacterBody3D = world.knight
	place(Vector3(0, 0.1, 10), 0.0)
	k.global_position = Vector3(0, 0.1, 8.4)
	k.yaw = PI
	k.brain_state = "battle"
	k.awareness = 1.0
	k.hp = 500.0
	k.max_hp = 500.0
	await ticks(6)
	var p: CharacterBody3D = pl()
	p.equip_slot(0)
	InventoryService.weapons[0].life = 15.0
	check("under 20% life the durability bar flashes", world.hud.durability_flash())
	InventoryService.weapons[0].life = 30.0
	var h0: float = k.hp
	p.start_move("light1")
	await secs(0.6)
	var normal: float = h0 - k.hp
	InventoryService.weapons[0].life = 1.0
	var broke: Array = [""]
	p.weapon_broke.connect(func(id: String) -> void: broke[0] = id, CONNECT_ONE_SHOT)
	var n_before: int = InventoryService.weapons.size()
	h0 = k.hp
	p.start_move("light1")
	await secs(0.6)
	var last: float = h0 - k.hp
	check("the breaking hit does double damage", absf(last - normal * 2.0) < 0.5, "%.0f vs %.0f" % [last, normal])
	check("at 0 the weapon breaks and drops a stub", broke[0] != "" and InventoryService.weapons.size() == n_before - 1 and get_tree().get_nodes_in_group("cc_stub").size() >= 1, broke[0])
	await secs(0.5)
	# throw
	k.global_position = Vector3(0, 0.1, 6.0)
	await ticks(4)
	h0 = k.hp
	var n2: int = InventoryService.weapons.size()
	var base: float = float(p.moves[str(p.weapon.string_moves[0])].damage) * float(p.weapon.damage_mult)
	p.press("throw")
	await secs(0.8)
	check("a thrown weapon hits for double and is gone", absf((h0 - k.hp) - base * 2.0) < 0.5 and InventoryService.weapons.size() == n2 - 1, "-%.0f (base %.0f)" % [h0 - k.hp, base])
	# full bag: pickup blocked until swap
	await fresh()
	while not InventoryService.is_full("Melee"):
		InventoryService.add_weapon("ironwood_blade", 100.0)
	var size0: int = InventoryService.weapons.size()
	var pk: Dictionary = world.pickups[0]
	place((pk.node as Node3D).global_position + Vector3(0, -0.2, 0.3), 0.0)
	await ticks(6)
	check("a full melee bag blocks the pickup (asks to swap)", world.swap_offer == "warden_greatblade" and InventoryService.weapons.size() == size0 and world.pickups.size() == 1)
	world.do_swap()
	await ticks(3)
	var has: bool = false
	for w: Dictionary in InventoryService.weapons:
		if str(w.id) == "warden_greatblade":
			has = true
	check("swap takes it and drops the old one", has and InventoryService.weapons.size() == size0 and world.pickups.size() == 1)
	# enemy drops resolve to CC items
	var kk: CharacterBody3D = world.knight
	var iron0: int = InventoryService.count("briar_iron")
	kk.take_hit({"damage": 9999.0, "plane": "horizontal", "from": kk.global_position + Vector3(1, 0, 0), "attacker": pl()})
	var ok_ids: bool = true
	var tbl: Dictionary = kk.WildDrops.drop_db()
	for t: String in ["briar_knight", "briar_archer"]:
		for e: Dictionary in tbl[t].entries:
			if not InventoryService.defs.has(str(e.item)):
				ok_ids = false
	check("enemy drops are CC items and land in the bag", InventoryService.count("briar_iron") > iron0 and ok_ids)
