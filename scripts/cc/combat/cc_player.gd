extends "res://scripts/cc/combat/combat_actor.gd"
## CC_Lance in the arena.
## Combat: a weapon class string (one-hand 3 / two-hand 3 / spear 5), hold to charge (by
## class), dodges (locked on: side hop / backflip, wired to the enemies' just-avoid windows;
## not locked: a roll), guard + parry (one-hand only), perfect dodge -> slow-mo -> flurry.
## Movement: jump arc (running jumps go higher and further), coyote time, jump buffer, air
## control, glider, climbing (stamina, rain slip), ledge mantle, fall damage curve.
## Input arrives in `inp` each frame (keyboard, touch HUD or tests).

signal perfect_dodge(attacker: Node3D)
signal parried(attacker: Node3D)
signal slipped
signal landed(height: float, damage: float)
signal weapon_broke(id: String)
signal bag_full(id: String)
signal dove(height: float)
signal drowned
signal shield_broke
signal arrow_fired(arrow: Node3D)

const MOVE_DIR: String = "res://data/cc/combat/moves/"
const WEAPON_DIR: String = "res://data/cc/combat/weapons/"
const ALL_MOVES: Array[String] = ["light1", "light2", "light3", "heavy", "flurry", "th1", "th2", "th3", "th_spin", "th_slam", "sp1", "sp2", "sp3", "sp4", "sp5", "sp_rapid"]
const WEAPONS: Array[String] = ["ironwood_blade", "warden_greatblade", "thornreach_spear", "bare_hands"]
const Thrown = preload("res://scripts/cc/combat/cc_thrown.gd")
const PlayerArrow = preload("res://scripts/cc/combat/cc_player_arrow.gd")

var team: String = "player"
var moves: Dictionary = {}
var weapons: Dictionary = {}
var weapon: Resource
var jt: Resource       # jump_tuning.gd
var ct: Resource       # climb_tuning.gd
var inp: Dictionary = {"move": Vector2.ZERO, "attack": false, "attack_held": false, "heavy": false,
	"guard_held": false, "guard": false, "dodge": false, "lock": false, "sprint": false, "crouch": false,
	"jump": false, "aim": false, "weapon": false, "throw": false}
var attack_buf: float = -999.0
var dodge_buf: float = -999.0
var jump_buf: float = -999.0
var guard_press_f: float = -999.0
var attack_hold_f: float = 0.0
var charge_f: float = 0.0
var charging_loop: bool = false
var dodge_kind: String = ""
var dodge_dir: Vector3 = Vector3.ZERO
var lock_target: Node3D
var cam_yaw: float = 0.0
var weapon_class: String = "one_hand"
var flurry_target: Node3D
var flurry_left: int = 0
var flurry_ready_until: float = 0.0
var flurry_hits_landed: int = 0
var crouched: bool = false
var sprinting: bool = false
var aiming: bool = false
var riding: bool = false
# movement
var last_ground_f: float = -999.0
var jumped: bool = false
var air_peak_y: float = 0.0
var was_air: bool = false
var no_climb: float = 0.0
var climb_normal: Vector3 = Vector3.ZERO
var climbed_m: float = 0.0
var slip_at_m: float = 8.0
var slips: int = 0
var climb_speed_mult: float = 1.0      # armour / food buff (does not stop rain slip)
var mantle_from: Vector3
var mantle_to: Vector3
var updraft: float = 0.0               # world chemistry can push the glider up
var hspeed_at_jump: float = 0.0
var stun_f: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var bag_slot: int = -1          # which InventoryService.weapons entry is in hand (-1 = bare hands)
var cold_resist: bool = false
var sheathed: bool = false       # weapon + shield on the back
var peace_t: float = 0.0         # seconds since the last fight action
const SHEATHE_AFTER_S: float = 4.0
const HANDS_FREE: Array[String] = ["climb", "glide", "mantle", "swim", "skydive", "surf", "tumble"]
var tt: Resource       # traverse_tuning.gd: swim, dive, surf, bow
var last_dry: Vector3 = Vector3.ZERO
var has_shield: bool = true
var shield_life: float = 100.0
var surf_v: Vector3 = Vector3.ZERO
var surf_air: bool = false
var bow_draw_t: float = 0.0
var aerial_slow_on: bool = false
var arrow_type: String = "arrow"
var aim_override: Vector3 = Vector3.INF
var bow_node: Node3D
var last_arrow: Node3D

func _ready() -> void:
	is_player = true
	own_vertical = true
	jt = load("res://data/cc/combat/jump_tuning.tres")
	ct = load("res://data/cc/combat/climb_tuning.tres")
	tt = load("res://data/cc/combat/traverse_tuning.tres")
	shield_life = float(tt.shield_life)
	for id: String in ALL_MOVES:
		moves[id] = load(MOVE_DIR + id + ".tres")
	for w: String in WEAPONS:
		weapons[w] = load(WEAPON_DIR + w + ".tres")
	var clips: Dictionary = {}
	for id: String in ALL_MOVES:
		var m: Resource = moves[id]
		clips[id] = {"frames": m.total_f(), "hit": [m.startup_f, m.startup_f + m.active_f],
			"lunge_m": m.lunge_m, "lunge_f": m.startup_f + m.active_f}
	for nm: String in ["heavy_charge", "guard", "air", "glide", "climb", "swim", "skydive", "surf", "bow_draw"]:
		clips[nm] = {"frames": 60, "loop": true}
	clips["dodge_side"] = {"frames": int(tuning.dodge_f)}
	clips["dodge_back"] = {"frames": int(tuning.dodge_f)}
	clips["dodge_roll"] = {"frames": int(tuning.dodge_f)}
	clips["parry"] = {"frames": 18}
	clips["hurt"] = {"frames": 18}
	clips["stagger"] = {"frames": 30}
	clips["land_stun"] = {"frames": int(jt.hard_land_stun_f)}
	clips["mantle"] = {"frames": int(jt.mantle_f), "lunge_m": 0.0}
	clips["dead"] = {"frames": 60}
	clips["tumble"] = {"frames": int(tt.tumble_f)}
	hp = 120.0
	max_hp = 120.0
	setup_body("res://assets/characters/lance.glb", 1.8, Color("b48cff"), clips)
	rig.add_shield(Color("b48cff"))
	add_to_group("cc_player")
	rng.seed = 7
	build_glider()
	build_bow()
	last_dry = global_position
	if InventoryService.weapons.is_empty():
		for w: String in ["ironwood_blade", "warden_greatblade", "thornreach_spear"]:
			InventoryService.add_weapon(w, float(weapons[w].life))
	equip_slot(0)
	air_peak_y = global_position.y

var glider_node: Node3D

## A curved cloth wing overhead, shown while gliding.
func build_glider() -> void:
	glider_node = Node3D.new()
	glider_node.position = Vector3(0, 2.55, 0.1)
	glider_node.visible = false
	facing_pivot.add_child(glider_node)
	var cloth: StandardMaterial3D = StandardMaterial3D.new()
	cloth.albedo_color = Color("e9dcc0")
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var trim: StandardMaterial3D = StandardMaterial3D.new()
	trim.albedo_color = Color("7a3d8c")
	var wing: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.is_hemisphere = true
	wing.mesh = sm
	wing.scale = Vector3(1.6, 0.35, 0.7)
	wing.material_override = cloth
	glider_node.add_child(wing)
	for sx: float in [-1.0, 1.0]:
		var strut: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 0.015
		cm.bottom_radius = 0.015
		cm.height = 1.25
		strut.mesh = cm
		strut.material_override = trim
		strut.position = Vector3(0.45 * sx, -0.55, 0)
		strut.rotation.z = 0.45 * sx
		glider_node.add_child(strut)

# ---------------------------------------------------------------- weapons

func set_weapon(id: String) -> void:
	weapon = weapons[id]
	weapon_class = weapon.weapon_class
	var bm: BoxMesh = rig.blade.mesh as BoxMesh
	bm.size = Vector3(float(weapon.blade_width), float(weapon.blade_len), 0.03)
	rig.blade.position.y = float(weapon.blade_len) * 0.5 + 0.13
	rig.blade_len = float(weapon.blade_len)
	rig.blade_mat.albedo_color = (weapon.color as Color).lerp(Color.WHITE, 0.5)
	rig.blade_mat.emission = weapon.color
	if rig.shield != null:
		rig.shield.visible = bool(weapon.can_guard) and has_shield
	if state == "guard" and not weapon.can_guard:
		go("locomote")

## Hold the weapon in bag slot i (bare hands if the bag is empty).
func equip_slot(i: int) -> void:
	var bag: Array[Dictionary] = InventoryService.weapons
	if bag.is_empty():
		bag_slot = -1
		set_weapon("bare_hands")
		return
	bag_slot = posmod(i, bag.size())
	set_weapon(str(bag[bag_slot].id))

## In the test arenas a weapon picked by id goes to the bag slot holding it.
func set_weapon_by_id(id: String) -> void:
	for i in InventoryService.weapons.size():
		if str(InventoryService.weapons[i].id) == id:
			equip_slot(i)
			return
	set_weapon(id)

func cycle_weapon() -> void:
	equip_slot(bag_slot + 1)

## Weapon and shield go on the back for climbing, gliding and vaulting, and after a few
## quiet seconds out of a fight. Any fight input draws them again.
func sheathe_tick(cdt: float) -> void:
	if state in HANDS_FREE or riding:
		if not sheathed:
			put_away()
		return
	if cur_move != null or state in ["guard", "parry", "heavy_charge", "flurry", "hurt", "stagger"] or lock_target != null or foe_fighting_near():
		peace_t = 0.0
	else:
		peace_t += cdt
	if not sheathed and peace_t >= SHEATHE_AFTER_S:
		put_away()

func foe_fighting_near() -> bool:
	for e: Node in get_tree().get_nodes_in_group("cc_enemy"):
		var n: Node3D = e as Node3D
		if n.alive() and str(n.get("brain_state")) == "battle" and n.global_position.distance_to(global_position) < 15.0:
			return true
	return false

func put_away() -> void:
	sheathed = true
	CombatFx.sound(get_tree(), "chip", -16.0)

func draw_weapon() -> void:
	sheathed = false
	peace_t = 0.0
	CombatFx.sound(get_tree(), "chip", -10.0)

func weapon_life() -> float:
	if bag_slot < 0 or bag_slot >= InventoryService.weapons.size():
		return 1.0
	return float(InventoryService.weapons[bag_slot].life)

func weapon_life_frac() -> float:
	if bag_slot < 0:
		return 1.0
	return weapon_life() / maxf(float(weapon.life), 1.0)

func carries_metal() -> bool:
	return str(weapon.material) == "metal"

## The last hit before a weapon breaks does double damage.
func pre_hit(_target: Node3D, info: Dictionary) -> Dictionary:
	if bag_slot >= 0 and bool(weapon.breakable) and weapon_life() <= 1.0:
		info.damage = float(info.damage) * 2.0
		info["break_hit"] = true
	return info

func wear(n: float) -> void:
	if bag_slot < 0 or not bool(weapon.breakable):
		return
	InventoryService.weapons[bag_slot].life = weapon_life() - n
	if weapon_life() <= 0.0:
		break_weapon()

func break_weapon() -> void:
	var id: String = str(weapon.id)
	InventoryService.weapons.remove_at(bag_slot)
	drop_stub()
	CombatFx.sound(get_tree(), "chip", 0.0)
	CombatFx.spark(get_tree(), global_position + forward() * 0.8 + Vector3.UP * 1.2, Color("dddddd"), 30)
	weapon_broke.emit(id)
	equip_slot(bag_slot)

## The broken weapon's stub drops to the ground.
func drop_stub() -> void:
	var b: RigidBody3D = RigidBody3D.new()
	b.name = "BrokenStub"
	b.add_to_group("cc_stub")
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = Vector3(0.08, 0.4, 0.04)
	cs.shape = bs
	b.add_child(cs)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = bs.size
	mi.mesh = bm
	b.add_child(mi)
	get_parent().add_child(b)
	b.global_position = global_position + forward() * 0.6 + Vector3.UP * 1.0
	b.linear_velocity = forward() * 1.5 + Vector3.UP * 2.0

## Throw the weapon in hand: it flies, hits for double and (usually) breaks.
func throw_weapon() -> bool:
	if bag_slot < 0 or cur_move != null or state != "locomote":
		return false
	var t: Area3D = Thrown.new()
	t.thrower = self
	t.damage = float(moves[str(weapon.string_moves[0])].damage) * float(weapon.damage_mult) * 2.0
	t.weapon_id = str(weapon.id)
	t.life = weapon_life()
	t.keeps = bool(weapon.survives_throw)
	get_parent().add_child(t)
	t.launch(global_position + Vector3.UP * 1.4 + forward() * 0.6, forward() * 14.0 + Vector3.UP * 1.0, float(weapon.blade_len))
	InventoryService.weapons.remove_at(bag_slot)
	equip_slot(bag_slot)
	return true

## Walking over a weapon: into the bag unless the melee bag is full (then it asks to swap).
func try_pickup(id: String, life: float) -> bool:
	if InventoryService.is_full("Melee"):
		bag_full.emit(id)
		return false
	InventoryService.add_weapon(id, life)
	if bag_slot < 0:
		equip_slot(0)
	return true

## Swap the weapon in hand for one on the ground. Returns the dropped [id, life].
func swap_for(id: String, life: float) -> Array:
	if bag_slot < 0:
		InventoryService.add_weapon(id, life)
		equip_slot(0)
		return []
	var old: Dictionary = InventoryService.weapons[bag_slot]
	InventoryService.weapons[bag_slot] = {"id": id, "life": life}
	set_weapon(id)
	return [str(old.id), float(old.life)]

# ---------------------------------------------------------------- input

func press(action: String) -> void:
	inp[action] = true

func noise() -> float:
	if crouched:
		return 0.08
	if sprinting:
		return 1.0
	if cur_move != null:
		return 0.7
	var s: float = Vector2(velocity.x, velocity.z).length()
	return clampf(0.15 + s / 8.0, 0.15, 0.7)

func cam_dir(mv: Vector2) -> Vector3:
	var f: Vector3 = Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	var r: Vector3 = Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	return r * mv.x + f * -mv.y

func grounded() -> bool:
	return is_on_floor()

# ---------------------------------------------------------------- brain

func brain(cdt: float) -> Vector3:
	var f: float = frames
	if inp.attack:
		attack_buf = f
	if inp.dodge:
		dodge_buf = f
	if inp.guard:
		guard_press_f = f
	var jump_now: bool = bool(inp.jump)
	if jump_now:
		jump_buf = f
	attack_hold_f = attack_hold_f + cdt * 60.0 if inp.attack_held else 0.0
	# drawing: any fight input pulls the weapon (the swing / guard still happens this frame)
	if inp.attack or inp.heavy or inp.guard or inp.guard_held or inp.lock or inp.attack_held or inp.throw:
		peace_t = 0.0
		if sheathed and state not in HANDS_FREE:
			draw_weapon()
	if inp.lock:
		toggle_lock()
	if inp.aim:
		aiming = not aiming
	if inp.weapon and aiming:
		arrow_type = "fire_arrow" if arrow_type == "arrow" else "arrow"
	elif inp.weapon and cur_move == null and state in ["locomote", "guard"]:
		cycle_weapon()
	if inp.throw:
		throw_weapon()
	crouched = bool(inp.crouch)
	sprinting = bool(inp.sprint) and not crouched
	var mv: Vector2 = inp.move
	for k: String in ["attack", "dodge", "guard", "lock", "jump", "aim", "weapon", "throw"]:
		inp[k] = false
	if lock_target != null and (not is_instance_valid(lock_target) or not lock_target.alive()):
		lock_target = null
	no_climb = maxf(0.0, no_climb - cdt)
	var on_ground: bool = grounded()
	if on_ground:
		last_ground_f = f
		jumped = false
	if not alive():
		vy = -1.0 if on_ground else vy - float(jt.gravity) * cdt
		return Vector3.ZERO
	if state not in ["climb", "mantle", "swim"] and in_deep_water():
		enter_water()
	var want: Vector3 = Vector3.ZERO
	var gravity_on: bool = true
	match state:
		"locomote":
			want = locomote(mv, cdt, jump_now)
		"guard":
			if jump_now and grounded() and has_shield:
				start_surf()         # hold GUARD, tap JUMP: onto the shield
			elif not inp.guard_held or not weapon.can_guard:
				go("locomote")
			elif try_dodge(mv):
				pass
			face_lock()
			want = cam_dir(mv) * float(tuning.walk_speed) * 0.5
		"heavy_charge":
			charge_f += cdt * 60.0
			face_lock()
			var drained: bool = not StaminaPool.spend(float(weapon.charge_drain_per_sec) * cdt)
			if dodge_pressed():
				try_dodge(mv)
			elif drained or StaminaPool.is_exhausted:
				start_move(str(weapon.finisher_move))      # ran dry: it fires on its own
			elif not inp.attack_held:
				if StaminaPool.spend(float(weapon.release_cost)):
					start_move(str(weapon.finisher_move))
				else:
					go("locomote")
		"flurry":
			flurry_tick()
		"dodge_side", "dodge_back", "dodge_roll":
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
			stagger_left -= cdt * 60.0
			if stagger_left <= 0.0:
				go("locomote")
		"land_stun":
			if state_f >= float(jt.hard_land_stun_f):
				go("locomote")
		"glide":
			want = glide(mv, cdt, jump_now)
			gravity_on = false
		"climb":
			want = climb(mv, cdt, jump_now)
			gravity_on = false
		"mantle":
			mantle_tick()
			gravity_on = false
			want = Vector3.ZERO
		"swim":
			want = swim(mv, cdt, jump_now)
			gravity_on = false
		"skydive":
			want = skydive(mv, cdt, jump_now)
			gravity_on = false
		"surf":
			want = surf(mv, cdt, jump_now)
			gravity_on = false
		"tumble":
			if state_f >= float(tt.tumble_f):
				go("locomote")
		"bow_draw":
			want = bow_tick(mv, cdt)
		_:
			if cur_move != null and state == str(cur_move.id):
				move_tick(mv)
	inp.heavy = false
	sheathe_tick(cdt)
	if gravity_on:
		if on_ground and vy <= 0.0:
			vy = -1.0
		else:
			vy -= float(jt.gravity) * cdt
	return want

func locomote(mv: Vector2, cdt: float, jump_now: bool) -> Vector3:
	var on_ground: bool = grounded()
	if flurry_target != null and Time.get_ticks_msec() < flurry_ready_until and attack_buffered():
		start_flurry()
		return Vector3.ZERO
	# jump: on the ground or within coyote frames after leaving it, from a press in the buffer
	if aiming and attack_buffered() and cur_move == null:
		start_bow()
		return Vector3(velocity.x, 0, velocity.z)
	# shield surf: GUARD + JUMP while moving on the ground
	if on_ground and jump_now and inp.guard_held and has_shield and weapon.can_guard and Vector2(velocity.x, velocity.z).length() > 1.5:
		start_surf()
		return Vector3(velocity.x, 0, velocity.z)
	var can_jump: bool = not jumped and (on_ground or frames - last_ground_f <= float(jt.coyote_f))
	if can_jump and frames - jump_buf <= float(jt.buffer_f) and cur_move == null:
		do_jump()
		return Vector3(velocity.x, 0, velocity.z)
	if not on_ground:
		# glider opens from a fresh press in the air with room below
		if jump_now and jumped_or_falling() and height_above_ground() >= float(jt.glide_min_height) and not StaminaPool.is_exhausted:
			go("glide")
			return Vector3(velocity.x, 0, velocity.z)
		if try_climb(mv):
			return Vector3.ZERO
		# a long drop: spread out and skydive
		if vy < -6.0 and height_above_ground() > float(tt.skydive_min_height):
			go("skydive")
			return Vector3(velocity.x, 0, velocity.z)
		var dir_a: Vector3 = cam_dir(mv)
		var hv: Vector3 = Vector3(velocity.x, 0, velocity.z)
		var cap: float = maxf(float(jt.air_max_speed), hspeed_at_jump)
		hv = hv.move_toward(dir_a.normalized() * cap * clampf(dir_a.length(), 0.0, 1.0) if dir_a.length() > 0.1 else hv, float(jt.air_accel) * cdt)
		return hv
	if try_dodge(mv):
		return Vector3.ZERO
	if inp.guard_held and weapon.can_guard:
		go("guard")
		return Vector3.ZERO
	if inp.heavy or (inp.attack_held and attack_hold_f >= float(tuning.hold_to_charge_f)):
		start_charge()
		return Vector3.ZERO
	if attack_buffered():
		attack_buf = -999.0
		start_move(str(weapon.string_moves[0]))
		return Vector3.ZERO
	if try_mantle(mv):
		return Vector3.ZERO
	if try_climb(mv):
		return Vector3.ZERO
	var dir: Vector3 = cam_dir(mv)
	var speed: float = float(tuning.run_speed) if mv.length() > 0.7 else float(tuning.walk_speed)
	if sprinting:
		speed = float(tuning.sprint_speed)
	if crouched:
		speed = float(tuning.crouch_speed)
	if aiming:
		speed = float(tuning.walk_speed)
		yaw = lerp_angle(yaw, cam_yaw, 0.35)
	speed *= float(weapon.walk_mult)
	if dir.length() > 0.1 and lock_target == null and not aiming:
		yaw = lerp_angle(yaw, atan2(-dir.x, -dir.z), 0.25)
	face_lock()
	tree.set("parameters/locomote/blend_position", Vector2(mv.x, -mv.y) * (1.0 if mv.length() > 0.7 else 0.5))
	return dir.normalized() * speed * clampf(dir.length(), 0.0, 1.0)

func jumped_or_falling() -> bool:
	return jumped or vy < 0.0

func do_jump() -> void:
	jump_buf = -999.0
	jumped = true
	var hs: float = Vector2(velocity.x, velocity.z).length()
	hspeed_at_jump = hs
	var h: float = float(jt.peak_height) + float(jt.run_height_add) * clampf(hs / float(tuning.run_speed), 0.0, 1.0)
	vy = sqrt(2.0 * float(jt.gravity) * h)
	air_peak_y = global_position.y
	CombatFx.sound(get_tree(), "step", -10.0)

func height_above_ground() -> float:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.1, global_position + Vector3.DOWN * 60.0, 1)
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return 60.0
	return global_position.y - (hit.position as Vector3).y

func after_move(_cdt: float) -> void:
	var on_ground: bool = is_on_floor()
	if not on_ground:
		air_peak_y = maxf(air_peak_y, global_position.y)
		if state == "glide":
			air_peak_y = global_position.y       # an open glider cancels the fall
		if state == "locomote" and cur_move == null:
			pass
	elif was_air and state not in ["climb", "mantle"]:
		var h: float = air_peak_y - global_position.y
		land(h)
	if on_ground:
		air_peak_y = global_position.y
		if state == "locomote" and not in_water_at(global_position + Vector3.UP * 0.2):
			last_dry = global_position
	was_air = not on_ground

func land(h: float) -> void:
	if state == "glide":
		go("locomote")
		landed.emit(h, 0.0)
		return
	if state == "surf":
		shield_wear(float(tt.surf_impact_cost))
		surf_air = false
		landed.emit(h, 0.0)
		return
	if aerial_slow_on:
		end_aerial()
	if state == "skydive":
		go("locomote")
	var frac: float = float(jt.fall_damage_frac(h))
	var dmg: float = frac * max_hp
	if dmg > 0.0:
		apply_damage(dmg, global_position, 0.0)
		CombatFx.shake(get_tree(), 0.5)
		CombatFx.sound(get_tree(), "hurt", -4.0)
		no_climb = float(ct.no_climb_time_after_fall)
		if alive():
			cur_move = null
			hitbox.close()
			go("land_stun")
	landed.emit(h, dmg)

# ---------------------------------------------------------------- water

func water_at(p: Vector3) -> Node:
	for w: Node in get_tree().get_nodes_in_group("cc_water"):
		if w.contains(p):
			return w
	return null

func in_water_at(p: Vector3) -> bool:
	return water_at(p) != null

## Depth of water under the chest (surface to the bottom below), 0 if none.
func water_depth() -> float:
	var chest: Vector3 = global_position + Vector3.UP * 0.9
	var w: Node = water_at(chest)
	if w == null:
		return 0.0
	var top: float = float(w.surface_y())
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(chest.x, top, chest.z), Vector3(chest.x, top - 30.0, chest.z), 1)
	q.exclude = [get_rid()]
	var hit: Dictionary = space.intersect_ray(q)
	return top - ((hit.position as Vector3).y if not hit.is_empty() else top - 30.0)

func in_deep_water() -> bool:
	return water_depth() >= float(tt.deep_water_m) and global_position.y < float(water_at(global_position + Vector3.UP * 0.9).surface_y()) - 0.6

## Into the water: a high dive into deep water is safe (big splash), then swim.
func enter_water() -> void:
	var h: float = air_peak_y - global_position.y
	var depth: float = water_depth()
	if vy < -8.0:
		if depth >= float(tt.dive_min_depth):
			CombatFx.spark(get_tree(), global_position + Vector3.UP * 1.2, Color("cfefff"), 50)
			CombatFx.sound(get_tree(), "explosion", -14.0)
			dove.emit(h)
		else:
			land(h)     # too shallow for a dive: it hurts like ground
	if aerial_slow_on:
		end_aerial()
	hitbox.close()
	cur_move = null
	vy = 0.0
	air_peak_y = global_position.y
	was_air = false
	go("swim")

func swim(mv: Vector2, cdt: float, jump_now: bool) -> Vector3:
	var w: Node = water_at(global_position + Vector3.UP * 0.9)
	if w == null or water_depth() < float(tt.deep_water_m) * 0.8:
		go("locomote")       # waded out
		return Vector3(velocity.x, 0, velocity.z)
	var target_y: float = float(w.surface_y()) - float(tt.swim_float)
	vy = clampf((target_y - global_position.y) * 5.0, -4.0, 4.0)
	var dir: Vector3 = cam_dir(mv)
	var dash: bool = (sprinting or dodge_pressed()) and dir.length() > 0.2
	var drain: float = float(tt.swim_dash_drain) if dash else 1.5
	if not StaminaPool.spend(drain * cdt) or StaminaPool.is_exhausted:
		drown()
		return Vector3.ZERO
	if dir.length() > 0.1:
		yaw = lerp_angle(yaw, atan2(-dir.x, -dir.z), 0.15)
		# swimming into the bank or a wall: climb out
		var d: Vector3 = dir.normalized()
		if not wall_hit(1.0, d, 0.7).is_empty():
			if try_climb(mv):
				return Vector3.ZERO
			if start_mantle(true, d):
				return Vector3.ZERO
	var speed: float = float(tt.swim_dash_speed) if dash else float(tt.swim_speed)
	return dir.normalized() * speed * clampf(dir.length(), 0.0, 1.0)

## Out of stamina in deep water: you go under, lose some health, and come back on the shore.
func drown() -> void:
	apply_damage(float(tt.drown_damage), global_position, 0.0)
	drowned.emit()
	CombatFx.sound(get_tree(), "hurt", -4.0)
	global_position = last_dry + Vector3.UP * 0.2
	velocity = Vector3.ZERO
	vy = 0.0
	air_peak_y = global_position.y
	was_air = false
	if alive():
		go("locomote")

# ---------------------------------------------------------------- skydive

func skydive(mv: Vector2, cdt: float, jump_now: bool) -> Vector3:
	if jump_now and not StaminaPool.is_exhausted:
		go("glide")
		return Vector3(velocity.x, 0, velocity.z)
	if try_climb(mv):
		return Vector3.ZERO
	vy = maxf(vy - float(jt.gravity) * cdt, -float(tt.terminal_speed))
	var dir: Vector3 = cam_dir(mv)
	var hv: Vector3 = Vector3(velocity.x, 0, velocity.z)
	var want_v: Vector3 = dir.normalized() * float(tt.skydive_air_speed) * clampf(dir.length(), 0.0, 1.0) if dir.length() > 0.1 else hv * 0.98
	hv = hv.move_toward(want_v, 13.0 * cdt)
	if hv.length() > 0.5:
		yaw = lerp_angle(yaw, atan2(-hv.x, -hv.z), 0.12)
	return hv

## Water close below while skydiving: the dive pose (head first).
func diving() -> bool:
	if state != "skydive":
		return false
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * 9.0, 1)
	q.exclude = [get_rid()]
	var hit: Dictionary = space.intersect_ray(q)
	var below: Vector3 = (hit.position as Vector3) if not hit.is_empty() else global_position + Vector3.DOWN * 9.0
	return in_water_at(Vector3(below.x, below.y + 0.5, below.z))

# ---------------------------------------------------------------- shield surf

func surface_under() -> String:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.3, global_position + Vector3.DOWN * 1.2, 1)
	q.exclude = [get_rid()]
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return "grass"
	return str((hit.collider as Node).get_meta("surface", "grass"))

func start_surf() -> void:
	surf_v = Vector3(velocity.x, 0, velocity.z)
	surf_air = false
	jump_buf = -999.0
	go("surf")

func surf(mv: Vector2, cdt: float, jump_now: bool) -> Vector3:
	if not inp.guard_held or not has_shield:
		go("locomote")
		return Vector3(surf_v.x, 0, surf_v.z)
	var on_ground: bool = grounded()
	var g: float = float(jt.gravity)
	var surface: String = surface_under()
	var mu: float = float(tt.surf_friction.get(surface, 0.16))
	if WeatherService.is_precipitating:
		mu *= float(tt.surf_rain_friction_mult)
	if on_ground:
		var n: Vector3 = get_floor_normal()
		var downhill: Vector3 = Vector3.DOWN - n * n.dot(Vector3.DOWN)
		surf_v += downhill * g * float(tt.surf_gravity_k) * cdt
		# keep the board's velocity in the slope plane
		surf_v -= n * surf_v.dot(n)
		surf_v = surf_v.move_toward(Vector3.ZERO, mu * g * cdt)
		shield_wear(float(tt.surf_sled_wear.get(surface, 0.4)) * cdt)
		if not has_shield:
			return Vector3.ZERO
		if jump_now:
			vy = float(tt.surf_hop_speed)
			surf_air = true
		else:
			vy = minf(surf_v.y, 0.0) - 1.5
	else:
		vy -= g * cdt
	var dir: Vector3 = cam_dir(mv)
	var hv: Vector3 = Vector3(surf_v.x, 0, surf_v.z)
	if dir.length() > 0.2 and hv.length() > 0.5:
		var want_yaw: float = atan2(-dir.x, -dir.z)
		var cur_yaw: float = atan2(-hv.x, -hv.z)
		var ny: float = rotate_toward(cur_yaw, want_yaw, float(tt.surf_turn_rate) * cdt)
		var rot: Basis = Basis(Vector3.UP, ny - cur_yaw)
		surf_v = rot * surf_v
		hv = Vector3(surf_v.x, 0, surf_v.z)
	if hv.length() > 0.5:
		yaw = lerp_angle(yaw, atan2(-hv.x, -hv.z), 0.2)
	return hv

func shield_wear(n: float) -> void:
	if not has_shield:
		return
	shield_life -= n
	if shield_life <= 0.0:
		break_shield()

## The shield gives out under you: it shatters and you tumble.
func break_shield() -> void:
	has_shield = false
	shield_life = 0.0
	if rig.shield != null:
		rig.shield.visible = false
	CombatFx.spark(get_tree(), global_position + Vector3.UP * 0.2, Color("dddddd"), 30)
	CombatFx.sound(get_tree(), "chip", 0.0)
	apply_damage(max_hp * float(tt.shield_break_damage_frac), global_position, 0.0)
	shield_broke.emit()
	if alive():
		go("tumble")

# ---------------------------------------------------------------- bow

func build_bow() -> void:
	bow_node = Node3D.new()
	bow_node.position = Vector3(-0.32, 1.4, -0.45)
	bow_node.visible = false
	facing_pivot.add_child(bow_node)
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_color = Color("7a4a2a")
	for sgn: float in [-1.0, 1.0]:
		var limb: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(0.04, 0.62, 0.05)
		limb.mesh = bm
		limb.material_override = wood
		limb.position = Vector3(0, 0.28 * sgn, 0.08)
		limb.rotation.x = -0.35 * sgn
		bow_node.add_child(limb)
	var string: MeshInstance3D = MeshInstance3D.new()
	var sm: BoxMesh = BoxMesh.new()
	sm.size = Vector3(0.008, 1.1, 0.008)
	string.mesh = sm
	string.position = Vector3(0, 0, 0.22)
	bow_node.add_child(string)

func start_bow() -> void:
	attack_buf = -999.0
	if InventoryService.count(arrow_type) <= 0:
		return
	bow_draw_t = 0.0
	go("bow_draw")
	if not grounded() and height_above_ground() > 2.0 and not StaminaPool.is_exhausted:
		aerial_slow_on = true
		TimeDilation.slow(float(tt.aerial_time_scale), 30.0)

func end_aerial() -> void:
	aerial_slow_on = false
	TimeDilation.release()

func bow_tick(mv: Vector2, cdt: float) -> Vector3:
	bow_draw_t += cdt
	yaw = lerp_angle(yaw, cam_yaw, 0.4)
	if aerial_slow_on:
		# real-time drain: the world is slowed, the stamina isn't
		if not StaminaPool.spend(float(tt.aerial_drain) * cdt / maxf(time_scale(), 0.05)) or StaminaPool.is_exhausted:
			end_aerial()
	if not inp.attack_held:
		fire_arrow()
		if aerial_slow_on:
			end_aerial()
		go("locomote")
		return Vector3(velocity.x, 0, velocity.z)
	if grounded():
		return cam_dir(mv) * float(tuning.walk_speed) * 0.5
	return Vector3(velocity.x, 0, velocity.z)

## Where the shot should land: the centre of the screen (or a test override).
func aim_point() -> Vector3:
	if aim_override != Vector3.INF:
		return aim_override
	var cam: Camera3D = get_viewport().get_camera_3d()
	var from: Vector3 = cam.global_position
	var to: Vector3 = from - cam.global_transform.basis.z * 80.0
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1 | 16)
	q.collide_with_areas = true
	q.exclude = [get_rid(), hurtbox.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	return (hit.position as Vector3) if not hit.is_empty() else to

## Launch direction that lands on target at this speed (the low arc), so drop is allowed for.
static func ballistic_dir(from: Vector3, target: Vector3, speed: float, g: float) -> Vector3:
	var d: Vector3 = target - from
	var flat: Vector3 = Vector3(d.x, 0, d.z)
	var x: float = flat.length()
	var y: float = d.y
	if x < 0.01:
		return d.normalized()
	var v2: float = speed * speed
	var disc: float = v2 * v2 - g * (g * x * x + 2.0 * y * v2)
	var ang: float = PI / 4.0 if disc < 0.0 else atan((v2 - sqrt(disc)) / (g * x))
	return (flat.normalized() * cos(ang) + Vector3.UP * sin(ang)).normalized()

func fire_arrow() -> void:
	if not InventoryService.remove(arrow_type, 1):
		return
	var k: float = clampf(bow_draw_t / float(tt.bow_draw_s), 0.0, 1.0)
	var speed: float = lerpf(float(tt.arrow_speed_min), float(tt.arrow_speed_max), k)
	var from: Vector3 = global_position + Vector3.UP * 1.45 + forward() * 0.5
	var a: Area3D = PlayerArrow.new()
	a.shooter = self
	a.damage = float(tt.arrow_damage)
	a.drop = float(tt.arrow_gravity)
	a.headshot_mult = float(tt.headshot_mult)
	a.fire = arrow_type == "fire_arrow"
	get_parent().add_child(a)
	a.launch(from, ballistic_dir(from, aim_point(), speed, float(tt.arrow_gravity)) * speed)
	last_arrow = a
	CombatFx.sound(get_tree(), "step", -6.0)
	arrow_fired.emit(a)

# ---------------------------------------------------------------- glide

func glide(mv: Vector2, cdt: float, jump_now: bool) -> Vector3:
	if jump_now or not StaminaPool.spend(float(jt.glide_drain) * cdt) or StaminaPool.is_exhausted:
		go("locomote")       # folds up; falls from here
		return Vector3(velocity.x, 0, velocity.z)
	vy = -float(jt.glide_fall_speed) + updraft
	updraft = move_toward(updraft, 0.0, cdt * 4.0)
	var dir: Vector3 = cam_dir(mv)
	if dir.length() > 0.1:
		yaw = lerp_angle(yaw, atan2(-dir.x, -dir.z), 0.1)
	var wind: Vector3 = WeatherService.wind_vec
	return forward() * float(jt.glide_speed) * (0.55 + 0.45 * clampf(dir.length(), 0.0, 1.0)) + Vector3(wind.x, 0, wind.z) * 0.35

# ---------------------------------------------------------------- climb and mantle

func wall_hit(height: float, dir: Vector3, length: float = 0.75) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var from: Vector3 = global_position + Vector3.UP * height
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + dir * length, 1)
	q.exclude = [get_rid()]
	return space.intersect_ray(q)

func try_climb(mv: Vector2) -> bool:
	if no_climb > 0.0 or StaminaPool.is_exhausted or mv.length() < 0.4:
		return false
	var dir: Vector3 = cam_dir(mv).normalized()
	var hit: Dictionary = wall_hit(1.1, dir)
	if hit.is_empty() or not (hit.collider as Node).is_in_group("cc_climbable"):
		return false
	var n: Vector3 = hit.normal
	if absf(n.y) > 0.5 or dir.dot(-n) < 0.6:
		return false
	climb_normal = Vector3(n.x, 0, n.z).normalized()
	climbed_m = 0.0
	slip_at_m = float(ct.slip_after_meters) + rng.randf() * float(ct.slip_random_extra_meters)
	yaw = atan2(climb_normal.x, climb_normal.z)
	vy = 0.0
	go("climb")
	return true

func climb(mv: Vector2, cdt: float, jump_now: bool) -> Vector3:
	var rain: bool = WeatherService.is_precipitating
	var moving: bool = mv.length() > 0.2
	var drain: float = float(ct.stamina_drain_move) if moving else float(ct.stamina_drain_hold)
	if rain:
		drain *= float(ct.rain_drain_mult)
	var still_ok: bool = StaminaPool.spend(drain * cdt)
	if not still_ok or StaminaPool.is_exhausted:
		detach(true)
		return Vector3.ZERO
	var up: Vector3 = Vector3.UP
	var side: Vector3 = climb_normal.cross(Vector3.UP).normalized()
	var spd: float = float(ct.climb_speed) * climb_speed_mult
	if jump_now:
		if StaminaPool.spend(float(ct.drain_jump)):
			global_position += Vector3.UP * float(ct.leap_height)
			climbed_m += float(ct.leap_height)
	var v: Vector3 = (up * -mv.y + side * -mv.x) * spd
	vy = v.y
	climbed_m += maxf(0.0, v.y) * cdt
	# rain: after a stretch of climbing the grip goes
	if rain and climbed_m >= slip_at_m:
		slip()
	# lost the wall (top reached or edge): pull up over the top, or let go
	if wall_hit(1.1, -climb_normal, 0.9).is_empty():
		if not wall_hit(0.3, -climb_normal, 0.9).is_empty():
			start_mantle(true)
		else:
			detach(false)
		return Vector3.ZERO
	if grounded() and mv.y > 0.3:
		go("locomote")
		return Vector3.ZERO
	return Vector3(v.x, 0, v.z) - climb_normal * 0.6     # keep pressed to the wall

func slip() -> void:
	slips += 1
	climbed_m = 0.0
	slip_at_m = float(ct.slip_after_meters) + rng.randf() * float(ct.slip_random_extra_meters)
	global_position += Vector3.DOWN * float(ct.slip_distance)
	StaminaPool.spend(float(ct.slip_stamina_penalty))
	CombatFx.sound(get_tree(), "hurt", -10.0)
	slipped.emit()

func detach(tired: bool) -> void:
	no_climb = float(ct.no_climb_time_tired) if tired else float(ct.no_climb_time_after_fall)
	global_position += climb_normal * 0.3
	vy = 0.0
	go("locomote")

## Waist-high ledge straight ahead: vault onto it (no jump needed).
func try_mantle(mv: Vector2) -> bool:
	if mv.length() < 0.5:
		return false
	var dir: Vector3 = cam_dir(mv).normalized()
	if wall_hit(0.35, dir, 0.7).is_empty():
		return false
	if not wall_hit(float(jt.mantle_max_m) + 0.15, dir, 0.9).is_empty():
		return false
	return start_mantle(false, dir)

func start_mantle(from_climb: bool, dir: Vector3 = Vector3.ZERO) -> bool:
	if dir == Vector3.ZERO:
		dir = -climb_normal
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var probe: Vector3 = global_position + dir * 0.75 + Vector3.UP * (float(jt.mantle_max_m) + 1.4 if from_climb else float(jt.mantle_max_m) + 0.3)
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(probe, probe + Vector3.DOWN * 3.0, 1)
	q.exclude = [get_rid()]
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return false
	var top: Vector3 = hit.position
	var rise: float = top.y - global_position.y
	if not from_climb and (rise < float(jt.mantle_min_m) or rise > float(jt.mantle_max_m)):
		return false
	mantle_from = global_position
	mantle_to = top + Vector3.UP * 0.05 + dir * 0.1
	yaw = atan2(-dir.x, -dir.z)
	vy = 0.0
	go("mantle")
	return true

func mantle_tick() -> void:
	var k: float = clampf(state_f / float(jt.mantle_f), 0.0, 1.0)
	# up first, then over
	var up_k: float = clampf(k / 0.6, 0.0, 1.0)
	var over_k: float = clampf((k - 0.4) / 0.6, 0.0, 1.0)
	var p: Vector3 = mantle_from
	p.y = lerpf(mantle_from.y, mantle_to.y, ease(up_k, 0.6))
	p.x = lerpf(mantle_from.x, mantle_to.x, over_k)
	p.z = lerpf(mantle_from.z, mantle_to.z, over_k)
	global_position = p
	vy = 0.0
	if k >= 1.0:
		air_peak_y = global_position.y
		was_air = false
		go("locomote")

# ---------------------------------------------------------------- attacks

func attack_buffered() -> bool:
	return frames - attack_buf <= float(tuning.input_buffer_f)

func dodge_pressed() -> bool:
	return frames - dodge_buf <= float(tuning.input_buffer_f)

func face_lock() -> void:
	if lock_target != null:
		var to: Vector3 = lock_target.global_position - global_position
		yaw = lerp_angle(yaw, atan2(-to.x, -to.z), 0.3)

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

func start_charge() -> void:
	charge_f = 0.0
	if weapon.charge_kind == "spin_release":
		go("heavy_charge")
	else:
		charging_loop = true
		start_move(str(weapon.charge_loop_move))

func start_move(id: String) -> void:
	if id == "":
		cur_move = null
		go("locomote")
		return
	cur_move = moves[id]
	var dmg: float = float(cur_move.damage) * float(weapon.damage_mult)
	var heavy: bool = int(cur_move.stagger_f) >= 30
	if id == "heavy":
		dmg *= lerpf(1.0, 1.5, clampf(charge_f / float(tuning.charge_full_f), 0.0, 1.0))
	cur_info = {"damage": dmg, "plane": cur_move.plane, "hitstop_f": cur_move.hitstop_f, "shake": cur_move.shake,
		"stagger_f": cur_move.stagger_f, "knockback": cur_move.knockback, "heavy": heavy, "id": id}
	aim_assist()
	go(id)

func move_tick(mv: Vector2) -> void:
	var m: Resource = cur_move
	var active_end: float = float(m.startup_f + m.active_f)
	if state_f >= active_end + float(tuning.dodge_cancel_after_active_f) and dodge_pressed():
		hitbox.close()
		charging_loop = false
		try_dodge(mv)
		return
	if state_f >= float(m.total_f()):
		hitbox.close()
		if charging_loop:
			# two-hand spin / spear rapid thrusts: keep going while held and stamina lasts
			var cost: float = float(weapon.charge_drain_per_sec) * float(m.total_f()) / 60.0
			if inp.attack_held and not StaminaPool.is_exhausted and StaminaPool.spend(cost) and not StaminaPool.is_exhausted:
				start_move(str(m.id))
			else:
				charging_loop = false
				start_move(str(weapon.finisher_move))
			return
		if m.chain_to != "" and attack_buffered():
			attack_buf = -999.0
			start_move(m.chain_to)
		elif inp.attack_held and str(m.id) in weapon.string_moves:
			start_charge()
		else:
			cur_move = null
			go("locomote")

## Locked on: side hop (stick sideways) or backflip. Not locked: a roll toward the stick.
func try_dodge(mv: Vector2) -> bool:
	if not dodge_pressed():
		return false
	if not StaminaPool.spend(float(tuning.dodge_stamina)):
		return false
	dodge_buf = -999.0
	hitbox.close()
	cur_move = null
	charging_loop = false
	if lock_target == null:
		dodge_kind = "roll"
		var d: Vector3 = cam_dir(mv)
		dodge_dir = d.normalized() if d.length() > 0.2 else forward()
		yaw = atan2(-dodge_dir.x, -dodge_dir.z)
		go("dodge_roll")
		return true
	var side: bool = absf(mv.x) > 0.5 and absf(mv.x) >= absf(mv.y)
	if side:
		dodge_kind = "side"
		dodge_dir = right() * signf(mv.x)
		go("dodge_side")
	else:
		dodge_kind = "back"
		dodge_dir = -forward()
		go("dodge_back")
	check_perfect_dodge()
	return true

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
	if dodge_kind == "roll":
		return true
	return plane == "horizontal"

func start_flurry() -> void:
	attack_buf = -999.0
	flurry_left = int(weapon.flurry_hits)
	flurry_hits_landed = 0
	TimeDilation.slow(float(tuning.flurry_time_scale), 30.0)
	var t: Node3D = flurry_target
	var to: Vector3 = t.global_position - global_position
	to.y = 0.0
	yaw = atan2(-to.x, -to.z)
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
	wear(1.0)

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
	var iframes: float = float(jt.roll_iframes_f) if state == "dodge_roll" else float(tuning.dodge_iframes_f)
	if state in ["dodge_side", "dodge_back", "dodge_roll"] and state_f < iframes and dodge_beats(plane):
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
	if alive() and state not in ["climb", "glide"]:
		hitbox.close()
		cur_move = null
		charging_loop = false
		go("hurt")
	took.emit(info, "hit")
	return "hit"

# ---------------------------------------------------------------- look

func bow_pose(k: float) -> Dictionary:
	var p: Dictionary = P.idle(0.0, false)
	p["L_Upperarm"] = P.d(1, 0.05, -0.15)
	p["L_Forearm"] = P.d(1, 0.05, -0.05)
	p["R_Upperarm"] = P.d(0.6, 0.0, 0.5).slerp(P.d(-0.3, 0.1, 0.9), k)
	p["R_Forearm"] = P.d(1, 0.1, -0.4).slerp(P.d(0.6, 0.15, -0.8), k)
	p["Spine02"] = P.yaw(-0.5)
	return p

func thrust_pose(u: float) -> Dictionary:
	var p: Dictionary = P.idle(0.0, true)
	var k: float = sin(clampf(u * 1.4, 0.0, 1.0) * PI)
	p["R_Upperarm"] = P.d(0.2, -0.5, 0.6).slerp(P.d(1, 0.0, 0.1), k)
	p["R_Forearm"] = P.d(0.6, -0.3, 0.2).slerp(P.d(1, 0.05, 0.0), k)
	p["L_Upperarm"] = P.d(0.5, -0.6, -0.3).slerp(P.d(1, -0.1, 0.15), k)
	p["L_Forearm"] = P.d(0.8, 0.0, 0.3)
	p["blade"] = P.d(1, 0.05, 0.0)
	p["Spine01"] = P.lean(0.15 * k)
	p["L_Thigh"] = P.leg(0.35 * k, -0.18)
	p["R_Thigh"] = P.leg(-0.3 * k, 0.18)
	return p

func pose() -> Dictionary:
	if glider_node != null:
		glider_node.visible = state == "glide"
	rig.sheathed = sheathed or aiming
	if bow_node != null:
		bow_node.visible = aiming or state == "bow_draw"
	var tilt: float = 0.0
	if state == "skydive":
		tilt = -2.5 if diving() else -1.25
	elif state == "swim":
		tilt = -1.0 if Vector2(velocity.x, velocity.z).length() > 0.5 else -0.3
	rig.rotation.x = lerpf(rig.rotation.x, tilt, 0.15)
	if state == "surf":
		rig.shield_mode = "surf"
	elif sheathed or aiming:
		rig.shield_mode = "back"
	elif state in ["guard", "parry"]:
		rig.shield_mode = "guard"
	else:
		rig.shield_mode = "arm"
	var t: float = frames / 60.0
	var u: float = clampf(state_f / maxf(clip_len_f(), 1.0), 0.0, 1.0)
	if cur_move != null and state == str(cur_move.id):
		match str(cur_move.pose):
			"slash0":
				return P.slash(0, u)
			"slash1":
				return P.slash(1, u)
			"slash2":
				return P.slash(2, u)
			"spin":
				return P.spin(u)
			"th", "slam":
				return P.chop(u)
			"thrust":
				return thrust_pose(u)
	match state:
		"heavy_charge":
			return P.spin_ready(t)
		"guard", "parry":
			return P.shield_block(t)
		"dodge_side", "dodge_back", "dodge_roll":
			return P.crouch(0.0, 0.0)
		"hurt":
			return P.hurt(u)
		"stagger":
			return P.stagger(t)
		"dead":
			return P.dead()
		"glide":
			return P.glide(t)
		"climb":
			return P.climb(t * 4.0)
		"mantle":
			return P.pullup(u)
		"land_stun":
			return P.land(u)
		"skydive":
			return P.glide(t)
		"swim":
			return P.crawl(t * 5.0, clampf(Vector2(velocity.x, velocity.z).length() / 3.0, 0.2, 1.0))
		"surf":
			return P.surf(t)
		"tumble":
			return P.hurt(u)
		"bow_draw":
			return bow_pose(clampf(bow_draw_t / float(tt.bow_draw_s), 0.0, 1.0))
	if not is_on_floor():
		return P.airborne(vy)
	var sp: float = Vector2(velocity.x, velocity.z).length()
	if sp > 0.4:
		if crouched:
			return P.crouch(t * 8.0, sp / 3.0)
		return P.run_free(t * (6.0 + sp), clampf(sp / 6.0, 0.3, 1.0)) if sheathed else P.run(t * (6.0 + sp), clampf(sp / 6.0, 0.3, 1.0))
	if crouched:
		return P.crouch(0.0, 0.0)
	return P.idle_free(t) if sheathed else P.idle(t, true)
