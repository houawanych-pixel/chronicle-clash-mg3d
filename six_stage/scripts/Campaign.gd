extends RefCounted
const V=preload("res://scripts/Visuals.gd")
const SAVE="user://hovagi_six_stage_v1.json"
var game: Node3D
var state: Dictionary={"card":0,"done":{},"room":0,"records":[],"total_time":0.0,"total_alarms":0}
var checkpoint: Dictionary={}
var data: Array=[]
var cells: Dictionary={}
var nodes: Array=[]
var objective_nodes: Dictionary={}
var map_data: Dictionary
var puzzle: String=""
var sequence: Array=[]
var valves: Array=[false,false,false]
var puzzle_message: String=""
var clock: float=0
var extraction: float=-1
var survivor: Node3D
var doors: Array=[]
var lasers: Array=[]
var nav_graph: AStar3D
var saved: bool=false
var card: bool=false
var power: bool=true
var gate_open: bool=false
var vent: AABB=AABB()
func _init(g: Node3D) -> void:
	game=g
	for i in range(1,7):
		var d: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/stages/mission%d.json"%i))
		d.start=vec(d.start);d.exit=vec(d.points.back().at)
		for p: Dictionary in d.points:p.at=vec(p.at)
		data.append(d)
	saved=FileAccess.file_exists(SAVE)
func vec(a: Array) -> Vector3: return Vector3(float(a[0]),float(a[1]),float(a[2]))
func fresh() -> void:
	state={"card":0,"done":{},"room":0,"records":[],"total_time":0.0,"total_alarms":0};checkpoint=state.duplicate(true);game.load_room(0);save_checkpoint()
func resume_save() -> void:
	if saved:
		var result: Variant=JSON.parse_string(FileAccess.get_file_as_string(SAVE))
		if result is Dictionary and result.get("version",0)==1:state=result;checkpoint=state.duplicate(true);game.load_room(clampi(int(state.room),0,5));return
	fresh()
func save_checkpoint() -> void:
	state.room=game.room;state.version=1;checkpoint=state.duplicate(true)
	var f: FileAccess=FileAccess.open(SAVE,FileAccess.WRITE)
	if f:f.store_string(JSON.stringify(state));saved=true
func retry() -> void:
	state=checkpoint.duplicate(true);game.load_room(int(state.get("room",game.room)))
func done(id: String) -> bool: return bool(state.done.get(id,false))
func build() -> void:
	clock=0;extraction=-1;puzzle="";sequence=[];valves=[false,false,false];survivor=null;doors=[];lasers=[];objective_nodes={}
	game.stage=Node3D.new();game.add_child(game.stage);game.walls=[];game.crates=[]
	game.lab.water.enabled=false;game.lab.test_mode=false;game.lab.missions.hidden=false;game.lab.missions.backup_guards=[];game.lab.missions.active=false
	game.lab.missions.locker=Vector3(999,999,999);game.lab.missions.shadow=Rect2(999,999,1,1)
	game.lab.motion.grabbers=[];game.lab.motion.airborne=0;game.lab.motion.anchor={};game.lab.motion.pushed=null
	var model: Node3D=load(data[game.room].asset).instantiate();game.stage.add_child(model);model.scale=Vector3.ONE*64
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for k in range(mesh.mesh.get_surface_count()):
			var mat: Material=mesh.get_active_material(k)
			if mat is StandardMaterial3D:
				var copy: StandardMaterial3D=mat.duplicate();copy.roughness=.94;copy.metallic=.05;mesh.set_surface_override_material(k,copy)
	map_data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/stages/nav%d.json"%(game.room+1)))
	build_navigation()
	var floor_scene: Node3D=load("res://assets/stages/floor%d.glb"%(game.room+1)).instantiate();game.stage.add_child(floor_scene)
	for m: MeshInstance3D in floor_scene.find_children("*","MeshInstance3D",true,false):
		m.create_trimesh_collision();m.visible=false
		for floor_body: StaticBody3D in m.find_children("*","StaticBody3D",true,false):floor_body.collision_layer=32
	var edge: PackedVector3Array=[]
	for pair: Array in map_data.walls:
		var a: Vector3=vec(pair[0]);var b: Vector3=vec(pair[1]);var c: Vector3=b+Vector3.UP*3.4;var d: Vector3=a+Vector3.UP*3.4
		edge.append_array(PackedVector3Array([a,b,c,a,c,d,c,b,a,d,c,a]))
	var shape: ConcavePolygonShape3D=ConcavePolygonShape3D.new();shape.set_faces(edge)
	var body: StaticBody3D=StaticBody3D.new();var col: CollisionShape3D=CollisionShape3D.new();col.shape=shape;body.add_child(col);game.stage.add_child(body)
	for bridge: Array in map_data.bridges: ramp(vec(bridge[0]),vec(bridge[1]))
	# Exterior scenery stays below the original structure and has no effect on mission collision.
	if game.room==0:
		V.box(game.stage,Vector3(0,-1.4,0),Vector3(90,.6,65),V.mat(Color("303b3c")))
		for i in range(28):
			var angle: float=TAU*i/28;var at: Vector3=Vector3(cos(angle)*43,1,sin(angle)*27)
			var rock: MeshInstance3D=MeshInstance3D.new();var sphere: SphereMesh=SphereMesh.new();sphere.radial_segments=6;sphere.rings=3;rock.mesh=sphere;rock.scale=Vector3(7,4+sin(i)*2,5);rock.position=at;rock.material_override=V.mat(Color("41484b"));game.stage.add_child(rock)
	game.player=game.PlayerScript.new();game.player.game=game;game.stage.add_child(game.player);game.player.position=data[game.room].start;game.player.last_safe=game.player.position
	game.console_point=Vector3(999,999,999)
	for route: Array in data[game.room].routes:
		game.spawn_guard([Vector2(route[0][0],route[0][2]),Vector2(route[1][0],route[1][2])]);game.guards.back().position=vec(route[0]);game.guards.back().sight_range=7.5
	for p: Dictionary in data[game.room].points: build_point(p)
	if game.room in [0,3,5]:
		var route: Array=data[game.room].routes.back()
		var drone: CharacterBody3D=game.DroneScript.new();drone.game=game;drone.kind="scout" if game.room==0 else "attack";game.stage.add_child(drone)
		drone.route=[vec(route[0])+Vector3.UP*3,vec(route[1])+Vector3.UP*3];drone.position=drone.route[0];game.drones.append(drone)
	# Laser hazards have solid posts and cycle visibly; their controls remove them permanently.
	var point: Dictionary=data[game.room].points[mini(1,data[game.room].points.size()-1)]
	if game.room in [1,3,5]:
		var at: Vector3=point.at+Vector3(0,0,2.0)
		for y: float in [.35,1.0,1.65]:
			var laser: MeshInstance3D=V.line(game.stage,at+Vector3(-1.5,y,0),at+Vector3(1.5,y,0),Color("ff405d"),.035)
			lasers.append({"node":laser,"at":at,"off":"security" if game.room==1 else "cooling" if game.room==3 else "emitter"})
	game.lab.item_counts={"ration":3,"binoculars":1,"frag":2,"chaff":3,"c4":1,"claymore":1}
	game.gear.items=game.gear.items.filter(func(w: Dictionary):return str(w.id) in ["pistol","rifle","sniper","dagger"])
	game.gear.selected=0
	card=int(state.card)>0;power=not done("perimeter");gate_open=done("gate1")
	game.camera_controller.reset();game.hud.release_controls();game.notification_time=0

func ramp(a: Vector3,b: Vector3) -> void:
	var length: float=a.distance_to(b);var mesh: MeshInstance3D=V.box(game.stage,(a+b)*.5+Vector3.UP*.04,Vector3(2.4,.08,length),V.mat(Color("354b50")))
	mesh.look_at(b,Vector3.UP)
	var flat: Vector3=b-a;flat.y=0;var side: Vector3=flat.normalized().cross(Vector3.UP)*1.15
	V.line(game.stage,a+side+Vector3.UP*.12,b+side+Vector3.UP*.12,Color("7fb6a3"),.06)
	V.line(game.stage,a-side+Vector3.UP*.12,b-side+Vector3.UP*.12,Color("7fb6a3"),.06)
func build_navigation() -> void:
	cells={};nodes=[];nav_graph=AStar3D.new()
	for c: Array in map_data.cells:
		var id: int=nodes.size();var key: Vector2i=Vector2i(int(c[0]),int(c[1]));var at: Vector3=Vector3(float(map_data.offset)+key.x*.5,float(c[2]),float(map_data.offset)+key.y*.5)
		cells[key]=id;nodes.append(at);nav_graph.add_point(id,at)
	for key: Vector2i in cells:
		for d: Vector2i in [Vector2i(1,0),Vector2i(0,1),Vector2i(1,1),Vector2i(1,-1)]:
			if cells.has(key+d) and (d.x==0 or d.y==0 or (cells.has(key+Vector2i(d.x,0)) and cells.has(key+Vector2i(0,d.y)))):
				nav_graph.connect_points(cells[key],cells[key+d])
func near_node(at: Vector3) -> int: return nav_graph.get_closest_point(at)
func path(from: Vector3,to: Vector3) -> PackedVector3Array: return nav_graph.get_point_path(near_node(from),near_node(to))
func floor_y(at: Vector3) -> float:
	var key: Vector2i=Vector2i(roundi((at.x-float(map_data.offset))*2),roundi((at.z-float(map_data.offset))*2))
	return nodes[cells[key]].y if cells.has(key) else -100
func build_point(p: Dictionary) -> void:
	var n: Node3D=Node3D.new();game.stage.add_child(n);n.position=p.at;objective_nodes[p.id]=n
	var color: Color=Color("ffbd62") if p.kind in ["card1","card2","door"] else Color("66edcd")
	V.ring(n,Vector3(0,.04,0),.85,color)
	if p.kind in ["exit","finish"]:
		V.box(n,Vector3(0,.025,0),Vector3(1.7,.04,1.7),V.mat(Color("245a50")))
	else:
		V.box(n,Vector3(0,.55,0),Vector3(.6,1.1,.5),V.mat(Color("263943")))
		V.box(n,Vector3(0,.97,.26),Vector3(.5,.3,.02),V.mat(color,.4))
	var title: Label3D=V.label(n,Vector3(0,1.8,0),p.name,color,25);title.name="Title"
	if p.kind in ["door","data"]:
		var gate: StaticBody3D=V.solid(game.stage,p.at+Vector3(2,1.4,0),Vector3(.25,2.8,3.5),Color("915733") if p.kind=="door" else Color("963f4b"),true)
		doors.append({"body":gate,"id":p.id})
	if done(p.id):n.visible=false
func current_point() -> Dictionary:
	for p: Dictionary in data[game.room].points:
		if not done(p.id):return p
	return data[game.room].points.back()
func objective() -> String:
	if extraction>=0:return "Pickup in %ds · stay alive, then reach the helicopter"%ceili(extraction)
	return current_point().name.capitalize()+"  ·  ACTION"
func nearby() -> Dictionary:
	var best: Dictionary={};var distance: float=2.0
	for p: Dictionary in data[game.room].points:
		if done(p.id):continue
		var d: float=game.player.position.distance_to(p.at)
		if d<distance:best=p;distance=d
	return best
func context() -> String:
	var p: Dictionary=nearby()
	return "USE" if not p.is_empty() else ""
func interact() -> bool:
	var p: Dictionary=nearby()
	if p.is_empty():return false
	for required: String in p.requires:
		if not done(required):game.toast("Locked: complete "+required.replace("_"," ")+" first.");game.sound("empty");return true
	if p.kind in ["data","rescue"] and int(state.card)<2:game.toast("Level 2 keycard required.");return true
	if p.kind in ["door","sequence"] and int(state.card)<1:game.toast("Level 1 keycard required.");return true
	match str(p.kind):
		"sequence","valves","timing":
			puzzle=p.id;game.mode="puzzle";game.hud.release_controls();puzzle_message="";return true
		"card1":state.card=1;card=true;game.toast("Level 1 acquired. Orange readers now accept your card.")
		"card2":state.card=2;game.toast("Level 2 acquired. Red readers now accept your card.")
		"note":
			game.toast("Circuit order: B, A, C. A wrong switch resets the panel." if p.id=="log" else "Officer credential stored upstairs in the west barracks." if p.id=="duty" else "Scientist transferred to manufacturing detention. Research first.")
		"data":game.toast("Research copied. Get the scientist out of detention.")
		"switch":game.toast(p.name+" disabled.")
		"door":gate_open=true;game.toast("Level 1 accepted. Security door unlocked.")
		"rescue":
			game.toast("Scientist released. Lead them to the service lift.");create_survivor(p.at)
		"beacon":extraction=35;game.toast("Signal sent. Pickup in 35 seconds. Use cover!")
		"finish":
			if extraction>0:game.toast("Hold position. Helicopter inbound.");return true
			if extraction<0:game.toast("Send the extraction signal first.");return true
			complete_point(p.id);finish_stage();return true
		"exit":
			if is_instance_valid(survivor) and survivor.position.distance_to(game.player.position)>4:game.toast("Wait for the scientist to catch up.");return true
			complete_point(p.id);finish_stage();return true
	complete_point(p.id);return true
func complete_point(id: String) -> void:
	state.done[id]=true;game.goals[id]=true;game.sound("chip")
	if objective_nodes.has(id):objective_nodes[id].visible=false
	for door: Dictionary in doors:
		if door.id==id and is_instance_valid(door.body):door.body.queue_free()
func puzzle_input(index: int) -> void:
	if puzzle=="grid":
		var expected: Array=[1,0,2]
		if index==expected[sequence.size()]:sequence.append(index);puzzle_message="Circuit isolated. "+str(sequence.size())+" / 3"
		else:sequence=[];puzzle_message="Wrong order. Reset. Maintenance log: B → A → C.";game.alarms+=1;game.sound("alarm",-16)
		if sequence.size()==3:solve()
	elif puzzle=="cooling":
		valves[index]=not valves[index];valves[(index+1)%3]=not valves[(index+1)%3]
		puzzle_message="Each valve toggles itself and the next. Target: ON / OFF / ON."
		if valves==[true,false,true]:solve()
	elif puzzle=="conveyor":
		if fmod(clock,3)<1.2:solve()
		else:puzzle_message="Cycle running. Wait for the green service window.";game.sound("empty")
func solve() -> void:
	complete_point(puzzle);game.toast("Interlock released. Route clear.");puzzle="";game.mode="play";game.hud.release_controls()
func create_survivor(at: Vector3) -> void:
	survivor=Node3D.new();game.stage.add_child(survivor);survivor.position=at
	var avatar: Node3D=preload("res://scripts/Avatar.gd").new();survivor.add_child(avatar);avatar.scale=Vector3.ONE*.92
	V.label(survivor,Vector3(0,2.2,0),"SCIENTIST",Color("7cffc5"),24)
func tick(delta: float) -> void:
	clock+=delta
	if extraction>0:extraction=maxf(0,extraction-delta)
	for laser: Dictionary in lasers:
		var active: bool=not done(laser.off) and fmod(clock,4.5)<3.0
		laser.node.visible=active
		var p: Vector3=game.player.position-laser.at
		if active and absf(p.x)<1.7 and absf(p.z)<.3 and absf(p.y)<1:game.player.damage(15);game.emit_noise(game.player.position,12)
	if game.room==0 and done("perimeter"):
		for drone: Node3D in game.drones:drone.disabled=1
	if is_instance_valid(survivor):
		var route: PackedVector3Array=path(survivor.position,game.player.position)
		if survivor.position.distance_to(game.player.position)>1.6 and route.size()>1:survivor.position=survivor.position.move_toward(route[1],delta*3.7)
		var avatar: Node3D=survivor.get_child(0);avatar.move_speed=2;avatar.facing=(game.player.position-survivor.position).normalized();avatar.tick(delta,game.camera)
	# Recover a physics escape to the last safe floor, never strand the mission.
	if game.player.position.y<floor_y(game.player.position)-1.3:
		game.player.position=game.player.last_safe+Vector3.UP*.3;game.player.velocity=Vector3.ZERO
func finish_stage() -> void:
	state.total_time=float(state.total_time)+game.elapsed;state.total_alarms=int(state.total_alarms)+game.alarms
	state.records.append({"stage":game.room+1,"seconds":game.elapsed,"alarms":game.alarms})
	game.mode="complete" if game.room<5 else "victory";game.sound("win");game.hud.release_controls()
func next_stage() -> void:
	if game.room<5:
		state.room=game.room+1;checkpoint=state.duplicate(true);game.load_room(game.room+1);save_checkpoint()
