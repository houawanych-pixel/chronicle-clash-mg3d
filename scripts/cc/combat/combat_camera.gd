extends Camera3D
## Arena camera: follows the player over the shoulder; when locked on it sits behind the
## player on the player-to-target line and looks at the target, so the target stays centred.
## Trauma shake: hits add trauma, offset = trauma^2 x max, decays every second.

var player: Node3D
var cam_yaw: float = 0.0
var cam_pitch: float = 0.28
var dist: float = 4.2
var trauma: float = 0.0
var tuning: Resource
var look_drag: Vector2 = Vector2.ZERO
var shake_offset: Vector3 = Vector3.ZERO
var _noise_t: float = 0.0

func _ready() -> void:
	tuning = load("res://data/cc/combat/tuning.tres")
	CombatFx.shake_requested.connect(add_trauma)
	fov = 52.0
	current = true

func add_trauma(t: float) -> void:
	trauma = clampf(trauma + t, 0.0, 1.0)

func _process(dt: float) -> void:
	if player == null:
		return
	var target: Node3D = player.lock_target
	cam_yaw -= look_drag.x * 0.006
	cam_pitch = clampf(cam_pitch + look_drag.y * 0.004, 0.05, 0.9)
	look_drag = Vector2.ZERO
	var focus: Vector3 = player.global_position + Vector3.UP * 1.5
	if target != null:
		var to: Vector3 = target.global_position - player.global_position
		to.y = 0.0
		if to.length() > 0.1:
			cam_yaw = lerp_angle(cam_yaw, atan2(-to.x, -to.z), 1.0 - exp(-10.0 * dt))
	var back: Vector3 = Vector3(sin(cam_yaw), 0, cos(cam_yaw))
	var pos: Vector3 = focus + back * dist * cos(cam_pitch) + Vector3.UP * dist * sin(cam_pitch)
	global_position = pos
	if target != null:
		look_at(target.global_position + Vector3.UP * 1.1, Vector3.UP)
	else:
		look_at(focus + Vector3(-sin(cam_yaw), 0, -cos(cam_yaw)) * 3.0, Vector3.UP)
	player.cam_yaw = cam_yaw
	# trauma shake
	_noise_t += dt * 40.0
	var k: float = trauma * trauma
	shake_offset = Vector3(sin(_noise_t * 1.3), sin(_noise_t * 1.7 + 1.0), 0.0) * float(tuning.shake_max_offset) * k
	global_position += global_transform.basis * shake_offset
	rotation.z += deg_to_rad(float(tuning.shake_max_roll_deg)) * k * sin(_noise_t * 1.1)
	trauma = maxf(0.0, trauma - float(tuning.shake_decay) * dt)

## Angle (deg) between where the camera looks and the locked target (0 = dead centre).
func target_off_center_deg() -> float:
	if player == null or player.lock_target == null:
		return 999.0
	var to: Vector3 = (player.lock_target.global_position + Vector3.UP * 1.1 - global_position).normalized()
	return rad_to_deg((-global_transform.basis.z).angle_to(to))
