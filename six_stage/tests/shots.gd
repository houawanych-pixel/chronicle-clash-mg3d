extends SceneTree
## Renders gameplay screenshots at chosen spots (needs a display: xvfb-run).
var game: Node3D
func _initialize() -> void: run.call_deferred()
func settle(frames: int) -> void:
	for i in range(frames): await process_frame
func shot(name: String) -> void:
	await settle(3)
	root.get_viewport().get_texture().get_image().save_png("res://docs/stage01_clean/"+name+".png"); print("SHOT ",name)
func place(at: Vector3, face: Vector3, walk: Vector2=Vector2.ZERO, seconds: float=1.2) -> void:
	game.player.position=at; game.player.velocity=Vector3.ZERO; game.player.facing=face.normalized()
	game.camera_controller.reset()
	var t: float=0
	while t<seconds:
		game.hud.joystick=walk; if walk!=Vector2.ZERO: game.hud.joy_id=5
		await physics_frame; t+=1.0/60
	game.hud.joystick=Vector2.ZERO; game.hud.joy_id=-99
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/stage01_clean")
	root.get_window().size=Vector2i(1600,720)
	game=load("res://scripts/Game.gd").new();root.add_child(game)
	await settle(5); game.muted=true
	await shot("a_title")
	game.command("new_game"); await settle(10); await shot("b_brief")
	game.command("confirm"); await settle(10)
	for g in game.guards: g.set_physics_process(false)
	await place(game.stage01.data[0].start,Vector3(0,0,-1),Vector2(0,-1),1.6); await shot("c_start_running")
	await place(Vector3(-16.75,2.9,-7.0),Vector3(1,0,0),Vector2(0,-.6),2.5); await shot("d_stairs")
	await place(Vector3(0.0,8.1,-6.0),Vector3(1,0,0),Vector2(0,-.4),1.5); await shot("e_upper_deck")
	await place(Vector3(16.75,5.3,9.5),Vector3(0,0,-1),Vector2(0,-.4),1.5); await shot("f_ramp_to_deck")
	await place(Vector3(9.0,4.8,8.0),Vector3(1,0,.2),Vector2.ZERO,1.0); await shot("g_objective_beacon")
	game.stage01.state.done["perimeter"]=true;game.stage01.state.done["card1"]=true;game.stage01.state.card=1;game.stage01.card=true
	await place(Vector3(10.0,8.1,-5.5),Vector3(1,0,0),Vector2.ZERO,1.0); await shot("h_green_door")
	quit()
