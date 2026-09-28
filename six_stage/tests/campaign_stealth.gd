extends SceneTree
var failures: Array=[]
var checks: int=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,msg: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",msg)
	if not ok:failures.append(msg)
func run() -> void:
	var game: Node3D=load("res://scripts/Game.gd").new();root.add_child(game);await physics_frame;game.set_physics_process(false);game.muted=true;game.mode="play"
	var guard: CharacterBody3D=game.guards[0]
	game.player.position=guard.position+Vector3(0,0,1.7);guard.facing=Vector3.BACK
	await physics_frame
	guard.tick(.9);guard.tick(.2)
	check(guard.state=="CALL","Visible player triggers interruptible radio call")
	guard.receive_hit(10,"pistol",guard.position);check(guard.radio_time==0 and guard.state=="INVESTIGATE","Hit interrupts radio call")
	guard.knock_out();check(guard.state=="DOWN" and guard.collision_layer==0,"Nonlethal takedown removes enemy threat")
	game.player.position=game.rooms[0].start;game.player.facing=Vector3.FORWARD
	var wall: StaticBody3D=game.V.solid(game.stage,game.player.position+Vector3(0,1,-.8),Vector3(3,2,.2),Color.GRAY,true)
	await physics_frame;await physics_frame
	game.player.toggle_cover();check(game.player.mode=="cover","Wall cover works above ground level")
	game.command("knock");check(game.goals.has("knock"),"Cover ACTION can make a noise distraction")
	game.player.toggle_cover();check(game.player.mode=="ground","Player can leave cover")
	print("STEALTH_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
