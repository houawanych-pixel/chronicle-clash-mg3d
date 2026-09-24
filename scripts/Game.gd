extends Node3D
const LabScript=preload("res://scripts/Lab.gd")
var lab: RefCounted
var key_hold: Dictionary={}
const EnvironmentCameraScript=preload("res://scripts/EnvironmentCamera.gd")
var camera_controller: RefCounted
var crates: Array=[]
var roof_body: StaticBody3D
const Data=preload("res://scripts/Data.gd")
const V=preload("res://scripts/Visuals.gd")
const Spatial=preload("res://scripts/StealthMath.gd")
const PlayerScript=preload("res://scripts/Player.gd")
const DroneScript=preload("res://scripts/Drone.gd")
var drones: Array=[]
var locked_drone: Node3D
var vent_bounds: AABB=AABB(Vector3(5.8,0,-.6),Vector3(1.4,.85,4.1))
const GuardScript=preload("res://scripts/Guard.gd")
const GearScript=preload("res://scripts/Equipment.gd")
const HUDScript=preload("res://scripts/HUD.gd")
const TitanScript=preload("res://scripts/Titan.gd")
const TargetScript=preload("res://scripts/Target.gd")
const ProjectileScript=preload("res://scripts/Projectile.gd")
const MineScript=preload("res://scripts/Mine.gd")
var rooms: Array=Data.rooms()
var room: int=0
var mode: String="title"
var stage: Node3D
var player: CharacterBody3D
var gear: Node
var hud: Control
var camera: Camera3D
var titan: Node3D
var guards: Array=[]
var chips: Array=[]
var targets: Array=[]
var projectiles: Array=[]
var mines: Array=[]
var effects: Array=[]
var walls: Array=[]
var goals: Dictionary={}
var navigation: AStarGrid2D
var elapsed: float=0
var alarms: int=0
var support_count: int=0
var support_cooldown: float=0
var noise_cooldown: float=0
var collected: int=0
var toast_text: String=""
var notification_time: float=0
var aim_screen: Vector2=Vector2(640,300)
var aim_point: Vector3=Vector3.ZERO
var aim_hit: Dictionary={}
var aim_enabled: bool=false
var mouse_fire: bool=false
var last_scope: bool=false
var scope_yaw: float=0
var scope_pitch: float=-.08
var console_point: Vector3=Vector3(-12,0,8)
var exit_mesh: MeshInstance3D
var music: AudioStreamPlayer
var muted: bool=false
var audio_bank: Dictionary={}
var scores: Dictionary={}
var lab_drill: int=0
var tick_count: int=0
var capture_name: String=""
var demo_kind: String=""
var verify_web: bool=false
func _ready() -> void:
	lab=LabScript.new(self)
	setup_input()
	setup_audio()
	load_scores()
	var env: WorldEnvironment=WorldEnvironment.new()
	var e: Environment=Environment.new()
	e.background_mode=Environment.BG_COLOR; e.background_color=Color("081221")
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color=Color("b4d4ee"); e.ambient_light_energy=.85
	env.environment=e; add_child(env)
	var light: DirectionalLight3D=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-60,-30,0); light.light_energy=1.2; light.shadow_enabled=true; add_child(light)
	camera=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=27
	camera.far=100; camera.near=.1; add_child(camera); camera.current=true
	camera_controller=EnvironmentCameraScript.new(self)
	gear=GearScript.new(); gear.game=self; add_child(gear)
	var layer: CanvasLayer=CanvasLayer.new(); add_child(layer)
	hud=HUDScript.new(); hud.game=self; layer.add_child(hud)
	load_room(0,false)
	var args: PackedStringArray=OS.get_cmdline_user_args()
	for arg: String in args:
		if arg=="--verify-web": verify_web=true
		if arg.begins_with("--capture="): capture_name=arg.trim_prefix("--capture=")
		if arg.begins_with("--demo="): demo_kind=arg.trim_prefix("--demo=")
	if not demo_kind.is_empty(): setup_demo.call_deferred()
func setup_input() -> void:
	var keys: Dictionary={"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],"up":[KEY_W,KEY_UP],"down":[KEY_S,KEY_DOWN],"fire":[KEY_J],"scope":[KEY_V],"run":[KEY_SHIFT],"sneak":[KEY_ALT],"action":[KEY_SPACE],"aim":[KEY_V],"weapon_slot":[KEY_E],"item_slot":[KEY_Q],"crawl":[KEY_Z],"climb_box":[KEY_B],"reload":[KEY_R],"hook":[KEY_H],"brace":[KEY_T],"crouch":[KEY_C],"knock":[KEY_K],"cloak":[KEY_X],"drop":[KEY_Y],"detonate":[KEY_G],"equipment":[KEY_TAB],"use":[KEY_F],"pause":[KEY_ESCAPE,KEY_P],"confirm":[KEY_ENTER],"next":[KEY_BRACKETRIGHT],"previous":[KEY_BRACKETLEFT],"zoom":[KEY_V]}
	for name: String in keys:
		InputMap.add_action(name)
		for code: int in keys[name]:
			var event: InputEventKey=InputEventKey.new(); event.physical_keycode=code; InputMap.action_add_event(name,event)
	var pad: Dictionary={"fire":JOY_BUTTON_RIGHT_SHOULDER,"action":JOY_BUTTON_A,"aim":JOY_BUTTON_LEFT_SHOULDER,"weapon_slot":JOY_BUTTON_RIGHT_STICK,"crouch":JOY_BUTTON_B,"climb_box":JOY_BUTTON_Y,"reload":JOY_BUTTON_X,"item_slot":JOY_BUTTON_LEFT_STICK,"equipment":JOY_BUTTON_BACK,"pause":JOY_BUTTON_START,"next":JOY_BUTTON_DPAD_RIGHT,"previous":JOY_BUTTON_DPAD_LEFT,"use":JOY_BUTTON_DPAD_UP,"drop":JOY_BUTTON_DPAD_DOWN}
	for name: String in pad:
		var event: InputEventJoypadButton=InputEventJoypadButton.new(); event.button_index=pad[name]; InputMap.action_add_event(name,event)
func setup_audio() -> void:
	for cue: String in ["step","cover","chip","alarm","pulse","win","fail","pistol","rifle","sniper","rocket","explosion","reload","empty","hook","hurt","hit","guard_down","bleep","knock","radio"]:
		audio_bank[cue]=load("res://audio/"+cue+".wav")
	music=AudioStreamPlayer.new(); music.stream=load("res://audio/grid_ambient.wav"); music.volume_db=-24
	music.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
	music.stream.loop_end=int(music.stream.get_length()*music.stream.mix_rate)
	add_child(music); 
	if not OS.get_cmdline_args().has("Dummy"): music.play()
func sound(cue: String, volume: float=-8) -> void:
	if muted or not audio_bank.has(cue): return
	var node: AudioStreamPlayer=AudioStreamPlayer.new(); node.stream=audio_bank[cue]; node.volume_db=volume
	add_child(node); node.finished.connect(node.queue_free); node.play()
func load_room(index: int, brief: bool=true) -> void:
	if is_instance_valid(stage): remove_child(stage); stage.queue_free()
	room=index; mode="brief" if brief else "title"
	guards.clear(); drones.clear(); locked_drone=null; chips.clear(); targets.clear(); projectiles.clear(); mines.clear(); effects.clear(); goals.clear()
	titan=null; collected=0; alarms=0; elapsed=0; support_count=0; support_cooldown=0; lab_drill=0
	gear.reset(); lab.reset(); last_scope=false; aim_enabled=false
	var data: Dictionary=rooms[room]
	walls=data.walls.duplicate()
	walls.append_array([Rect2(-16,-12,32,.4),Rect2(-16,11.6,32,.4),Rect2(-16,-12,.4,24),Rect2(15.6,-12,.4,24)])
	# The north-east shelter has a 4m doorway facing the open courtyard.
	var shelter_walls: Array=[Rect2(5,-10,.4,10),Rect2(13.6,-10,.4,10),Rect2(5,-10,9,.4),Rect2(5,-.4,.8,.4),Rect2(7.2,-.4,.8,.4),Rect2(12,-.4,2,.4)]
	walls.append_array(shelter_walls)
	stage=Node3D.new(); add_child(stage)
	lab.water.build_floor()
	for rect: Rect2 in walls:
		var h: float=4.3 if rect in shelter_walls else 2.5
		if rect.size.x>25 or rect.size.y>20: h=1.0
		V.solid(stage,Vector3(rect.get_center().x,h/2,rect.get_center().y),Vector3(rect.size.x,h,rect.size.y),Color("2b435b"),true)
	# Low entrance through the front wall, with an intact lintel above.
	V.solid(stage,Vector3(6.5,2.575,-.2),Vector3(1.4,3.45,.4),Color("2b435b"),true)
	V.solid(stage,Vector3(5.7,.525,1.55),Vector3(.2,1.05,3.9),Color("304f60"),true)
	V.solid(stage,Vector3(7.3,.525,1.55),Vector3(.2,1.05,3.9),Color("304f60"),true)
	V.solid(stage,Vector3(6.5,.95,1.55),Vector3(1.8,.2,3.9),Color("304f60"),true)
	walls.append_array([Rect2(5.6,-.4,.2,3.9),Rect2(7.2,-.4,.2,3.9)])
	V.label(stage,Vector3(6.5,1.35,3.55),"CRAWL / VENT",Color("74e6dd"),24)
	crates.clear()
	for entry: Dictionary in data.crates:
		var size: Vector3=entry.size
		var body: StaticBody3D=V.solid(stage,entry.at+Vector3.UP*size.y*.5,size,Color("426476"),true)
		body.set_meta("waist_crate",true);body.set_meta("nav_rect",Rect2(entry.at.x-size.x*.5,entry.at.z-size.z*.5,size.x,size.z)); crates.append(body)
		walls.append(Rect2(entry.at.x-size.x*.5,entry.at.z-size.z*.5,size.x,size.z))
		V.label(stage,entry.at+Vector3.UP*(size.y+.4),"CLIMB",Color("ffd18b"),24)
	var shelter: Rect2=data.shelter
	roof_body=V.solid(stage,Vector3(shelter.get_center().x,4.45,shelter.get_center().y),Vector3(shelter.size.x,.3,shelter.size.y),Color("263d50"),true)
	roof_body.set_meta("roof",true)
	V.label(stage,Vector3(10,3.5,.12),"ROOFED / FOLLOW CAMERA",Color("74e6dd"),27)
	V.label(stage,Vector3(-5,.08,9.4),"OPEN SKY / OVERHEAD",Color("74e6dd"),28)
	lab.motion.build()
	build_navigation()
	player=PlayerScript.new(); player.game=self; stage.add_child(player); player.position=data.start; player.last_safe=data.start
	if room==2: player.health=65
	console_point=data.start+Vector3(-1.5,0,-.8)
	V.solid(stage,console_point+Vector3.UP*.45,Vector3(.7,.9,.7),Color("276977"),false)
	V.label(stage,console_point+Vector3.UP*1.6,"USE / TRAINING",Color("7ae8e1"),25)
	for route: Array in data.routes: spawn_guard(route)
	for kind: String in (["dog","kamikaze","master"] if data.get("kind","")=="drones" else ["scout","attack"]):
		var drone=DroneScript.new(); drone.game=self; drone.kind=kind; stage.add_child(drone); drones.append(drone)
	for point: Vector3 in data.chips:
		var node: Node3D=Node3D.new(); stage.add_child(node); node.position=point+Vector3.UP*.8
		var mesh: MeshInstance3D=V.box(node,Vector3.ZERO,Vector3(.48,.48,.48),V.mat(Color("ffcf75"),.6)); mesh.rotation_degrees=Vector3(35,0,45)
		V.ring(node,Vector3(0,-.74,0),.55,Color("e6b869"))
		chips.append({"node":node,"at":point,"taken":false})
	V.ring(stage,data.exit+Vector3.UP*.06,1.1,Color("62f3b0"))
	exit_mesh=V.box(stage,data.exit+Vector3.UP*.025,Vector3(1.6,.04,1.6),V.mat(Color("296a51")))
	V.label(stage,data.exit+Vector3.UP*.7,"EXTRACT",Color("73efb0"),25)
	if room==1:
		var ids: Array=["pistol","rifle","sniper","rocket"]
		for i in range(4):
			var t: StaticBody3D=TargetScript.new(); t.game=self; t.weapon=ids[i]; stage.add_child(t); t.position=Vector3(-12+i*8,0,-7); targets.append(t)
		V.label(stage,Vector3(0,.06,4),"PISTOL    /    RIFLE    /    SNIPER    /    ROCKET",Color("96bacb"),32)
	if room==2:
		V.label(stage,Vector3(-11,1,5),"TACTICAL PRACTICE / SUPPLIES",Color("a4c8d7"),24)
	lab.missions.build()
	camera.position=Vector3(0,30,23); camera.look_at(Vector3(0,0,0),Vector3.UP)
	camera_controller.reset()
	hud.release_controls(); notification_time=0
func spawn_guard(route: Array) -> void:
	var g: CharacterBody3D=GuardScript.new(); g.game=self; g.route=route; stage.add_child(g)
	g.position=Vector3(route[0].x,0,route[0].y); guards.append(g)
func build_navigation() -> void:
	navigation=AStarGrid2D.new(); navigation.region=Rect2i(0,0,64,48); navigation.cell_size=Vector2(.5,.5); navigation.offset=Vector2(-15.75,-11.75)
	navigation.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES; navigation.update()
	for x in range(64):
		for y in range(48):
			var id: Vector2i=Vector2i(x,y)
			for wall: Rect2 in walls:
				if wall.grow(.4).has_point(navigation.get_point_position(id)) or Rect2(5.5,-.7,2,4.5).has_point(navigation.get_point_position(id)): navigation.set_point_solid(id); break
func nav_cell(at: Vector2) -> Vector2i:
	var id: Vector2i=Vector2i(clampi(roundi((at.x+15.75)*2),0,63),clampi(roundi((at.y+11.75)*2),0,47))
	if not navigation.is_point_solid(id): return id
	for r in range(1,8):
		for x in range(-r,r+1):
			for y in range(-r,r+1):
				var n: Vector2i=id+Vector2i(x,y)
				if navigation.is_in_boundsv(n) and not navigation.is_point_solid(n): return n
	return id
func route_to(from: Vector2,to: Vector2) -> PackedVector2Array:
	var expanded: Array=[]
	for wall: Rect2 in walls: expanded.append(wall.grow(.4))
	if Spatial.visible(from,to,expanded): return PackedVector2Array([to])
	return navigation.get_point_path(nav_cell(from),nav_cell(to))
func ray(from: Vector3,to: Vector3,mask: int=17,exclude: Array=[]) -> Dictionary:
	if from.distance_to(to)<.001: return {}
	var rids: Array[RID]=[]
	rids.assign(exclude)
	var query: PhysicsRayQueryParameters3D=PhysicsRayQueryParameters3D.create(from,to,mask,rids)
	query.hit_from_inside=false
	return get_world_3d().direct_space_state.intersect_ray(query)
func clear_sight(from: Vector3,to: Vector3) -> bool: return ray(from,to,17).is_empty()
func held(action: String) -> bool:
	return Input.is_action_pressed(action) or bool(hud.holds.get(action,false)) or (action=="fire" and (mouse_fire or hud.aim_firing))
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo: return
	for action: String in ["weapon_slot","item_slot"]:
		if event.is_action_pressed(action): key_hold[action]=Time.get_ticks_msec()
		elif event.is_action_released(action) and key_hold.has(action):
			var held_time: int=-1 if int(key_hold[action])<0 else Time.get_ticks_msec()-int(key_hold[action]); key_hold.erase(action)
			if held_time<0: pass
			elif held_time>=450: lab.open_wheel("weapon" if action=="weapon_slot" else "item")
			elif action=="weapon_slot": lab.drawn=not lab.drawn
			else: lab.use_item()
	for action: String in ["reload","action","aim","crouch","pause","confirm"]:
		if event.is_action_pressed(action): command(action)
func command(action: String) -> void:
	if action in ["hook","scope","cloak","drop","detonate","equipment","next","previous","zoom"]: return
	if action.begins_with("room_"):
		var id: int=int(action.trim_prefix("room_"))
		if id>=0 and id<rooms.size() and (lab.test_mode or id<=int(scores.get("unlocked",7))): load_room(id)
		return
	if action=="chambers": mode="chambers";hud.release_controls();return
	if action=="checklist": mode="checklist";hud.release_controls();return
	if action=="test_mode": lab.test_mode=not lab.test_mode; return
	if action in ["page_next","page_prev"]: lab.menu_page=posmod(lab.menu_page+(1 if action=="page_next" else -1),3);return
	if action in ["features_next","features_prev"]: lab.feature_page=posmod(lab.feature_page+(1 if action=="features_next" else -1),5);return
	if action.begins_with("equip_"): lab.choose_weapon(int(action.trim_prefix("equip_"))); return
	if action.begins_with("item_"): lab.choose_item(action.trim_prefix("item_")); return
	if action=="wheel_close": lab.close_wheel(); return
	if action in ["wheel_next","wheel_prev"]:
		lab.wheel_page=posmod(lab.wheel_page+(1 if action=="wheel_next" else -1),maxi(1,ceili((lab.item_counts.size() if lab.wheel=="item" else gear.items.size())/6.0))); return
	if action=="objectives": lab.objective_expanded=not lab.objective_expanded; return
	if action=="mute": muted=not muted; music.volume_db=-80 if muted else -24; return
	if action=="menu": lab.close_wheel(); mode="title"; hud.release_controls(); return
	if action=="retry": load_room(room); return
	if action=="pause":
		lab.close_wheel()
		if mode=="play": mode="paused"
		elif mode in ["paused","equipment"]: mode="play"
		hud.release_controls(); return
	if action=="confirm":
		if mode=="title": load_room(room)
		elif mode in ["brief","paused"]: mode="play"
		elif mode=="failed": load_room(room)
		elif mode=="complete": load_room(mini(room+1,rooms.size()-1) if not lab.test_mode else room)
		hud.release_controls(); return
	if mode!="play": return
	match action:
		"action": lab.action()
		"aim": lab.toggle_aim()
		"zoom_in": lab.zoom=mini(2,lab.zoom+1)
		"zoom_out": lab.zoom=maxi(0,lab.zoom-1)
		"spectrum": lab.spectrum=(lab.spectrum+1)%3
		"equipment": mode="equipment"; hud.release_controls()
		"next": gear.equip(gear.selected+1)
		"previous": gear.equip(gear.selected-1)
		"scope": gear.toggle_scope()
		"zoom": gear.zoom=(gear.zoom+1)%3
		"reload": gear.reload()
		"climb_box": player.climb_box()
		"hook": player.hook()
		"brace":
			if player.mode in ["ground","cover"]: player.toggle_cover()
		"crouch": player.toggle_crouch()
		"crawl": player.toggle_crawl()
		"cloak": player.toggle_cloak()
		"drop": player.drop()
		"detonate": gear.detonate()
		"knock":
			if player.mode=="cover": emit_noise(player.global_position,11); sound("knock"); mark_goal("knock"); toast("Knock knock — guards investigate the sound.")
			else: toast("Press against a wall before knocking.")
		"use": use_console()
func update_aim(screen: Vector2) -> void:
	aim_screen=screen; aim_enabled=true; hud.touch_aim_active=false
func refresh_aim() -> void:
	var from: Vector3
	var direction: Vector3
	if lab.aim:
		from=player.target_point(); direction=lab.look_direction()
	elif hud.touch_aim_active:
		from=player.target_point()
		var right: Vector3=camera.global_basis.x; right.y=0; right=right.normalized()
		var back: Vector3=Vector3(-right.z,0,right.x)
		direction=(right*hud.aim_direction.x+back*hud.aim_direction.y).normalized()
	elif gear.scope:
		from=camera.global_position; direction=-camera.global_basis.z
	elif aim_enabled:
		from=camera.project_ray_origin(aim_screen); direction=camera.project_ray_normal(aim_screen)
	else:
		from=player.global_position+Vector3.UP*1.2; direction=player.facing
	locked_drone=null
	if hud.touch_aim_active or not lab.aim:
		locked_drone=assist_drone(direction)
		if is_instance_valid(locked_drone): direction=(locked_drone.global_position-from).normalized()
	if not lab.aim and not hud.touch_aim_active:
		var target: Node3D=lab.lock_target()
		if is_instance_valid(target): direction=(target.position+(Vector3.UP if target in guards else Vector3.ZERO)-from).normalized()
	aim_hit=ray(from,from+direction*80,29,[player.get_rid()])
	aim_point=aim_hit.get("position",from+direction*28)
	if lab.aim or aim_enabled or gear.scope:
		var face: Vector3=aim_point-player.global_position; face.y=0
		if face.length()>.3 and player.mode=="ground": player.facing=face.normalized()
func _physics_process(delta: float) -> void:
	tick_count+=1
	for action: String in key_hold.keys():
		if int(key_hold[action])>=0 and Time.get_ticks_msec()-int(key_hold[action])>=450:
			key_hold[action]=-1;lab.open_wheel("weapon" if action=="weapon_slot" else "item")
	if demo_kind=="reload" and tick_count==72: gear.items[0].ammo=3; gear.reload()
	if mode=="play":
		elapsed+=delta; notification_time=maxf(0,notification_time-delta); support_cooldown=maxf(0,support_cooldown-delta); noise_cooldown=maxf(0,noise_cooldown-delta)
		if player.prone and in_vent(player.global_position) and hud.touch_aim_active:
			player.facing=player.facing.rotated(Vector3.UP,-hud.aim_stick.x*delta*1.5)
		lab.tick(delta)
		refresh_aim()
		var move: Vector2=Input.get_vector("left","right","up","down")
		if not Input.get_connected_joypads().is_empty():
			var pad: int=Input.get_connected_joypads()[0]
			var stick: Vector2=Vector2(Input.get_joy_axis(pad,JOY_AXIS_LEFT_X),Input.get_joy_axis(pad,JOY_AXIS_LEFT_Y))
			if stick.length()>.2: move=stick.limit_length()
			var look: Vector2=Vector2(Input.get_joy_axis(pad,JOY_AXIS_RIGHT_X),Input.get_joy_axis(pad,JOY_AXIS_RIGHT_Y))
			if look.length()>.2:
				if lab.aim: lab.look(look*delta*250)
				elif gear.scope: scope_yaw-=look.x*delta*1.8; scope_pitch=clampf(scope_pitch-look.y*delta*1.3,-1.1,1.1)
				else: aim_screen+=look*delta*400; aim_screen=aim_screen.clamp(Vector2.ZERO,get_viewport().get_visible_rect().size); aim_enabled=true
		if hud.joystick.length()>.08:
			var right: Vector3=camera.global_basis.x; right.y=0; right=right.normalized()
			var back: Vector3=Vector3(-right.z,0,right.x)
			var touch_move: Vector3=right*hud.joystick.x+back*hud.joystick.y
			move=Vector2(touch_move.x,touch_move.z)
		if demo_kind=="reveal_right": move=Vector2(1,0)
		elif demo_kind=="reveal_left": move=Vector2(-1,0)
		if lab.aim and hud.joy_id==-99:
			var side: Vector3=Vector3(cos(lab.yaw),0,-sin(lab.yaw))
			var back: Vector3=Vector3(sin(lab.yaw),0,cos(lab.yaw))
			var world_move: Vector3=side*move.x+back*move.y; move=Vector2(world_move.x,world_move.z)
		if not lab.wheel.is_empty() or lab.missions.hidden: move=Vector2.ZERO
		player.tick(delta,move)
		gear.tick(delta)
		if held("fire") and player.mode!="mantle":
			if room==3 and player.mode=="climb": player.strike()
			else: lab.fire()
		for guard: CharacterBody3D in guards: guard.tick(delta)
		for drone: CharacterBody3D in drones: drone.tick(delta)
		for projectile: Node3D in projectiles.duplicate(): if is_instance_valid(projectile): projectile.tick(delta)
		for mine: Node3D in mines.duplicate(): if is_instance_valid(mine): mine.tick(delta)
		if is_instance_valid(titan): titan.tick(delta)
		update_objectives()
	update_camera(delta)
	if is_instance_valid(player) and mode!="play": player.avatar.tick(delta,camera)
	for chip: Dictionary in chips:
		if not chip.taken: chip.node.rotation.y+=delta
	for i in range(effects.size()-1,-1,-1):
		var fx: Dictionary=effects[i]; fx.life-=delta
		if fx.life<=0: fx.node.queue_free(); effects.remove_at(i)
	hud.queue_redraw()
	if verify_web and tick_count%60==0:
		print("MG05_STATE "+JSON.stringify({"mode":mode,"room":room,"aim":lab.aim,"wheel":lab.wheel,"stamina":lab.stamina,"view":camera_controller.view,"prone":player.prone,"position":[player.position.x,player.position.y,player.position.z],"meshes":find_children("*","MeshInstance3D",true,false).size(),"drones":drones.size(),"feature_count":lab.evidence.size(),"object_count":stage.find_children("*","Node3D",true,false).size()}))
	if not capture_name.is_empty() and tick_count==100: capture.call_deferred()
func update_camera(delta: float) -> void:
	if is_instance_valid(player): camera_controller.update(delta)
func update_objectives() -> void:
	if mode!="play": return
	for chip: Dictionary in chips:
		if not chip.taken and player.global_position.distance_to(chip.at+Vector3.UP*.3)<1.2:
			chip.taken=true; chip.node.visible=false; collected+=1; sound("chip"); toast("Data secured %d/%d"%[collected,chips.size()])
	if mission_ready():
		exit_mesh.material_override=V.mat(Color("63efb0"),.8)
		if player.global_position.distance_to(rooms[room].exit)<1.4:
			mode="complete"; sound("win"); hud.release_controls()
			var score: int=maxi(100,4000-int(elapsed*8)-alarms*150)
			lab.missions.record()
			scores[str(room)]=maxi(score,int(scores.get(str(room),0))); save_scores()
func mission_ready() -> bool:
	if collected<chips.size(): return false
	for goal: String in rooms[room].goals:
		if not goals.has(goal): return false
	return true
func mark_goal(key: String) -> void:
	if not goals.has(key): goals[key]=true; sound("chip",-16)
func use_console() -> void:
	if player.global_position.distance_to(console_point)>3.5: toast("Move near the cyan training console, then USE."); return
	gear.replenish()
	if room==1:
		lab_drill=(lab_drill+1)%3
		if lab_drill==1: gear.force_jam(false)
		elif lab_drill==2: gear.force_jam(true)
		else:
			for target: StaticBody3D in targets:
				target.health=100; target.marker.material_override=V.mat(Color("394b5d"))
			toast("Range targets reset. Supplies refilled.")
	elif room==3: toast("Jump forward to catch the ledge. Up pulls up; down drops.")
	else: toast("Supplies refilled. All equipment is available from EQUIP.")
func emit_noise(at: Vector3,radius: float) -> void:
	for guard: CharacterBody3D in guards:
		if guard.global_position.distance_to(at)<radius: guard.hear(at)
func call_support(_at: Vector3) -> void:
	lab.missions.support(_at)
	toast("Radio complete: card-table backup is responding!")
	sound("radio")
func mark_aimed_guard() -> void:
	if aim_hit.has("collider") and aim_hit.collider in guards:
		aim_hit.collider.mark_time=30; toast("Guard marked on radar.")
	else: toast("Aim at a guard and USE to mark.")
func spawn_projectile(kind: String,at: Vector3,speed: Vector3) -> void:
	var node: Node3D=ProjectileScript.new(); node.game=self; node.kind=kind; node.velocity=speed; stage.add_child(node); node.global_position=at; projectiles.append(node)
func place_mine(kind: String) -> void:
	var node: Node3D=MineScript.new(); node.game=self; node.kind=kind; node.facing=player.facing
	stage.add_child(node); node.global_position=player.global_position+player.facing*.9; mines.append(node)
	toast("Mine placed." if kind=="claymore" else "C4 placed. Tap the C4 item again to detonate.")
func blast(at: Vector3,radius: float,damage: float,kind: String) -> void:
	if kind=="chaff":
		for drone: Node3D in drones:
			if drone.position.distance_to(at)<8 and clear_sight(at,drone.position): drone.disabled=8; drone.seeing=false
		toast("CHAFF: nearby drones disabled for 8 seconds."); sound("bleep",-12); return
	sound("explosion",-5); emit_noise(at,24)
	var sphere: MeshInstance3D=V.box(stage,at,Vector3.ONE*.6,V.mat(Color("ffb467"),1))
	var tween: Tween=sphere.create_tween(); tween.tween_property(sphere,"scale",Vector3.ONE*radius,.25)
	effects.append({"node":sphere,"life":.32})
	for guard: CharacterBody3D in guards:
		if guard.global_position.distance_to(at)<radius and clear_sight(at,guard.global_position+Vector3.UP): guard.receive_hit(damage,kind,at)
	for drone: Node3D in drones:
		if drone.position.distance_to(at)<radius and clear_sight(at,drone.position): drone.receive_hit(damage,kind,at)
	for target: StaticBody3D in targets:
		if target.global_position.distance_to(at)<radius and clear_sight(at,target.global_position+Vector3.UP): target.receive_hit(damage,kind,at)
	if player.global_position.distance_to(at)<radius and clear_sight(at,player.global_position+Vector3.UP): player.damage(damage*.3)
func tracer(a: Vector3,b: Vector3,color: Color,life: float) -> void:
	var node: MeshInstance3D=V.line(stage,a,b,color,.024); effects.append({"node":node,"life":life})
func flash_at(at: Vector3) -> void:
	var node: MeshInstance3D=V.box(stage,at,Vector3(.24,.24,.24),V.mat(Color("fff0a1"),2)); effects.append({"node":node,"life":.07})
func eject_case(at: Vector3,direction: Vector3) -> void:
	var node: MeshInstance3D=V.box(stage,at,Vector3(.08,.04,.13),V.mat(Color("d9b968")))
	var side: Vector3=direction.cross(Vector3.UP).normalized()
	var tween: Tween=node.create_tween(); tween.tween_property(node,"position",at+side*.7+Vector3.UP*.25,.12); tween.tween_property(node,"position",Vector3(at.x+side.x,0.1,at.z+side.z),.25)
	effects.append({"node":node,"life":.7})
func fail_mission() -> void:
	if mode=="play": mode="failed"; sound("fail"); hud.release_controls()
func toast(message: String) -> void: toast_text=message; notification_time=4
func save_scores() -> void:
	var file: FileAccess=FileAccess.open("user://mg_3d_scores.json",FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(scores))
func load_scores() -> void:
	if FileAccess.file_exists("user://mg_3d_scores.json"):
		var data: Variant=JSON.parse_string(FileAccess.get_file_as_string("user://mg_3d_scores.json"))
		if data is Dictionary: scores=data
func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and mode=="play": mode="paused"; hud.release_controls()
func setup_demo() -> void:
	mode="play"
	if demo_kind=="cover":
		player.global_position=Vector3(-4,0,3.48); player.toggle_cover()
	elif demo_kind=="reload":
		player.global_position=Vector3(-4,0,3.48); player.toggle_cover(); gear.items[0].ammo=3; gear.reload()
	elif demo_kind=="overhead": player.global_position=Vector3(-4,0,5)
	elif demo_kind=="vent":
		player.global_position=Vector3(6.5,0,2.5); player.toggle_crawl(); player.facing=Vector3.FORWARD
	elif demo_kind=="crawl":
		player.global_position=Vector3(6.5,0,4.5); player.toggle_crawl(); player.facing=Vector3.FORWARD
	elif demo_kind=="drones": player.global_position=Vector3(6,0,8)
	elif demo_kind=="indoor": player.global_position=Vector3(10,0,-3)
	elif demo_kind in ["reveal_right","reveal_left"]:
		player.global_position=Vector3(10,0,-9.1); player.toggle_cover()
	elif demo_kind=="crate_top":
		player.global_position=Vector3(-10,0,7.0); player.facing=Vector3.FORWARD
		await get_tree().physics_frame
		player.climb_box()
func capture() -> void:
	# Deterministic pose inspection, independent of software-renderer frame timing.
	if demo_kind=="reload":
		set_physics_process(false)
		gear.action="reload"; gear.action_time=.8; gear.items[0].ammo=3
		player.avatar.pose=6; player.avatar.tick(.01,camera)
		player.avatar.animation.play("reload",0); player.avatar.animation.advance(.5)
		player.avatar.animation.pause()
		hud.queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(capture_name)
	var tree: SceneTree=get_tree()
	tree.process_frame.connect(tree.quit,CONNECT_ONE_SHOT)
	queue_free()
func _exit_tree() -> void:
	if is_instance_valid(music):
		music.stop()
		music.stream=null

func in_vent(at: Vector3) -> bool:
	return vent_bounds.has_point(at+Vector3.UP*.3)
func assist_drone(direction: Vector3) -> Node3D:
	var best: Node3D=null
	var best_angle: float=deg_to_rad(12)
	var flat: Vector3=Vector3(direction.x,0,direction.z).normalized()
	for drone: Node3D in drones:
		if drone.health<=0: continue
		var to: Vector3=drone.global_position-player.target_point()
		var ground: Vector3=Vector3(to.x,0,to.z)
		if ground.length()<.1 or to.length()>18: continue
		var angle: float=flat.angle_to(ground.normalized())
		if angle<best_angle and clear_sight(player.target_point(),drone.global_position):
			best=drone; best_angle=angle
	return best
