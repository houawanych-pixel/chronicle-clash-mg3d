extends SceneTree
## Renders the hero rig in a row of key poses for checking the procedural animation.
const RigScript = preload("res://scripts/citadel/Rig.gd")
const P = preload("res://scripts/citadel/Poses.gd")
func _init() -> void:
	var root3d: Node3D = Node3D.new()
	get_root().add_child(root3d)
	var model: String = "blonde_lance"
	var view: float = 0.0
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--model="): model = a.trim_prefix("--model=")
		if a.begins_with("--view="): view = float(a.trim_prefix("--view="))
	var poses: Array = [P.idle(0, true), P.run(1.2, 1.0), P.slash(0, 0.2), P.slash(0, 0.6), P.slash(2, 0.62), P.block(0), P.windup(1.0), P.airborne(2.0)]
	var rigs: Array = []
	var x: float = -7.0
	for p: Dictionary in poses:
		var r: Node3D = Node3D.new()
		r.set_script(RigScript)
		root3d.add_child(r)
		r.position = Vector3(x, 0, 0)
		r.rotation.y = view
		r.setup("res://assets/characters/%s.glb" % model, 1.8, Color("8fe9ff"), 1.05, 1.0)
		rigs.append([r, p])
		x += 2.0
	var cam: Camera3D = Camera3D.new()
	root3d.add_child(cam)
	cam.fov = 40
	cam.look_at_from_position(Vector3(0, 1.6, 22), Vector3(0, 1.0, 0))
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
	var img: Image = get_root().get_texture().get_image()
	img.save_png(OS.get_cmdline_user_args()[0])
	quit()
