extends RefCounted
## Guard patrol, vision cone, suspicion and noise investigation for the
## Citadel knights. Ported from the MG build's scripts/Guard.gd (tick,
## hear, update_cone) with the same numbers: 40° half-cone, suspicion
## +1.15/s while seen and -0.3/s when not, crouch x0.8 and crawl x0.5 range,
## INVESTIGATE -> SEARCH -> PATROL after a noise. "CALL" becomes an alarm
## that wakes nearby guards, and "CHASE" hands the knight to sword combat.
const Spatial = preload("res://scripts/StealthMath.gd")
const RANGE: float = 9.5
const HALF_ANGLE: float = 40.0
const CONE_SPREAD: float = 0.7

var game: Node

func _init(g: Node) -> void:
	game = g

func setup(e: CharacterBody3D, route: Array) -> void:
	e.stealth = true
	e.route = route
	e.route_i = 1 if route.size() > 1 else 0
	e.gstate = "PATROL"
	e.suspicion = 0.0
	if route.size() > 1:
		var dir: Vector2 = route[1] - route[0]
		e.yaw = atan2(-dir.x, -dir.y)
	var cone: MeshInstance3D = MeshInstance3D.new()
	cone.top_level = true
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(1, 0.7, 0.2, 0.16)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	cone.material_override = m
	e.add_child(cone)
	e.cone = cone

func point(n: Node3D) -> Vector2:
	return Vector2(n.global_position.x, n.global_position.z)

func hear(e: CharacterBody3D, at: Vector3) -> void:
	if not e.alive() or e.active:
		return
	e.last_known = at
	e.gstate = "INVESTIGATE"
	e.search_t = 5.0

func range_limit() -> float:
	var r: float = RANGE
	if game.prone:
		r *= 0.5
	elif game.crouched:
		r *= 0.8
	return r

func can_see(e: CharacterBody3D) -> bool:
	var hero: CharacterBody3D = game.hero
	if not hero.alive():
		return false
	var eye: Vector3 = e.global_position + Vector3.UP * 1.55
	var target: Vector3 = game.hero_target_point()
	var to_player: Vector3 = target - eye
	var flat: Vector3 = Vector3(to_player.x, 0, to_player.z)
	if to_player.length() > range_limit():
		return false
	if flat.length() > 0.7 and e.forward().dot(flat.normalized()) < cos(deg_to_rad(HALF_ANGLE)):
		return false
	return game.ray(eye, target).is_empty()

func tick(e: CharacterBody3D, dt: float) -> void:
	e.seeing = can_see(e)
	if e.seeing:
		e.suspicion = minf(1.0, e.suspicion + dt * 1.15)
		e.last_known = game.hero.global_position
		if e.suspicion >= 1.0:
			alarm(e)
			return
	else:
		e.suspicion = maxf(0.0, e.suspicion - dt * 0.3)
	var dest: Vector3 = e.global_position
	match e.gstate:
		"PATROL":
			var p: Vector2 = e.route[e.route_i]
			dest = Vector3(p.x, e.global_position.y, p.y)
		"INVESTIGATE":
			dest = e.last_known
		"SEARCH":
			e.search_t -= dt
			e.yaw += dt * 0.85
			if e.search_t <= 0:
				e.gstate = "PATROL"
	# Turn toward whatever is making them suspicious, as the old guards did.
	if e.suspicion > 0.35 and e.seeing:
		e.face_toward(game.hero.global_position, dt, 3.0)
		dest = e.global_position
	e.velocity.x = 0
	e.velocity.z = 0
	if e.gstate != "SEARCH":
		var flat: Vector2 = Vector2(dest.x, dest.z) - point(e)
		if flat.length() < 0.45:
			if e.gstate == "PATROL" and e.route.size() > 1:
				e.route_i = (e.route_i + 1) % e.route.size()
			elif e.gstate == "INVESTIGATE":
				e.gstate = "SEARCH"
				e.search_t = 5.0
		else:
			var d: Vector2 = flat.normalized()
			var speed: float = 1.55 if e.gstate == "PATROL" else 2.2
			e.velocity.x = d.x * speed
			e.velocity.z = d.y * speed
			e.face_toward(e.global_position + Vector3(d.x, 0, d.y), dt, 7.0)
	e.cone_t -= dt
	if e.cone_t <= 0:
		update_cone(e)
		e.cone_t = 0.12

func alarm(e: CharacterBody3D) -> void:
	## The old radio call: this guard and any guard within 14 m join the fight.
	game.alert_guard(e)
	for o: CharacterBody3D in game.enemies:
		if o != e and o.stealth and not o.active and o.alive() and o.global_position.distance_to(e.global_position) < 14.0:
			game.alert_guard(o)

func update_cone(e: CharacterBody3D) -> void:
	var cone: MeshInstance3D = e.cone
	if cone == null:
		return
	cone.visible = e.alive() and not e.active
	if not cone.visible or DisplayServer.get_name() == "headless":
		return
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var start: Vector3 = e.global_position + Vector3.UP * 0.09
	var r: float = range_limit()
	var fwd: Vector3 = e.forward()
	for i in range(20):
		var pts: Array = []
		for j in [i, i + 1]:
			var dir: Vector3 = fwd.rotated(Vector3.UP, lerpf(-CONE_SPREAD, CONE_SPREAD, float(j) / 20.0))
			var hit: Dictionary = game.ray(start + Vector3.UP * 0.8, start + Vector3.UP * 0.8 + dir * r)
			var end: Vector3 = hit.get("position", start + dir * r)
			end.y = start.y
			pts.append(end)
		mesh.surface_add_vertex(start)
		mesh.surface_add_vertex(pts[0])
		mesh.surface_add_vertex(pts[1])
	mesh.surface_end()
	cone.mesh = mesh
	var m: StandardMaterial3D = cone.material_override
	m.albedo_color = Color(1, 0.2, 0.3, 0.24) if e.seeing else Color(1, 0.68, 0.2, 0.15)
