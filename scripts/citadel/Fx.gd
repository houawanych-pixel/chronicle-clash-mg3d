extends RefCounted
## Hit effects in the style of the concept screens: crescent slash arcs,
## a bright impact star with a light flash, streaking sparks, a short
## freeze on heavy hits (hitstop), and a combo counter.
var game: Node3D
var star_tex: Texture2D
var hitstop_until: int = 0
var combo_hits: int = 0
var combo_t: float = 0.0

func _init(g: Node3D) -> void:
	game = g
	star_tex = make_star()

func make_star() -> Texture2D:
	var n: int = 128
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var dx: float = (x - n * 0.5) / (n * 0.5)
			var dy: float = (y - n * 0.5) / (n * 0.5)
			var r: float = sqrt(dx * dx + dy * dy)
			var core: float = clampf(1.0 - r * 2.2, 0, 1)
			var glow: float = pow(clampf(1.0 - r, 0, 1), 2.5) * 0.6
			# Four long spikes plus four short ones.
			var spike: float = maxf(clampf(1.0 - absf(dx) * 22.0, 0, 1) * clampf(1.0 - absf(dy), 0, 1), clampf(1.0 - absf(dy) * 22.0, 0, 1) * clampf(1.0 - absf(dx), 0, 1))
			var u: float = (dx + dy) * 0.7071
			var v: float = (dx - dy) * 0.7071
			var spike2: float = maxf(clampf(1.0 - absf(u) * 26.0, 0, 1) * clampf(1.0 - absf(v) * 1.6, 0, 1), clampf(1.0 - absf(v) * 26.0, 0, 1) * clampf(1.0 - absf(u) * 1.6, 0, 1)) * 0.6
			var a: float = clampf(core + glow + spike + spike2, 0, 1)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

func additive(color: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.albedo_color = color
	m.disable_receive_shadows = true
	return m

## Crescent arc across the target. tilt 0 = flat sweep, PI/2 = overhead chop.
func slash(center: Vector3, forward: Vector3, color: Color, radius: float = 1.5, tilt: float = 0.25, flip: bool = false) -> void:
	var f: Vector3 = Vector3(forward.x, 0, forward.z).normalized()
	if f.length() < 0.1:
		f = Vector3.FORWARD
	var side: Vector3 = f.cross(Vector3.UP).normalized().rotated(f, tilt)
	if flip:
		side = -side
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs: int = 24
	var rows: Array = []
	for i in segs + 1:
		var t: float = float(i) / segs
		var ang: float = lerpf(-1.35, 1.35, t)
		# Thick in the middle, thin at the tips, brightest at the leading end.
		var w: float = pow(sin(t * PI), 0.7) * radius * 0.42
		var dir: Vector3 = f * cos(ang) + side * sin(ang)
		var lead: float = 0.35 + 0.65 * t
		var glow: Color = color
		glow.a = 0.0
		var edge: Color = color.lerp(Color.WHITE, 0.1)
		edge.a = 0.85 * lead
		var core: Color = Color.WHITE
		core.a = lead
		var mid: Color = color.lerp(Color.WHITE, 0.15)
		mid.a = 0.75 * lead
		var clear: Color = color
		clear.a = 0.0
		rows.append([[dir * (radius + w * 0.12), glow], [dir * radius, edge], [dir * (radius - w * 0.08), core], [dir * (radius - w * 0.4), mid], [dir * (radius - w), clear]])
	for i in segs:
		for k in 4:
			var a0: Array = rows[i][k]
			var a1: Array = rows[i][k + 1]
			var b0: Array = rows[i + 1][k]
			var b1: Array = rows[i + 1][k + 1]
			for v: Array in [a0, b0, a1, a1, b0, b1]:
				mesh.surface_set_color(v[1])
				mesh.surface_add_vertex(v[0])
	mesh.surface_end()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m: StandardMaterial3D = additive(Color(1, 1, 1, 1))
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	mi.material_override = m
	game.add_child(mi)
	# A second, additive copy makes the arc glow on dark backgrounds.
	var glow_mi: MeshInstance3D = MeshInstance3D.new()
	glow_mi.mesh = mesh
	glow_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var gm: StandardMaterial3D = additive(Color(1, 1, 1, 0.9))
	glow_mi.material_override = gm
	mi.add_child(glow_mi)
	mi.global_position = center - f * radius * 0.8
	mi.scale = Vector3.ONE * 0.75
	var tw: Tween = mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 1.18, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.24).set_delay(0.05)
	tw.tween_property(gm, "albedo_color:a", 0.0, 0.2).set_delay(0.03)
	tw.chain().tween_callback(mi.queue_free)

func impact(pos: Vector3, color: Color, size: float = 1.2, light: bool = true) -> void:
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2.ONE
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = q
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = star_tex
	m.albedo_color = color.lerp(Color.WHITE, 0.4)
	m.no_depth_test = true
	mi.material_override = m
	size *= 1.8
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game.add_child(mi)
	mi.global_position = pos
	mi.rotation.z = randf() * TAU
	mi.scale = Vector3.ONE * size * 0.35
	var tw: Tween = mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * size, 0.09).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.2).set_delay(0.06)
	tw.chain().tween_callback(mi.queue_free)
	if light:
		var l: OmniLight3D = OmniLight3D.new()
		l.light_color = color
		l.light_energy = 3.0
		l.omni_range = 4.5
		game.add_child(l)
		l.global_position = pos
		var tl: Tween = l.create_tween()
		tl.tween_property(l, "light_energy", 0.0, 0.18)
		tl.tween_callback(l.queue_free)

func sparks(pos: Vector3, color: Color, count: int = 22, speed: float = 9.0, dir: Vector3 = Vector3.ZERO) -> void:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = count
	p.lifetime = 0.38
	p.explosiveness = 1.0
	p.direction = dir.normalized() if dir.length() > 0.1 else Vector3.UP
	p.spread = 70.0 if dir.length() > 0.1 else 180.0
	p.initial_velocity_min = speed * 0.45
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -14, 0)
	p.particle_flag_align_y = true
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.4
	p.damping_min = 6.0
	p.damping_max = 10.0
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(color.r, color.g, color.b, 0))
	p.color_ramp = ramp
	var qm: BoxMesh = BoxMesh.new()
	qm.size = Vector3(0.035, 0.38, 0.035)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	qm.material = m
	p.mesh = qm
	game.add_child(p)
	p.global_position = pos
	p.emitting = true
	game.get_tree().create_timer(1.0).timeout.connect(p.queue_free)

## Brief freeze that sells the weight of a hit. Real-time, so it never sticks.
func hitstop(seconds: float) -> void:
	if game.autotest != null:
		return
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	hitstop_until = maxi(hitstop_until, until)
	Engine.time_scale = 0.06
	game.get_tree().create_timer(seconds, true, false, true).timeout.connect(func() -> void:
		if Time.get_ticks_msec() >= hitstop_until - 2:
			Engine.time_scale = 1.0)

func count_hit() -> void:
	combo_hits = combo_hits + 1 if combo_t > 0.0 else 1
	combo_t = 1.6

func tick(dt: float) -> void:
	combo_t = maxf(0.0, combo_t - dt)
	if combo_t <= 0.0:
		combo_hits = 0

## Everything for one sword hit on an enemy.
func sword_hit(attacker: Node3D, target: Node3D, color: Color, heavy: bool, step: int) -> void:
	var h: float = target.height
	var at: Vector3 = target.global_position + Vector3.UP * h * 0.58
	var fwd: Vector3 = target.global_position - attacker.global_position
	var tilt: float = [0.85, -0.9, 1.4][clampi(step, 0, 2)]
	slash(at, fwd, color, 1.25 + h * 0.12 + (0.35 if heavy else 0.0), tilt, step == 1)
	impact(at - fwd.normalized() * 0.3, color, 1.5 if heavy else 1.0)
	sparks(at, Color("ffd27a"), 26 if heavy else 16, 10.0 if heavy else 7.5, fwd.normalized() + Vector3.UP * 0.4)
	count_hit()
	hitstop(0.085 if heavy else 0.045)
