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
	game=Game.new();game.muted=true;root.add_child(game);game.set_physics_process(false);await physics_frame;game.load_room(6);await physics_frame;await physics_frame;game.mode="play"
	var p=game.player;var l=game.lab
	check(l.water.enabled,"Water lab installs physical pool")
	var hit: Dictionary=game.ray(Vector3(-4,1,-4),Vector3(-4,-6,-4));check(hit.position.y< -3.9,"Pool is a real floor opening")
	p.position=Vector3(-4,-.2,-4);p.tick(.1,Vector2.RIGHT);check(p.mode=="swim" and p.position.x> -4,"Entering water enables swimming movement")
	game.lab.action();check(l.water.dive,"Context action dives")
	for i in range(90):p.tick(1.0/60,Vector2.ZERO);await physics_frame
	check(p.position.y< -1.3 and l.oxygen<100,"Diving submerges and consumes oxygen")
	l.oxygen=0;p.health=100;p.hurt_time=0;p.tick(.1,Vector2.ZERO);check(p.health<100,"Empty oxygen damages health")
	game.lab.action();check(not l.water.dive,"Context action surfaces")
	for i in range(180):p.tick(1.0/60,Vector2.ZERO);await physics_frame
	check(p.position.y>-.6 and l.oxygen>20,"Surfacing raises swimmer and restores oxygen")
	p.position=Vector3(-4,-.35,-.5);game.lab.action();check(p.mode=="ground" and p.position.z>0 and game.goals.has("water_exit"),"Pool edge action climbs onto deck")
	for i in range(30):p.tick(1.0/60,Vector2.ZERO);await physics_frame
	check(absf(p.position.y)<.1,"Swimmer remains standing on physical deck")
	print("RESULT: %d passed, %d failed"%[passed,failed]);l=null;game.queue_free();await process_frame;await process_frame;quit(1 if failed else 0)
