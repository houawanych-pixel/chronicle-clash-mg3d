extends SceneTree
const Game=preload("res://scripts/Game.gd")
var game: Node3D
var passed: int=0
var failed: int=0
func check(ok: bool,label: String) -> void:
	if ok: passed+=1; print("PASS ",label)
	else: failed+=1; push_error("FAIL "+label)
func _initialize() -> void: run.call_deferred()
func settle_camera(frames: int=90) -> void:
	for i in range(frames): game.update_camera(1.0/60)
func place(at: Vector3) -> void:
	game.player.position=at; game.player.velocity=Vector3.ZERO; game.player.mode="ground"; game.player.cover_motion=Vector3.ZERO; game.player.climb_input_lock=false
func run() -> void:
	game=Game.new(); game.muted=true; root.add_child(game); game.set_physics_process(false)
	await physics_frame; await physics_frame
	game.mode="play"
	var cam=game.camera_controller
	place(Vector3(-5,0,6)); settle_camera()
	check(cam.mode=="overhead","Open sky selects overhead")
	check(game.camera.position.y>15,"Overhead camera is elevated")
	place(Vector3(10,0,-3)); settle_camera()
	check(cam.mode=="follow","Roof selects follow camera")
	var screen: Vector2=game.camera.unproject_position(game.player.position+Vector3.UP*1.05)
	check(absf(screen.x-root.size.x*.5)<3,"Normal follow camera centers character")
	game.player.position=Vector3(11,0,-7)
	game.camera.position=Vector3(11,12,-7); cam.transition_time=0
	game.update_camera(1.0/60)
	check(cam.last_hard_cut and is_equal_approx(cam.transition_time,.4),"Roof obstructs camera sweep and causes hard cut")
	check(not cam.path_blocked(game.camera.position,game.camera.position),"Follow camera remains outside geometry")
	var count: int=cam.switches
	for i in range(80):
		game.player.position.z=.1 if i%2==0 else -.1
		game.update_camera(1.0/60)
	check(cam.switches==count and cam.mode=="follow","Doorway jitter does not flicker")
	game.player.position.z=.5; settle_camera(6)
	check(cam.mode=="follow","Brief doorway exit is debounced")
	settle_camera(80); check(cam.mode=="overhead","Sustained exit restores overhead")
	place(Vector3(10,0,-9.12)); game.player.toggle_cover(); settle_camera()
	check(game.player.mode=="cover","Roofed wall supports wall hug")
	for i in range(25):
		game.player.tick(1.0/60,Vector2(1,0)); game.update_camera(1.0/60); await physics_frame
	screen=game.camera.unproject_position(game.player.position+Vector3.UP*1.05)
	check(screen.x<root.size.x*.48,"Right wall shuffle reveals right / character left")
	for i in range(40):
		game.player.tick(1.0/60,Vector2(-1,0)); game.update_camera(1.0/60); await physics_frame
	screen=game.camera.unproject_position(game.player.position+Vector3.UP*1.05)
	check(screen.x>root.size.x*.52,"Left wall shuffle reveals left / character right")
	game.player.tick(1.0/60,Vector2.ZERO); settle_camera()
	check(cam.reveal.length()<.01,"Stationary wall hug recenters")
	game.player.toggle_cover(); game.player.cover_motion=Vector3.RIGHT; settle_camera()
	check(cam.reveal.length()<.01,"Normal movement has no lookahead")
	# Force a mode change in unobstructed space to verify the actual .4s interpolation.
	place(Vector3(-5,0,7)); cam.mode="follow"; cam.initialized=true; cam.candidate="overhead"; cam.candidate_time=.2
	game.camera.position=game.player.position+Vector3(0,2.4,4.6)
	game.update_camera(1.0/60)
	check(cam.transition_time>0 and cam.transition_time<.4 and not cam.last_hard_cut,"Clear path starts smooth transition")
	settle_camera(24); check(is_equal_approx(cam.transition_time,.4),"Smooth transition completes in .4s")
	for data in game.rooms[0].crates:
		place(data.at+Vector3(0,0,data.size.z*.5+.65)); game.player.facing=Vector3.FORWARD
		await physics_frame; await physics_frame
		check(not game.player.box_climb_target().is_empty(),"Crate has clear climb target")
		game.command("climb_box")
		check(game.player.mode=="mantle","CLIMB starts physical climb")
		for i in range(85): game.player.tick(1.0/60,Vector2(0,-1)); await physics_frame
		check(game.player.mode=="ground" and absf(game.player.position.y-data.size.y)<.08,"Climb finishes standing on crate")
		check(absf(game.player.position.z-data.at.z)<data.size.z*.5,"Held movement does not vault off crate")
		for i in range(20): game.player.tick(1.0/60,Vector2.ZERO); await physics_frame
		check(absf(game.player.position.y-data.size.y)<.08,"Character stays on top after release")
	place(Vector3(-5,0,8)); game.player.facing=Vector3.FORWARD; await physics_frame
	check(game.player.box_climb_target().is_empty(),"Distant crate cannot be climbed")
	place(Vector3(-4,0,3.48)); game.player.facing=Vector3.FORWARD; await physics_frame
	check(game.player.box_climb_target().is_empty(),"Tall walls cannot be climbed as crates")
	place(Vector3(-10,0,6.85)); game.player.facing=Vector3.FORWARD; await physics_frame
	game.hud.queue_redraw(); await process_frame; await process_frame
	var button: Dictionary={}
	for entry in game.hud.buttons:
		if entry.action=="climb_box": button=entry
	check(not button.is_empty(),"Rendered HUD includes CLIMB touch button")
	if not button.is_empty():
		var e=InputEventScreenTouch.new(); e.index=3; e.pressed=true; e.position=button.rect.get_center()*game.hud.scale_ui+game.hud.offset_ui
		game.hud._input(e); check(game.player.mode=="mantle","Real CLIMB button touch starts climb")
	print("RESULT: %d passed, %d failed"%[passed,failed])
	game.queue_free(); await process_frame; await process_frame; quit(1 if failed else 0)
