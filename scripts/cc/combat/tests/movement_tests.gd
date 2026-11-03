extends Node
## Movement + camera + weapon-class checks in the arena. Prints "MV PASS/FAIL ..." and
## "MV RESULT n/m". Run: godot --path . res://scenes/systems/cc_combat_arena.tscn -- --move-test --quit-after-test

var arena: Node3D
var results: Array[bool] = []
var shots: String = ""

func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.trim_prefix("--shots=")
	run.call_deferred()

func check(name: String, ok: bool, info: String = "") -> void:
	results.append(ok)
	print("MV ", "PASS " if ok else "FAIL ", name, "  ", info)

func ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func shot(name: String) -> void:
	if shots.is_empty():
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [shots, name])

func pl() -> CharacterBody3D:
	return arena.player

func cam() -> Node3D:
	return arena.camera

## Fresh round; the knight is parked out of the way as a still dummy.
func reset(at: Vector3, yaw: float = 0.0, knight_at: Vector3 = Vector3(0, 0.1, -20)) -> void:
	arena.start_round(1)
	await ticks(2)
	var k: CharacterBody3D = arena.enemies[0]
	k.route = []
	k.dummy = true
	k.brain_state = "battle"
	k.awareness = 1.0
	k.global_position = knight_at
	pl().global_position = at
	pl().yaw = yaw
	cam().cam_yaw = yaw
	WeatherService.set_weather(false)
	StaminaPool.refill()
	await ticks(8)

func solid_at(p: Vector3) -> bool:
	var q: PhysicsPointQueryParameters3D = PhysicsPointQueryParameters3D.new()
	q.position = p
	q.collision_mask = 1
	return not pl().get_world_3d().direct_space_state.intersect_point(q).is_empty()

func run() -> void:
	await ticks(10)
	await camera_tests()
	await jump_tests()
	await climb_tests()
	await weapon_tests()
	var ok: int = 0
	for r: bool in results:
		if r:
			ok += 1
	print("MV RESULT %d/%d %s" % [ok, results.size(), "PASS" if ok == results.size() else "FAIL"])
	WeatherService.set_weather(false)
	TimeDilation.release()
	if "--quit-after-test" in OS.get_cmdline_user_args():
		get_tree().quit(0 if ok == results.size() else 1)

# ---------------------------------------------------------------- camera

func camera_tests() -> void:
	# a pillar right behind the player: the arm shortens, the camera stays out of it
	await reset(Vector3(-11, 0.1, -7.4), 0.0)
	await ticks(30)
	var c: Camera3D = cam().camera
	check("camera never sits inside geometry", not solid_at(c.global_position) and cam().arm_length() < 2.5, "arm %.2f m (wants %.1f)" % [cam().arm_length(), float(cam().cur.dist)])
	await shot("mv_01_pillar")
	# lock-on while strafing
	await reset(Vector3(0, 0.1, 2), 0.0, Vector3(0, 0.1, -4))
	pl().press("lock")
	await ticks(4)
	var worst: float = 0.0
	var all_on: bool = true
	pl().inp.move = Vector2(1, 0)
	for i in 90:
		await ticks(1)
		if i % 10 == 9:
			worst = maxf(worst, cam().target_off_center_deg())
			all_on = all_on and c.is_position_in_frustum(arena.enemies[0].global_position + Vector3.UP)
	pl().inp.move = Vector2.ZERO
	check("lock-on keeps the target on screen while strafing", all_on and worst < 8.0, "worst %.1f deg off centre" % worst)
	pl().press("lock")
	await ticks(20)
	# explore -> ADS within 0.25 s, back restores the shoulder
	pl().press("aim")
	await ticks(15)
	var ads: Dictionary = cam().cur
	check("Explore -> ADS within 0.25 s", cam().mode == "ads" and absf(float(ads.dist) - 1.6) < 0.12 and absf(float(ads.fov) - 42.0) < 1.5, "dist %.2f, fov %.1f" % [float(ads.dist), float(ads.fov)])
	pl().press("aim")
	await ticks(15)
	check("ADS -> Explore restores the shoulder", cam().mode == "explore" and absf(float(cam().cur.shoulder) - 0.45) < 0.04, "shoulder %.2f" % float(cam().cur.shoulder))
	# glide uses a longer arm and still takes look input
	await reset(Vector3(17, 12.2, -10), 0.0)
	pl().inp.move = Vector2(0, -1)
	var opened: bool = false
	for i in 120:
		await ticks(1)
		if not pl().is_on_floor() and pl().vy < -4.0 and pl().height_above_ground() > 3.0 and not opened:
			pl().press("jump")
			opened = true
		if pl().state == "glide" and i > 30:
			break
	pl().inp.move = Vector2.ZERO
	await ticks(20)
	var y0: float = cam().cam_yaw
	cam().look_drag = Vector2(60, 0)
	await ticks(2)
	check("glide: longer arm, look still works", pl().state == "glide" and float(cam().cur.dist) > 5.0 and absf(angle_difference(cam().cam_yaw, y0)) > 0.2, "%s, dist %.1f" % [pl().state, float(cam().cur.dist)])
	await shot("mv_02_glide")
	await ticks(200)
	pl().riding = true
	await ticks(25)
	check("ride mode uses the long arm", cam().mode == "ride" and float(cam().cur.dist) > 6.0)
	pl().riding = false

# ---------------------------------------------------------------- jump, hops, fall, mantle

func jump_arc(run_first: bool) -> Array:
	await reset(Vector3(0, 0.1, 10), 0.0)
	var p: CharacterBody3D = pl()
	if run_first:
		p.inp.move = Vector2(0, -1)
		await ticks(40)
	var start: Vector3 = p.global_position
	p.press("jump")
	var peak: float = 0.0
	var left: bool = false
	for i in 200:
		await ticks(1)
		peak = maxf(peak, p.global_position.y - start.y)
		if not p.is_on_floor():
			left = true
		elif left:
			break
	p.inp.move = Vector2.ZERO
	var dist: float = Vector2(p.global_position.x - start.x, p.global_position.z - start.z).length()
	return [peak, dist]

func jump_tests() -> void:
	var stand: Array = await jump_arc(false)
	var run_j: Array = await jump_arc(true)
	check("standing jump peaks near 2 m", absf(float(stand[0]) - 2.0) < 0.25, "%.2f m" % float(stand[0]))
	check("running jump is higher and longer", float(run_j[0]) > float(stand[0]) + 0.2 and float(run_j[1]) > float(stand[1]) + 3.0, "peak %.2f vs %.2f, length %.1f vs %.1f m" % [float(run_j[0]), float(stand[0]), float(run_j[1]), float(stand[1])])
	# coyote time: a jump a few frames after walking off the ledge still counts
	for late: int in [4, 14]:
		await reset(Vector3(14, 1.2, 16), PI)
		var p: CharacterBody3D = pl()
		p.inp.move = Vector2(0, -1)
		var off_f: int = -1
		var jumped_ok: bool = false
		for i in 120:
			await ticks(1)
			if off_f < 0 and not p.is_on_floor():
				off_f = i
			if off_f >= 0 and i - off_f == late:
				p.press("jump")
			# only a jump that starts in mid-air counts (a buffered jump on landing is not coyote)
			if off_f >= 0 and i - off_f > late and not p.is_on_floor() and p.jumped and p.vy > 0.0:
				jumped_ok = true
				break
			if off_f >= 0 and (i - off_f > late + 3 or (i - off_f > late and p.is_on_floor())):
				break
		p.inp.move = Vector2.ZERO
		if late == 4:
			check("coyote: jump 4 f after leaving the edge works", jumped_ok)
		else:
			check("no jump 14 f after leaving the edge", not jumped_ok)
	# jump buffer: pressed just before landing, it jumps on touchdown
	await reset(Vector3(0, 3.0, 8), 0.0)
	var p2: CharacterBody3D = pl()
	var pressed: bool = false
	var hopped: bool = false
	for i in 120:
		await ticks(1)
		if not pressed and not p2.is_on_floor() and p2.vy < 0.0 and p2.height_above_ground() < 0.55:
			p2.press("jump")
			pressed = true
		if pressed and p2.jumped and p2.vy > 2.0:
			hopped = true
			break
	check("jump buffer: a press just before landing jumps", pressed and hopped)
	# hops only while locked on
	await reset(Vector3(0, 0.1, 2), 0.0, Vector3(0, 0.1, -3))
	pl().inp.move = Vector2(1, 0)
	pl().press("dodge")
	await ticks(2)
	var unlocked: String = pl().state
	await ticks(30)
	pl().lock_target = arena.enemies[0]
	pl().inp.move = Vector2(1, 0)
	pl().press("dodge")
	await ticks(2)
	pl().inp.move = Vector2.ZERO
	check("side hop only while locked on (roll otherwise)", unlocked == "dodge_roll" and pl().state == "dodge_side", "%s / %s" % [unlocked, pl().state])
	await ticks(30)
	# hard landing from 12 m
	for glide: bool in [false, true]:
		await reset(Vector3(0, 12.3, 6), 0.0)
		var p3: CharacterBody3D = pl()
		var got: Array = [-1.0, -1.0]
		p3.landed.connect(func(h: float, d: float) -> void:
			got[0] = h
			got[1] = d, CONNECT_ONE_SHOT)
		var hp0: float = p3.hp
		for i in 600:
			await ticks(1)
			if glide and i == 20:
				p3.press("jump")
			if float(got[0]) >= 0.0:
				break
		var want: float = float(p3.jt.fall_damage_frac(float(got[0]))) * p3.max_hp
		if not glide:
			check("hard landing: curve damage + stun + no-climb lockout", float(got[0]) > 10.0 and absf(float(got[1]) - want) < 0.5 and p3.state == "land_stun" and p3.no_climb > 0.0, "fell %.1f m, -%.0f hp (curve %.0f), %s" % [float(got[0]), hp0 - p3.hp, want, p3.state])
		else:
			check("an open glider cancels fall damage", float(got[1]) == 0.0 and p3.hp == hp0, "-%.0f hp" % (hp0 - p3.hp))
		await ticks(40)
	# mantle a waist-high ledge without pressing jump
	await reset(Vector3(14, 0.1, 19.6), 0.0)
	var p4: CharacterBody3D = pl()
	p4.inp.move = Vector2(0, -1)
	var saw: bool = false
	for i in 120:
		await ticks(1)
		if p4.state == "mantle":
			saw = true
		if saw and p4.state == "locomote":
			break
	p4.inp.move = Vector2.ZERO
	await ticks(5)
	check("mantle: walk into a waist-high ledge and vault it", saw and p4.global_position.y > 0.9 and not p4.jumped, "y %.2f" % p4.global_position.y)
	await shot("mv_03_mantle")

# ---------------------------------------------------------------- climbing

func climb_tests() -> void:
	await reset(Vector3(17, 0.1, -7.2), 0.0)
	var p: CharacterBody3D = pl()
	p.inp.move = Vector2(0, -1)
	await ticks(20)
	check("pushing into the tower starts a climb", p.state == "climb", p.state)
	var s0: float = StaminaPool.value
	await ticks(120)
	var used: float = s0 - StaminaPool.value
	check("dry climb drains about 12 / s", absf(used - 24.0) < 5.0, "%.1f in 2 s" % used)
	await shot("mv_04_climb")
	StaminaPool.value = 30.0
	var fell_off: bool = false
	for i in 300:
		await ticks(1)
		if p.state != "climb":
			fell_off = true
			break
	p.inp.move = Vector2.ZERO
	check("empty stamina lets go of the wall", fell_off and StaminaPool.is_exhausted and p.no_climb > 0.0, p.state)
	await ticks(120)
	# rain slip (short stretch for the test), still slips with a climbing-speed buff
	await reset(Vector3(17, 0.1, -7.2), 0.0)
	p = pl()
	p.ct = p.ct.duplicate()
	p.ct.slip_after_meters = 2.0
	p.ct.slip_random_extra_meters = 1.0
	p.climb_speed_mult = 1.5
	WeatherService.set_weather(true)
	var slipped: Array = [false]
	p.slipped.connect(func() -> void: slipped[0] = true, CONNECT_ONE_SHOT)
	p.inp.move = Vector2(0, -1)
	var st_before: float = 0.0
	for i in 300:
		await ticks(1)
		if p.state == "climb" and st_before == 0.0:
			st_before = StaminaPool.value
		if slipped[0]:
			break
	p.inp.move = Vector2.ZERO
	check("rain: a slip after the climb stretch (buff doesn't stop it)", slipped[0] and p.slips >= 1, "slips %d" % p.slips)
	WeatherService.set_weather(false)
	p.climb_speed_mult = 1.0
	await ticks(30)
	# glide drains stamina and folds when empty
	await reset(Vector3(17, 12.2, -10), 0.0)
	p = pl()
	p.inp.move = Vector2(0, -1)
	var opened: bool = false
	for i in 200:
		await ticks(1)
		if not p.is_on_floor() and p.vy < -4.0 and p.height_above_ground() > 3.0 and not opened:
			p.press("jump")
			opened = true
		if p.state == "glide":
			break
	StaminaPool.value = 8.0
	var folded: bool = false
	for i in 180:
		await ticks(1)
		if p.state != "glide":
			folded = true
			break
	p.inp.move = Vector2.ZERO
	check("glider drains stamina and folds when empty", opened and folded)
	await ticks(200)

# ---------------------------------------------------------------- weapon classes

func weapon_tests() -> void:
	await reset(Vector3(0, 0.1, 6), 0.0)
	var p: CharacterBody3D = pl()
	var looks: Dictionary = {}
	for w: String in ["ironwood_blade", "warden_greatblade", "thornreach_spear"]:
		p.set_weapon_by_id(w)
		p.start_move(str(p.weapon.string_moves[0]))
		await ticks(int(p.cur_move.startup_f) + 1)
		looks[w] = [p.rig.blade_len, p.rig.shield.visible, p.pose().get("R_Upperarm", Vector3.ZERO)]
		await ticks(60)
	var a1: Vector3 = looks.ironwood_blade[2]
	var a2: Vector3 = looks.warden_greatblade[2]
	var a3: Vector3 = looks.thornreach_spear[2]
	var lens_ok: bool = looks.ironwood_blade[0] < looks.warden_greatblade[0] and looks.warden_greatblade[0] < looks.thornreach_spear[0]
	var shield_ok: bool = looks.ironwood_blade[1] and not looks.warden_greatblade[1] and not looks.thornreach_spear[1]
	var poses_ok: bool = rad_to_deg(a1.angle_to(a2)) > 15.0 and rad_to_deg(a1.angle_to(a3)) > 15.0 and rad_to_deg(a2.angle_to(a3)) > 15.0
	check("each class reads differently (length, shield, swing pose)", lens_ok and shield_ok and poses_ok, "blades %.2f / %.2f / %.2f" % [looks.ironwood_blade[0], looks.warden_greatblade[0], looks.thornreach_spear[0]])
	# string lengths
	var lens: Array = []
	for w2: String in ["ironwood_blade", "warden_greatblade", "thornreach_spear"]:
		p.set_weapon_by_id(w2)
		var n: int = 1
		var id: String = str(p.weapon.string_moves[0])
		while str(p.moves[id].chain_to) != "":
			id = str(p.moves[id].chain_to)
			n += 1
		lens.append(n)
	check("strings: one-hand 3, two-hand 3, spear 5", lens == [3, 3, 5], str(lens))
	# one-hand: charge drains, empty stamina fires the spin by itself
	p.set_weapon_by_id("ironwood_blade")
	StaminaPool.refill()
	StaminaPool.value = 6.0
	p.inp.attack_held = true
	var fired: bool = false
	for i in 200:
		await ticks(1)
		if p.state == "heavy":
			fired = true
			break
	p.inp.attack_held = false
	check("one-hand: charge drains, empty stamina auto-fires the spin", fired)
	await ticks(80)
	# two-hand: hold = keep spinning (drains), release = slam
	p.set_weapon_by_id("warden_greatblade")
	StaminaPool.refill()
	p.inp.attack_held = true
	var spins: int = 0
	var last: String = ""
	for i in int(p.tuning.hold_to_charge_f) + 80:
		await ticks(1)
		if p.state == "th_spin" and last != "th_spin":
			spins += 1
		if p.state == "th_spin" and p.state_f < 1.0:
			spins += 0
		last = p.state
	var st_after: float = StaminaPool.value
	p.inp.attack_held = false
	var slam: bool = false
	for i in 60:
		await ticks(1)
		if p.state == "th_slam":
			slam = true
			break
	check("two-hand: hold keeps spinning (drains), release slams", spins >= 1 and st_after < 95.0 and slam, "stamina %.0f" % st_after)
	await ticks(80)
	# spear: hold = rapid thrusts; running dry stops cleanly
	p.set_weapon_by_id("thornreach_spear")
	StaminaPool.refill()
	StaminaPool.value = 12.0
	p.inp.attack_held = true
	var thrusts: int = 0
	var prev_f: float = 999.0
	var ended: bool = false
	for i in 300:
		await ticks(1)
		if p.state == "sp_rapid" and p.state_f < prev_f:
			thrusts += 1
		prev_f = p.state_f if p.state == "sp_rapid" else 999.0
		if thrusts > 0 and p.state == "locomote":
			ended = true
			break
	p.inp.attack_held = false
	check("spear: rapid thrusts, then stops cleanly when stamina runs out", thrusts >= 2 and ended, "%d thrusts" % thrusts)
