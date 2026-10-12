extends SceneTree
## Renders the character GLBs side by side and prints their skeletons.
## xvfb-run -a godot --path . --script tools/inspect_models.gd -- out.png
func _init() -> void:
	var root3d: Node3D = Node3D.new()
	get_root().add_child(root3d)
	var names: Array = ["lance", "blonde_lance", "eliza", "knight"]
	var x: float = -3.0
	for n: String in names:
		var scene: PackedScene = load("res://assets/characters/%s.glb" % n)
		var inst: Node3D = scene.instantiate()
		root3d.add_child(inst)
		inst.position = Vector3(x, 0, 0)
		inst.rotation_degrees.y = -90.0
		inst.scale = Vector3.ONE * 1.85
		x += 2.0
		var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
		var meshes: Array = inst.find_children("*", "MeshInstance3D", true, false)
		var aabb: AABB = (meshes[0] as MeshInstance3D).get_aabb()
		print("== ", n, " aabb ", aabb, " bones ", sk.get_bone_count(), " skel xform ", sk.global_transform.basis.get_scale())
		if false:
			for i in sk.get_bone_count():
				var g: Transform3D = sk.get_bone_global_rest(i)
				print("  ", i, " ", sk.get_bone_name(i), " parent ", sk.get_bone_parent(i), " pos ", g.origin.snapped(Vector3.ONE * 0.01))
	var cam: Camera3D = Camera3D.new()
	root3d.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.0, 6.5), Vector3(0, 0.9, 0))
	var light: DirectionalLight3D = DirectionalLight3D.new()
	root3d.add_child(light)
	light.rotation_degrees = Vector3(-30, 20, 0)
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.3, 0.35, 0.45)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = 0.7
	env.environment = e
	root3d.add_child(env)
	for i in 6:
		await process_frame
	var img: Image = get_root().get_texture().get_image()
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp/models.png"
	img.save_png(out)
	quit()
