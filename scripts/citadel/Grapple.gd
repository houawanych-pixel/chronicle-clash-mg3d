extends RefCounted
## Grappling hook (Sky Citadel). Tap HOOK (G, or hold LT on a pad) to aim: the
## camera moves in over the shoulder, a crosshair shows, and the right side of
## the screen becomes an aim stick (right analog stick on a pad, mouse drag on
## desktop). FIRE (the ATTACK button, E, J or RT) shoots the hook along the
## crosshair. It latches onto stone (walls, ledges, floating platforms) and
## pulls the hero in: on a wall he ends up climbing, on a ledge he lands on it.
## Gates can't be hooked.

const RANGE: float = 28.0
const PULL_SPEED: float = 19.0
const SHOOT_SPEED: float = 70.0
const COST: float = 10.0

var game: Node
var aiming: bool = false
var blend: float = 0.0           # 0 = normal camera, 1 = aim camera
var aim_pitch: float = 0.15       # up is positive
var target: Dictionary = {}       # current crosshair hit (valid or not)
var shot: Dictionary = {}         # {anchor, normal, out, t, pulling}
var rope: MeshInstance3D
var head: MeshInstance3D
var lt_prev: bool = false
var rt_prev: bool = false

func _init(g: Node) -> void:
	game = g

func reset() -> void:
	aiming = false
	blend = 0.0
	shot = {}
	target = {}
	if is_instance_valid(rope):
		rope.visible = false
		head.visible = false

func available() -> bool:
	return game.stage == "citadel"

func ensure_nodes() -> void:
	if is_instance_valid(rope):
		return
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color("d8b45a")
	m.emission_enabled = true
	m.emission = Color("ffcf6a")
	m.emission_energy_multiplier = 1.2
	rope = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.03
	cyl.bottom_radius = 0.03
	cyl.height = 1.0
	cyl.radial_segments = 6
	cyl.rings = 1
	rope.mesh = cyl
	rope.material_override = m
	rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game.add_child(rope)
	head = MeshInstance3D.new()
	var pr: PrismMesh = PrismMesh.new()
	pr.size = Vector3(0.32, 0.42, 0.12)
	head.mesh = pr
	var hm: StandardMaterial3D = StandardMaterial3D.new()
	hm.albedo_color = Color("6fe0ff")
	hm.emission_enabled = true
	hm.emission = Color("6fe0ff")
	hm.emission_energy_multiplier = 2.0
	head.material_override = hm
	game.add_child(head)
	rope.visible = false
	head.visible = false

## Aim direction from the camera yaw and the aim pitch.
func aim_dir() -> Vector3:
	var f: Vector3 = game.cam_forward()
	return (f * cos(aim_pitch) + Vector3.UP * sin(aim_pitch)).normalized()

func hand(f: CharacterBody3D) -> Vector3:
	return f.global_position + Vector3.UP * 1.35 + game.cam_right() * 0.25 + f.forward() * 0.3

## What the crosshair is on: a ray from the camera through the screen centre.
func probe() -> Dictionary:
	var cam: Camera3D = game.camera
	var from: Vector3 = cam.global_position
	var dir: Vector3 = -cam.global_transform.basis.z
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + dir * (RANGE + 4.0), 1)
	q.exclude = [game.hero.get_rid()]
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return {"ok": false, "pos": from + dir * RANGE}
	var c: Object = hit.collider
	var ok: bool = true
	if c is CharacterBody3D:
		ok = false
	if c is Node and (c as Node).get_parent() in game.barriers:
		ok = false
	var p: Vector3 = hit.position
	if p.distance_to(game.hero.global_position + Vector3.UP * 1.3) > RANGE:
		ok = false
	if (hit.normal as Vector3).y < -0.6:
		ok = false   # ceilings: nothing to stand or climb on
	return {"ok": ok, "pos": p, "normal": hit.normal, "collider": c}

## Called from hero_tick. Returns true while the hook owns the hero.
func tick(f: CharacterBody3D, dt: float, mv: Vector2, dir: Vector3, attack: bool, jump: bool) -> bool:
	if not available():
		return false
	ensure_nodes()
	var toggle: bool = game.hud.take("hook") or Input.is_action_just_pressed("cc_aim")
	var fire: bool = Input.is_action_just_pressed("cc_fire")
	# gamepad triggers: hold LT to aim, RT fires
	var lt: bool = Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT) > 0.5
	var rt: bool = Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.5
	if lt and not lt_prev:
		toggle = not aiming or toggle
	if not lt and lt_prev and aiming:
		toggle = true
	if rt and not rt_prev:
		fire = true
	lt_prev = lt
	rt_prev = rt
	if game.mode != "play":
		toggle = false
		fire = false
	if not shot.is_empty():
		return pull_tick(f, dt)
	if toggle and not aiming and f.state in ["idle", "block"]:
		start_aim(f)
	elif toggle and aiming:
		stop_aim()
	if not aiming:
		blend = move_toward(blend, 0.0, dt / 0.18)
		return false
	blend = move_toward(blend, 1.0, dt / 0.18)
	if f.state not in ["idle", "block"] or not f.alive() or game.hud.take("dodge"):
		stop_aim()
		return false
	# aim: right stick / right-side aim stick / mouse drag (cam_yaw is turned in update_camera)
	f.state = "idle"
	f.yaw = game.cam_yaw
	f.velocity.x = dir.x * 2.2
	f.velocity.z = dir.z * 2.2
	target = probe()
	if jump and f.is_on_floor():
		f.velocity.y = 9.6
	if fire or attack or game.hud.take("fire"):
		shoot(f)
	return true

func start_aim(f: CharacterBody3D) -> void:
	aiming = true
	# start level with where the camera was looking
	aim_pitch = clampf(-(game.cam_pitch - 0.2) * 0.6, -0.9, 1.25)
	if game.crouched:
		game.set_crouch(false)
	game.sound("bleep", -14)
	game.say_once("hook_tip", "tip", "Aim with the right stick (or drag the right side). FIRE to hook stone and pull yourself in.")

func stop_aim() -> void:
	aiming = false
	target = {}

## Turn the aim from look input (called by update_camera while aiming).
func aim_turn(d_yaw: float, d_pitch: float) -> void:
	game.cam_yaw -= d_yaw
	aim_pitch = clampf(aim_pitch + d_pitch, -1.0, 1.3)

func shoot(f: CharacterBody3D) -> void:
	var t: Dictionary = probe()
	shot = {"anchor": t.pos, "normal": t.get("normal", Vector3.UP), "ok": t.ok, "out": 0.0, "t": 0.0, "pulling": false, "best": INF, "stall": 0.0,
		"len": hand(f).distance_to(t.pos), "back": false}
	aiming = false
	game.stamina = maxf(0.0, game.stamina - COST)
	f.state = "grapple"
	f.state_t = 0.0
	f.velocity = Vector3(0, minf(f.velocity.y, 0.0) * 0.2, 0)
	game.sound("hook", -6)

## Where the hero's feet should end up for a given anchor and surface.
func goal_for(anchor: Vector3, n: Vector3) -> Vector3:
	if n.y > 0.55:
		return anchor + Vector3.UP * 0.15
	var flat: Vector3 = Vector3(n.x, 0, n.z).normalized()
	return anchor + flat * 0.45 - Vector3.UP * 1.25

func pull_tick(f: CharacterBody3D, dt: float) -> bool:
	shot.t += dt
	blend = move_toward(blend, 0.0, dt / 0.25)
	var h: Vector3 = hand(f)
	var anchor: Vector3 = shot.anchor
	if not shot.pulling:
		# the hook flies out (or back in after a miss)
		if not shot.back:
			shot.out = minf(shot.len, shot.out + SHOOT_SPEED * dt)
			if shot.out >= shot.len:
				if shot.ok:
					shot.pulling = true
					game.burst(anchor, Color("6fe0ff"), 14, 3.0)
					game.sound("chip", -8)
				else:
					shot.back = true
		else:
			shot.out = maxf(0.0, shot.out - SHOOT_SPEED * dt)
			if shot.out <= 0.0:
				end(f)
				f.state = "idle"
				return false
		f.velocity.x = 0
		f.velocity.z = 0
		f.velocity.y = maxf(f.velocity.y - 20.0 * dt, -6.0)
		draw_rope(h, h + (anchor - h).normalized() * shot.out)
		return true
	# pulled in along the rope
	var goal: Vector3 = goal_for(anchor, shot.normal)
	var to: Vector3 = goal - f.global_position
	var d: float = to.length()
	f.velocity = to.normalized() * minf(PULL_SPEED, d / maxf(dt, 0.001))
	f.yaw = atan2(-to.x, -to.z) if Vector2(to.x, to.z).length() > 0.3 else f.yaw
	draw_rope(h, anchor)
	if d < shot.best - 0.05:
		shot.best = d
		shot.stall = 0.0
	else:
		shot.stall += dt
	if d < 0.35 or shot.stall > 0.3 or shot.t > 3.5:
		arrive(f)
	return true

func arrive(f: CharacterBody3D) -> void:
	var n: Vector3 = shot.normal
	end(f)
	f.velocity = Vector3.ZERO
	if n.y <= 0.55:
		# on a wall: hang on and climb
		var wn: Vector3 = Vector3(n.x, 0, n.z).normalized()
		if game.wall_ray(f, 1.2, -wn, 1.4).is_empty() and game.wall_ray(f, 0.6, -wn, 1.4).is_empty():
			# nothing to hold (thin edge): a little hop up instead
			f.state = "idle"
			f.velocity = Vector3.UP * 6.0 - wn * 2.0
			return
		game.wall_n = wn
		game.climb_leap = 0.0
		game.stamina = maxf(game.stamina, 30.0)
		f.state = "wallclimb"
		f.state_t = 0.0
		game.say_once("hook_climb", "tip", "Hooked on! Climb up, or JUMP to leap.")
	else:
		f.state = "idle"
		f.velocity = Vector3.UP * 3.0
	f.state_t = 0.0

func end(_f: CharacterBody3D) -> void:
	shot = {}
	rope.visible = false
	head.visible = false

func draw_rope(a: Vector3, b: Vector3) -> void:
	var v: Vector3 = b - a
	var l: float = v.length()
	if l < 0.05:
		rope.visible = false
		head.visible = false
		return
	rope.visible = true
	head.visible = true
	var y: Vector3 = v / l
	var x: Vector3 = y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z: Vector3 = x.cross(y)
	rope.global_transform = Transform3D(Basis(x, y * l, z), (a + b) * 0.5)
	head.global_transform = Transform3D(Basis(x, y, z), b)
