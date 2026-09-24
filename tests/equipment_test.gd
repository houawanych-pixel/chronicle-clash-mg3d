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
	game=Game.new();game.muted=true;root.add_child(game);game.set_physics_process(false);await physics_frame;await physics_frame;game.mode="play"
	var p=game.player;var l=game.lab;var d=game.drones[0]
	p.position=Vector3(0,0,-8);p.facing=Vector3.FORWARD
	l.item="frag";l.use_item();check(game.projectiles.size()==1 and l.item_counts.frag==7,"Frag throws projectile and consumes inventory")
	var frag=game.projectiles[0];var vy: float=frag.velocity.y;frag.tick(.1);check(frag.velocity.y<vy,"Frag follows gravity")
	l.item_cooldown=0;l.item="chaff";l.use_item();check(game.projectiles.back().kind=="chaff","Chaff throws separate payload")
	d.position=Vector3(0,2,-8);await physics_frame;game.blast(Vector3(0,1,-8),4,0,"chaff");check(d.disabled==8,"Chaff disables nearby drone")
	d.tick(1);check(d.state=="DISABLED" and not d.seeing,"Disabled drone cannot detect or shoot")
	d.tick(8);check(d.disabled==0,"Chaff expires")
	game.blast(d.position,4,110,"grenade");check(d.health==0,"Explosions damage drones")
	l.item_cooldown=0;l.item="c4";l.use_item();check(game.mines.size()==1 and game.mines[0].kind=="remote","C4 places charge")
	p.position=Vector3(0,0,-3);l.item_cooldown=0;l.use_item();check(game.mines.is_empty() and game.goals.has("detonate"),"Second C4 use detonates charge")
	l.item_cooldown=0;l.item="claymore";l.use_item();var mine=game.mines[0];check(mine.kind=="claymore","Claymore places directional mine")
	var g=game.guards[0];g.position=mine.position+mine.facing*1.5;await physics_frame;mine.tick(1);check(mine.dead,"Armed claymore detects forward guard")
	p.health=40;l.item_cooldown=0;l.item="ration";l.use_item();check(p.health==85 and l.item_counts.ration==4,"Ration consumes and restores health")
	l.item_cooldown=0;l.item="cloak";l.use_item();check(p.cloaked,"Cloak toggles on")
	p.tick(.5,Vector2.ZERO);check(p.cloak_energy<100,"Cloak consumes energy")
	l.use_item();check(not p.cloaked,"Cloak toggles off")
	l.item="binoculars";l.use_item();check(l.aim and l.optic=="binoculars","Binoculars share first-person view")
	game.command("zoom_in");game.update_camera(1);check(game.camera.fov<=40,"Optic zoom changes actual camera FOV")
	l.aim=false;p.position=Vector3(0,0,-8);p.facing=Vector3.RIGHT;var enemy=game.drones[1];enemy.position=Vector3(7,1.2,-8);await physics_frame
	check(l.lock_target()==null,"Rocket cannot lock through shelter wall")
	enemy.position=Vector3(3.5,1.2,-8);await physics_frame
	check(l.lock_target()==enemy,"Rocket acquires visible target in aiming cone")
	game.gear.equip(3);game.gear.tick(1);game.refresh_aim();game.gear.fire();var rocket=game.projectiles.back();check(rocket.homing_target==enemy,"Launcher transfers target to rocket")
	var before: Vector3=rocket.velocity;enemy.position.z+=3;rocket.tick(.1);check(rocket.velocity.z>before.z,"Heat seeker steers toward moving target")
	game.gear.replenish();check(l.item_counts.frag==8 and game.gear.items[3].ammo==1,"Console replenishes all equipment")
	print("RESULT: %d passed, %d failed"%[passed,failed]);game.queue_free();await process_frame;await process_frame;quit(1 if failed else 0)
