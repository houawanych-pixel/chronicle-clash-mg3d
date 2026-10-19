extends SceneTree
func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0]
	await process_frame
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(1600, 900)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	get_root().add_child(vp)
	var world: Node3D = Node3D.new()
	vp.add_child(world)
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	var sm: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("4d8fe8"); sm.sky_horizon_color = Color("cfe3f7"); sm.ground_horizon_color = Color("e6eef7"); sm.ground_bottom_color = Color("f2f6fb")
	sky.sky_material = sm
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.4
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 0.7
	e.glow_enabled = false
	e.glow_intensity = 0.6
	env.environment = e
	world.add_child(env)
	var c: Node3D = (load("res://castle.glb") as PackedScene).instantiate()
	world.add_child(c)
	if "--nonormal" in args:
		for mi: MeshInstance3D in c.find_children("*", "MeshInstance3D", true, false):
			for i in mi.mesh.get_surface_count():
				var m: StandardMaterial3D = (mi.mesh.surface_get_material(i) as StandardMaterial3D).duplicate()
				m.normal_enabled = false
				mi.set_surface_override_material(i, m)
	if "--views1" in args:
		pass
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.light_energy = 0.5
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 400
	sun.rotation_degrees = Vector3(-40, 35, 0)
	world.add_child(sun)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 50
	cam.far = 2000
	world.add_child(cam)
	cam.current = true
	var views: Array = [
		["b0_front34", Vector3(110, 110, 170), Vector3(0, 78, 0)],
		["b1_back34", Vector3(-130, 120, -140), Vector3(0, 80, 0)],
		["b2_ring1", Vector3(52, 64, 38), Vector3(20, 60, 15)],
		["b3_crown", Vector3(30, 150, 50), Vector3(0, 128, -4)],
		["b4_core", Vector3(8, 111, 6), Vector3(-6, 106, -4)],
		["b5_low", Vector3(60, 20, 120), Vector3(0, 60, 0)],
	]
	for v: Array in views:
		cam.global_position = v[1]
		cam.look_at(v[2], Vector3.UP)
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s/%s.png" % [out, v[0]])
	quit()
