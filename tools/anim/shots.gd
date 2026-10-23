extends SceneTree
## Renders contact strips: a clip on a real hero GLB, side view, N frames.
## godot --path . --script res://shots.gd -- --clip=mx_run --char=blonde_lance --out=/dir [--view=side|front|three]
const RigScript = preload("res://scripts/Rig.gd")
const ClipScript = preload("res://scripts/ClipPlayer.gd")
func _initialize() -> void: run.call_deferred()
func arg(k: String, d: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"+k+"="): return a.trim_prefix("--"+k+"=")
	return d
func run() -> void:
	var clip: String = arg("clip","mx_run"); var ch: String = arg("char","blonde_lance"); var out: String = arg("out","/tmp"); var view: String = arg("view","side")
	var n: int = int(arg("n","8"))
	var env := WorldEnvironment.new(); var e := Environment.new(); e.background_mode=Environment.BG_COLOR; e.background_color=Color("2a3340"); e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color=Color(0.8,0.85,0.9); e.ambient_light_energy=0.7; env.environment=e; root.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-50,30,0); root.add_child(sun)
	var floor := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size=Vector2(20,20); floor.mesh=pm; var fm:=StandardMaterial3D.new(); fm.albedo_color=Color("56606b"); floor.material_override=fm; root.add_child(floor)
	var holder := Node3D.new(); root.add_child(holder)
	var rig: Node3D = Node3D.new(); rig.set_script(RigScript); holder.add_child(rig)
	rig.setup("res://chars/%s.glb" % ch, 1.8, Color("8fe9ff"), 1.25, 0.8)
	var cp: RefCounted = ClipScript.new(); cp.load_file("res://clips.json")
	var cam := Camera3D.new(); root.add_child(cam); cam.fov=35
	var tgt := Vector3(0,0.95,0)
	var pos := Vector3(0,1.1,5.2) if view=="front" else (Vector3(5.2,1.1,0) if view=="side" else Vector3(3.8,1.6,3.8))
	# rig faces -Z (Fighter yaw 0 = forward -Z): side view looks from +X
	cam.look_at_from_position(pos, tgt)
	await process_frame
	var hip_h: float = 0.95
	var sk: Skeleton3D = rig.sk
	var hi: int = sk.find_bone("Hip")
	if hi >= 0: hip_h = (rig.model.transform * sk.get_bone_global_rest(hi)).origin.y
	var imgs: Array = []
	var L: float = cp.length(clip) if clip != "procedural" else 0.8
	for f in n:
		var t: float = L * f / n
		var pose: Dictionary
		if clip == "procedural":
			pose = load("res://scripts/Poses.gd").run(t / L * TAU, 1.0)
		else:
			pose = cp.sample(clip, t)
		if not pose.has("blade") and pose.has("R_Forearm"): pose["blade"] = (pose["R_Forearm"] as Vector3)
		for i in 12: rig.apply(pose, 1.0/30, 200.0)
		rig.position.y = float(pose.get("lift", 0.0)) * hip_h
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		imgs.append(root.get_viewport().get_texture().get_image())
	var w: int = imgs[0].get_width(); var h: int = imgs[0].get_height()
	var cw: int = w * 3 / 8; var x0: int = (w - cw) / 2
	var strip := Image.create(cw * n, h, false, imgs[0].get_format())
	for i in n: strip.blit_rect(imgs[i], Rect2i(x0, 0, cw, h), Vector2i(i * cw, 0))
	strip.save_png("%s/%s_%s_%s.png" % [out, ch, clip, view])
	print("saved hip_h ", hip_h)
	quit()
