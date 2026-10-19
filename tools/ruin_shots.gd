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
		["s0_approach", Vector3(-38, 40, 95), Vector3(0, 36, 0)],
		["s1_dock", Vector3(9, 30, 64), Vector3(0, 26, 40)],
		["s2_deck", Vector3(14, 39.5, 19), Vector3(-4, 36.5, 7)],
		["s3_span", Vector3(5, 45, 7), Vector3(-1, 43, -8)],
		["s4_core", Vector3(7.5, 55.5, 3.5), Vector3(-1, 52.8, -2)],
		["s5_side", Vector3(70, 30, -20), Vector3(0, 32, 0)],
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
