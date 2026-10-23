extends SceneTree
## Side-view contact strips of Kai's motion-capture clips (run under xvfb with a real renderer).
## godot --path . --script res://tests/mocap_shots.gd -- --out=/dir
const AvatarScript=preload("res://scripts/RigAvatar.gd")
var out: String="/tmp"
func _initialize() -> void: run.call_deferred()
func run() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out=a.trim_prefix("--out=")
	var env := WorldEnvironment.new(); var e := Environment.new(); e.background_mode=Environment.BG_COLOR; e.background_color=Color("1b2530"); e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color=Color(.85,.9,.95); e.ambient_light_energy=.8; env.environment=e; root.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-45,40,0); root.add_child(sun)
	var fl := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size=Vector2(20,20); fl.mesh=pm; var fm:=StandardMaterial3D.new(); fm.albedo_color=Color("4a5560"); fl.material_override=fm; root.add_child(fl)
	var av: Node3D=AvatarScript.new(); root.add_child(av)
	var cam := Camera3D.new(); root.add_child(cam); cam.fov=34
	cam.look_at_from_position(Vector3(5.0,1.1,0),Vector3(0,.9,0))
	av.facing=Vector3(0,0,-1)
	await process_frame
	print("mocap ",av.mocap," speeds ",av.mocap_speed)
	for spec: Array in [["sneak",1.4,false,true],["run",4.4,false,true],["crouch_idle",0.0,true,true],["idle_holstered",0.0,false,false],["run_holstered",4.4,false,false]]:
		av.move_speed=spec[1]; av.crouched=spec[2]; av.weapon_drawn=spec[3]; av.pose=14 if spec[2] else -1
		for i in 40:
			av.tick(1.0/60,cam); await process_frame
		var imgs: Array=[]
		for f in 6:
			for i in 7:
				av.tick(1.0/60,cam); await process_frame
			await RenderingServer.frame_post_draw
			imgs.append(root.get_viewport().get_texture().get_image())
		var w: int=imgs[0].get_width(); var h: int=imgs[0].get_height(); var cw: int=w*3/8; var x0: int=(w-cw)/2
		var strip := Image.create(cw*6,h,false,imgs[0].get_format())
		for i in 6: strip.blit_rect(imgs[i],Rect2i(x0,0,cw,h),Vector2i(i*cw,0))
		strip.save_png("%s/kai_%s.png"%[out,spec[0]])
		print("clip ",spec[0]," -> ",av.current_clip," speed_scale ",av.animation.speed_scale)
	quit()
