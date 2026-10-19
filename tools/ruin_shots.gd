extends SceneTree
## Beauty shots of the sky ruin stage (no HUD): godot --path . -s tools/ruin_shots.gd -- /outdir
func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var scene: Node = (load("res://scenes/citadel.tscn") as PackedScene).instantiate() if ResourceLoader.exists("res://scenes/citadel.tscn") else null
	if scene == null:
		print("no scene"); quit(); return
	get_root().add_child(scene)
	for i in 20:
		await process_frame
	scene.start_game()
	scene.hud.visible = false
	for i in 30:
		await process_frame
	var cam: Camera3D = scene.camera
	var views: Array = [
		["s0_approach", Vector3(-80, 95, 190), Vector3(0, 80, 0)],
		["s1_dock", Vector3(16, 60, 112), Vector3(0, 54, 70)],
		["s2_ring", Vector3(85, 75, 40), Vector3(30, 62, 10)],
		["s3_back", Vector3(-30, 110, -120), Vector3(0, 85, 0)],
		["s4_stair", Vector3(30, 140, 70), Vector3(0, 128, 22)],
		["s5_core", Vector3(10, 111, 8), Vector3(-1, 105.5, -3)],
		["s6_side", Vector3(150, 80, -40), Vector3(0, 75, 0)],
	]
	scene.set_process(false)
	scene.set_physics_process(false)
	for v: Array in views:
		cam.global_position = v[1]
		cam.look_at(v[2], Vector3.UP)
		cam.fov = 60
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, v[0]])
	quit()
