extends SceneTree
var game: Node3D
var failures: Array=[]
var checks: int=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message);print("FAIL ",message)
	else:print("PASS ",message)
func walk(to: Vector3) -> bool:
	var path: PackedVector3Array=game.stage01.path(game.player.position,to)
	if path.is_empty():return false
	var index: int=0;var frames: int=0;var stuck: int=0;var old: Vector3=game.player.position
	while index<path.size() and frames<14000:
		var target: Vector3=path[index];var flat: Vector2=Vector2(target.x-game.player.position.x,target.z-game.player.position.z)
		if flat.length()<.20:index+=1;continue
		game.player.tick(1.0/60,flat.normalized()*.65)
		frames+=1
		if frames%120==0:
			if game.player.position.distance_to(old)<.15:stuck+=1
			else:stuck=0
			old=game.player.position
			if stuck>=2:print("BLOCKED ",game.room+1," at ",game.player.position," target ",target," goal ",to);return false
		if frames%8==0:await physics_frame
	return game.player.position.distance_to(to)<1.9
func run() -> void:
	Engine.physics_ticks_per_second=240
	game=load("res://scripts/Game.gd").new();root.add_child(game)
	await physics_frame;game.set_physics_process(false);game.muted=true;game.stage01.fresh()
	for stage in range(6):
		if stage>0:game.stage01.next_stage()
		game.mode="play"
		await physics_frame
		for g: Node3D in game.guards:g.set_process(false)
		for i in range(30):game.player.tick(1.0/60,Vector2.ZERO);await physics_frame
		var c: RefCounted=game.stage01
		check(game.room==stage,"Stage %d transition"%(stage+1))
		if stage>0:check(int(c.state.card)>0,"Keycard persists into stage %d"%(stage+1))
		var end: Dictionary=c.data[stage].points.back()
		var before: Vector3=game.player.position
		game.player.position=end.at;c.interact();check(not c.done(end.id),"Stage %d exit rejects missing objective"%(stage+1));game.player.position=before
		for p: Dictionary in c.data[stage].points:
			var reached: bool=await walk(p.at);check(reached,"Stage %d physical route to %s"%[stage+1,p.id])
			if not reached: game.player.position=p.at # Continue gate checks; failure remains explicit.
			if stage==3 and p.id=="archive":
				c.state.card=1;c.interact();check(not c.done(p.id),"Level 1 cannot open research archive");c.state.card=2
			c.interact()
			if p.kind=="sequence":
				c.puzzle_input(0);check(c.sequence.is_empty(),"Wrong circuit order resets without softlock")
				for x in [1,0,2]:c.puzzle_input(x)
			elif p.kind=="valves":c.puzzle_input(2)
			elif p.kind=="timing":c.clock=2;c.puzzle_input(0);check(not c.done(p.id),"Conveyor rejects unsafe timing");c.clock=0;c.puzzle_input(0)
			if p.kind=="rescue":check(is_instance_valid(c.survivor),"Scientist spawns")
			if p.kind=="exit" and is_instance_valid(c.survivor):
				for i in range(2400):c.tick(1.0/60)
				c.interact()
			if p.kind=="finish":
				check(game.mode!="victory","Extraction waits for pickup timer")
				c.extraction=0;c.interact()
			check(c.done(p.id),"Objective completes: "+p.id)
		check(game.mode==("victory" if stage==5 else "complete"),"Stage %d complete state"%(stage+1))
	print("CAMPAIGN_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
