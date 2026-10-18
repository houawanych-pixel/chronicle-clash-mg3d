extends SceneTree
## Renders each village kit building from a 3/4 front view and prints its size in metres.
## godot --path . -s tools/render_kit.gd -- --out=/dir
const NAMES: Array = ["b12", "b01", "b21", "b22", "b15", "b23", "b13", "b17", "b14", "b06", "b20"]
const SCALE: float = 58.0
func _init() -> void:
	var out: String = "/tmp/kit"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var kit: Node3D = (load("res://assets/village/village_kit.glb") as PackedScene).instantiate()
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(900, 900)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(vp)
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("dfe6ee")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.85, 0.9)
	e.ambient_light_energy = 0.7
	env.environment = e
	vp.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	vp.add_child(sun)
	var cam: Camera3D = Camera3D.new()
	vp.add_child(cam)
	for n: String in NAMES:
		var src: Node3D = kit.find_child(n, true, false)
		if src == null:
			print("missing ", n)
			continue
		var b: Node3D = src.duplicate()
		b.transform = Transform3D.IDENTITY
		b.scale = Vector3.ONE * SCALE
		vp.add_child(b)
		await process_frame
		var aabb: AABB = AABB()
		var first: bool = true
		var meshes: Array = b.find_children("*", "MeshInstance3D", true, false)
		if b is MeshInstance3D:
			meshes.append(b)
		for m: MeshInstance3D in meshes:
			var bb: AABB = m.global_transform * m.get_aabb()
			aabb = bb if first else aabb.merge(bb)
			first = false
		var c: Vector3 = aabb.get_center()
		var r: float = aabb.size.length() * 0.62
		cam.look_at_from_position(c + Vector3(0.55, 0.35, 1.0).normalized() * r * 2.0, c)
		cam.fov = 45
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s/%s.png" % [out, n])
		print("KIT %s size_m w=%.1f d=%.1f h=%.1f" % [n, aabb.size.x, aabb.size.z, aabb.size.y])
		b.queue_free()
		await process_frame
	quit()
