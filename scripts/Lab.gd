extends RefCounted
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
	game=owner_game
	if FileAccess.file_exists("res://tests/verified_features.json"):
		var data: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/verified_features.json"))
		if data is Dictionary: evidence=data
func reset() -> void:
	aim=false; optic="gun"; drawn=true; stamina=100; oxygen=100; close_wheel()
func toggle_aim(kind: String="gun") -> void:
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
	if item=="binoculars": toggle_aim("binoculars"); return
	if item=="ration" and item_counts.ration>0 and game.player.health<100:
		game.player.health=minf(100,game.player.health+45); item_counts.ration-=1; game.mark_goal("ration")
func fire() -> void:
	if optic=="binoculars" and aim: game.mark_aimed_guard(); return
	if drawn: game.gear.fire()
func context() -> String:
	if game.player.mode=="cover": return "KNOCK"
	if not game.player.box_climb_target().is_empty(): return "CLIMB"
	if game.player.position.distance_to(game.console_point)<2: return "USE"
	return "JUMP"
func action() -> void:
	match context():
		"KNOCK": game.command("knock")
		"CLIMB": game.player.climb_box()
		"USE": game.use_console()
func tick(delta: float) -> void:
	stamina=minf(100,stamina+delta*8)
func objective() -> String:
	var names: Dictionary={"cover":"Push into a wall to take cover","knock":"Use ACTION to knock in cover","reload":"Fire, then tap RELOAD","guard_down":"Defeat the patrol guard"}
	for goal: String in game.rooms[game.room].goals:
		if not game.goals.has(goal): return names.get(goal,"Practice: "+goal.replace("_"," "))
	return "Reach the green extraction ring"
