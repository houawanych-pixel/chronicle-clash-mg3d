extends SceneTree
const Game=preload("res://scripts/Game.gd")
var game: Node3D
var passed: int=0
var failed: int=0
func check(ok: bool,label: String) -> void:
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	game=Game.new();game.muted=true;root.add_child(game);game.set_physics_process(false);await physics_frame;await physics_frame
	check(game.rooms.size()==18,"Seven labs and eleven training stages")
	for i in range(game.rooms.size()):
		game.command("room_"+str(i));await physics_frame;await physics_frame
		check(game.room==i and game.stage.find_children("*","MeshInstance3D",true,false).size()<300,"Chamber %02d unlocked and below mesh budget"%i)
	game.load_room(4);await physics_frame;await physics_frame;game.mode="play"
	var m=game.lab.missions
	check(m.backup_guards.size()==2 and m.backup_guards[0].seated,"Two guards sit at card table")
	var g=game.guards[0];var p=game.player
	p.position=Vector3(0,0,-8);g.position=Vector3(0,0,-6);g.facing=Vector3.FORWARD;g.state="CALL";g.radio_time=.2;await physics_frame
	g.receive_hit(1,"pistol",g.position);g.tick(.3);check(not m.active and m.backup_guards[0].seated,"Interrupted transmission does not summon backup")
	g.stun=0;g.state="CALL";g.radio_time=.01;g.tick(.02);check(m.active and not m.backup_guards[0].seated,"Completed transmission dispatches seated guards")
	check(m.backup_guards[0].last_known==p.position,"Backup receives last known location")
	for guard in game.guards:guard.seeing=false
	m.tick(21);check(m.backup_guards[0].returning,"Twenty seconds without sight sends backup home")
	for guard in m.backup_guards:guard.position=guard.home;guard.tick(.1)
	check(m.backup_guards[0].seated,"Backup sits again on arrival")
	p.position=m.locker+Vector3.FORWARD;game.lab.action();check(m.hidden,"Context action conceals operative in locker")
	g.state="PATROL";g.position=p.position+Vector3.FORWARD;g.facing=Vector3.BACK;g.tick(.1);check(not g.seeing,"Hidden operative excluded from guard sight")
	game.lab.action();check(not m.hidden,"Context action exits locker")
	check(m.in_shadow(Vector3(-12,0,-9)) and not m.in_shadow(Vector3.ZERO),"Marked shadow zone influences sight")
	game.load_room(5);await physics_frame;await physics_frame;game.mode="play";p=game.player
	var dog=game.drones[0];var kam=game.drones[1];var master=game.drones[2]
	check(dog.kind=="dog" and kam.kind=="kamikaze" and master.kind=="master","Three advanced drone roles spawn")
	p.position=Vector3(0,0,-7);dog.position=Vector3(0,.5,-8);dog.route=[dog.position,dog.position];dog.heading=Vector3.BACK;await physics_frame;var hp: float=p.health;dog.tick(.1);check(p.health<hp,"Drone dog closes and attacks")
	p.hurt_time=0;kam.position=p.position+Vector3(0,1,-.8);kam.route=[kam.position,kam.position];kam.heading=Vector3.BACK;await physics_frame;kam.tick(.1);check(kam.health==0,"Kamikaze detonates at contact")
	master.position=Vector3(0,2,-10);master.route=[master.position,master.position];master.heading=Vector3.BACK;p.hurt_time=0;hp=p.health;await physics_frame;master.tick(.01);check(p.health<hp and master.cooldown<.5,"Drone Master fires faster burst cadence")
	master.receive_hit(999,"rocket",master.position);check(game.goals.has("master_down"),"Master defeat satisfies chamber goal")
	game.lab.test_mode=false;game.scores.erase("unlocked");game.command("room_17");check(game.room==5,"Training mode enforces locked stage")
	game.load_room(7);await physics_frame;game.elapsed=25;game.alarms=0;game.lab.missions.record();game.save_scores();game.load_scores();check(game.scores.get("unlocked",0)==8 and game.scores.record_7.rank=="S","Training record and next unlock persist")
	game.lab.test_mode=true;game.command("room_17");check(game.room==17,"Test mode bypasses progression")
	print("RESULT: %d passed, %d failed"%[passed,failed]);m=null;game.queue_free();await process_frame;await process_frame;quit(1 if failed else 0)
