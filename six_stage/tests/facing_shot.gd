extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.get_window().size=Vector2i(900,500)
	var env: WorldEnvironment=WorldEnvironment.new(); var e: Environment=Environment.new(); e.background_mode=Environment.BG_COLOR; e.background_color=Color("203040"); e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color=Color.WHITE; e.ambient_light_energy=1.0; env.environment=e; root.add_child(env)
	var light: DirectionalLight3D=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-40,20,0); root.add_child(light)
	var cam: Camera3D=Camera3D.new(); root.add_child(cam); cam.position=Vector3(0,1.3,-3.2); cam.look_at(Vector3(0,1.0,0)); cam.current=true
	for i in range(3):
		var a: Node3D=load("res://scripts/RigAvatar.gd").new(); root.add_child(a); a.position=Vector3((i-1)*1.4,0,0)
		a.facing=[Vector3(0,0,-1),Vector3(1,0,0),Vector3(0,0,1)][i]
		a.set_meta("i",i)
	for f in range(20):
		for a in root.get_children(): if a.has_meta("i"): a.tick(1.0/60,cam)
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("/home/claude/scratch/facing.png"); quit()
