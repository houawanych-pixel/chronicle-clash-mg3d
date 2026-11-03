extends "res://scripts/cc/combat/combat_actor.gd"
## CC_Lance in the combat arena: light 1-2-3 string, hold to charge a heavy spin, side hop /
## backflip dodges (perfect dodge -> slow-mo -> flurry), guard and parry, lock-on.
## Input arrives in `inp` each frame (keyboard, touch HUD or tests).

signal perfect_dodge(attacker: Node3D)
signal parried(attacker: Node3D)

const MOVE_DIR: String = "res://data/cc/combat/moves/"

var team: String = "player"
var moves: Dictionary = {}
var inp: Dictionary = {"move": Vector2.ZERO, "attack": false, "attack_held": false, "heavy": false,
	"guard_held": false, "guard": false, "dodge": false, "lock": false, "sprint": false, "crouch": false}
var attack_buf: float = -999.0     # frame of the last ATTACK press (input buffer)
var dodge_buf: float = -999.0
var guard_press_f: float = -999.0
var attack_hold_f: float = 0.0
var charge_f: float = 0.0
var dodge_kind: String = ""
var dodge_dir: Vector3 = Vector3.ZERO
var lock_target: Node3D
var cam_yaw: float = 0.0           # set by the camera: stick directions are camera-relative
var weapon_class: String = "one_hand"
var flurry_target: Node3D
var flurry_left: int = 0
var flurry_ready_until: float = 0.0   # real msec
var flurry_hits_landed: int = 0
var crouched: bool = false
var sprinting: bool = false

func _ready() -> void:
	is_player = true
	for id: String in ["light1", "light2", "light3", "heavy", "flurry"]:
		moves[id] = load(MOVE_DIR + id + ".tres")
	var clips: Dictionary = {}
	for id: String in ["light1", "light2", "light3", "heavy", "flurry"]:
		var m: Resource = moves[id]
		clips[id] = {"frames": m.total_f(), "hit": [m.startup_f, m.startup_f + m.active_f],
			"lunge_m": m.lunge_m, "lunge_f": m.startup_f + m.active_f}
	clips["heavy_charge"] = {"frames": 60, "loop": true}
	clips["dodge_side"] = {"frames": int(tuning.dodge_f)}
	clips["dodge_back"] = {"frames": int(tuning.dodge_f)}
	clips["guard"] = {"frames": 60, "loop": true}
	clips["parry"] = {"frames": 18}
	clips["hurt"] = {"frames": 18}
	clips["stagger"] = {"frames": 30}
	clips["dead"] = {"frames": 60}
	hp = 120.0
	max_hp = 120.0
	setup_body("res://assets/characters/lance.glb", 1.8, Color("b48cff"), clips)
	rig.add_shield(Color("b48cff"))
	add_to_group("cc_player")

# ---------------------------------------------------------------- input

func press(action: String) -> void:
	inp[action] = true

func noise() -> float:
	if crouched:
		return 0.08
	if sprinting:
		return 1.0
	if state in ["light1", "light2", "light3", "heavy", "flurry"]:
		return 0.7
	var s: float = Vector2(velocity.x, velocity.z).length()
	return clampf(0.15 + s / 8.0, 0.15, 0.7)

func cam_dir(mv: Vector2) -> Vector3:
	var f: Vector3 = Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	var r: Vector3 = Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	return r * mv.x + f * -mv.y

# ---------------------------------------------------------------- brain

func brain(_cdt: float) -> Vector3:
	var f: float = frames
	if inp.attack:
		attack_buf = f
	if inp.dodge:
		dodge_buf = f
	if inp.guard:
		guard_press_f = f
	attack_hold_f = attack_hold_f + _cdt * 60.0 if inp.attack_held else 0.0
	if inp.lock:
		toggle_lock()
	crouched = bool(inp.crouch)
	sprinting = bool(inp.sprint) and not crouched
	var mv: Vector2 = inp.move
	inp.attack = false
	inp.dodge = false
	inp.guard = false
	inp.lock = false
	if lock_target != null and (not is_instance_valid(lock_target) or not lock_target.alive()):
		lock_target = null
	if not alive():
		return Vector3.ZERO
	var want: Vector3 = Vector3.ZERO
	match state:
		"locomote":
			want = locomote(mv)
		"guard":
			if not inp.guard_held:
				go("locomote")
			elif try_dodge(mv):
				pass
			face_lock()
			want = cam_dir(mv) * float(tuning.walk_speed) * 0.5
		"heavy_charge":
			charge_f += _cdt * 60.0
			face_lock()
			if dodge_pressed():
				try_dodge(mv)          # a dodge cancels the charge, no stamina spent
			elif not inp.attack_held and not inp.heavy:
				if StaminaPool.spend(float(moves.heavy.stamina_cost)):
					start_move("heavy")
				else:
					go("locomote")
		"light1", "light2", "light3", "heavy":
			move_tick(mv)
		"flurry":
			flurry_tick()
		"dodge_side", "dodge_back":
			if flurry_target != null and Time.get_ticks_msec() < flurry_ready_until and attack_buffered():
				start_flurry()
				return Vector3.ZERO
			want = dodge_dir * float(tuning.dodge_speed) * (1.0 - clampf(state_f / float(tuning.dodge_f), 0.0, 1.0) * 0.6)
			if state_f >= float(tuning.dodge_f):
				go("locomote")
		"parry", "hurt":
			if state_f >= clip_len_f():
				go("locomote")
		"stagger":
			stagger_left -= _cdt * 60.0
			if stagger_left <= 0.0:
				go("locomote")
	inp.heavy = false
	return want

func locomote(mv: Vector2) -> Vector3:
	# flurry: ATTACK during the slow-mo after a perfect dodge
	if flurry_target != null and Time.get_ticks_msec() < flurry_ready_until and attack_buffered():
		start_flurry()
		return Vector3.ZERO
	if try_dodge(mv):
		return Vector3.ZERO
	if inp.guard_held:
		go("guard")
		return Vector3.ZERO
	if inp.heavy or (inp.attack_held and attack_hold_f >= float(tuning.hold_to_charge_f)):
		charge_f = 0.0
		go("heavy_charge")
		return Vector3.ZERO
	if attack_buffered():
		attack_buf = -999.0
		start_move("light1")
		return Vector3.ZERO
	var dir: Vector3 = cam_dir(mv)
	var speed: float = float(tuning.run_speed) if mv.length() > 0.7 else float(tuning.walk_speed)
	if sprinting:
		speed = float(tuning.sprint_speed)
	if crouched:
		speed = float(tuning.crouch_speed)
	if dir.length() > 0.1:
		if lock_target == null:
			yaw = lerp_angle(yaw, atan2(-dir.x, -dir.z), 0.25)
	face_lock()
	tree.set("parameters/locomote/blend_position", Vector2(mv.x, -mv.y) * (1.0 if mv.length() > 0.7 else 0.5))
	return dir.normalized() * speed * clampf(dir.length(), 0.0, 1.0)

func attack_buffered() -> bool:
	return frames - attack_buf <= float(tuning.input_buffer_f)

func dodge_pressed() -> bool:
	return frames - dodge_buf <= float(tuning.input_buffer_f)

func face_lock() -> void:
	if lock_target != null:
		var to: Vector3 = lock_target.global_position - global_position
		yaw = lerp_angle(yaw, atan2(-to.x, -to.z), 0.3)

## Attack facing: full turn to a locked target; otherwise snap if a foe is within the assist cone.
func aim_assist() -> void:
	if lock_target != null:
		var to: Vector3 = lock_target.global_position - global_position
		yaw = atan2(-to.x, -to.z)
		return
	var best: Node3D = null
	var best_a: float = deg_to_rad(float(tuning.lock_assist_deg))
	for e: Node in get_tree().get_nodes_in_group("cc_enemy"):
		var n: Node3D = e as Node3D
		if not n.alive():
			continue
		var to2: Vector3 = n.global_position - global_position
		to2.y = 0.0
		if to2.length() > 4.0:
			continue
		var a: float = forward().angle_to(to2.normalized())
		if a <= best_a:
			best_a = a
			best = n
	if best != null:
		var to3: Vector3 = best.global_position - global_position
		yaw = atan2(-to3.x, -to3.z)

func start_move(id: String) -> void:
	cur_move = moves[id]
	var dmg: float = float(cur_move.damage)
	if id == "heavy":
		dmg *= lerpf(1.0, 1.5, clampf(charge_f / float(tuning.charge_full_f), 0.0, 1.0))
	cur_info = {"damage": dmg, "plane": cur_move.plane, "hitstop_f": cur_move.hitstop_f, "shake": cur_move.shake,
		"stagger_f": cur_move.stagger_f, "knockback": cur_move.knockback, "heavy": id == "heavy", "id": id}
	aim_assist()
	go(id)

## During a swing: chain on a buffered press at the end, or cancel into a dodge after active.
func move_tick(mv: Vector2) -> void:
	var m: Resource = cur_move
	var active_end: float = float(m.startup_f + m.active_f)
	if state_f >= active_end + float(tuning.dodge_cancel_after_active_f) and dodge_pressed():
		hitbox.close()
		try_dodge(mv)
		return
	if state_f >= float(m.total_f()):
		hitbox.close()
		if m.chain_to != "" and attack_buffered():
			attack_buf = -999.0
			start_move(m.chain_to)
		elif inp.attack_held and state != "heavy":
			charge_f = 0.0
			go("heavy_charge")
		else:
			cur_move = null
			go("locomote")

func try_dodge(mv: Vector2) -> bool:
	if not dodge_pressed():
		return false
	if not StaminaPool.spend(float(tuning.dodge_stamina)):
		return false
	dodge_buf = -999.0
	hitbox.close()
	cur_move = null
	var side: bool = absf(mv.x) > 0.5 and absf(mv.x) >= absf(mv.y)
	if side:
		dodge_kind = "side"
		var r: Vector3 = right() if lock_target != null else Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
		dodge_dir = r * signf(mv.x)
		go("dodge_side")
	else:
		dodge_kind = "back"
		dodge_dir = -forward()
		go("dodge_back")
	check_perfect_dodge()
	return true

## A dodge started while an enemy's swing is in its just-avoid window, in the right direction
## for that swing (side hop for overheads and thrusts, backflip for horizontal sweeps).
func check_perfect_dodge() -> void:
	for e: Node in get_tree().get_nodes_in_group("cc_enemy"):
		var n: Node3D = e as Node3D
		if not n.alive() or not n.just_avoid_open():
			continue
		if n.global_position.distance_to(global_position) > 4.5:
			continue
		if dodge_beats(str(n.attack_plane())):
			flurry_target = n
			flurry_ready_until = Time.get_ticks_msec() + float(tuning.flurry_window_s) * 1000.0
			TimeDilation.slow(float(tuning.flurry_time_scale), float(tuning.flurry_window_s))
			CombatFx.sound(get_tree(), "pulse", -4.0)
			perfect_dodge.emit(n)
			return

func dodge_beats(plane: String) -> bool:
	if dodge_kind == "side":
		return plane in ["vertical", "thrust"]
	return plane == "horizontal"

func start_flurry() -> void:
	attack_buf = -999.0
	flurry_left = int(tuning.flurry_hits.get(weapon_class, 7))
	flurry_hits_landed = 0
	TimeDilation.slow(float(tuning.flurry_time_scale), 30.0)   # held until the flurry ends
	var t: Node3D = flurry_target
	var to: Vector3 = t.global_position - global_position
	to.y = 0.0
	yaw = atan2(-to.x, -to.z)
	# dash in close
	global_position = t.global_position - to.normalized() * 1.2
	next_flurry_hit()

func next_flurry_hit() -> void:
	cur_move = moves.flurry
	cur_info = {"damage": float(tuning.flurry_hit_damage), "plane": "thrust", "hitstop_f": cur_move.hitstop_f,
		"shake": cur_move.shake, "stagger_f": 30, "knockback": 0.0, "heavy": false, "flurry": true, "id": "flurry"}
	go("flurry")

func flurry_tick() -> void:
	if state_f >= float(cur_move.total_f()):
		hitbox.close()
		flurry_left -= 1
		if flurry_left > 0 and flurry_target != null and flurry_target.alive():
			next_flurry_hit()
		else:
			flurry_target = null
			cur_move = null
			TimeDilation.release()
			go("locomote")

func confirm_impact(target: Node3D, info: Dictionary, result: String) -> void:
	super.confirm_impact(target, info, result)
	if info.get("flurry", false):
		flurry_hits_landed += 1

# ---------------------------------------------------------------- lock-on

func toggle_lock() -> void:
	if lock_target != null:
		lock_target = null
		return
	lock_target = find_lock()

func find_lock() -> Node3D:
	var cam_f: Vector3 = Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	var best: Node3D = null
	var best_score: float = INF
	for e: Node in get_tree().get_nodes_in_group("cc_enemy"):
		var n: Node3D = e as Node3D
		if not n.alive():
			continue
		var to: Vector3 = n.global_position - global_position
		to.y = 0.0
		var d: float = to.length()
		if d > float(tuning.lock_range_m):
			continue
		var a: float = rad_to_deg(cam_f.angle_to(to.normalized())) if d > 0.1 else 0.0
		if a > float(tuning.lock_cone_deg):
			continue
		var score: float = a * 0.08 + d
		if score < best_score:
			best_score = score
			best = n
	return best

# ---------------------------------------------------------------- getting hit

func take_hit(info: Dictionary) -> String:
	if not alive():
		return "none"
	var atk: Node3D = info.get("attacker")
	var plane: String = str(info.get("plane", "horizontal"))
	if state in ["dodge_side", "dodge_back"] and state_f < float(tuning.dodge_iframes_f) and dodge_beats(plane):
		took.emit(info, "dodge")
		return "dodge"
	if state == "guard":
		var to: Vector3 = info.get("from", global_position) - global_position
		to.y = 0.0
		var facing: bool = to.length() < 0.1 or forward().angle_to(to.normalized()) < deg_to_rad(100.0)
		if facing and frames - guard_press_f <= float(tuning.parry_window_f):
			go("parry")
			if atk != null and atk.has_method("stun"):
				atk.stun(float(tuning.parry_stun_f))
			CombatFx.spark(get_tree(), global_position + forward() * 0.6 + Vector3.UP * 1.2, Color("ffffff"), 40)
			CombatFx.sound(get_tree(), "chip", -2.0)
			parried.emit(atk)
			took.emit(info, "parry")
			return "parry"
		if facing:
			apply_damage(float(info.damage) * float(tuning.guard_damage_mult), info.get("from", global_position), 1.0)
			took.emit(info, "guard")
			return "guard"
	apply_damage(float(info.damage), info.get("from", global_position), float(info.get("knockback", 2.0)))
	if alive():
		hitbox.close()
		cur_move = null
		go("hurt")
	took.emit(info, "hit")
	return "hit"

# ---------------------------------------------------------------- look

func pose() -> Dictionary:
	var t: float = frames / 60.0
	var u: float = clampf(state_f / maxf(clip_len_f(), 1.0), 0.0, 1.0)
	match state:
		"light1":
			return P.slash(0, u)
		"light2":
			return P.slash(1, u)
		"light3":
			return P.slash(2, u)
		"heavy":
			return P.spin(u)
		"heavy_charge":
			return P.spin_ready(t)
		"flurry":
			return P.slash(flurry_left % 3, u)
		"guard", "parry":
			return P.shield_block(t)
		"dodge_side", "dodge_back":
			return P.crouch(0.0, 0.0)
		"hurt":
			return P.hurt(u)
		"stagger":
			return P.stagger(t)
		"dead":
			return P.dead()
	var sp: float = Vector2(velocity.x, velocity.z).length()
	if sp > 0.4:
		return P.crouch(t * 8.0, sp / 3.0) if crouched else P.run(t * (6.0 + sp), clampf(sp / 6.0, 0.3, 1.0))
	return P.crouch(0.0, 0.0) if crouched else P.idle(t, true)
