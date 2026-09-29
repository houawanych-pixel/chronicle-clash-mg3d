extends SceneTree
## Side-view frames of the player walking over a grid (fixed camera) to check foot planting.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var args: PackedStringArray=OS.get_cmdline_user_args()
	var v: float=float(args[0]) if args.size()>0 else 1.4
	var out: String=args[1] if args.size()>1 else "/home/claude/scratch/strip"
	root.get_window().size=Vector2i(640,360)
	var env: WorldEnvironment=WorldEnvironment.new(); var e: Environment=Environment.new(); e.background_mode=Environment.BG_COLOR; e.background_color=Color("1a2430"); e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color=Color.WHITE; e.ambient_light_energy=1.2; env.environment=e; root.add_child(env)
	var floor: MeshInstance3D=MeshInstance3D.new(); var pm: PlaneMesh=PlaneMesh.new(); pm.size=Vector2(40,.6); floor.mesh=pm; root.add_child(floor)
	var fm: StandardMaterial3D=StandardMaterial3D.new(); fm.albedo_color=Color("4a5560"); floor.material_override=fm
	for x in range(-20,21):
		var line: MeshInstance3D=MeshInstance3D.new(); var bm: BoxMesh=BoxMesh.new(); bm.size=Vector3(.03,.012,.6); line.mesh=bm; line.position=Vector3(x*.5,.005,0); root.add_child(line)
		var lm: StandardMaterial3D=StandardMaterial3D.new(); lm.albedo_color=Color.WHITE if x%2==0 else Color("8899aa"); line.material_override=lm
	var cam: Camera3D=Camera3D.new(); root.add_child(cam); cam.position=Vector3(0,.9,6); cam.look_at(Vector3(0,.8,0)); cam.current=true; cam.fov=32
	var a: Node3D=load("res://scripts/RigAvatar.gd").new(); root.add_child(a)
	a.facing=Vector3(1,0,0); a.move_speed=v; a.position=Vector3(-1.2,0,0)
	var dt: float=1.0/60
	await process_frame
	a.animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for f in range(200):
		a.position+=Vector3(1,0,0)*v*dt
		a.tick(dt,cam); a.animation.advance(dt)
		if a.position.x> -2.0 and f>=60 and (f-60)%6==0 and (f-60)/6<10:
			await process_frame
			root.get_viewport().get_texture().get_image().save_png("%s_%02d.png"%[out,(f-60)/6])
		if f==59: a.position=Vector3(-1.2,0,0)
		await process_frame
	quit()
