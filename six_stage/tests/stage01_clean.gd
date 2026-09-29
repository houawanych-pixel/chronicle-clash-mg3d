extends SceneTree
## Checks for the Stage 01 clean-map / controls update.
var failures: Array=[]; var checks: int=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message)
	print(("PASS " if ok else "FAIL ")+message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game: Node3D=load("res://scripts/Game.gd").new();root.add_child(game)
	await physics_frame;game.muted=true;game.stage01.fresh();game.mode="play"
	for i in range(5): await physics_frame
	for g in game.guards: g.set_physics_process(false)
	var c=game.stage01
	check(c.clean,"Stage 01 uses the clean map")
	var tris: int=0
	for ch: Dictionary in c.chunks:
		var m: Mesh=ch.node.mesh
		for s in range(m.get_surface_count()): tris+=m.surface_get_arrays(s)[Mesh.ARRAY_INDEX].size()/3
	check(tris>0 and tris<10000,"Stage 01 map is under 10,000 triangles (%d, was 152,174)"%tris)
	check(c.chunks.size()>=8,"Map is split into %d chunks for culling"%c.chunks.size())
	check(c.cut_materials.size()>0,"Cutaway materials active")
	# AIM toggle
	game.toggle_aim(); check(game.lab.aim,"Tap AIM enters aim mode")
	game.hud.queue_redraw(); await process_frame
	game.toggle_aim(); check(not game.lab.aim,"Tap LOWER leaves aim mode")
	# FIRE without aim does not shoot
	var shots: int=game.gear.shot_serial
	game.hud.holds.fire=true; for i in range(4): await physics_frame
	game.hud.holds.fire=false; for i in range(2): await physics_frame
	check(game.gear.shot_serial==shots,"FIRE without AIM does not shoot")
	game.toggle_aim(); for i in range(2): await physics_frame
	game.hud.holds.fire=true; for i in range(4): await physics_frame
	game.hud.holds.fire=false; for i in range(2): await physics_frame
	check(game.gear.shot_serial>shots,"FIRE while aiming shoots")
	game.toggle_aim()
	# guide
	for i in range(30): await physics_frame
	check(c.beacon.global_position.distance_to(c.current_point().at)<.3,"Green beacon sits on the current objective")
	c.state.done["perimeter"]=true
	for i in range(60): await physics_frame
	check(c.beacon.global_position.distance_to(c.current_point().at)<.3 and c.current_point().id=="card1","Beacon moves on to the next objective")
	# walking uses the matched speeds
	check(absf(game.lab.motion.speed(Vector2(0,1))-4.4)<.01 or absf(game.lab.motion.speed(Vector2(0,1))-2.6)<.01,"Movement speeds match the animation cycles")
	print("STAGE01_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit()
