extends Node
## Checks for the P0 survival systems on the test map. Prints "CC PASS/FAIL ..." and
## "CC RESULT n/m".

var map: Node3D
var results: Array[bool] = []
var shots: String = ""

func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.trim_prefix("--shots=")
	run.call_deferred()

func check(name: String, ok: bool, info: String = "") -> void:
	results.append(ok)
	print("CC ", "PASS " if ok else "FAIL ", name, "  ", info)

func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func shot(name: String) -> void:
	if shots.is_empty():
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [shots, name])

func look(from: Vector3, to: Vector3) -> void:
	map.camera.global_position = from
	map.camera.look_at(to)

func run() -> void:
	await wait(0.5)
	InventoryService.clear()
	WorldClock.paused = true
	WorldClock.set_time(1, 10.0)
	await shot("cc_00_overview")
	await test_trees()
	test_cooking()
	await test_hunting()
	await test_bike()
	var ok: int = 0
	for r: bool in results:
		if r:
			ok += 1
	print("CC RESULT %d/%d %s" % [ok, results.size(), "PASS" if ok == results.size() else "FAIL"])
	if "--quit-after-test" in OS.get_cmdline_user_args():
		get_tree().quit(0 if ok == results.size() else 1)

# ---------------------------------------------------------------- P0-A trees

func test_trees() -> void:
	var axe: Resource = load("res://data/cc/tools/axe.tres")
	var sword: Resource = load("res://data/cc/tools/sword.tres")
	var club: Resource = load("res://data/cc/tools/club.tres")
	var oak: StaticBody3D = map.trees[0]
	var from: Vector3 = oak.global_position + Vector3(0, 1, 1.2)
	var wood0: int = InventoryService.count("oak_wood")
	oak.hit(axe, from)
	oak.hit(axe, from)
	check("oak stands after 2 axe hits", not oak.is_felled, "hp %.0f" % oak.hp)
	oak.hit(axe, from)
	check("axe fells the oak on the 3rd hit", oak.is_felled)
	check("stump stays, trunk gone", oak.stump_mesh.visible and not oak.trunk_mesh.visible)
	var gained: int = InventoryService.count("oak_wood") - wood0
	check("wood stack increases", gained >= 2 and gained <= 3, "+%d oak wood" % gained)
	var lg: RigidBody3D = oak.log_body
	check("a physics log spawns", lg != null and is_instance_valid(lg))
	var p0: Vector3 = lg.global_position
	look(oak.global_position + Vector3(5, 3, 6), oak.global_position + Vector3(0, 1, -1))
	await wait(2.5)
	var tilt: float = rad_to_deg(lg.global_transform.basis.y.angle_to(Vector3.UP))
	var moved: float = Vector2(lg.global_position.x - p0.x, lg.global_position.z - p0.z).length()
	check("the log tips over and rolls away", tilt > 50.0 and moved > 0.4, "tilt %.0f deg, moved %.1f m" % [tilt, moved])
	await shot("cc_01_felled")
	var pine: StaticBody3D = map.trees[1]
	var hp0: float = pine.hp
	var bounced: Array[bool] = [false]
	pine.bounced.connect(func(_k: String) -> void: bounced[0] = true)
	var d_club: float = pine.hit(club, pine.global_position + Vector3(1, 1, 0))
	check("a blunt club can't cut a tree", d_club == 0.0 and pine.hp == hp0 and bounced[0])
	var d_sword: float = pine.hit(sword, pine.global_position + Vector3(1, 1, 0))
	var d_axe: float = pine.chop_damage(axe)
	check("a sword cuts, but much weaker than an axe", d_sword > 0.0 and d_sword < d_axe * 0.6, "sword %.1f vs axe %.1f" % [d_sword, d_axe])

# ---------------------------------------------------------------- P0-B cooking

func test_cooking() -> void:
	var C: Node = CookingService
	C.crit_override = 0
	check("1 ingredient makes a meal", not C.cook(["field_mushroom"]).is_empty())
	check("5 ingredients make one meal", not C.cook(["field_mushroom", "sunpear", "doe_venison", "hare_leg", "field_mushroom"]).is_empty())
	check("6 ingredients are refused", C.cook(["sunpear", "sunpear", "sunpear", "sunpear", "sunpear", "sunpear"]).is_empty())
	var three: Array = ["field_mushroom", "field_mushroom", "field_mushroom"]
	var raw: float = C.raw_hearts(three)
	var m: Dictionary = C.cook(three)
	check("a pot meal heals about 2x raw", absf(float(m.hearts) - raw * 2.0) < 0.3, "raw %.1f -> pot %.1f" % [raw, float(m.hearts)])
	var buff: Dictionary = C.cook(["emberroot", "emberroot", "emberroot"])
	check("matching tags give a timed buff", buff.buff == "might" and int(buff.tier) >= 1 and float(buff.duration) > 0.0, "%s T%d %ds (%s)" % [buff.buff, buff.tier, int(buff.duration), buff.name])
	var mixed: Dictionary = C.cook(["emberroot", "ironcap", "field_mushroom"])
	check("mixed tags fail (no buff)", mixed.buff == "" and mixed.name == "Murky Stew", str(mixed.name))
	var base: Dictionary = C.cook(["ironcap", "ironcap", "saltbloom"])
	C.crit_override = 1
	var crit: Dictionary = C.cook(["ironcap", "ironcap", "saltbloom"])
	var better: bool = float(crit.hearts) > float(base.hearts) or int(crit.tier) > int(base.tier) or float(crit.duration) > float(base.duration)
	check("a crit adds heal, tier or time", crit.crit and better, "bonus: %s" % str(crit.get("crit_bonus", "")))
	C.crit_override = 0
	WorldClock.set_time(6, 23.75)
	var not_omen: Dictionary = C.cook(["ironcap"])
	WorldClock.set_time(7, 23.75)
	var omen: Dictionary = C.cook(["ironcap"])
	WorldClock.set_time(8, 0.1)
	var omen2: Dictionary = C.cook(["ironcap"])
	WorldClock.set_time(1, 10.0)
	check("an Omen Night forces a crit", omen.crit and omen2.crit and not not_omen.crit)
	var roast: Dictionary = C.cook(["boar_flank"], "roast")
	var roast_herb: Dictionary = C.cook(["emberroot"], "roast")
	check("roasting heals 1.5x and gives no buff", absf(float(roast.hearts) - 4.5) < 0.01 and roast.buff == "" and roast_herb.buff == "", "%s %.2f" % [roast.name, float(roast.hearts)])
	InventoryService.add("field_mushroom", 3)
	var pm: Dictionary = map.pot.cook(three)
	check("the pot cooks from the inventory", not pm.is_empty() and InventoryService.count("field_mushroom") == 0 and InventoryService.meals.size() == 1)
	check("can't cook what you don't have", map.pot.cook(three).is_empty())
	InventoryService.add("hare_leg", 1)
	var fm: Dictionary = map.campfire.cook(["hare_leg"])
	check("a bare campfire roasts", fm.get("method", "") == "roast")
	C.crit_override = -1

# ---------------------------------------------------------------- P0-C hunting

func test_hunting() -> void:
	var doe: CharacterBody3D = map.animals[0]
	var doe_pos: Vector3 = doe.global_position
	map.hunter_noise = 1.0
	map.hunter.global_position = doe_pos + Vector3(10, 0, 0)
	var fled_at: float = -1.0
	for i in 60:
		var to: Vector3 = doe.global_position - map.hunter.global_position
		to.y = 0.0
		if to.length() > 1.0:
			map.hunter.global_position += to.normalized() * 3.0 * 0.05
		await get_tree().physics_frame
		await get_tree().physics_frame
		await get_tree().physics_frame
		if doe.state == "flee":
			fled_at = i * 0.05
			break
	check("a loud approach makes it flee", doe.state == "flee", "fled after %.1f s" % fled_at)
	var d0: float = doe.global_position.distance_to(map.hunter.global_position)
	await wait(1.2)
	var d1: float = doe.global_position.distance_to(map.hunter.global_position)
	check("it runs away", d1 > d0 + 2.0, "%.1f m -> %.1f m" % [d0, d1])
	# stealth: sneak up behind the second doe, quietly
	var doe2: CharacterBody3D = map.animals[1]
	map.hunter_noise = 0.05
	map.hunter.global_position = doe2.global_position + Vector3(0, 0, 40)
	await wait(0.2)
	doe2.awareness = 0.0   # it heard the chase next door; start this one calm
	var behind: Vector3 = Vector3(sin(doe2.yaw), 0, cos(doe2.yaw)) * 2.5
	map.hunter.global_position = doe2.global_position + behind
	doe2.set_state("graze", 30.0)
	await wait(1.0)
	check("a quiet hunter behind it stays unnoticed", doe2.unaware(), "awareness %.2f" % doe2.awareness)
	var ven0: int = InventoryService.count("doe_venison")
	var got: Array = [{}, false]
	doe2.died.connect(func(_s: String, drops: Dictionary, stealth: bool) -> void:
		got[0] = drops
		got[1] = stealth)
	doe2.take_hit(8.0, "head", map.hunter.global_position)
	check("a stealth head strike kills it", not doe2.alive() and got[1] == true)
	var drops: Dictionary = got[0]
	var ven_got: int = InventoryService.count("doe_venison") - ven0
	check("drops resolve in the inventory", ven_got > 0 and ven_got == int(drops.get("doe_venison", 0)), str(drops))
	# headshot bonus on an alert animal (no unaware bonus)
	var boar: CharacterBody3D = map.animals[2]
	boar.awareness = 1.0
	boar.set_state("alert", 0.0)
	var body_d: float = boar.take_hit(4.0, "body", boar.global_position + Vector3(2, 0, 0))
	var head_d: float = boar.take_hit(4.0, "head", boar.global_position + Vector3(2, 0, 0))
	check("headshots do double damage", absf(head_d - body_d * 2.0) < 0.01, "body %.0f, head %.0f" % [body_d, head_d])
	# stealth kills roll extra drops on average
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = 5
	var loud_total: int = 0
	var quiet_total: int = 0
	for i in 200:
		loud_total += int(map.animals[0].roll_drops("mossback_doe", false, r).get("doe_venison", 0))
		quiet_total += int(map.animals[0].roll_drops("mossback_doe", true, r).get("doe_venison", 0))
	check("stealth kills drop more", quiet_total > loud_total * 1.5, "%d vs %d venison over 200 kills" % [quiet_total, loud_total])
	var bad: Array = ["korok", "bokoblin", "moblin", "lynel", "hylian", "hyrule", "sheikah", "zelda", "rupee", "zonai", "goron", "rito", "gerudo", "keese", "chuchu", "hinox"]
	var names: String = (JSON.stringify(map.animals[0].species_db()) + JSON.stringify(InventoryService.defs) + JSON.stringify(CookingService.ingredients)).to_lower()
	var hits: Array = []
	for w: String in bad:
		if names.contains(w):
			hits.append(w)
	check("no borrowed creature or item names", hits.is_empty(), str(hits))
	look(map.animals[1].global_position + Vector3(4, 3, 5), map.animals[1].global_position)
	await shot("cc_02_hunt")

# ---------------------------------------------------------------- P0-D bike

func test_bike() -> void:
	var b: CharacterBody3D = map.bike
	var t: Resource = b.tuning
	b.fuel = 100.0
	var secs: float = 0.0
	while b.fuel > 0.0 and secs < 2000.0:
		b.fuel_tick(0.1, 1.0, true)
		secs += 0.1
	check("full tank lasts about tank_seconds", absf(secs - float(t.tank_seconds)) <= float(t.tank_seconds) * 0.01, "%.1f s (tank %.0f s)" % [secs, float(t.tank_seconds)])
	b.fuel = 50.0
	var air: float = b.fuel_tick(5.0, 1.0, false)
	var idle: float = b.fuel_tick(5.0, 0.0, true)
	check("no fuel burnt in the air or off the throttle", air == 0.0 and idle == 0.0 and b.fuel == 50.0)
	# real driving on the pad
	look(b.global_position + Vector3(6, 4, 8), b.global_position)
	b.fuel = 0.0
	b.speed = 0.0
	b.throttle = 1.0
	await wait(1.2)
	check("empty tank = no acceleration", b.speed < 0.3, "speed %.2f m/s" % b.speed)
	b.fuel = 60.0
	b.yaw = PI * 0.5
	b.travel_yaw = b.yaw
	await wait(1.0)
	check("with fuel it drives", b.speed > 5.0, "speed %.1f m/s" % b.speed)
	await shot("cc_03_bike")
	b.throttle = 0.0
	b.brake = 1.0
	await wait(1.0)
	b.brake = 0.0
	check("brakes stop it", b.speed < 0.5)
	# refuel
	InventoryService.add("oak_wood", 11)
	var wood0: int = InventoryService.count("oak_wood")
	b.fuel = 70.0
	var added: float = b.refuel(["oak_wood", "oak_wood", "oak_wood", "oak_wood", "oak_wood"])
	check("refuel caps at 100%", b.fuel == 100.0 and absf(added - 30.0) < 0.01 and InventoryService.count("oak_wood") == wood0 - 5, "added %.0f%%" % added)
	b.fuel = 10.0
	var six: float = b.refuel(["oak_wood", "oak_wood", "oak_wood", "oak_wood", "oak_wood", "oak_wood"])
	check("more than 5 refuel items are refused", six == 0.0 and b.fuel == 10.0 and InventoryService.count("oak_wood") == wood0 - 5)
	check("non-fuel items are refused", b.refuel(["sunpear"]) == 0.0)
	# drift gates (on the logic alone)
	b.drifting = false
	b.drift = true
	b.steer = 1.0
	b.speed = float(t.drift_enter_speed) - 1.0
	check("no drift below the enter speed", not b.drift_tick(true))
	b.speed = float(t.drift_enter_speed) + 2.0
	check("drift starts above the enter speed", b.drift_tick(true))
	b.speed = float(t.drift_exit_speed) + 0.5
	check("drift holds above the exit speed", b.drift_tick(true))
	b.speed = float(t.drift_exit_speed) - 0.1
	check("drift ends below the exit speed", not b.drift_tick(true))
	b.drift = false
	b.steer = 0.0
	# wheelie lasts its time
	b.fuel = 100.0
	b.grounded_override = 1
	b.speed = 10.0
	b.throttle = 1.0
	b.wheelie = true
	var up: float = 0.0
	for i in 80:
		b.step(0.05)
		if b.wheelie_on():
			up += 0.05
	check("a wheelie lasts its set time", absf(up - float(t.wheelie_time)) < 0.11, "%.2f s" % up)
	b.wheelie = false
	b.throttle = 0.0
	b.grounded_override = -1
	# summon deny list
	var deny: Array = t.summon_deny_tags
	var inside: String = b.summon_block_reason(get_tree(), map.sanctum.global_position + Vector3(1, 0, 1), deny)
	var outside: String = b.summon_block_reason(get_tree(), map.at(map.BIKE_PAD), deny)
	check("summon blocked inside the sanctum", inside == "sanctum")
	check("summon allowed on the bike pad", outside == "")
	look(Vector3(0, 30, 40), Vector3(0, 0, 0))
	await shot("cc_04_map")
