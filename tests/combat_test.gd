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
	var p=game.player;var g=game.guards[0];var gear=game.gear
	p.position=Vector3(0,0,-8);p.facing=Vector3.RIGHT;g.position=Vector3(3,0,-8);await physics_frame
	game.refresh_aim();gear.fire();check(g.health==65,"Pistol ray damages guard")
	check(gear.current().ammo==11 and gear.muzzle_time>0,"Shot consumes round and starts flash")
	gear.reload();gear.tick(2);check(gear.current().ammo==12 and gear.current().reserve==143,"Reload transfers reserve rounds")
	gear.current().ammo=0;gear.cooldown=0;gear.fire();check(gear.action=="reload","Empty trigger automatically reloads")
	gear.tick(2);gear.equip(1);gear.tick(1);gear.jam_countdown=0;gear.current().heat=60;gear.fire();check(gear.current().jammed,"Hot rifle jams at magazine threshold")
	gear.reload();gear.tick(3);check(not gear.current().jammed,"Reload clears ordinary jam")
	gear.force_jam(true);gear.reload();gear.tick(3);check(gear.selected==0,"Persistent jam falls back to pistol")
	check(gear.items.size()==7,"All seven weapons available")
	g.position=p.position+Vector3.RIGHT;g.health=100;g.state="PATROL";g.facing=Vector3.RIGHT;g.stun=0
	game.lab.drawn=false
	for i in range(3):game.lab.melee_timer=0;game.lab.melee("fist")
	check(g.state=="DOWN" and game.goals.has("combo"),"Punch punch kick knocks guard out")
	game.lab.action();check(game.lab.hostage==g,"Holstered action grabs downed guard")
	p.position+=Vector3.BACK;game.lab.tick(.1);check(g.position.distance_to(p.position)<1,"Dragging keeps body beside operative")
	game.lab.action();check(not is_instance_valid(game.lab.hostage),"Action releases body")
	g.position=p.position+Vector3.RIGHT;g.health=100;g.state="PATROL";g.facing=Vector3.RIGHT
	game.lab.action();check(game.lab.hostage==g,"Approach from behind grabs live guard")
	g.tick(.1);check(not g.seeing and g.radio_time==0,"Held guard cannot see or radio")
	game.lab.action();check(g.state=="DOWN","Action chokes held guard unconscious")
	g.position=p.position+Vector3.RIGHT;g.health=100;g.state="PATROL";game.lab.melee_timer=0;game.lab.melee("dagger");check(g.health<=0,"Dagger rear takedown")
	gear.equip(6);game.lab.drawn=true;game.lab.toggle_aim();var hp: float=p.health;p.damage(10);check(p.health==hp,"Sword timed parry blocks damage")
	game.lab.tick(.6);p.damage(10);check(p.health<hp,"Parry expires")
	print("RESULT: %d passed, %d failed"%[passed,failed]);game.queue_free();await process_frame;await process_frame;quit(1 if failed else 0)
