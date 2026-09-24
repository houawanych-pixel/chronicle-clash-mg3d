extends SceneTree
const Game=preload("res://scripts/Game.gd")
var game: Node3D
var passed: int=0
var failed: int=0
func check(ok: bool,label: String) -> void:
	if ok: passed+=1; print("PASS ",label)
	else: failed+=1; push_error("FAIL "+label)
func touch(p: Vector2,id: int,down: bool=true) -> void:
	var e=InputEventScreenTouch.new(); e.position=p*game.hud.scale_ui+game.hud.offset_ui;e.index=id;e.pressed=down;game.hud._input(e)
func drag(p: Vector2,id: int) -> void:
	var e=InputEventScreenDrag.new();e.position=p*game.hud.scale_ui+game.hud.offset_ui;e.index=id;game.hud._input(e)
func redraw() -> void:
	game.hud.queue_redraw();await process_frame;await process_frame
func _initialize() -> void: run.call_deferred()
func run() -> void:
	game=Game.new();game.muted=true;root.add_child(game);game.set_physics_process(false)
	await physics_frame;await redraw();game.mode="play";await redraw()
	check(game.hud.text_sizes.min()>=22,"HUD text never below 22px")
	check(game.hud.buttons.filter(func(x: Dictionary):return x.has("circle")).size()==6,"Four main round actions plus reload and pause")
	var overlaps: int=0
	for i in range(game.hud.buttons.size()):
		for j in range(i+1,game.hud.buttons.size()):
			if game.hud.buttons[i].rect.grow(6).intersects(game.hud.buttons[j].rect.grow(6)): overlaps+=1
	check(overlaps==0,"Gameplay hit targets do not overlap")
	touch(Vector2(270,490),1);drag(Vector2(300,490),1)
	check(game.hud.move_center==Vector2(270,490) and game.hud.joystick.x>.3,"Floating stick spawns at thumb position")
	touch(Vector2(1160,612),2);check(game.held("fire") and game.hud.joystick.x>.3,"Move and FIRE have independent fingers")
	touch(Vector2(1110,455),3);check(game.lab.aim,"AIM toggles on")
	touch(Vector2(760,270),4);var yaw: float=game.lab.yaw;drag(Vector2(800,290),4)
	check(game.lab.yaw<yaw and game.lab.pitch<0,"Right-side drag changes aim yaw and pitch")
	touch(Vector2(800,290),4,false);check(game.held("fire"),"Look release does not release FIRE")
	touch(Vector2(1160,612),2,false);check(not game.held("fire") and game.hud.joystick.x>.3,"Fire release preserves movement")
	touch(Vector2(300,490),1,false);check(game.hud.joystick==Vector2.ZERO,"Movement release stops joystick")
	for i in range(60):game.update_camera(1.0/60)
	check(game.camera_controller.view=="aim" and not game.player.avatar.visible,"AIM camera is first person")
	touch(Vector2(1110,455),3,false);touch(Vector2(1110,455),3);check(not game.lab.aim,"AIM toggles off")
	touch(Vector2(1000,257),5);check(game.lab.drawn,"Weapon press waits for tap versus hold")
	touch(Vector2(1000,257),5,false);check(not game.lab.drawn,"Weapon tap holsters")
	touch(Vector2(1000,257),5);game.hud.fingers[5].start-=500;game.hud._process(.01)
	check(game.lab.wheel=="weapon" and is_equal_approx(Engine.time_scale,.2),"Weapon hold opens wheel at 20 percent time")
	game.lab.choose_weapon(0);check(game.lab.drawn and Engine.time_scale==1 and game.lab.wheel.is_empty(),"Weapon wheel selection restores time")
	game.player.health=50;touch(Vector2(1010,347),6);touch(Vector2(1010,347),6,false)
	check(game.player.health==95 and game.lab.item_counts.ration==4,"Item tap uses ration")
	game.lab.choose_item("binoculars");game.lab.use_item();game.command("zoom_in")
	check(game.lab.aim and game.lab.optic=="binoculars" and game.lab.zoom==1,"Binoculars use first-person zoom")
	game.lab.aim=false;game.hud.holds.fire=true;game.command("pause")
	check(not game.held("fire") and game.hud.joystick==Vector2.ZERO,"Pause clears touch ownership")
	game.mode="play";game.hud.scale_ui=.55;game.hud.offset_ui=Vector2(120,0)
	touch(Vector2(200,500),7);drag(Vector2(278,500),7);check(game.hud.joystick.x>.99,"Phone-scaled touch remains accurate")
	print("RESULT: %d passed, %d failed"%[passed,failed]);game.queue_free();await process_frame;await process_frame;quit(1 if failed else 0)
