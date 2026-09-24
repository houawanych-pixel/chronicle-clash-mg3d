extends SceneTree
const Game=preload("res://scripts/Game.gd")
var game: Node3D
var passed: int=0
var failed: int=0
func check(ok: bool,label: String) -> void:
	if ok: passed+=1;print("PASS ",label)
	else: failed+=1;push_error("FAIL "+label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	game=Game.new();game.muted=true;root.add_child(game);game.set_physics_process(false);await physics_frame;await physics_frame;game.mode="play"
	var p=game.player;var m=game.lab.motion
	game.hud.joy_id=1;m.speed(Vector2(.3,0));check(m.tier=="sneak","Light stick selects sneak")
	m.speed(Vector2(.7,0));check(m.tier=="walk","Middle stick selects walk")
	check(m.speed(Vector2(1,0))>6 and m.tier=="run","Full stick selects run")
	m.tick(1,Vector2.RIGHT);check(game.lab.stamina<90,"Running drains stamina")
	game.lab.stamina=0;m.speed(Vector2.RIGHT);check(m.tier=="walk","Exhaustion prevents sprint")
	game.lab.stamina=100;game.command("crouch");p.tick(.016,Vector2(.3,0));check(p.prone,"Crouch plus movement becomes prone")
	game.command("crouch");check(not p.prone and not p.crouched,"Tap crouch from prone stands")
	p.position=Vector3(-12,0,1.4);p.facing=Vector3.FORWARD;p.velocity=Vector3.ZERO
	for i in range(3):p.tick(1.0/60,Vector2.ZERO);await physics_frame
	m.jump();check(p.velocity.y>7,"Ground jump launches capsule")
	for i in range(55):
		p.tick(1.0/60,Vector2.ZERO);await physics_frame
		if p.mode=="hang":break
	check(p.mode=="hang","Jump automatically grabs ledge")
	var x: float=p.position.x
	p.tick(.2,Vector2.RIGHT);check(p.position.x>x,"Hanging stick shimmies")
	check(m.pull_up(),"Up on ledge starts safe pull-up")
	for i in range(60):p.tick(1.0/60,Vector2.ZERO);await physics_frame
	check(p.position.y>2.25 and p.mode=="ground","Pull-up ends standing on ledge")
	p.position=Vector3(-9,1.3,10.5);p.mode="ground";check(m.grab(),"Bar can be grabbed")
	game.lab.stamina=.05;p.tick(.1,Vector2.ZERO);check(p.mode=="ground","Stamina zero drops from bar")
	game.lab.stamina=100;p.position=Vector3(-14,0,5.6);check(m.grab(),"Pole grab succeeds");var y: float=p.position.y;p.tick(.3,Vector2(0,-1));check(p.position.y>y,"Pole supports upward climbing")
	m.drop();check(p.mode=="ground","Drop releases pole")
	p.position=Vector3(-10,0,6.7);p.velocity=Vector3.ZERO;p.crouched=true
	check(game.lab.context()=="PUSH","Crouched crate context selects push/pull")
	game.lab.action();var before: Vector3=game.crates[0].position;p.tick(.2,Vector2(0,1))
	check(game.crates[0].position.z>before.z,"Pull moves crate physically")
	game.lab.action();check(p.mode=="ground","Action releases pushed crate")
	print("RESULT: %d passed, %d failed"%[passed,failed]);game.queue_free();await process_frame;await process_frame;quit(1 if failed else 0)
