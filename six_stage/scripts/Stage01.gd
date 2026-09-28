extends RefCounted
const V=preload("res://scripts/Visuals.gd")
var game: Node3D
var power: bool=true
var card: bool=false
var gate_open: bool=false
var gate: StaticBody3D
var gate_rect: Rect2=Rect2(4.8,3,0.4,4)
var vent: AABB=AABB(Vector3(4,-.1,-9),Vector3(2,.9,3))
var power_at: Vector3=Vector3(-11,0,-7)
var terminal_at: Vector3=Vector3(2,0,8)
var card_at: Vector3=Vector3(12,0,-7)
var exit_at: Vector3=Vector3(13,0,8.5)
var distraction_at: Vector3=Vector3(-3,0,7)
var card_mesh: MeshInstance3D
var camera_lens: MeshInstance3D
var beam: MeshInstance3D
var laser: MeshInstance3D
var lamps: Array=[]
var lamp_meshes: Array=[]
var camera_at: Vector3=Vector3(9,2.8,1)
var camera_alarm: float=0
var camera_cooldown: float=0
var last_sector: int=-1
var used_vent: bool=false
var used_platform: bool=false
func _init(g: Node3D) -> void: game=g
func room_data() -> Dictionary:
	return {"name":"01 / LANDFALL", "tag":"Water Access / Vehicle Bay / Gatehouse — secure ORANGE access", "start":Vector3(-12,-.3,9.4),"exit":exit_at,"goals":["orange_keycard"],"walls":[],"crates":[],"routes":[],"chips":[],"shelter":Rect2(7,-10,8,10),"kind":"landfall"}
func wall(rect: Rect2,height: float=2.5) -> StaticBody3D:
	game.walls.append(rect)
	return V.solid(game.stage,Vector3(rect.get_center().x,height/2,rect.get_center().y),Vector3(rect.size.x,height,rect.size.y),Color("51595c"),false)
func prop(at: Vector3,size: Vector3,color: String="575d60") -> StaticBody3D:
	return V.solid(game.stage,at,size,Color(color),false)
func station(at: Vector3,title: String,color: String) -> void:
	prop(at+Vector3.UP*.5,Vector3(.7,1,.5),"333b40")
	V.box(game.stage,at+Vector3(0,.95,.27),Vector3(.5,.3,.04),V.mat(Color(color),.7))
	V.label(game.stage,at+Vector3.UP*1.7,title,Color(color),26)
func build() -> void:
	power=true;card=false;gate_open=false;camera_alarm=0;camera_cooldown=0;last_sector=-1;used_vent=false;used_platform=false
	lamps.clear();lamp_meshes.clear();game.walls.clear();game.crates.clear()
	game.stage=Node3D.new();game.add_child(game.stage)
	game.lab.motion.grabbers.clear();game.lab.motion.anchor.clear();game.lab.motion.pushed=null;game.lab.motion.airborne=0
	game.lab.missions.hidden=false;game.lab.missions.backup_guards.clear();game.lab.missions.active=false
	game.lab.missions.locker=Vector3(-4,0,-10);game.lab.missions.shadow=Rect2(-6,-11,10,3)
	game.lab.water.enabled=true;game.lab.water.dive=false;game.lab.water.pool=Rect2(-15,4,6,6)
	# Physical deck surrounds a lowered water access basin.
	for part: Array in [[Vector3(3.5,-.3,0),Vector3(25,.6,24)],[Vector3(-15.5,-.3,0),Vector3(1,.6,24)],[Vector3(-12,-.3,-4),Vector3(6,.6,16)],[Vector3(-12,-.3,11),Vector3(6,.6,2)],[Vector3(-12,-3.3,7),Vector3(6,.6,6)]]:
		prop(part[0],part[1],"343f43")
	var water_mat: StandardMaterial3D=V.mat(Color("1f5965"),.15)
	V.box(game.stage,Vector3(-12,-.2,7),Vector3(6,.035,6),water_mat)
	V.box(game.stage,Vector3(-21,-.45,0),Vector3(10,.04,35),V.mat(Color("153d49"),.1))
	for i in range(8):
		var rock: MeshInstance3D=V.box(game.stage,Vector3(-17.5-(i%2)*1.4,.2,-11+i*3),Vector3(2.4,2.5+(i%3),2.8),V.mat(Color("454748")));rock.rotation.y=i*.5
	# Roofless inspection view: two-storey wall scale, clear openings and no floating stairs.
	wall(Rect2(-16,-12,32,.4),3.6);wall(Rect2(-16,11.6,32,.4),.7);wall(Rect2(-16,-12,.4,24),.7);wall(Rect2(15.6,-12,.4,24),3.6)
	wall(Rect2(-7.2,-12,.4,3));wall(Rect2(-7.2,-6,.4,9));wall(Rect2(-7.2,7,.4,5))
	wall(Rect2(4.8,-12,.4,3));wall(Rect2(4.8,-6,.4,9));wall(Rect2(4.8,7,.4,5))
	gate=prop(Vector3(5,1.4,5),Vector3(.4,2.8,4),"745d37");game.walls.append(gate_rect)
	V.label(game.stage,Vector3(5,3.2,5),"LOCKED / LOCAL TERMINAL",Color("ffcf70"),24)
	# Actual crawl-only northern bypass through the checkpoint wall.
	prop(Vector3(5,1.9,-7.5),Vector3(2,2.1,3),"525b60")
	V.label(game.stage,Vector3(3.5,1.5,-7.5),"SERVICE CRAWL",Color("ffd17a"),25)
	# Vehicle silhouettes and useful occluding cover.
	for at: Vector3 in [Vector3(-2,0,1),Vector3(1,0,-4)]:
		wall(Rect2(at.x-1.1,at.z-2,2.2,4),1.45)
		V.box(game.stage,at+Vector3(0,1.85,-.6),Vector3(1.9,.8,1.7),V.mat(Color("657071")))
		for side: float in [-1.2,1.2]:
			for z: float in [-1.3,1.3]: V.box(game.stage,at+Vector3(side,.4,z),Vector3(.22,.7,.7),V.mat(Color("1c2226")))
	for at: Vector3 in [Vector3(-10,0,1),Vector3(-3,0,5),Vector3(10,0,5),Vector3(9,0,-5),Vector3(13,0,-1)]:
		var size: Vector3=Vector3(1.6,1.15,1.6)
		var body: StaticBody3D=prop(at+Vector3.UP*.575,size,"686957")
		body.set_meta("waist_crate",true);body.set_meta("nav_rect",Rect2(at.x-.8,at.z-.8,1.6,1.6));game.crates.append(body);game.walls.append(body.get_meta("nav_rect"))
		V.box(game.stage,at+Vector3.UP*1.16,Vector3(1.62,.035,.13),V.mat(Color("d2b05e")))
	# North platform: two ramps made as wedge collision meshes, joined by a solid deck.
	prop(Vector3(-1,1.1,-10),Vector3(6,.25,2),"555e62")
	ramp(Vector3(-5,0,-10),false);ramp(Vector3(3,0,-10),true)
	V.label(game.stage,Vector3(-1,2,-10),"UPPER SERVICE WALK",Color("b3d7d6"),25)
	prop(game.lab.missions.locker+Vector3.UP,Vector3(1,2,.5),"355052")
	station(power_at,"LOCAL POWER","ffe292");station(terminal_at,"UNLOCK GATE","74ddd0");station(card_at,"ORANGE ACCESS","ffc170");station(distraction_at,"SOUND DECOY","b7c2c9")
	card_mesh=V.box(game.stage,card_at+Vector3.UP*1.3,Vector3(.45,.28,.06),V.mat(Color("ffad43"),1))
	V.ring(game.stage,exit_at+Vector3.UP*.07,1,Color("ffbd69"));game.exit_mesh=V.box(game.stage,exit_at+Vector3.UP*.03,Vector3(1.8,.05,1.8),V.mat(Color("6e643f")))
	V.label(game.stage,exit_at+Vector3.UP*1,"TOP DECK / EXIT",Color("ffcf70"),26)
	for i in range(3):
		var x: float=-11+i*11
		V.label(game.stage,Vector3(x,3,-11),["01 / WATER ACCESS","02 / VEHICLE BAY","03 / GATEHOUSE"][i],Color("d9e3df"),32)
		var light: OmniLight3D=OmniLight3D.new();game.stage.add_child(light);light.position=Vector3(x,3,0);light.light_color=Color("ffce83");light.omni_range=9;light.light_energy=.7;lamps.append(light)
		lamp_meshes.append(V.box(game.stage,Vector3(x,3.3,-.2),Vector3(2.3,.08,.18),V.mat(Color("ffe4a0"),1)))
	# Small surveillance head; sweep uses actual occlusion ray tests.
	prop(camera_at+Vector3(0,.2,0),Vector3(.6,.3,.35),"2e3438")
	camera_lens=V.box(game.stage,camera_at,Vector3(.16,.16,.2),V.mat(Color("ffd159"),1))
	beam=V.line(game.stage,camera_at,camera_at+Vector3(0,-2,7),Color("ffd159"),.035)
	laser=V.line(game.stage,Vector3.ZERO,Vector3.UP,Color("ff7054"),.012);laser.visible=false
	game.roof_body=null
	game.vent_bounds=vent
	game.build_navigation()
	game.player=game.PlayerScript.new();game.player.game=game;game.stage.add_child(game.player);game.player.position=room_data().start;game.player.last_safe=Vector3(-12,0,10.6)
	game.player.facing=Vector3.BACK
	game.console_point=Vector3(-100,0,-100)
	game.spawn_guard([Vector2(-11,-1),Vector2(-9,-4)]);game.guards.back().detection_rate=.5;game.guards.back().sight_range=5
	game.spawn_guard([Vector2(-4,3),Vector2(2,3),Vector2(2,-6),Vector2(-4,-6)]);game.guards.back().detection_rate=.8
	game.spawn_guard([Vector2(12,2),Vector2(8,2),Vector2(8,-8),Vector2(13,-8)]);game.guards.back().detection_rate=1.05
	game.camera.position=Vector3(-12,18,20);game.camera.look_at(game.player.position)
	game.gear.shot_serial=0
	game.toast("Water access: ACTION climbs out. Find ORANGE access.")
func ramp(at: Vector3,reverse: bool) -> void:
	# A 2 m wedge meets the 1.225 m deck exactly; no disconnected steps.
	var verts: PackedVector3Array=PackedVector3Array()
	var low: float=1.225 if reverse else 0
	var high: float=0 if reverse else 1.225
	var a: Vector3=Vector3(-1,low,-1);var b: Vector3=Vector3(1,high,-1);var c: Vector3=Vector3(1,high,1);var d: Vector3=Vector3(-1,low,1)
	verts.append_array([a,c,b,a,d,c])
	var mesh: ArrayMesh=ArrayMesh.new();var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=verts;mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var body: StaticBody3D=StaticBody3D.new();game.stage.add_child(body);body.position=at
	var shape: CollisionShape3D=CollisionShape3D.new();shape.shape=mesh.create_trimesh_shape();body.add_child(shape)
	var n: MeshInstance3D=MeshInstance3D.new();n.mesh=mesh;n.material_override=V.mat(Color("838673"));body.add_child(n)
func context() -> String:
	var p: Vector3=game.player.position
	if p.distance_to(power_at)<1.8:return "POWER"
	if p.distance_to(terminal_at)<1.8:return "UNLOCK" if not gate_open else "OPEN"
	if p.distance_to(card_at)<1.8 and not card:return "KEYCARD"
	if p.distance_to(distraction_at)<1.8:return "DECOY"
	return ""
func interact() -> bool:
	match context():
		"POWER":
			power=not power
			for light: OmniLight3D in lamps:light.visible=power
			for n: MeshInstance3D in lamp_meshes:n.visible=power
			camera_lens.material_override=V.mat(Color("ffd159") if power else Color("293c3b"),1 if power else 0)
			game.toast("Power ON / camera active" if power else "Power OFF / lights + camera disabled")
		"UNLOCK":
			gate_open=true;gate.collision_layer=0;gate.visible=false;game.walls.erase(gate_rect);game.build_navigation();game.toast("Gate unlocked. Direct route is open.")
		"OPEN":game.toast("Gate already open. The crawl route is also available.")
		"KEYCARD":
			card=true;card_mesh.visible=false;game.mark_goal("orange_keycard");game.exit_mesh.material_override=V.mat(Color("50dca7"),.6);game.toast("ORANGE access acquired. Reach the southern exit.")
		"DECOY":game.emit_noise(distraction_at,13);game.toast("Decoy ringing — guards investigate the vehicle bay.")
		_:return false
	game.sound("bleep",-12);return true
func objective() -> String:
	if game.lab.water.inside():return "ACTION: climb out at the near edge"
	return "ORANGE secured / reach TOP DECK exit" if card else "Find ORANGE access / gate terminal or north crawl"
func tick(delta: float) -> void:
	camera_cooldown=maxf(0,camera_cooldown-delta)
	beam.visible=power
	var sweep: Vector3=Vector3(sin(game.elapsed*.65)*.8,-.32,1).normalized()
	var hit: Dictionary=game.ray(camera_at,camera_at+sweep*10,17)
	var end: Vector3=hit.get("position",camera_at+sweep*10)
	beam.position=(camera_at+end)*.5;beam.scale=Vector3(1,1,camera_at.distance_to(end)/Vector3(0,-2,7).length());beam.look_at(end)
	var to: Vector3=game.player.target_point()-camera_at
	var seen: bool=power and not game.lab.missions.hidden and to.length()<10 and to.normalized().dot(sweep)>.88 and game.clear_sight(camera_at,game.player.target_point())
	camera_alarm=clampf(camera_alarm+delta*(1 if seen else -2),0,1.2)
	if camera_alarm>=1.2 and camera_cooldown<=0:
		camera_cooldown=6;game.alarms+=1;game.emit_noise(game.player.position,25);game.toast("Camera alert! Break line of sight or cut power.");game.sound("alarm",-15)
	camera_lens.material_override=V.mat(Color("ff534f") if seen and camera_alarm>1 else Color("ffd159") if power else Color("293c3b"),.8 if power else 0)
	laser.visible=game.lab.aim and game.lab.optic!="binoculars"
	if laser.visible:
		var origin: Vector3=game.player.target_point()
		laser.position=(origin+game.aim_point)*.5;laser.scale=Vector3(1,1,origin.distance_to(game.aim_point));laser.look_at(game.aim_point)
	if game.player.prone and vent.has_point(game.player.position+Vector3.UP*.3):used_vent=true
	if game.player.position.y>1 and game.player.position.z< -9:used_platform=true
	if card and game.player.position.distance_to(exit_at)<1.3:
		game.mode="complete";game.hud.release_controls();game.lab.missions.record();game.save_scores();game.sound("win")
