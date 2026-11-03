extends Node
## Combat checks in the arena (feel, moveset, enemy brain, group). Prints "CB PASS/FAIL ..."
## and "CB RESULT n/m".
## Run: godot --path . res://scenes/systems/cc_combat_arena.tscn -- --combat-test --quit-after-test

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
	print("CB ", "PASS " if ok else "FAIL ", name, "  ", info)

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

func knight() -> CharacterBody3D:
	return arena.enemies[0]

## Fresh round 1 with the knight as a still training dummy (or awake if dummy = false).
func reset(dummy: bool = true, knight_at: Vector3 = Vector3(0, 0.1, -1.6), player_at: Vector3 = Vector3.ZERO) -> void:
	arena.start_round(1)
	await ticks(2)
	var k: CharacterBody3D = knight()
	k.route = []
	k.global_position = knight_at
	k.yaw = PI      # facing +z (toward the player's side)
	k.set_meta("dummy", dummy)
	if dummy:
		k.brain_state = "battle"
		k.awareness = 1.0
		k.dummy = true
	pl().global_position = player_at
	pl().yaw = 0.0
	arena.camera.cam_yaw = 0.0
	StaminaPool.refill()
	await ticks(6)

func swing_and_record(id: String) -> Array:
	var p: CharacterBody3D = pl()
	var live: Array = []
	p.start_move(id)
	var guard: int = 0
	while p.state == id and guard < 200:
		await ticks(1)
		live.append(p.hitbox.live)
		guard += 1
	return live

func run() -> void:
	await ticks(10)
	await feel_tests()
	await moveset_tests()
	await enemy_tests()
	await group_tests()
	var ok: int = 0
	for r: bool in results:
		if r:
			ok += 1
	print("CB RESULT %d/%d %s" % [ok, results.size(), "PASS" if ok == results.size() else "FAIL"])
	TimeDilation.release()
	if "--quit-after-test" in OS.get_cmdline_user_args():
		get_tree().quit(0 if ok == results.size() else 1)

# ---------------------------------------------------------------- P0 feel

func feel_tests() -> void:
	# whiff: knight out of reach
	await reset(true, Vector3(0, 0.1, -5.0))
	var k: CharacterBody3D = knight()
	var hp0: float = k.hp
	var live: Array = await swing_and_record("light1")
	var on: int = live.count(true)
	var first_on: int = live.find(true)
	var m: Resource = pl().moves.light1
	check("hitbox is live only on the active frames", on >= m.active_f - 1 and on <= m.active_f + 1 and absi(first_on - m.startup_f) <= 1, "on %d frames from frame %d (active %d from %d)" % [on, first_on, m.active_f, m.startup_f])
	check("a whiff can't hit", k.hp == hp0)
	# moving into the blade after it's gone still can't hit
	pl().start_move("light1")
	await ticks(m.startup_f + m.active_f + 3)
	k.global_position = pl().global_position + pl().forward() * 1.4
	await ticks(m.recovery_f)
	check("walking into the recovery frames does no damage", k.hp == hp0)
	# a real hit: both freeze, spark and sound on the same frame
	await reset(true)
	k = knight()
	hp0 = k.hp
	var frozen: Array = [false, false, 0.0]
	pl().impact.connect(func(t: Node3D, _i: Dictionary) -> void:
		frozen[0] = pl().hitstop_left > 0.0 and t.hitstop_left > 0.0
		frozen[2] = pl().playback.get_current_play_position(), CONNECT_ONE_SHOT)
	pl().start_move("light1")
	await ticks(m.startup_f + 2)
	var li: Dictionary = pl().last_impact
	check("a hit lands in reach", k.hp < hp0 and not li.is_empty(), "%.0f -> %.0f" % [hp0, k.hp])
	check("hitstop freezes attacker and victim", frozen[0])
	check("spark and sound on the impact frame", li.get("spark_frame", -1) == li.get("frame", -2) and li.get("sound_frame", -1) == li.get("frame", -2))
	await ticks(2)
	check("the clip holds still during hitstop", absf(pl().playback.get_current_play_position() - float(frozen[2])) < 0.0001 and pl().hitstop_left > 0.0)
	var light_shake: float = CombatFx.shakes.back()
	await ticks(40)
	# heavy
	await reset(true)
	pl().charge_f = 40.0
	pl().start_move("heavy")
	await ticks(pl().moves.heavy.startup_f + 3)
	var heavy_shake: float = CombatFx.shakes.back()
	check("camera shake is bigger on a heavy", heavy_shake > light_shake * 1.8, "light %.2f, heavy %.2f" % [light_shake, heavy_shake])
	check("heavy hitstop is longer", int(pl().last_impact.get("hitstop", 0)) > int(m.hitstop_f), "%d vs %d frames" % [int(pl().last_impact.get("hitstop", 0)), m.hitstop_f])
	await ticks(60)
	# input buffer: a press in the last 8 frames of recovery chains; an earlier one doesn't
	await reset(true, Vector3(0, 0.1, -6))
	pl().start_move("light1")
	await ticks(m.total_f() - 5)
	pl().press("attack")
	await ticks(8)
	check("ATTACK in the last 8 f of recovery chains", pl().state == "light2", pl().state)
	await ticks(60)
	pl().start_move("light1")
	await ticks(m.startup_f + 2)
	pl().press("attack")
	await ticks(m.total_f())
	check("an early press is not buffered (no mashing)", pl().state == "locomote", pl().state)
	# lock-on keeps the target centred
	await reset(true, Vector3(0, 0.1, -6))
	pl().press("lock")
	await ticks(3)
	check("LOCK picks the knight", pl().lock_target == knight())
	for i in 40:
		knight().global_position.x += 0.1
		await ticks(1)
	await ticks(10)
	var off: float = arena.camera.target_off_center_deg()
	check("lock-on keeps the target centred", off < 4.0, "%.1f deg off centre" % off)
	await shot("cb_01_lockon")
	# attack assist turns to the locked target
	pl().yaw = 1.2
	pl().start_move("light1")
	var to: Vector3 = knight().global_position - pl().global_position
	var err: float = rad_to_deg(absf(angle_difference(pl().yaw, atan2(-to.x, -to.z))))
	check("attacks turn to the locked target", err < 1.0)
	pl().press("lock")
	await ticks(40)

# ---------------------------------------------------------------- P0 moveset

func moveset_tests() -> void:
	await reset(true)
	var k: CharacterBody3D = knight()
	var dmg: Array = []
	var last: float = k.hp
	pl().start_move("light1")
	for step in 3:
		var mv: Resource = pl().cur_move
		while pl().state_f < mv.total_f() - 4 and pl().state != "locomote":
			await ticks(1)
		dmg.append(last - k.hp)
		last = k.hp
		pl().press("attack")
		await ticks(6)
	check("3-hit string runs light1 -> light2 -> light3", dmg.size() == 3 and dmg[0] > 0 and dmg[1] > 0 and dmg[2] > 0, str(dmg))
	check("the last hit is the strongest", dmg[2] > dmg[0] * 1.4, str(dmg))
	await ticks(60)
	# charge: hold, release spends stamina
	await reset(true, Vector3(0, 0.1, -6))
	StaminaPool.refill()
	pl().inp.attack_held = true
	await ticks(int(pl().tuning.hold_to_charge_f) + 4)
	check("holding ATTACK charges", pl().state == "heavy_charge", pl().state)
	await ticks(30)
	var st0: float = StaminaPool.value
	pl().inp.attack_held = false
	await ticks(2)
	check("release swings the heavy and uses stamina", pl().state == "heavy" and StaminaPool.value <= st0 - 24.0, "stamina %.0f -> %.0f" % [st0, StaminaPool.value])
	await ticks(80)
	StaminaPool.refill()
	pl().inp.attack_held = true
	await ticks(int(pl().tuning.hold_to_charge_f) + 10)
	var st1: float = StaminaPool.value
	pl().inp.move = Vector2(0, 1)
	pl().press("dodge")
	await ticks(2)
	pl().inp.move = Vector2.ZERO
	check("a dodge cancels the charge (only the dodge cost)", pl().state.begins_with("dodge") and StaminaPool.value > st1 - 20.0, "%s, stamina %.0f -> %.0f" % [pl().state, st1, StaminaPool.value])
	pl().inp.attack_held = false
	await ticks(40)
	# guard and parry
	var p: CharacterBody3D = pl()
	p.inp.guard_held = true
	await ticks(3)
	p.guard_press_f = p.frames - 30.0
	var hp0: float = p.hp
	var r: String = p.take_hit({"damage": 20.0, "plane": "horizontal", "from": p.global_position + p.forward() * 2.0, "attacker": knight()})
	check("guard cuts damage", r == "guard" and absf((hp0 - p.hp) - 5.0) < 0.01, "%s, -%.1f" % [r, hp0 - p.hp])
	await ticks(20)
	p.go("guard")
	p.guard_press_f = p.frames - 6.0
	r = p.take_hit({"damage": 20.0, "plane": "horizontal", "from": p.global_position + p.forward() * 2.0, "attacker": knight()})
	check("guard pressed 6 f before the hit parries", r == "parry" and knight().state == "stun", "%s, knight %s" % [r, knight().state])
	await ticks(30)
	p.go("guard")
	p.guard_press_f = p.frames - 14.0
	r = p.take_hit({"damage": 20.0, "plane": "horizontal", "from": p.global_position + p.forward() * 2.0, "attacker": knight()})
	check("14 f early is just a block", r == "guard", r)
	p.inp.guard_held = false
	await ticks(20)
	# dodge directions
	p.dodge_kind = "side"
	p.go("dodge_side")
	await ticks(2)
	var a1: String = p.take_hit({"damage": 10.0, "plane": "vertical", "from": p.global_position + p.forward()})
	var a2: String = p.take_hit({"damage": 10.0, "plane": "horizontal", "from": p.global_position + p.forward()})
	check("side hop beats an overhead, not a sweep", a1 == "dodge" and a2 == "hit", "%s / %s" % [a1, a2])
	await ticks(30)
	p.dodge_kind = "back"
	p.go("dodge_back")
	await ticks(2)
	var b1: String = p.take_hit({"damage": 10.0, "plane": "horizontal", "from": p.global_position + p.forward()})
	var b2: String = p.take_hit({"damage": 10.0, "plane": "vertical", "from": p.global_position + p.forward()})
	check("backflip beats a sweep, not an overhead", b1 == "dodge" and b2 == "hit", "%s / %s" % [b1, b2])
	await ticks(30)

# ---------------------------------------------------------------- P1 enemy brain

func enemy_tests() -> void:
	# crouch-sneak up behind a standing knight
	await reset(false, Vector3(0, 0.1, -4), Vector3(0, 0.1, 6))
	var k: CharacterBody3D = knight()
	k.yaw = 0.0          # facing -z, away from the player
	var p: CharacterBody3D = pl()
	p.inp.crouch = true
	var noticed: bool = false
	for i in 600:
		var to: Vector3 = k.global_position + Vector3(0, 0, 1.6) - p.global_position
		to.y = 0.0
		if to.length() < 0.15:
			break
		p.inp.move = Vector2(0, -1) * clampf(to.length(), 0.3, 1.0) if to.z < 0 else Vector2.ZERO
		await ticks(1)
		if k.brain_state != "roam" or k.awareness > 0.25:
			noticed = true
	p.inp.move = Vector2.ZERO
	var d: float = Vector2(k.global_position.x - p.global_position.x, k.global_position.z - p.global_position.z).length()
	check("crouch-sneaking reaches backstab range unseen", d < 1.9 and not noticed, "%.2f m, %s, awareness %.2f" % [d, k.brain_state, k.awareness])
	await shot("cb_02_sneak")
	var hp0: float = k.hp
	p.yaw = 0.0
	p.start_move("light1")
	await ticks(p.moves.light1.startup_f + 4)
	check("a sneak strike does big damage", hp0 - k.hp >= p.moves.light1.damage * 5.0, "-%.0f" % (hp0 - k.hp))
	p.inp.crouch = false
	await ticks(30)
	# sprint noise
	await reset(false, Vector3(0, 0.1, -4), Vector3(0, 0.1, 3.5))
	k = knight()
	k.yaw = 0.0
	p = pl()
	p.inp.sprint = true
	var heard: bool = false
	for i in 120:
		await ticks(1)
		if k.brain_state != "roam":
			heard = true
			break
	p.inp.sprint = false
	check("sprint noise alerts it", heard, k.brain_state)
	# lose sight -> back to roam
	await reset(false, Vector3(0, 0.1, -4), Vector3(0, 0.1, 0))
	k = knight()
	k.profile = k.profile.duplicate()
	k.profile.forget_time_s = 2.0
	k.alert(pl().global_position)
	await ticks(10)
	check("in battle", k.brain_state == "battle")
	pl().inp.crouch = true
	pl().global_position = Vector3(-11, 0.1, -9.5)   # behind a pillar, far away, quiet
	k.global_position = Vector3(-11, 0.1, -1.0)
	var path: Array = []
	for i in 600:
		await ticks(1)
		if path.is_empty() or path.back() != k.brain_state:
			path.append(k.brain_state)
		if k.brain_state == "roam":
			break
	pl().inp.crouch = false
	check("loses you, searches, goes back to roam", k.brain_state == "roam" and "forget" in path, str(path))
	# readable wind-up + perfect dodge -> slow-mo -> flurry for each weapon class
	for wc: String in ["one_hand", "two_hand", "spear"]:  # CC defaults 7 / 4 / 8
		await reset(true, Vector3(0, 0.1, -2.0))
		k = knight()
		p = pl()
		p.set_weapon({"one_hand": "ironwood_blade", "two_hand": "warden_greatblade", "spear": "thornreach_spear"}[wc])
		p.lock_target = k
		k.hp = 500.0
		k.max_hp = 500.0
		k.plane_i = 1    # "vertical": beaten by a side hop
		k.start_attack()
		var tele: Array = []
		var live_in_windup: bool = false
		for i in 60:
			await ticks(1)
			if k.telegraphing():
				tele.append(k.flash)
				if k.hitbox.live:
					live_in_windup = true
			if k.just_avoid_open():
				break
		if wc == "one_hand":
			check("wind-up is readable (>= 18 f, glowing, no live hitbox)", k.profile.windup_f >= 18 and tele.size() >= 10 and tele.max() > 0.3 and not live_in_windup, "%d f, glow %.2f" % [k.profile.windup_f, tele.max()])
			await shot("cb_03_windup")
		p.inp.move = Vector2(1, 0)
		p.press("dodge")
		await ticks(2)
		p.inp.move = Vector2.ZERO
		var perfect: bool = TimeDilation.active() and p.flurry_target == k
		p.press("attack")
		var guard: int = 0
		while p.state != "flurry" and guard < 30:
			await ticks(1)
			guard += 1
		while p.state == "flurry" and guard < 400:
			await ticks(1)
			guard += 1
		var want: int = int(p.weapon.flurry_hits)
		check("perfect dodge -> slow-mo -> flurry (%s: %d hits)" % [wc, want], perfect and p.flurry_hits_landed == want, "perfect %s, %d hits" % [str(perfect), p.flurry_hits_landed])
		TimeDilation.release()
		await ticks(20)
	# wrong direction: no slow-mo
	await reset(true, Vector3(0, 0.1, -2.0))
	k = knight()
	k.plane_i = 1
	k.start_attack()
	for i in 60:
		await ticks(1)
		if k.just_avoid_open():
			break
	pl().inp.move = Vector2.ZERO
	pl().lock_target = k
	pl().press("dodge")      # backflip vs an overhead
	await ticks(2)
	check("a wrong-way dodge gets no slow-mo", not TimeDilation.active())
	TimeDilation.release()
	await ticks(40)

# ---------------------------------------------------------------- P2 group

func group_tests() -> void:
	arena.start_round(2)
	await ticks(4)
	var p: CharacterBody3D = pl()
	p.global_position = Vector3(0, 0.1, 2)
	arena.tactics.max_attackers = 0      # hold the ring: nobody steps in to attack
	for e: Node in arena.enemies:
		e.alert(p.global_position)
	await ticks(240)
	var melee: Array = arena.enemies.filter(func(e: Node) -> bool: return not e.profile.is_archer)
	var archer: Node3D = arena.enemies.filter(func(e: Node) -> bool: return e.profile.is_archer)[0]
	var min_pair: float = 99.0
	for i in melee.size():
		for j in range(i + 1, melee.size()):
			min_pair = minf(min_pair, (melee[i] as Node3D).global_position.distance_to((melee[j] as Node3D).global_position))
	var ring: Array = []
	for e: Node3D in melee:
		ring.append(snappedf(Vector2(e.global_position.x - p.global_position.x, e.global_position.z - p.global_position.z).length(), 0.1))
	check("3 melee foes ring the player without stacking", min_pair > 1.5, "closest pair %.1f m, ring %s" % [min_pair, str(ring)])
	await shot("cb_04_ring")
	var ad: float = Vector2(archer.global_position.x - p.global_position.x, archer.global_position.z - p.global_position.z).length()
	check("the archer keeps its distance", ad >= archer.profile.archer_min_m - 1.0 and ad <= archer.profile.archer_max_m + 3.0, "%.1f m" % ad)
	check("the archer's wind-up is longer", archer.profile.windup_f > (melee[0] as Node3D).profile.windup_f, "%d vs %d f" % [archer.profile.windup_f, (melee[0] as Node3D).profile.windup_f])
	# kill one: the others don't get pushed in
	var victim: CharacterBody3D = melee[0]
	victim.take_hit({"damage": 999.0, "plane": "horizontal", "from": p.global_position, "attacker": p})
	var closest: float = 99.0
	for i in 120:
		await ticks(1)
		for e: Node3D in melee:
			if e != victim and e.alive():
				closest = minf(closest, Vector2(e.global_position.x - p.global_position.x, e.global_position.z - p.global_position.z).length())
	check("killing one doesn't push the others onto you", closest >= (melee[1] as Node3D).profile.keep_dist_m - 0.8, "closest %.1f m" % closest)
	# stagger lengths and interrupts
	var k: CharacterBody3D = melee[1]
	arena.tactics.max_attackers = 1
	k.start_attack()
	await ticks(4)
	k.take_hit({"damage": 1.0, "plane": "horizontal", "from": p.global_position, "attacker": p, "stagger_f": 12, "heavy": false})
	check("a light hit staggers 12 f and cancels its attack", k.state == "stagger" and k.attack_f < 0.0 and absf(k.stagger_left - 12.0) < 0.01)
	await ticks(30)
	k.start_attack()
	await ticks(4)
	k.take_hit({"damage": 1.0, "plane": "horizontal", "from": p.global_position, "attacker": p, "stagger_f": 30, "heavy": true})
	check("a heavy hit staggers 30 f", k.state == "stagger" and absf(k.stagger_left - 30.0) < 0.01)
	await ticks(60)
	# the archer actually shoots
	arena.tactics.max_attackers = 1
	var hp0: float = p.hp
	for i in 400:
		await ticks(1)
		if p.hp < hp0:
			break
	check("round 2 fights back (player takes damage)", p.hp < hp0, "%.0f -> %.0f" % [hp0, p.hp])
	await shot("cb_05_round2")
