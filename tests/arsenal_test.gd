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
	var p=game.player;var g=game.guards[0];var gear=game.gear
	p.position=Vector3(0,0,-8);p.facing=Vector3.RIGHT;g.position=Vector3(3,0,-8)
	for id: int in [1,2,4]:
		g.health=100;g.collision_layer=4;g.state="PATROL";await physics_frame
		gear.equip(id);gear.tick(3);game.aim_point=g.position+Vector3.UP;gear.fire()
		check(g.health==100-float(gear.current().damage),str(gear.current().name)+" actual projectile ray damage")
		var reserve: int=gear.current().reserve;gear.reload();gear.tick(3)
		check(gear.current().ammo==gear.current().capacity and gear.current().reserve==reserve-1,str(gear.current().name)+" reload conservation")
	g.health=100;g.collision_layer=4;g.state="PATROL";g.position=p.position+Vector3.RIGHT;await physics_frame
	game.lab.drawn=true;gear.equip(6);gear.tick(2);gear.fire();check(g.health==45,"Sword slash damage")
	p._update_visual(.1);check(p.avatar.blade.visible and not p.avatar.gun_body.visible,"Sword replaces gun mesh")
	game.lab.drawn=false;p._update_visual(.1);check(not p.avatar.blade.visible and not p.avatar.gun_body.visible,"Holstering hides held weapon")
	game.lab.combo=3;p.attack_time=.3;p._update_visual(.1);check(p.avatar.current_clip=="kick","Third combo attack plays kick animation")
	game.lab.combo=1;p._update_visual(.1);check(p.avatar.current_clip=="punch","First combo attack plays punch animation")
	g.health=100;g.state="PATROL";g.facing=Vector3.RIGHT;game.lab.action();game.lab.fire();check(g.state=="DOWN" and game.goals.has("throw"),"Held guard can be thrown")
	game.lab.drawn=true;gear.equip(1);gear.force_jam(false);gear.reload();p._update_visual(.1);check(p.avatar.current_clip=="reload","Jam clearing animates weapon handling")
	game.load_room(1);await physics_frame;await physics_frame;game.mode="play";p=game.player;gear=game.gear
	for target in game.targets:
		target.position=Vector3(1,0,-8)
		p.position=Vector3(-2,0,-8);p.facing=Vector3.RIGHT
		var index: int=["pistol","rifle","sniper","rocket"].find(target.weapon);gear.equip(index);gear.tick(3)
		await physics_frame;game.aim_point=target.position+Vector3.UP
		for shot in range(4):
			gear.cooldown=0;gear.fire()
			for i in range(30):
				for projectile in game.projectiles.duplicate():projectile.tick(1.0/60)
				await physics_frame
			if target.health<=0:break
		check(game.goals.has("target_"+target.weapon),target.weapon+" firing completes range target")
		target.position=Vector3(12,0,-7)
	print("RESULT: %d passed, %d failed"%[passed,failed]);game.queue_free();await process_frame;await process_frame;quit(1 if failed else 0)
