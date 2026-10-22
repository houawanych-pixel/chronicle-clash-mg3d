extends RefCounted
## Hero traversal (Breath of the Wild-inspired, original code): sprinting with
## acceleration, ledge catching / shimmy / pull-up, a glider, slope sliding and
## the shared stamina rules (regen delay, exhaustion, low-stamina warning).
##
## The ledge probe (wall ray, then a downward ray onto the top, then head-room
## checks) follows the approach of Project White Deer (MIT, (c) 2024 @koboldskeep)
## and the glide/stamina drain idea follows Climb 'n' Glide (MIT, (c) 2022 Ashton
## McAllan). No code was copied; see licenses/THIRD_PARTY_MOVEMENT.md.
##
## Hero states added here (Fighter.state): "glide", "ledge", "pullup", "slide".
## Sprint is a flag, not a state, so every combat check that looks for "idle"
## (dodge, attack, block, charge) still works while sprinting.

const SettingsScript = preload("res://scripts/citadel/MoveSettings.gd")
const SETTINGS_PATH: String = "res://data/movement.tres"
const HANG_DROP: float = 1.95      # feet sit this far below the ledge top while hanging
const WALL_GAP: float = 0.42       # capsule radius + a little

var game: Node
var cfg: Resource
var sprinting: bool = false
var sprint_toggle: bool = false     # touch: tap SPRINT, it stays on while you keep moving
var still_t: float = 0.0
var exhausted: bool = false
var regen_wait: float = 0.0
var land_t: float = 0.0
var air_vy: float = 0.0              # last downward speed in the air (for landing)
var beep_t: float = 0.0
var ledge: Dictionary = {}
var pull: Dictionary = {}
var slide_air: float = 0.0
var push_up_t: float = 0.0
var glider: Node3D
var glider_on: float = 0.0           # 0..1 opening animation
var events: Array = []               # for tests: names of transitions, newest last

func _init(g: Node) -> void:
	game = g
	if ResourceLoader.exists(SETTINGS_PATH):
		cfg = load(SETTINGS_PATH)
	if cfg == null:
		cfg = SettingsScript.new()

func reset() -> void:
	sprinting = false
	sprint_toggle = false
	exhausted = false
	regen_wait = 0.0
	land_t = 0.0
	ledge = {}
	pull = {}
	glider = null   # the old hero (and its glider) is freed with the stage
	glider_on = 0.0
	events.clear()

## Ledges, the glider and slope sliding are on in the sky stages; sprint and
## acceleration work everywhere.
func enabled() -> bool:
	return game.stage == "citadel" or game.stage == "trials"

func slide_stage() -> bool:
	return game.stage == "trials"

func climb_stage() -> bool:
	return enabled()

func note(e: String) -> void:
	events.append(e)
	if events.size() > 40:
		events.pop_front()

# ---------------------------------------------------------------- stamina

func spend(amount: float) -> void:
	if amount <= 0.0:
		return
	game.stamina = maxf(0.0, game.stamina - amount)
	regen_wait = cfg.regen_delay
	if game.stamina <= 0.0 and not exhausted:
		exhausted = true
		note("exhausted")
		game.hud.popup("EXHAUSTED", Color("ff8a5a"))
		game.sound("fail", -16)

func low() -> bool:
	return game.stamina < cfg.stamina_max * cfg.low_warning

## Called once per hero tick (replaces the old fixed regen line).
func stamina_tick(f: CharacterBody3D, dt: float) -> void:
	var resting: bool = f.state != "block" and f.state not in ["wallclimb", "ledge", "pullup", "glide"] and not sprinting
	if resting and (f.is_on_floor() or not climb_stage()):
		if regen_wait > 0.0:
			regen_wait -= dt
		else:
			game.stamina = minf(cfg.stamina_max, game.stamina + dt * cfg.regen_rate)
	if exhausted and game.stamina >= cfg.stamina_max * cfg.exhausted_until:
		exhausted = false
		note("recovered")
	# heartbeat while low and working
	beep_t -= dt
	if low() and not resting and beep_t <= 0.0 and game.stamina > 0.0:
		beep_t = 0.55
		game.sound("bleep", -20)

# ---------------------------------------------------------------- ground

func sprint_wanted(f: CharacterBody3D, dir: Vector3) -> bool:
	if game.hud.take("sprint"):
		sprint_toggle = not sprint_toggle
	var key: bool = Input.is_action_pressed("cc_sprint")
	if dir.length() < 0.2:
		still_t += game.get_physics_process_delta_time()
		if still_t > 0.35:
			sprint_toggle = false
	else:
		still_t = 0.0
	if exhausted or game.stamina <= 0.0:
		sprint_toggle = false
		return false
	if game.crouched or game.prone or game.in_cover() or f.state != "idle":
		sprint_toggle = false
		return false
	return (key or sprint_toggle) and dir.length() > 0.5

## Free movement on the ground and in the air: accelerate toward the stick.
func ground_move(f: CharacterBody3D, dt: float, dir: Vector3, base_speed: float) -> void:
	var want: bool = sprint_wanted(f, dir)
	if f.is_on_floor():
		sprinting = want
	elif not want:
		sprinting = false
	var speed: float = cfg.sprint_speed if sprinting else base_speed
	if exhausted:
		speed = minf(speed, cfg.exhausted_speed)
	var target: Vector3 = dir.limit_length(1.0) * speed
	var cur: Vector3 = Vector3(f.velocity.x, 0, f.velocity.z)
	var rate: float
	if f.is_on_floor():
		rate = cfg.ground_accel if target.length() >= cur.length() - 0.05 else cfg.ground_decel
		if target.length() > 0.1 and cur.length() > 0.1 and target.normalized().dot(cur.normalized()) < -0.3:
			rate = cfg.ground_decel * 1.4   # quick turn-around
	else:
		rate = cfg.air_accel if dir.length() > 0.15 else cfg.air_accel * 0.35
	cur = cur.move_toward(target, rate * dt)
	f.velocity.x = cur.x
	f.velocity.z = cur.z
	if sprinting and f.is_on_floor():
		spend(cfg.sprint_drain * dt)

## Track landings for the landing pose.
func air_tick(f: CharacterBody3D, dt: float) -> void:
	land_t = maxf(0.0, land_t - dt)
	if not f.is_on_floor():
		air_vy = minf(air_vy, f.velocity.y)
	else:
		if air_vy < -9.0:
			land_t = clampf(-air_vy / 60.0, 0.12, 0.3)
			note("land")
		air_vy = 0.0

# ---------------------------------------------------------------- probes

func ray(from: Vector3, to: Vector3) -> Dictionary:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	return game.get_world_3d().direct_space_state.intersect_ray(q)

func ground_below(f: CharacterBody3D, depth: float) -> bool:
	var p: Vector3 = f.global_position + Vector3.UP * 0.2
	return not ray(p, p + Vector3.DOWN * (depth + 0.2)).is_empty()

## Look for a ledge in front of a point: a wall, then a walkable top within reach.
## Returns {} or {top_y, n, wall, collider}.
func probe_ledge(feet: Vector3, toward: Vector3) -> Dictionary:
	toward.y = 0
	if toward.length() < 0.1:
		return {}
	toward = toward.normalized()
	var hit: Dictionary = {}
	for h: float in [1.25, 0.9, 1.6]:
		hit = game.wall_ray_at(feet + Vector3.UP * h, toward, 0.95, true)
		if not hit.is_empty():
			break
	if hit.is_empty():
		return {}
	var n: Vector3 = hit.normal
	n.y = 0
	if n.length() < 0.2 or toward.dot(-n.normalized()) < 0.45:
		return {}
	n = n.normalized()
	var wall: Vector3 = hit.position
	# the top: straight down just inside the wall face
	var over: Vector3 = Vector3(wall.x, feet.y + cfg.ledge_reach + 0.35, wall.z) - n * 0.3
	var top: Dictionary = ray(over, over + Vector3.DOWN * (cfg.ledge_reach - 0.2))
	if top.is_empty() or (top.normal as Vector3).y < 0.6:
		return {}
	var top_y: float = (top.position as Vector3).y
	var rise: float = top_y - feet.y
	if rise < 0.55 or rise > cfg.ledge_reach:
		return {}
	# nothing above the ledge in front of the face (the wall really ends here)
	var above: Vector3 = Vector3(feet.x, top_y + 0.3, feet.z)
	if not ray(above, above - n * 1.0).is_empty():
		return {}
	# room to stand on top
	var stand: Vector3 = (top.position as Vector3) - n * 0.25 + Vector3.UP * 0.1
	if not ray(stand, stand + Vector3.UP * 1.7).is_empty():
		return {}
	return {"top_y": top_y, "n": n, "wall": wall, "collider": top.collider, "top": top.position}

# ---------------------------------------------------------------- states

## Runs before the wall climb / ladders / grapple. Returns true when it handled the hero.
func pre_tick(f: CharacterBody3D, dt: float, mv: Vector2, dir: Vector3, jump: bool, attack: bool) -> bool:
	air_tick(f, dt)
	update_glider(f, dt)
	if f.state != "idle":
		sprinting = false
	match f.state:
		"glide":
			return glide_tick(f, dt, dir, jump, attack)
		"ledge":
			return ledge_tick(f, dt, mv, jump)
		"pullup":
			return pull_tick(f, dt)
		"slide":
			return slide_tick(f, dt, dir, jump, attack)
		"wallclimb":
			if take_drop():
				f.state = "idle"
				f.velocity = game.wall_n * 2.0
				note("drop")
				return true
	if not enabled() or f.state != "idle":
		return false
	# catch a ledge while falling past it (pushing toward the wall)
	if not f.is_on_floor() and f.velocity.y < 1.5 and dir.length() > 0.3 and not exhausted and game.stamina > 0.0:
		var l: Dictionary = probe_ledge(f.global_position, dir)
		if not l.is_empty():
			start_ledge(f, l)
			return true
	# slide down floors that are too steep (only on authored slopes: the sky ruin's
	# rubble and stair meshes have steep bits that must not throw you off the route)
	if f.is_on_floor() and slide_stage():
		var n: Vector3 = f.get_floor_normal()
		if rad_to_deg(n.angle_to(Vector3.UP)) > cfg.slide_angle:
			f.state = "slide"
			f.state_t = 0.0
			slide_air = 0.0
			sprinting = false
			note("slide")
			return true
	return false

func take_drop() -> bool:
	return game.hud.take("dodge") or Input.is_action_just_pressed("cc_dodge")

## Free-movement jump: on the ground it's a normal jump; in the air it opens the glider.
func air_jump(f: CharacterBody3D) -> bool:
	if not enabled() or f.is_on_floor() or f.state != "idle":
		return false
	if f.velocity.y > 3.0:
		return false
	if exhausted or game.stamina <= 1.0:
		game.hud.popup("TOO TIRED TO GLIDE", Color("ff8a5a"))
		return false
	if ground_below(f, cfg.glide_min_height):
		return false
	f.state = "glide"
	f.state_t = 0.0
	sprinting = false
	note("glide")
	game.sound("hook", -10)
	game.say_once("glide_tip", "tip", "Gliding! Steer with the stick. JUMP closes the glider, ATTACK dives.")
	return true

func glide_tick(f: CharacterBody3D, dt: float, dir: Vector3, jump: bool, attack: bool) -> bool:
	if f.is_on_floor():
		close_glider(f, "landed")
		return true
	if jump or take_drop():
		close_glider(f, "closed")
		return true
	if attack:
		close_glider(f, "dive")
		f.set_state("plunge", 1.0)
		return true
	spend(cfg.glide_drain * dt)
	if game.stamina <= 0.0:
		close_glider(f, "tired")
		return true
	# a ledge in reach: grab it
	if dir.length() > 0.3:
		var l: Dictionary = probe_ledge(f.global_position, dir)
		if not l.is_empty():
			close_glider(f, "ledge")
			start_ledge(f, l)
			return true
		# a climbable wall ahead: let go and grab it (the wall climb picks it up)
		if climb_stage() and not game.wall_ray(f, 1.1, dir.normalized(), 0.95).is_empty():
			close_glider(f, "wall")
			return false
	f.velocity.y = move_toward(f.velocity.y, -cfg.glide_fall, 30.0 * dt)
	var cur: Vector3 = Vector3(f.velocity.x, 0, f.velocity.z)
	var target: Vector3 = dir.limit_length(1.0) * cfg.glide_speed
	if dir.length() < 0.2:
		var fw: Vector3 = cur.normalized() if cur.length() > 0.5 else f.forward()
		target = fw * maxf(cfg.glide_min_speed, minf(cur.length(), cfg.glide_speed))
	cur = cur.move_toward(target, cfg.glide_accel * dt)
	f.velocity.x = cur.x
	f.velocity.z = cur.z
	if cur.length() > 0.5:
		f.face_toward(f.global_position + cur, dt, 5.0)
	return true

func close_glider(f: CharacterBody3D, why: String) -> void:
	if f.state == "glide":
		f.state = "idle"
		f.state_t = 0.0
	note("glide_end:" + why)

func start_ledge(f: CharacterBody3D, l: Dictionary) -> void:
	var n: Vector3 = l.n
	var wall: Vector3 = l.wall
	var hang: Vector3 = Vector3(wall.x, l.top_y - HANG_DROP, wall.z) + n * WALL_GAP
	var rise: float = l.top_y - f.global_position.y
	ledge = {"n": n, "top_y": l.top_y, "collider": l.collider, "target": hang}
	if l.collider is Node3D:
		ledge["local"] = (l.collider as Node3D).to_local(hang)
	game.wall_n = n
	f.velocity = Vector3.ZERO
	sprinting = false
	push_up_t = 0.0
	if crouch_low(rise):
		# low ledge: vault straight up onto it
		start_pullup(f, l.top, n, 0.32)
		note("mantle")
		return
	f.state = "ledge"
	f.state_t = 0.0
	note("ledge")
	game.sound("step", -8)
	game.say_once("ledge_tip", "tip", "Hanging on a ledge! Push up (or JUMP) to climb up, left/right to shimmy, DODGE to drop.")

func crouch_low(rise: float) -> bool:
	return rise < 1.35

func ledge_point(f: CharacterBody3D) -> Vector3:
	if ledge.has("local") and is_instance_valid(ledge.collider):
		return (ledge.collider as Node3D).to_global(ledge.local)
	return ledge.target

func ledge_tick(f: CharacterBody3D, dt: float, mv: Vector2, jump: bool) -> bool:
	var n: Vector3 = ledge.n
	f.velocity = Vector3.ZERO
	f.yaw = atan2(n.x, n.z)
	var want: Vector3 = ledge_point(f)
	f.global_position = f.global_position.lerp(want, 1.0 - exp(-18.0 * dt))
	var right: Vector3 = Vector3.UP.cross(n).normalized()
	if right.dot(game.cam_right()) < 0:
		right = -right
	var up_in: float = -mv.y
	var side_in: float = mv.x
	spend(cfg.ledge_drain * dt * (2.0 if absf(side_in) > 0.2 else 1.0))
	if take_drop() or game.stamina <= 0.0:
		f.state = "idle"
		f.velocity = n * 1.5
		note("drop")
		if game.stamina <= 0.0:
			game.hud.popup("OUT OF STAMINA", Color("ffd36b"))
		return true
	push_up_t = push_up_t + dt if up_in > 0.5 else 0.0
	if jump or push_up_t > 0.18:
		var top: Vector3 = Vector3(f.global_position.x, ledge.top_y, f.global_position.z) - n * (WALL_GAP + 0.35)
		start_pullup(f, top, n, cfg.pullup_time)
		return true
	if up_in < -0.5 and climb_stage() and f.state_t > 0.25:
		# let go of the top and climb down the wall face
		f.state = "wallclimb"
		f.state_t = 0.0
		game.climb_leap = 0.0
		note("ledge_to_wall")
		return true
	if absf(side_in) > 0.2:
		var step: Vector3 = right * signf(side_in) * cfg.shimmy_speed * absf(side_in) * dt
		var next: Vector3 = want + step
		var l: Dictionary = probe_ledge(next, -n)
		if not l.is_empty() and absf(l.top_y - ledge.top_y) < 0.35:
			ledge.top_y = l.top_y
			var nn: Vector3 = l.n
			ledge.n = n.lerp(nn, 0.5).normalized()
			var hang: Vector3 = Vector3(next.x, l.top_y - HANG_DROP, next.z)
			ledge.target = hang
			ledge.collider = l.collider
			if l.collider is Node3D:
				ledge["local"] = (l.collider as Node3D).to_local(hang)
			else:
				ledge.erase("local")
			game.climb_phase += dt * 5.0
	return true

func start_pullup(f: CharacterBody3D, top: Vector3, n: Vector3, dur: float) -> void:
	pull = {"from": f.global_position, "to": top + Vector3.UP * 0.08 - n * 0.15, "n": n, "t": 0.0, "dur": dur, "mask": f.collision_mask}
	f.collision_mask = 0
	f.velocity = Vector3.ZERO
	f.state = "pullup"
	f.state_t = 0.0
	ledge = {}
	note("pullup")
	game.sound("step", -6)

func pull_tick(f: CharacterBody3D, dt: float) -> bool:
	pull.t += dt
	var u: float = clampf(pull.t / pull.dur, 0.0, 1.0)
	var from: Vector3 = pull.from
	var to: Vector3 = pull.to
	# up first, then over the lip
	var up_u: float = smoothstep(0.0, 0.65, u)
	var fw_u: float = smoothstep(0.45, 1.0, u)
	var p: Vector3 = Vector3(lerpf(from.x, to.x, fw_u), lerpf(from.y, to.y, up_u), lerpf(from.z, to.z, fw_u))
	f.global_position = p
	f.velocity = Vector3.ZERO
	f.yaw = atan2((pull.n as Vector3).x, (pull.n as Vector3).z)
	if u >= 1.0:
		f.collision_mask = pull.mask
		f.state = "idle"
		f.state_t = 0.0
		f.velocity = -(pull.n as Vector3) * 0.8
		note("pullup_done")
	return true

func slide_tick(f: CharacterBody3D, dt: float, dir: Vector3, jump: bool, attack: bool) -> bool:
	if not f.is_on_floor():
		slide_air += dt
		if slide_air > 0.25:
			f.state = "idle"
			note("slide_end:air")
			return false
	else:
		slide_air = 0.0
	var n: Vector3 = f.get_floor_normal() if f.is_on_floor() else Vector3.UP
	var steep: float = rad_to_deg(n.angle_to(Vector3.UP))
	if f.is_on_floor() and steep < cfg.slide_angle - 4.0:
		f.state = "idle"
		note("slide_end:flat")
		return false
	if jump and f.is_on_floor():
		var away: Vector3 = Vector3(n.x, 0, n.z).normalized()
		f.velocity = away * 4.0 + Vector3.UP * cfg.jump_speed * 0.75
		f.state = "idle"
		note("slide_jump")
		return true
	if attack or take_drop():
		f.state = "idle"
		return false
	var down: Vector3 = (Vector3.DOWN - n * n.dot(Vector3.DOWN))
	var flat: Vector3 = Vector3(down.x, 0, down.z)
	if flat.length() > 0.01:
		flat = flat.normalized()
	var cur: Vector3 = Vector3(f.velocity.x, 0, f.velocity.z)
	cur = cur.move_toward(flat * cfg.slide_max + dir * 2.5, cfg.slide_accel * dt)
	f.velocity.x = cur.x
	f.velocity.z = cur.z
	if cur.length() > 0.5:
		f.face_toward(f.global_position + cur, dt, 8.0)
	return true

# ---------------------------------------------------------------- glider model

## An original paraglider-style wing (cloth panels in Chronicle Clash colours),
## held by two lines from the hero's raised hands.
func make_glider(f: CharacterBody3D) -> void:
	glider = Node3D.new()
	glider.name = "Glider"
	var cloth: StandardMaterial3D = StandardMaterial3D.new()
	cloth.albedo_color = Color("2b6f9e")
	cloth.roughness = 0.8
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var trim: StandardMaterial3D = StandardMaterial3D.new()
	trim.albedo_color = Color("d8b45a")
	trim.metallic = 0.6
	trim.roughness = 0.4
	var panels: int = 7
	var tips: Array = []
	for i in panels:
		var a: float = lerpf(-0.85, 0.85, float(i) / (panels - 1))
		var mi: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(0.36, 0.03, 0.85)
		mi.mesh = bm
		mi.material_override = cloth if i % 2 == 0 else trim
		mi.position = Vector3(sin(a) * 1.15, 3.0 + (cos(a) - 1.0) * 0.55, 0.05)
		mi.rotation.z = -a * 0.85
		glider.add_child(mi)
		if i == 0 or i == panels - 1:
			tips.append(mi.position)
	for k in 2:
		var tip: Vector3 = tips[k]
		var hand: Vector3 = Vector3(signf(tip.x) * 0.2, 2.1, 0.0)
		line_between(glider, tip, hand, trim)
		line_between(glider, Vector3(tip.x * 0.45, 3.0 - 0.1, 0.05), hand, trim)
	glider.scale = Vector3.ONE * 0.01
	glider.visible = false
	f.add_child(glider)

func line_between(parent: Node3D, a: Vector3, b: Vector3, m: Material) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.01
	cm.bottom_radius = 0.01
	cm.height = a.distance_to(b)
	cm.radial_segments = 4
	mi.mesh = cm
	mi.material_override = m
	parent.add_child(mi)
	mi.position = (a + b) * 0.5
	var d: Vector3 = (b - a).normalized()
	mi.basis = Basis(Quaternion(Vector3.UP, d))

func update_glider(f: CharacterBody3D, dt: float) -> void:
	var open: bool = f.state == "glide"
	if glider == null or not is_instance_valid(glider):
		if not open:
			return
		make_glider(f)
	glider_on = move_toward(glider_on, 1.0 if open else 0.0, dt * (5.0 if open else 8.0))
	glider.visible = glider_on > 0.01
	glider.scale = Vector3.ONE * maxf(0.01, glider_on)
	glider.rotation.y = f.yaw
