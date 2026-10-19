extends SceneTree
## Orthographic guide views of the sky ruin at game size (2x, metres), all at the
## same scale and framing: godot --path . -s tools/ruin_ortho.gd -- /outdir
const SIZE: float = 150.0      # metres shown top to bottom in every view
const PX: int = 2048
func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	await process_frame
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(PX, PX)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	get_root().add_child(vp)
	var world: Node3D = Node3D.new()
	vp.add_child(world)
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.93, 0.93, 0.93)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	world.add_child(env)
	var ruin: Node3D = (load("res://assets/ruin/skyruin.glb") as PackedScene).instantiate()
	ruin.scale = Vector3.ONE * 142.7533
	ruin.position = Vector3(-0.1895, 69.9695, -0.3943)
	world.add_child(ruin)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.light_energy = 0.9
	world.add_child(key)
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = SIZE
	cam.near = 0.1
	cam.far = 1000.0
	world.add_child(cam)
	cam.current = true
	var c: Vector3 = Vector3(0, 70, 0)
	var views: Array = [
		["front", c + Vector3(0, 0, 300), Vector3.UP],
		["back", c + Vector3(0, 0, -300), Vector3.UP],
		["left", c + Vector3(-300, 0, 0), Vector3.UP],
		["right", c + Vector3(300, 0, 0), Vector3.UP],
		["top", c + Vector3(0, 300, 0), Vector3(0, 0, -1)],
		["bottom", c + Vector3(0, -300, 0), Vector3(0, 0, -1)],
	]
	for v: Array in views:
		cam.global_position = v[1]
		cam.look_at(c, v[2])
		key.global_transform = cam.global_transform
		key.rotate_object_local(Vector3.RIGHT, -0.35)
		key.rotate_object_local(Vector3.UP, 0.35)
		for i in 10:
			await process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s/%s.png" % [out, v[0]])
	quit()
