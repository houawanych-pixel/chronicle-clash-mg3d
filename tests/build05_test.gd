extends SceneTree
const Game=preload("res://scripts/Game.gd")
var game: Node3D
var passed: int=0
var failed: int=0
func check(ok: bool,label: String) -> void:
	if ok: passed+=1; print("PASS ",label)
	else: failed+=1; push_error("FAIL "+label)
func _initialize() -> void: run.call_deferred()
func camera_settle() -> void:
	for i in range(90): game.update_camera(1.0/60)
func place(at: Vector3) -> void:
	game.player.position=at; game.player.velocity=Vector3.ZERO; game.player.mode="ground"; game.player.cover_motion=Vector3.ZERO
func run() -> void:
	game=Game.new(); game.muted=true; root.add_child(game); game.set_physics_process(false)
	await physics_frame; await physics_frame; game.mode="play"
	check(game.find_children("*","MeshInstance3D",true,false).size()<300,"MeshInstance count below 300")
	print("MESH COUNT: ",game.find_children("*","MeshInstance3D",true,false).size())
	place(Vector3(-6.5,0,3.48)); game.player.toggle_cover(); camera_settle()
	check(game.camera_controller.view=="cover" and is_equal_approx(game.camera.fov,58),"Outdoor cover restores low FOV58 view")
	game.player.cover_side=-1; game.player.cover_motion=Vector3.RIGHT; camera_settle()
	var expected: Vector3=game.player.position+Vector3(-3,2.8,5.5)
	check(game.camera.position.distance_to(expected)<.03,"Clear cover camera uses Build03 5.5 / -3 / 2.8 offsets")
	check(game.camera_controller.reveal.distance_to(Vector3(1.4,0,0))<.01,"Build03 tangent focus 1.4 restored")
	game.player.peek=Vector3.RIGHT; camera_settle()
	check(game.camera_controller.reveal.distance_to(Vector3(3.4,0,0))<.01,"Corner peek adds 2-unit focus swing")
	game.player.peek=Vector3.ZERO; game.player.cover_motion=Vector3.ZERO; camera_settle()
	check(game.camera_controller.reveal.length()<.01,"Stationary cover removes side shift")
	place(Vector3(11,0,-9.12)); game.player.toggle_cover(); camera_settle()
	check(game.camera_controller.view=="cover" and is_equal_approx(game.camera.fov,58),"Roofed cover also restores FOV58 view")
	# Crawl clearance is physical, not merely a visual pose.
	place(Vector3(6.5,0,4.1)); game.player.facing=Vector3.FORWARD; await physics_frame
	game.command("crawl"); check(game.player.prone and is_equal_approx(game.player.body_shape.shape.height,.6),"CRAWL reduces capsule to .6m")
	for i in range(230): game.player.tick(1.0/60,Vector2(0,-1)); game.update_camera(1.0/60); await physics_frame
	check(game.player.position.z<.1 and game.player.position.z>-.4,"Crawl traverses 4m vent at 1.1m/s")
	check(game.camera_controller.view=="vent" and not game.player.avatar.visible,"Vent uses first person and hides own body")
	check(absf(game.camera.position.y-.43)<.08,"Vent eye is below low ceiling")
	game.player.tick(1.0/60,Vector2(0,1)); await physics_frame
	check(game.player.facing.dot(Vector3.FORWARD)>.99,"Backing up in vent does not flip POV")
	game.player.tick(1.0/60,Vector2(0,-1)); await physics_frame
	game.command("crawl"); check(game.player.prone,"Cannot stand through vent ceiling")
	game.command("crouch"); check(game.player.prone,"CROUCH cannot bypass low-ceiling stand protection")
	game.command("climb_box"); check(game.player.mode=="ground" and game.player.prone,"Climb does not bypass prone clearance")
	for i in range(65): game.player.tick(1.0/60,Vector2(0,-1)); game.update_camera(1.0/60); await physics_frame
	check(game.player.position.z<-.8,"Crawl exits into roofed room")
	game.command("crawl"); check(not game.player.prone,"Can stand after clearing vent")
	camera_settle(); check(game.camera_controller.view=="follow" and game.player.avatar.visible,"Vent exit restores visible third-person player")
	var guard=game.guards[0]
	guard.position=Vector3(-14.5,0,0); guard.facing=Vector3.FORWARD; place(Vector3(-14.5,0,-6)); await physics_frame
	guard.tick(.01); check(guard.seeing,"Standing target visible at six meters")
	game.command("crawl"); guard.facing=Vector3.FORWARD; guard.tick(.01)
	check(not guard.seeing,"Prone target hidden beyond half guard range")
	game.command("crawl")
	# Guard navigation excludes the low passage and collision blocks a direct push.
	guard.position=Vector3(6.5,0,3.9)
	for i in range(70): guard.velocity=Vector3(0,-1,-2); guard.move_and_slide(); await physics_frame
	check(guard.position.z>3.4,"Standing guard physically cannot enter vent")
	var scout=game.drones[0]; var attack=game.drones[1]
	check(scout.kind=="scout" and attack.kind=="attack","Both drone roles spawn")
	scout.position=Vector3(-14.5,3,0); scout.route=[scout.position,scout.position]; scout.heading=Vector3.FORWARD
	place(Vector3(-14.5,0,-2)); await physics_frame
	var alarms: int=game.alarms
	for i in range(5): scout.tick(.1)
	check(game.alarms==alarms and scout.suspicion>.4,"Scout detection accumulates without immediate alarm")
	for i in range(6): scout.tick(.1)
	check(game.alarms==alarms+1,"Scout raises alarm after one second")
	for i in range(20): scout.tick(.1)
	check(game.alarms==alarms+1,"Continuous spotlight does not spam alarms")
	scout.position=Vector3(10,6,-5); scout.beam_direction=Vector3.DOWN; place(Vector3(10,0,-5)); await physics_frame
	check(not scout.can_see_player(),"Roof blocks drone sight")
	scout.position=Vector3(6.5,3,1.5); scout.beam_direction=Vector3.DOWN; place(Vector3(6.5,0,1.5)); game.command("crawl"); await physics_frame
	check(not scout.can_see_player(),"Vent blocks drone sight")
	place(Vector3(-14.5,0,-2)); game.command("crawl"); attack.position=Vector3(-14.5,3,0); attack.route=[attack.position,attack.position]; attack.heading=Vector3.FORWARD
	game.player.health=100; game.player.hurt_time=0; await physics_frame
	attack.tick(.01); check(game.player.health==92,"Attack drone deals eight damage")
	game.player.hurt_time=0; attack.tick(.5); check(game.player.health==92,"Attack drone waits for shot cooldown")
	attack.tick(.71); check(game.player.health==84,"Attack drone fires again after 1.2 seconds")
	# Aim assist checks horizontal bearing because the touch stick has no elevation axis.
	place(Vector3(-14.5,0,4)); scout.position=Vector3(-14.5,3,-2); attack.position=Vector3(12,3,6); await physics_frame
	camera_settle(); game.hud.touch_aim_active=true; game.hud.aim_direction=Vector2(0,-1); game.refresh_aim()
	check(game.locked_drone==scout and game.aim_point.y>2,"Aim stick locks onto elevated drone in real aim pipeline")
	game.hud.touch_aim_active=false
	check(game.assist_drone(Vector3.FORWARD.rotated(Vector3.UP,deg_to_rad(10)))==scout,"Aim assist accepts drone within 12 degrees")
	check(game.assist_drone(Vector3.FORWARD.rotated(Vector3.UP,deg_to_rad(15)))==null,"Aim assist rejects drone outside cone")
	place(Vector3(10,0,-5)); scout.position=Vector3(10,6,-8); await physics_frame
	check(game.assist_drone(Vector3.FORWARD)==null,"Aim assist cannot lock through roof")
	place(Vector3(-14.5,0,4)); scout.position=Vector3(-14.5,3,-2); await physics_frame
	game.aim_point=scout.position
	for i in range(2): game.gear.cooldown=0; game.gear.switch_time=0; game.gear.fire()
	check(scout.health==0 and scout.state=="DOWN","Two real pistol hits down scout")
	var y: float=scout.position.y
	for i in range(60): scout.tick(1.0/60); await physics_frame
	check(scout.position.y<y-1 and not scout.searchlight.visible,"Downed scout falls and searchlight turns off")
	attack.position=Vector3(-14.5,3,-2); await physics_frame; game.aim_point=attack.position
	for i in range(3): game.gear.cooldown=0; game.gear.fire()
	check(attack.health==0,"Three real pistol hits down attack drone")
	check(game.assist_drone(Vector3.FORWARD)==null,"Dead drones cannot be aim targets")
	game.hud.queue_redraw(); await process_frame; await process_frame
	var button: Dictionary={}
	for b in game.hud.buttons:
		if b.action=="crouch": button=b
	check(not button.is_empty(),"Rendered HUD contains CROUCH / crawl entry")
	if not button.is_empty():
		var e=InputEventScreenTouch.new(); e.index=5; e.pressed=true; e.position=button.rect.get_center()*game.hud.scale_ui+game.hud.offset_ui
		game.hud._input(e);game.player.tick(.016,Vector2(.2,0)); check(game.player.prone,"Touch CROUCH plus movement crawls")
	print("RESULT: %d passed, %d failed"%[passed,failed])
	game.queue_free(); await process_frame; await process_frame; quit(1 if failed else 0)
