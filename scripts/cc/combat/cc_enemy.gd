extends "res://scripts/cc/combat/combat_actor.gd"
## CC melee / archer enemy.
## Perception: sight cone + line of sight, hearing (player noise x range), proximity.
## Roam -> Notice (white ?) -> Investigate -> Battle (red !) -> lose you -> Forget -> Roam.
## Battle: hold a ring slot around the player (GroupTactics), take a turn to attack:
## telegraph wind-up (glow) -> active (hitbox + just-avoid window) -> recover.
## Light hits stagger 12 f, heavy 30 f, interrupting a normal attack. A parry stuns.

const Arrow = preload("res://scripts/cc/combat/cc_arrow.gd")

var team: String = "enemy"
var profile: Resource
var brain_state: String = "roam"   # roam | notice | investigate | battle | forget | stunned | dead
var awareness: float = 0.0
var last_known: Vector3
var lost_t: float = 0.0
var notice_t: float = 0.0
var home: Vector3
var route: Array = []
var route_i: int = 0
var cd: float = 0.0
var plane_i: int = 0
var attack_f: float = -1.0          # frames into the current attack (-1 = not attacking)
var slot: Vector3 = Vector3.ZERO
var marker: Label3D
var player: Node3D
var sees_player: bool = false
var hears_player: bool = false
var shots: int = 0
var dummy: bool = false            # training dummy: stands still (tests), still reacts to hits

func _ready() -> void:
	if profile == null:
		profile = load("res://data/cc/combat/briar_knight.tres")
	hp = float(profile.hp)
	max_hp = hp
	var total: int = int(profile.windup_f + profile.active_f + profile.recover_f)
	var clips: Dictionary = {}
	for pl: String in ["horizontal", "vertical", "thrust"]:
		clips["attack_" + pl] = {"frames": total, "hit": [profile.windup_f, profile.windup_f + profile.active_f],
			"lunge_m": 0.0 if profile.is_archer else 0.7, "lunge_f": profile.windup_f + profile.active_f}
	clips["stagger"] = {"frames": 30}
	clips["stun"] = {"frames": 60, "loop": true}
	clips["dead"] = {"frames": 60}
	setup_body(profile.model, float(profile.height), Color("ff7a5a") if not profile.is_archer else Color("ffd27a"), clips)
	home = global_position
	last_known = home
	add_to_group("cc_enemy")
	marker = Label3D.new()
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.font_size = 96
	marker.outline_size = 18
	marker.pixel_size = 0.004
	marker.position.y = float(profile.height) + 0.6
	marker.no_depth_test = true
	add_child(marker)

func find_player() -> Node3D:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("cc_player") as Node3D
	return player

func tactics() -> Node:
	return get_tree().get_first_node_in_group("cc_tactics")

# ---------------------------------------------------------------- senses

func sense(cdt: float) -> void:
	var p: Node3D = find_player()
	sees_player = false
	hears_player = false
	if p == null or not p.alive():
		return
	var to: Vector3 = p.global_position - global_position
	to.y = 0.0
	var d: float = to.length()
	var half: float = deg_to_rad(float(profile.sight_half_deg))
	if d < float(profile.sight_m) and (d < 0.1 or forward().angle_to(to.normalized()) < half):
		# crouching in the open still gets seen, just from not as far
		var range_k: float = 0.6 if p.crouched else 1.0
		if d < float(profile.sight_m) * range_k and line_of_sight(p):
			sees_player = true
	var noise: float = float(p.noise())
	if d < float(profile.hearing_m) * noise:
		hears_player = true
	if d < float(profile.proximity_m):
		awareness = 1.0
		last_known = p.global_position
		return
	if sees_player:
		var close: float = 1.0 + 2.0 * clampf(1.0 - d / float(profile.sight_m), 0.0, 1.0)
		awareness = minf(1.0, awareness + cdt / float(profile.notice_time_s) * close)
		last_known = p.global_position
	elif hears_player:
		awareness = minf(1.0, awareness + cdt * noise * 0.9)
		last_known = p.global_position
	elif brain_state != "battle":
		awareness = maxf(0.0, awareness - cdt * 0.3)

func line_of_sight(p: Node3D) -> bool:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.6, p.global_position + Vector3.UP * 1.2, 1)
	q.exclude = [get_rid(), p.get_rid()]
	return space.intersect_ray(q).is_empty()

## Somebody else spotted the player: join the fight.
func alert(at: Vector3) -> void:
	if not alive() or brain_state == "battle":
		return
	last_known = at
	awareness = 1.0
	enter_battle(false)

func enter_battle(call_allies: bool = true) -> void:
	brain_state = "battle"
	lost_t = 0.0
	cd = randf_range(0.4, 1.0)
	if call_allies:
		for e: Node in get_tree().get_nodes_in_group("cc_enemy"):
			var n: Node3D = e as Node3D
			if n != self and n.global_position.distance_to(global_position) < float(profile.alert_range_m):
				n.alert(last_known)

# ---------------------------------------------------------------- brain

func brain(cdt: float) -> Vector3:
	if not alive():
		marker.text = ""
		return Vector3.ZERO
	sense(cdt)
	cd = maxf(0.0, cd - cdt)
	if state == "stagger" or state == "stun":
		stagger_left -= cdt * 60.0
		if stagger_left <= 0.0:
			go("locomote")
		return Vector3.ZERO
	if attack_f >= 0.0:
		return attack_tick(cdt)
	if dummy:
		return Vector3.ZERO
	var want: Vector3 = Vector3.ZERO
	match brain_state:
		"roam":
			want = roam()
			if awareness >= 1.0:
				enter_battle()
			elif awareness > 0.25:
				brain_state = "notice"
				notice_t = 0.0
		"notice":
			notice_t += cdt
			face_to(last_known, 0.15)
			if awareness >= 1.0:
				enter_battle()
			elif notice_t > 0.7:
				brain_state = "investigate"
				notice_t = 0.0
			elif awareness <= 0.05:
				brain_state = "roam"
		"investigate":
			notice_t += cdt
			want = walk_to(last_known, float(profile.walk_speed))
			if awareness >= 1.0:
				enter_battle()
			elif notice_t > 6.0 or (global_position.distance_to(last_known) < 1.2 and awareness < 0.1):
				brain_state = "roam"
		"battle":
			want = battle(cdt)
		"forget":
			want = walk_to(last_known, float(profile.walk_speed))
			notice_t += cdt
			if awareness >= 1.0 and sees_player:
				enter_battle()
			elif notice_t > 2.5 or global_position.distance_to(last_known) < 1.2:
				brain_state = "roam"
				awareness = 0.0
	marker.text = {"notice": "?", "investigate": "?", "battle": "!", "forget": "?"}.get(brain_state, "")
	marker.modulate = Color("ff4040") if brain_state == "battle" else Color("ffffff")
	return want

func roam() -> Vector3:
	if route.is_empty():
		return Vector3.ZERO
	var tgt: Vector3 = route[route_i]
	if Vector2(tgt.x - global_position.x, tgt.z - global_position.z).length() < 0.6:
		route_i = (route_i + 1) % route.size()
	return walk_to(tgt, float(profile.walk_speed))

func walk_to(p: Vector3, speed: float) -> Vector3:
	var to: Vector3 = p - global_position
	to.y = 0.0
	if to.length() < 0.3:
		return Vector3.ZERO
	face_to(p, 0.15)
	return to.normalized() * speed * clampf(to.length(), 0.0, 1.0)

func face_to(p: Vector3, rate: float) -> void:
	var to: Vector3 = p - global_position
	to.y = 0.0
	if to.length() > 0.05:
		yaw = lerp_angle(yaw, atan2(-to.x, -to.z), rate)

func battle(cdt: float) -> Vector3:
	var p: Node3D = find_player()
	if p == null or not p.alive():
		brain_state = "roam"
		return Vector3.ZERO
	if sees_player or hears_player:
		lost_t = 0.0
	else:
		lost_t += cdt
		if lost_t > float(profile.forget_time_s):
			brain_state = "forget"
			notice_t = 0.0
			awareness = 0.5
			return Vector3.ZERO
	if not sees_player and not hears_player:
		# lost track of you: head for where you were last seen (no cheating)
		return walk_to(last_known, float(profile.run_speed)) + separation()
	var tac: Node = tactics()
	slot = tac.slot_for(self) if tac != null else p.global_position
	var to_p: Vector3 = p.global_position - global_position
	to_p.y = 0.0
	var d: float = to_p.length()
	var want: Vector3 = Vector3.ZERO
	face_to(p.global_position, 0.2)
	var my_turn: bool = tac == null or tac.may_attack(self)
	if profile.is_archer:
		want = steer_to(slot, float(profile.run_speed))
		if d < float(profile.archer_min_m):
			want = -to_p.normalized() * float(profile.run_speed)
		if cd <= 0.0 and d <= float(profile.attack_range_m) and sees_player and my_turn:
			start_attack()
	elif my_turn and cd <= 0.0:
		if d > float(profile.attack_range_m):
			want = to_p.normalized() * float(profile.run_speed)
		else:
			start_attack()
	else:
		want = steer_to(slot, float(profile.run_speed))
	return want + separation()

func steer_to(p: Vector3, speed: float) -> Vector3:
	var to: Vector3 = p - global_position
	to.y = 0.0
	if to.length() < 0.25:
		return Vector3.ZERO
	return to.normalized() * speed * clampf(to.length() / 1.5, 0.25, 1.0)

## Push away from allies standing too close (no stacking).
func separation() -> Vector3:
	var push: Vector3 = Vector3.ZERO
	for e: Node in get_tree().get_nodes_in_group("cc_enemy"):
		var n: Node3D = e as Node3D
		if n == self or not n.alive():
			continue
		var away: Vector3 = global_position - n.global_position
		away.y = 0.0
		var d: float = away.length()
		if d < 1.8 and d > 0.01:
			push += away.normalized() * (1.8 - d) * 3.0
	return push

# ---------------------------------------------------------------- attacking

func attack_plane() -> String:
	var pl: Array[String] = profile.planes
	return pl[plane_i % pl.size()]

func start_attack() -> void:
	attack_f = 0.0
	var tac: Node = tactics()
	if tac != null:
		tac.claim(self)
	cur_move = null
	if not profile.is_archer:
		cur_move = load("res://data/cc/combat/moves/light1.tres")
	cur_info = {"damage": float(profile.damage), "plane": attack_plane(), "hitstop_f": 6, "shake": 0.35,
		"stagger_f": 0, "knockback": 2.5, "heavy": false, "id": "enemy"}
	go("attack_" + attack_plane())

## Frames into the attack: [0, windup) telegraph, [windup, windup + active) live, then recover.
func attack_tick(_cdt: float) -> Vector3:
	attack_f = state_f
	var w: float = float(profile.windup_f)
	var p: Node3D = find_player()
	if attack_f < w * 0.66 and p != null:
		face_to(p.global_position, 0.2)    # tracks you early in the wind-up, then commits
	# telegraph glow builds through the wind-up
	if telegraphing():
		flash = maxf(flash, 0.35 + 0.65 * attack_f / w)
		flash_color = Color("ff8a3a")
	if profile.is_archer and attack_f >= w and shots == 0:
		shoot()
	var total: float = float(profile.windup_f + profile.active_f + profile.recover_f)
	if attack_f >= total:
		end_attack()
	return Vector3.ZERO

func telegraphing() -> bool:
	return attack_f >= 0.0 and attack_f < float(profile.windup_f)

## The just-avoid window: the last just_avoid_f frames of the wind-up through the active frames.
func just_avoid_open() -> bool:
	if attack_f < 0.0 or state.begins_with("attack") == false:
		return false
	var w: float = float(profile.windup_f)
	return attack_f >= w - float(profile.just_avoid_f) and attack_f < w + float(profile.active_f)

func hit_start() -> void:
	if profile.is_archer:
		return
	cur_move = load("res://data/cc/combat/moves/light1.tres")
	hitbox.configure(1.6, 1.0, height * 0.6)
	hitbox.open()

func shoot() -> void:
	shots += 1
	var p: Node3D = find_player()
	if p == null:
		return
	var a: Area3D = Arrow.new()
	a.shooter = self
	a.damage = float(profile.damage)
	get_parent().add_child(a)
	var from: Vector3 = global_position + Vector3.UP * 1.4 + forward() * 0.6
	var aim: Vector3 = p.global_position + Vector3.UP * 1.1 + p.velocity * 0.25
	a.launch(from, (aim - from).normalized() * float(profile.arrow_speed))

func end_attack() -> void:
	attack_f = -1.0
	shots = 0
	hitbox.close()
	plane_i += 1
	cd = float(profile.attack_cooldown_s) * randf_range(0.8, 1.3)
	var tac: Node = tactics()
	if tac != null:
		tac.release(self)
	go("locomote")

func interrupt() -> void:
	if attack_f >= 0.0:
		attack_f = -1.0
		shots = 0
		hitbox.close()
		var tac: Node = tactics()
		if tac != null:
			tac.release(self)

func stun(f: float) -> void:
	interrupt()
	stagger_left = f
	go("stun")

# ---------------------------------------------------------------- getting hit

func unaware() -> bool:
	return brain_state in ["roam", "notice", "investigate"] and awareness < 1.0

func take_hit(info: Dictionary) -> String:
	if not alive():
		return "none"
	var dmg: float = float(info.damage)
	var sneak: bool = unaware()
	if sneak:
		dmg *= float(tuning.sneak_mult)
	apply_damage(dmg, info.get("from", global_position), float(info.get("knockback", 2.0)))
	if not alive():
		interrupt()
		marker.text = ""
		var tac: Node = tactics()
		if tac != null:
			tac.release(self)
		took.emit(info, "hit")
		return "hit"
	# a hit always starts a fight
	last_known = (info.get("attacker") as Node3D).global_position if info.get("attacker") else global_position
	if brain_state != "battle":
		enter_battle()
	var st: float = float(tuning.stagger_heavy_f) if info.get("heavy", false) or int(info.get("stagger_f", 0)) >= 30 else float(tuning.stagger_light_f)
	interrupt()
	stagger_left = st
	go("stagger")
	took.emit(info, "hit")
	return "hit"

# ---------------------------------------------------------------- look

func pose() -> Dictionary:
	var t: float = frames / 60.0
	if state == "dead":
		return P.dead()
	if state == "stagger":
		return P.stagger(t)
	if state == "stun":
		return P.stagger(t * 0.5)
	if attack_f >= 0.0:
		var w: float = float(profile.windup_f)
		if attack_f < w:
			return P.windup(clampf(attack_f / w, 0.0, 1.0))
		return P.strike(clampf((attack_f - w) / maxf(float(profile.active_f) * 2.0, 1.0), 0.0, 1.0))
	var sp: float = Vector2(velocity.x, velocity.z).length()
	if sp > 0.4:
		return P.run(t * (6.0 + sp), clampf(sp / 5.0, 0.3, 1.0))
	return P.idle(t, brain_state == "battle")
