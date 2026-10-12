extends SceneTree
## Side view of the stealth stances (crouch, crawl, wall hug) on the hero rig.
const RigScript = preload("res://scripts/citadel/Rig.gd")
const P = preload("res://scripts/citadel/Poses.gd")
func _init() -> void:
	var root3d: Node3D = Node3D.new()
	get_root().add_child(root3d)
	var jobs: Array = [[P.crouch(0.0, 0.0), 0.0, -0.34], [P.crouch(1.2, 1.0), 0.0, -0.34], [P.crawl(0.0, 0.0), -1.42, 0.22], [P.crawl(1.5, 1.0), -1.42, 0.22], [P.hug(1.0, false, false), 0.0, 0.0], [P.hug(1.0, false, true), 0.0, 0.0]]
	var rigs: Array = []
	var x: float = -6.0
	for j: Array in jobs:
		var holder: Node3D = Node3D.new()
		root3d.add_child(holder)
		holder.position = Vector3(x, 0, 0)
		holder.rotation.y = PI / 2.0
		var r: Node3D = Node3D.new()
		r.set_script(RigScript)
		holder.add_child(r)
		r.setup("res://assets/characters/blonde_lance.glb", 1.8, Color("8fe9ff"), 1.05, 1.0)
		r.rotation.x = j[1]
		r.position.y = j[2]
		rigs.append([r, j[0]])
		x += 2.4
	var floor_mi: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(30, 6)
	floor_mi.mesh = pm
	root3d.add_child(floor_mi)
	var cam: Camera3D = Camera3D.new()
	root3d.add_child(cam)
	cam.fov = 40
	cam.look_at_from_position(Vector3(0, 1.4, 12), Vector3(0, 0.7, 0))
	var light: DirectionalLight3D = DirectionalLight3D.new()
	root3d.add_child(light)
	light.rotation_degrees = Vector3(-35, 25, 0)
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.25, 0.3, 0.4)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = 0.8
	env.environment = e
	root3d.add_child(env)
	for i in 30:
		for pair: Array in rigs:
			pair[0].apply(pair[1], 0.1, 60.0)
		await process_frame
	get_root().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	quit()
