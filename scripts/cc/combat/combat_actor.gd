extends CharacterBody3D
## Shared base for CC combat fighters: procedural rig body, AnimationTree timing, hitbox,
## hurtbox, hitstop and stagger. Subclasses fill in brain().

signal impact(target: Node3D, info: Dictionary)
signal took(info: Dictionary, result: String)
signal died

const RigScript = preload("res://scripts/citadel/Rig.gd")
const P = preload("res://scripts/citadel/Poses.gd")
const CombatAnim = preload("res://scripts/cc/combat/combat_anim.gd")
const HitboxDriver = preload("res://scripts/cc/combat/hitbox_driver.gd")
const GRAVITY: float = 20.0
const HURTBOX_LAYER: int = 16

var tuning: Resource
var hp: float = 100.0
var max_hp: float = 100.0
var yaw: float = 0.0
var rig: Node3D
var tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback
var hitbox: Node3D
var hurtbox: Area3D
var facing_pivot: Node3D
var hitstop_left: float = 0.0     # frames
var stagger_left: float = 0.0     # frames
var cur_move: Resource            # melee_move.gd (or null)
var cur_info: Dictionary = {}     # the hit this swing will deliver
var frames: float = 0.0           # this actor's own combat clock, in 60 fps frames
var state: String = "locomote"
var state_f: float = 0.0
var height: float = 1.8
var flash: float = 0.0
var flash_color: Color = Color.WHITE
var last_impact: Dictionary = {}  # {frame, spark_frame, sound_frame, hitstop}
var is_player: bool = false
var own_vertical: bool = false    # the subclass sets vy itself (jumps, glide, climb)
var vy: float = 0.0

func _init() -> void:
	tuning = load("res://data/cc/combat/tuning.tres")

func setup_body(model: String, h: float, blade: Color, clips: Dictionary) -> void:
	height = h
	var cs: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.38 * h / 1.8
	cap.height = h
	cs.shape = cap
	cs.position.y = h * 0.5
	add_child(cs)
	collision_layer = 2
	collision_mask = 1 | 2
	floor_snap_length = 0.4
	facing_pivot = Node3D.new()
	facing_pivot.name = "Facing"
	add_child(facing_pivot)
	rig = Node3D.new()
	rig.set_script(RigScript)
	facing_pivot.add_child(rig)
	rig.setup(model, h, blade, 1.2, 0.5 if is_player else 0.15)
	hitbox = HitboxDriver.new()
	facing_pivot.add_child(hitbox)
	hitbox.touched.connect(_on_hitbox_touched)
	hurtbox = Area3D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = HURTBOX_LAYER
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	hurtbox.set_meta("actor", self)
	var hs: CollisionShape3D = CollisionShape3D.new()
	var hc: CapsuleShape3D = CapsuleShape3D.new()
	hc.radius = 0.42 * h / 1.8
	hc.height = h
	hs.shape = hc
	hs.position.y = h * 0.5
	hurtbox.add_child(hs)
	add_child(hurtbox)
	tree = CombatAnim.build(self, clips)
	playback = tree.get("parameters/playback")
	tree.advance(0.0)

func forward() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))

func right() -> Vector3:
	return Vector3(cos(yaw), 0, -sin(yaw))

func alive() -> bool:
	return hp > 0.0

func time_scale() -> float:
	return TimeDilation.scale(is_player)

## Switch the AnimationTree to a state right away (no blend), from the start of its clip.
func go(s: String) -> void:
	state = s
	state_f = 0.0
	playback.start(s, true)
	tree.advance(0.0)

func clip_pos_f() -> float:
	return playback.get_current_play_position() * 60.0

func clip_len_f() -> float:
	return playback.get_current_length() * 60.0

## hit_start / hit_end are called by the clip's method track.
func hit_start() -> void:
	if cur_move == null:
		return
	hitbox.configure(float(cur_move.reach_m), float(cur_move.radius_m), height * 0.6)
	hitbox.open()

func hit_end() -> void:
	hitbox.close()

func _on_hitbox_touched(hb: Area3D) -> void:
	var target: Node3D = hb.get_meta("actor") as Node3D
	if target == null or target == self or not target.alive() or cur_move == null:
		return
	if target.get("team") == get("team"):
		return
	var info: Dictionary = cur_info.duplicate()
	info["attacker"] = self
	info["from"] = global_position
	info["move"] = cur_move
	info = pre_hit(target, info)
	var result: String = target.take_hit(info)
	if result in ["hit", "guard"]:
		confirm_impact(target, info, result)

## The moment a hit connects: both freeze, a spark and a sound, the camera shakes.
func confirm_impact(target: Node3D, info: Dictionary, result: String) -> void:
	var f: int = Engine.get_physics_frames()
	var stop: float = float(info.get("hitstop_f", 5))
	if result == "guard":
		stop *= 0.6
	hitstop_left = stop
	target.hitstop_left = stop
	var at: Vector3 = (global_position + target.global_position) * 0.5 + Vector3.UP * height * 0.62
	CombatFx.spark(get_tree(), at, Color("ffd27a") if result == "hit" else Color("9fd8ff"), 18 if float(info.get("shake", 0.3)) < 0.6 else 34)
	CombatFx.sound(get_tree(), "hit" if result == "hit" else "knock", -4.0)
	CombatFx.shake(get_tree(), float(info.get("shake", 0.3)) * (0.6 if result == "guard" else 1.0))
	last_impact = {"frame": f, "spark_frame": f, "sound_frame": f, "hitstop": stop, "result": result}
	impact.emit(target, info)

## Override in subclasses. Returns "hit", "guard", "parry", "dodge" or "none".
func take_hit(info: Dictionary) -> String:
	return "none"

func apply_damage(amount: float, from: Vector3, knock: float) -> void:
	hp = maxf(0.0, hp - amount)
	flash = 1.0
	flash_color = Color.WHITE
	var away: Vector3 = global_position - from
	away.y = 0.0
	if away.length() > 0.01:
		velocity += away.normalized() * knock
	if hp <= 0.0:
		hitbox.close()
		go("dead")
		died.emit()

func _physics_process(dt: float) -> void:
	if tree == null:
		return
	var s: float = time_scale()
	if hitstop_left > 0.0:
		# hitstop: the clip, the body and the motion all hold still
		hitstop_left -= 1.0
		velocity = Vector3.ZERO
		return
	var cdt: float = dt * s
	frames += cdt * 60.0
	state_f += cdt * 60.0
	tree.advance(cdt)
	var rm: Vector3 = tree.get_root_motion_position()
	var move_v: Vector3 = brain(cdt)
	var world_rm: Vector3 = Basis(Vector3.UP, yaw) * rm
	var v: Vector3 = move_v * s
	if dt > 0.0:
		v += world_rm / dt
	velocity.x = lerpf(velocity.x, v.x, 0.6)
	velocity.z = lerpf(velocity.z, v.z, 0.6)
	if own_vertical:
		velocity.x = v.x
		velocity.z = v.z
		velocity.y = vy
	elif not is_on_floor():
		velocity.y -= GRAVITY * cdt
	else:
		velocity.y = -0.5
	move_and_slide()
	after_move(cdt)
	facing_pivot.rotation.y = yaw
	flash = maxf(0.0, flash - cdt * 5.0)
	rig.set_flash(flash * 0.6, flash_color)
	rig.apply(pose(), cdt)

## Override: change a hit just before it lands (break hits etc.).
func pre_hit(_target: Node3D, info: Dictionary) -> Dictionary:
	return info

## Override: after move_and_slide (landing checks).
func after_move(_cdt: float) -> void:
	pass

## Override: think for one step, return the wanted move velocity (m/s, world).
func brain(_cdt: float) -> Vector3:
	return Vector3.ZERO

## Override: the procedural pose for the current state.
func pose() -> Dictionary:
	return P.idle(frames / 60.0, true)
