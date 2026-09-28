extends SceneTree
var game: Node3D
var failures: Array=[]
var checks: int=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,msg: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",msg)
	if not ok:failures.append(msg)
func run() -> void:
	game=load("res://scripts/Game.gd").new();root.add_child(game);await physics_frame
	game.set_physics_process(false);game.muted=true;game.stage01.fresh();game.mode="play"
	for g: Node3D in game.guards:g.health=0
	for d: Node3D in game.drones:d.health=0
	var before: int=game.gear.shot_serial
	game.set_precision(true);game.hud.joystick=Vector2(.7,0);game.hud.joy_id=2
	game._physics_process(.016)
	check(game.gear.shot_serial==before,"Aim-stick movement never fires")
	game.hud.holds.fire=true;game._physics_process(.016)
	check(game.gear.shot_serial==before+1,"Deliberate FIRE shoots once")
	for i in range(90):game._physics_process(1.0/60)
	check(game.gear.shot_serial==before+1,"Held pistol FIRE does not repeat")
	game.hud.holds.fire=false;game.set_precision(false);game._physics_process(.016)
	check(game.gear.shot_serial==before+1,"AIM release does not fire")
	game.hud.release_controls();check(game.hud.fingers.is_empty() and game.hud.joystick==Vector2.ZERO,"Focus/pause clears touch ownership")
	game.stage01.state.card=2;game.stage01.state.done={"card1":true,"card2":true};game.room=3;game.stage01.save_checkpoint()
	game.stage01.state.card=0;game.stage01.resume_save();check(game.room==3 and int(game.stage01.state.card)==2,"Checkpoint reload preserves stage and Level 2 card")
	game.stage01.state.done.archive=true;game.stage01.retry();check(not game.stage01.done("archive") and int(game.stage01.state.card)==2,"Retry resets current stage objectives and retains prior cards")
	game.mode="play";game.player.damage(100);game.player.tick(.016,Vector2.ZERO);check(game.mode=="failed","Health depletion reaches failure screen")
	print("CONTROLS_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
