extends RefCounted
const Traversal=preload("res://scripts/Traversal.gd")
var item_cooldown: float=0
var combo: int=0
var combo_timer: float=0
var melee_timer: float=0
var hostage: Node3D
var parry_time: float=0
var motion: RefCounted
var game: Node3D
var aim: bool=false
var optic: String="gun"
var zoom: int=0
var spectrum: int=0
var yaw: float=0
var pitch: float=0
var drawn: bool=true
var stamina: float=100
var oxygen: float=100
var wheel: String=""
var wheel_page: int=0
var item: String="ration"
var item_counts: Dictionary={"ration":5,"binoculars":1,"frag":8,"chaff":8,"c4":6,"claymore":6,"cloak":1}
var test_mode: bool=true
var menu_page: int=0
var feature_page: int=0
var objective_expanded: bool=false
var evidence: Dictionary={}
var features: Array=["Controls and HUD","Environment and cover cameras","First-person optics","Pressure movement","Crawl and vent","Climb and jump","Hanging and shimmy","Pipe climbing","Push and pull crates","Shooting and reloading","CQC and dragging","Dagger and sword","Weapons and item wheels","Grenades and chaff","C4 and claymores","Heat-seeking rockets","Cloak and rations","Guard awareness and shadows","Card-table backup","Aerial drones","Drone dogs and kamikaze","Drone Master","Lockers and concealment","Swimming and oxygen","Training and persistence"]
func _init(owner_game: Node3D) -> void:
	game=owner_game; motion=Traversal.new(game)
	if FileAccess.file_exists("res://tests/verified_features.json"):
		var data: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/verified_features.json"))
		if data is Dictionary: evidence=data
func reset() -> void:
	item_cooldown=0; item_counts={"ration":5,"binoculars":1,"frag":8,"chaff":8,"c4":6,"claymore":6,"cloak":1}; hostage=null; combo=0; melee_timer=0; aim=false; optic="gun"; drawn=true; stamina=100; oxygen=100; close_wheel()
func toggle_aim(kind: String="gun") -> void:
	if drawn and str(game.gear.current().id)=="sword": parry_time=.5; return
	if aim and optic==kind: aim=false; return
	aim=true; optic=kind; zoom=0
	var f: Vector3=game.player.facing
	yaw=atan2(-f.x,-f.z); pitch=0
func look(relative: Vector2) -> void:
	yaw-=relative.x*.004; pitch=clampf(pitch-relative.y*.003,-1.3,1.3)
func look_direction() -> Vector3:
	return Vector3(-sin(yaw)*cos(pitch),sin(pitch),-cos(yaw)*cos(pitch))
func open_wheel(kind: String) -> void:
	wheel=kind; wheel_page=0; game.hud.release_controls(); Engine.time_scale=.2
func close_wheel() -> void:
	wheel=""; Engine.time_scale=1
func choose_weapon(index: int) -> void:
	game.gear.equip(index); drawn=true; close_wheel()
func choose_item(id: String) -> void:
	item=id; close_wheel()
func use_item() -> void:
	if item_cooldown>0: return
	if item=="binoculars": toggle_aim("binoculars"); return
	if item=="cloak": game.player.toggle_cloak(); return
	if item=="c4":
		for mine: Node3D in game.mines:
			if mine.kind=="remote": game.gear.detonate(); item_cooldown=.5; return
	if int(item_counts.get(item,0))<=0: game.toast("Empty. Use the cyan console to resupply."); return
	if item=="ration":
		if game.player.health>=100: return
		game.player.health=minf(100,game.player.health+45);game.mark_goal("ration")
	elif item in ["frag","chaff"]:
		var dir: Vector3=look_direction() if aim else game.player.facing
		dir.y=0;dir=dir.normalized()
		var from: Vector3=game.player.target_point()
		if not game.ray(from,from+dir*.7,17).is_empty(): game.toast("Step clear before throwing."); return
		game.spawn_projectile("grenade" if item=="frag" else "chaff",from+dir*.6,dir*7+Vector3.UP*6);game.mark_goal(item)
	elif item in ["c4","claymore"]:
		var from: Vector3=game.player.position+Vector3.UP*.3
		if not game.ray(from,from+game.player.facing,17).is_empty(): game.toast("Step clear before placing a mine.");return
		game.place_mine("remote" if item=="c4" else "claymore");game.mark_goal(item)
	else: return
	item_counts[item]-=1;item_cooldown=.5
func fire() -> void:
	if optic=="binoculars" and aim: game.mark_aimed_guard(); return
	if drawn: game.gear.fire()
	else: melee("fist")
func context() -> String:
	if is_instance_valid(hostage): return "RELEASE" if hostage.state=="DOWN" else "CHOKE"
	var guard: Node3D=near_guard()
	if not drawn and is_instance_valid(guard) and (guard.state=="DOWN" or behind(guard)): return "DRAG" if guard.state=="DOWN" else "HOLD"
	if game.player.mode=="hang": return "DROP"
	if game.player.mode=="push": return "RELEASE"
	if motion.airborne>0 and not motion.nearest_grab().is_empty(): return "GRAB"
	if game.player.crouched and is_instance_valid(motion.near_crate()): return "PUSH"
	if game.player.mode=="cover": return "KNOCK"
	if not game.player.box_climb_target().is_empty(): return "CLIMB"
	if game.player.position.distance_to(game.console_point)<2: return "USE"
	return "JUMP"
func action() -> void:
	if is_instance_valid(hostage):
		if hostage.state!="DOWN": hostage.knock_out(); game.mark_goal("choke")
		hostage=null; return
	if context() in ["DRAG","HOLD"]:
		hostage=near_guard(); hostage.stun=60; hostage.radio_time=0; hostage.seeing=false; game.mark_goal("grab_guard"); return
	match context():
		"JUMP": motion.jump()
		"GRAB": motion.grab()
		"DROP": motion.drop()
		"PUSH": motion.pushed=motion.near_crate(); game.player.mode="push"
		"RELEASE": game.player.mode="ground"; motion.pushed=null; game.build_navigation()
		"KNOCK": game.command("knock")
		"CLIMB": game.player.climb_box()
		"USE": game.use_console()
func tick(delta: float) -> void:
	item_cooldown=maxf(0,item_cooldown-delta); melee_timer=maxf(0,melee_timer-delta); combo_timer=maxf(0,combo_timer-delta); parry_time=maxf(0,parry_time-delta)
	if combo_timer==0: combo=0
	if is_instance_valid(hostage):
		hostage.position=game.player.position-game.player.facing*.7; hostage.stun=1.0; game.mark_goal("drag")
	if not game.player.mode in ["hang","swim"] and motion.tier!="run": stamina=minf(100,stamina+delta*8)
func objective() -> String:
	var names: Dictionary={"cover":"Push into a wall to take cover","knock":"Use ACTION to knock in cover","reload":"Fire, then tap RELOAD","guard_down":"Defeat the patrol guard"}
	for goal: String in game.rooms[game.room].goals:
		if not game.goals.has(goal): return names.get(goal,"Practice: "+goal.replace("_"," "))
	return "Reach the green extraction ring"

func near_guard() -> Node3D:
	for g: Node3D in game.guards:
		if g.position.distance_to(game.player.position)<1.65 and game.clear_sight(game.player.target_point(),g.position+Vector3.UP): return g
	return null
func behind(g: Node3D) -> bool:
	return g.facing.dot((game.player.position-g.position).normalized())<-.45
func melee(kind: String) -> void:
	if melee_timer>0: return
	melee_timer=.42 if kind=="fist" else .65; combo_timer=1.3; combo=combo%3+1
	game.player.attack_time=.3; game.emit_noise(game.player.position,3); game.sound("cover",-12)
	var g: Node3D=near_guard()
	if not is_instance_valid(g) or g.health<=0: return
	if kind=="fist":
		g.receive_hit(10,"fist",g.position)
		if combo==3: g.knock_out(); game.mark_goal("combo")
	else:
		g.receive_hit(120 if kind=="dagger" and behind(g) else 45 if kind=="dagger" else 55,kind,g.position); game.mark_goal(kind)
func lock_target() -> Node3D:
	var origin: Vector3=game.player.target_point(); var dir: Vector3=look_direction() if aim else game.player.facing
	var best: Node3D; var score: float=cos(deg_to_rad(22))
	for enemy: Node3D in game.drones+game.guards:
		if enemy.health<=0: continue
		var target: Vector3=enemy.position+(Vector3.UP if enemy in game.guards else Vector3.ZERO)
		var delta: Vector3=target-origin; var dot: float=delta.normalized().dot(dir)
		if delta.length()<30 and dot>score and game.clear_sight(origin,target): best=enemy;score=dot
	return best
