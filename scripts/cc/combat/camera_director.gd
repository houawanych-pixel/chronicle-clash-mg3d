extends Node3D
## CameraDirector: Explore / LockOn / BowADS / Glide / Ride / Climb (numbers in
## res://data/cc/combat/camera_tuning.tres). A SpringArm3D probes from the shoulder pivot
## back toward the wanted camera spot; the camera sits at the arm's hit length, so it never
## ends up inside walls or pillars. Lock-on aims the rig at the target and looks at it, so
## the target stays centred. Modes blend (distance, height, FOV, shoulder) in about 0.2 s.
## Hits add trauma shake.

var player: Node3D
var camera: Camera3D
var pitch_pivot: Node3D
var arm: SpringArm3D
var ct: Resource
var tuning: Resource
var cam_yaw: float = 0.0
var cam_pitch: float = 0.28
var mode: String = "explore"
var cur: Dictionary = {"dist": 4.2, "height": 1.6, "fov": 52.0, "shoulder": 0.45, "pitch": 0.0}
var look_drag: Vector2 = Vector2.ZERO
var idle_look_t: float = 0.0
var trauma: float = 0.0
var _noise_t: float = 0.0

func _ready() -> void:
	ct = load("res://data/cc/combat/camera_tuning.tres")
	tuning = load("res://data/cc/combat/tuning.tres")
	pitch_pivot = Node3D.new()
	add_child(pitch_pivot)
	arm = SpringArm3D.new()
	arm.collision_mask = 1
	var s: SphereShape3D = SphereShape3D.new()
	s.radius = float(ct.probe_radius)
	arm.shape = s
	arm.margin = 0.05
	pitch_pivot.add_child(arm)
	camera = Camera3D.new()
	camera.current = true
	add_child(camera)
	camera.top_level = true
	CombatFx.shake_requested.connect(add_trauma)

func set_player(p: Node3D) -> void:
	player = p
	arm.clear_excluded_objects()
	arm.add_excluded_object(p.get_rid())

func add_trauma(t: float) -> void:
	trauma = clampf(trauma + t, 0.0, 1.0)

func pick_mode() -> String:
	if player.riding:
		return "ride"
	match str(player.state):
		"glide":
			return "glide"
		"climb", "mantle":
			return "climb"
	if player.aiming:
		return "ads"
	if player.lock_target != null:
		return "lock"
	return "explore"

func _physics_process(dt: float) -> void:
	update_cam(dt)

func _process(dt: float) -> void:
	update_cam(0.0)
	trauma = maxf(0.0, trauma - float(tuning.shake_decay) * dt)

func update_cam(dt: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	if dt > 0.0:
		mode = pick_mode()
		var want: Dictionary = ct.modes[mode]
		var k: float = 1.0 - exp(-float(ct.blend_rate) * dt)
		for key: String in cur:
			cur[key] = lerpf(float(cur[key]), float(want[key]), k)
		# look drag always turns the view (also while gliding or riding)
		if look_drag.length() > 0.0:
			idle_look_t = 0.0
		else:
			idle_look_t += dt
		cam_yaw -= look_drag.x * 0.006
		cam_pitch = clampf(cam_pitch + look_drag.y * 0.004, -0.3, 0.9)
		look_drag = Vector2.ZERO
		var tgt: Node3D = player.lock_target
		if tgt != null:
			var to: Vector3 = tgt.global_position - player.global_position
			to.y = 0.0
			if to.length() > 0.1:
				cam_yaw = lerp_angle(cam_yaw, atan2(-to.x, -to.z), 1.0 - exp(-12.0 * dt))
		elif mode in ["explore", "glide", "ride"] and idle_look_t > float(ct.recenter_after_s):
			var v: Vector3 = player.velocity
			v.y = 0.0
			if v.length() > 2.0:
				cam_yaw = lerp_angle(cam_yaw, atan2(-v.x, -v.z), 1.0 - exp(-1.5 * dt))
		elif mode == "ads":
			pass
	global_position = player.global_position + Vector3.UP * float(cur.height)
	rotation = Vector3(0, cam_yaw, 0)
	pitch_pivot.rotation = Vector3(-(cam_pitch + float(cur.pitch)), 0, 0)
	arm.position = Vector3(float(cur.shoulder), 0, 0)
	arm.spring_length = float(cur.dist)
	var len: float = arm.get_hit_length()
	if len <= 0.0:
		len = float(cur.dist)
	var pos: Vector3 = arm.global_transform * Vector3(0, 0, len)
	camera.global_position = pos
	camera.fov = float(cur.fov)
	var tgt2: Node3D = player.lock_target
	if tgt2 != null and mode == "lock":
		camera.look_at(tgt2.global_position + Vector3.UP * 1.1, Vector3.UP)
	else:
		var ahead: Vector3 = arm.global_transform * Vector3(0, 0, -6.0)
		camera.look_at(ahead, Vector3.UP)
	player.cam_yaw = cam_yaw
	# trauma shake (offset and roll from trauma squared)
	_noise_t += 0.6
	var tk: float = trauma * trauma
	camera.global_position += camera.global_transform.basis * Vector3(sin(_noise_t * 1.3), sin(_noise_t * 1.7 + 1.0), 0.0) * float(tuning.shake_max_offset) * tk
	camera.rotation.z += deg_to_rad(float(tuning.shake_max_roll_deg)) * tk * sin(_noise_t * 1.1)

func arm_length() -> float:
	return camera.global_position.distance_to(arm.global_position)

func target_off_center_deg() -> float:
	if player == null or player.lock_target == null:
		return 999.0
	var to: Vector3 = (player.lock_target.global_position + Vector3.UP * 1.1 - camera.global_position).normalized()
	return rad_to_deg((-camera.global_transform.basis.z).angle_to(to))
