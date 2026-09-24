extends Control
const Spatial=preload("res://scripts/StealthMath.gd")
const FONT=preload("res://assets/ui.ttf")
const BOLD=preload("res://assets/ui_bold.ttf")
const INK=Color("081726")
const WHITE=Color("e1eef8")
const MUTE=Color("91a7bb")
const CYAN=Color("66e9df")
const GOLD=Color("ffd386")
var game: Node
var buttons: Array=[]
var holds: Dictionary={}
var fingers: Dictionary={}
var joystick: Vector2=Vector2.ZERO
const MOVE_CENTER=Vector2(115,620)
const AIM_CENTER=Vector2(1155,620)
const STICK_RADIUS=62.0
var aim_stick: Vector2=Vector2.ZERO
var aim_direction: Vector2=Vector2(0,-1)
var touch_aim_active: bool=false
var aim_firing: bool=false
var aim_stick_id: int=-99
var joy_id: int=-99
var aim_id: int=-99
var scale_ui: float=1
var offset_ui: Vector2=Vector2.ZERO
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func release_controls() -> void:
	holds.clear(); fingers.clear(); joystick=Vector2.ZERO; joy_id=-99; aim_id=-99
	aim_stick=Vector2.ZERO; aim_stick_id=-99; aim_firing=false; touch_aim_active=false
	game.mouse_fire=false
func label(at: Vector2,text: String,size_px: int=16,color: Color=WHITE,bold: bool=false) -> void:
	draw_string(BOLD if bold else FONT,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px,color)
func center(at: Vector2,text: String,size_px: int=16,color: Color=WHITE) -> void:
	label(at-Vector2(FONT.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px).x/2,0),text,size_px,color)
func panel(rect: Rect2,color: Color=INK,edge: Color=Color("284252")) -> void:
	var style: StyleBoxFlat=StyleBoxFlat.new(); style.bg_color=color; style.border_color=edge; style.set_border_width_all(1); style.set_corner_radius_all(7)
	draw_style_box(style,rect)
func button(rect: Rect2,text: String,action: String,on: bool=false,small: bool=false) -> void:
	panel(rect,Color("16433f") if on else Color("142b3c"),CYAN if on else Color("436274"))
	center(rect.get_center()+Vector2(0,6),text,14 if small else 17,CYAN if on else WHITE)
	buttons.append({"rect":rect,"action":action})
func meter(at: Vector2,width: float,value: float,color: Color) -> void:
	draw_rect(Rect2(at,Vector2(width,5)),Color("2d4658")); draw_rect(Rect2(at,Vector2(width*clampf(value/100,0,1),5)),color)
func _draw() -> void:
	var viewport: Vector2=get_viewport_rect().size
	scale_ui=minf(viewport.x/1280,viewport.y/720); offset_ui=(viewport-Vector2(1280,720)*scale_ui)/2
	draw_set_transform(offset_ui,0,Vector2.ONE*scale_ui); buttons.clear()
	if not is_instance_valid(game.player): return
	panel(Rect2(16,14,974,73),Color(.025,.055,.095,.97))
	label(Vector2(32,38),"CHRONICLE CLASH / 3D",15,CYAN,true)
	label(Vector2(32,70),"%02d / %s"%[game.room+1,game.rooms[game.room].name],23,WHITE,true)
	label(Vector2(385,36),"HP %d"%int(game.player.health),13,MUTE); meter(Vector2(385,45),110,game.player.health,Color("78d6a7"))
	label(Vector2(515,36),"FULL 3D",13,CYAN)
	label(Vector2(645,36),"TOUCH v03",13,MUTE)
	label(Vector2(385,74),"%02d:%02d   DATA %d/%d"%[int(game.elapsed)/60,int(game.elapsed)%60,game.collected,game.chips.size()],16,WHITE)
	var alert: String="UNDETECTED"
	for guard: CharacterBody3D in game.guards:
		if guard.state in ["CALL","CHASE"]: alert="ALERT / EVADE"; break
		if guard.state in ["INVESTIGATE","SEARCH"]: alert="SEARCHING"
	label(Vector2(647,74),alert,14,Color("ff8b87") if alert=="ALERT / EVADE" else GOLD)
	button(Rect2(880,21,98,58),"PAUSE","pause",false,true)
	draw_radar(Rect2(1004,14,260,183))
	if game.mode=="play":
		panel(Rect2(16,99,245,42+game.rooms[game.room].goals.size()*22),Color(.025,.055,.095,.9))
		label(Vector2(29,122),"ONE-ROOM CHECKLIST",12,CYAN,true)
		var names: Dictionary={"cover":"Enter wall cover","guard_down":"Defeat the guard","knock":"Knock while in cover","binoculars":"Use binoculars","cloak":"Activate camouflage","target_pistol":"Pistol target","target_rifle":"Rifle target","target_sniper":"Sniper target","target_rocket":"Rocket target","reload":"Reload a weapon","grenade":"Throw a grenade","claymore":"Place a claymore","detonate":"Detonate a remote mine","ration":"Use a ration","titan_shoulder":"Disable shoulder target","titan_head":"Disable head target"}
		for i in range(game.rooms[game.room].goals.size()):
			var goal: String=game.rooms[game.room].goals[i]
			label(Vector2(29,147+i*22),("✓ " if game.goals.has(goal) else "○ ")+str(names.get(goal,goal)),13,CYAN if game.goals.has(goal) else WHITE)
	var item: Dictionary=game.gear.current()
	panel(Rect2(16,548,1248,156),Color(.025,.055,.095,.97))
	draw_stick(MOVE_CENTER,joystick,"MOVE",false)
	draw_stick(AIM_CENTER,aim_stick,"AIM / FIRE",aim_firing)
	label(Vector2(225,579),"PISTOL  %d / %d"%[item.ammo,item.reserve],21,GOLD,true)
	label(Vector2(490,579),"RELOADING" if game.gear.action_time>0 else "Push aim stick to its outer ring to fire",15,CYAN if game.gear.action_time>0 else MUTE)
	button(Rect2(905,558,136,37),"REFILL","use",false,true)
	var actions: Array=[["LEAVE COVER" if game.player.mode=="cover" else "COVER","brace"],["RELOAD","reload"],["FIRE","fire"],["KNOCK","knock"],["CROUCH","crouch"]]
	for i in range(actions.size()): button(Rect2(225+i*165,610,156,75),actions[i][0],actions[i][1],(game.held("fire") if actions[i][1]=="fire" else (game.player.mode=="cover" if actions[i][1]=="brace" else game.player.crouched if actions[i][1]=="crouch" else false)),true)
	if game.notification_time>0:
		panel(Rect2(185,511,1079,34),Color(.025,.055,.095,.95)); center(Vector2(724,534),game.toast_text,14,WHITE)
	elif game.room==3 and is_instance_valid(game.titan) and game.titan.warning:
		panel(Rect2(360,472,560,50),Color("532c26"),GOLD); center(Vector2(640,503),"SHAKE INCOMING — HOLD BRACE",21,GOLD)
	else:
		center(Vector2(640,542),"Left stick: move • Right stick: aim; push farther to fire • Tap buttons for actions",13,MUTE)
	if game.gear.selected==4 and game.mode=="play": draw_throw_arc()
	if game.gear.scope: draw_scope()
	elif game.aim_enabled and not game.camera.is_position_behind(game.aim_point):
		var p: Vector2=(game.camera.unproject_position(game.aim_point)-offset_ui)/scale_ui
		draw_arc(p,10,0,TAU,24,CYAN,1.5); draw_line(p-Vector2(15,0),p+Vector2(15,0),CYAN); draw_line(p-Vector2(0,15),p+Vector2(0,15),CYAN)
	if game.mode!="play": draw_modal()
func draw_scope() -> void:
	draw_arc(Vector2(640,360),145,0,TAU,80,Color("73eadb"),2)
	draw_line(Vector2(480,360),Vector2(800,360),Color("b7ddd8"),1)
	draw_line(Vector2(640,90),Vector2(640,510),Color("b7ddd8"),1)
	center(Vector2(640,112),"OPTICS  ×%d"%[2,4,8][game.gear.zoom],16,CYAN)
	center(Vector2(640,492),"Drag to look • USE to fire / mark • SCOPE to leave",13,WHITE)
func draw_radar(rect: Rect2) -> void:
	panel(rect); label(rect.position+Vector2(12,20),"TACTICAL GRID",12,CYAN,true)
	var r: Rect2=Rect2(rect.position+Vector2(12,30),rect.size-Vector2(24,41))
	for wall: Rect2 in game.walls: draw_rect(Rect2(map_point(wall.position,r),wall.size/Vector2(32,24)*r.size),Color("445d72"))
	for guard: CharacterBody3D in game.guards:
		if guard.health<=0: continue
		var at: Vector2=map_point(guard.point(),r)
		var color: Color=Color("ff7c7c") if guard.state in ["CALL","CHASE"] else GOLD
		draw_circle(at,3.4,color)
		if guard.mark_time>0: draw_arc(at,6,0,TAU,15,CYAN,1)
		var face: Vector2=Vector2(guard.facing.x,guard.facing.z)
		var points: PackedVector2Array=PackedVector2Array([at])
		for i in range(9): points.append(map_point(Spatial.clip_ray(guard.point(),guard.point()+face.rotated(lerpf(-.7,.7,i/8.0))*8.8,game.walls),r))
		draw_colored_polygon(points,Color(color,.13))
	for chip: Dictionary in game.chips:
		if not chip.taken: draw_circle(map_point(Vector2(chip.at.x,chip.at.z),r),2.4,GOLD)
	var exit: Vector3=game.rooms[game.room].exit
	draw_arc(map_point(Vector2(exit.x,exit.z),r),4,0,TAU,16,Color("71eab1"),1)
	draw_circle(map_point(game.player.point(),r),4,CYAN)
func map_point(at: Vector2,r: Rect2) -> Vector2: return r.position+(at+Vector2(16,12))/Vector2(32,24)*r.size
func draw_modal() -> void:
	draw_rect(Rect2(-1000,-1000,4000,3000),Color(.015,.035,.06,.9)); buttons.clear()
	panel(Rect2(135,100,1010,512),INK,Color("3b6475"))
	label(Vector2(174,144),"CHRONICLE CLASH / 3D / TOUCH BUILD 03",15,CYAN,true)
	var title: String="3D COVER PROTOTYPE"
	var sub: String="One room. Articulated 3D characters. Cover and pistol combat."
	var primary: String="TAP TO START"
	if game.mode=="equipment":
		label(Vector2(174,196),"EQUIPMENT",30,WHITE,true)
		for i in range(game.gear.items.size()):
			var item: Dictionary=game.gear.items[i]
			button(Rect2(174+(i%3)*303,224+int(i/3)*82,287,64),str(item.name),"equip_"+str(i),i==game.gear.selected,true)
		button(Rect2(174,530,265,48),"BACK TO TRAINING","pause",true)
		label(Vector2(470,561),"HOOK, CLOAK and BRACE always available.",15,MUTE)
		return
	if game.mode=="brief": title="%02d / %s"%[game.room+1,game.rooms[game.room].name]; sub=game.rooms[game.room].tag; primary="PLAY"
	elif game.mode=="paused": title="SIMULATION PAUSED"; sub="Review the controls or retry this room."; primary="RESUME"
	elif game.mode=="failed": title="SIGNAL LOST"; sub="Try again. Use cover and interrupt the guard before it fires."; primary="RETRY ROOM"
	elif game.mode=="complete": title="TRAINING COMPLETE"; sub="Room cleared in %.1fs / %d alerts / best %d"%[game.elapsed,game.alarms,int(game.scores.get(str(game.room),0))]; primary="REPLAY TEST ROOM"
	label(Vector2(174,199),title,30,WHITE,true); label(Vector2(174,236),sub,18,GOLD)
	if game.mode=="title":
		for i in range(1):
			button(Rect2(174+i*230,275,214,67),"COVER TEST","room_"+str(i),i==game.room,true)
		label(Vector2(174,386),"3D skeleton • Walk / aim / reload • Wall camera • One guard",17,WHITE)
		label(Vector2(174,421),"Character models are blockouts for testing movement and camera contact.",16,MUTE)
	elif game.mode=="brief":
		var lines: PackedStringArray=game.rooms[game.room].brief.split("\n")
		for i in range(lines.size()): label(Vector2(174,288+i*32),lines[i],18,WHITE)
		label(Vector2(174,410),"Left stick moves. Right stick aims; push to its edge to fire.",16,MUTE)
		label(Vector2(174,440),"Cyan console: refill pistol ammo. Green ring: extraction.",16,MUTE)
	else:
		label(Vector2(174,284),"Left stick: MOVE • Right stick: AIM / FIRE",16,WHITE)
		label(Vector2(174,317),"Tap COVER, then move sideways to peek. Tap KNOCK to distract.",16,WHITE)
		label(Vector2(174,350),"Tap RELOAD for ammo. REFILL works near the cyan console.",16,WHITE)
		label(Vector2(174,393),"You can move and aim/fire with two thumbs.",15,MUTE)
		label(Vector2(174,423),"Tap RESUME to continue or RETRY to restart.",15,MUTE)
	button(Rect2(174,525,360,57),primary,"confirm",true)
	button(Rect2(554,525,170,57),"SOUND "+("OFF" if game.muted else "ON"),"mute",false,true)
	button(Rect2(744,525,170,57),"RETRY","retry",false,true)
	button(Rect2(934,525,170,57),"MENU","menu",false,true)
func draw_stick(at: Vector2,value: Vector2,title: String,firing: bool) -> void:
	var color: Color=GOLD if firing else CYAN
	draw_circle(at,STICK_RADIUS,Color("152e40"))
	draw_arc(at,STICK_RADIUS,0,TAU,64,color,2.5)
	if title=="AIM / FIRE": draw_arc(at,STICK_RADIUS*.82,0,TAU,64,Color("76694d"),1)
	draw_circle(at+value*43,22,color)
	center(at+Vector2(0,78),title,14,color)
func stick_value(at: Vector2,center_at: Vector2) -> Vector2:
	var value: Vector2=((at-offset_ui)/scale_ui-center_at)/STICK_RADIUS
	return Vector2.ZERO if value.length()<.12 else value.limit_length()
func update_aim_stick(at: Vector2) -> void:
	aim_stick=stick_value(at,AIM_CENTER)
	aim_firing=aim_stick.length()>=.82
	if aim_stick.length()>.12:
		aim_direction=aim_stick.normalized(); touch_aim_active=true; game.aim_enabled=true
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed: press(event.position,event.index)
		else: release(event.index)
	elif event is InputEventScreenDrag:
		drag(event.position,event.index)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed: press(event.position,-1)
		else: release(-1); game.mouse_fire=false
	elif event is InputEventMouseMotion:
		if joy_id==-1 or aim_stick_id==-1: drag(event.position,-1)
		elif game.mode=="play" and event.position.y<(548*scale_ui+offset_ui.y): game.update_aim(event.position)
func drag(at: Vector2,id: int) -> void:
	if id==joy_id: joystick=stick_value(at,MOVE_CENTER)
	elif id==aim_stick_id: update_aim_stick(at)
	elif id==aim_id: game.update_aim(at)
func press(at: Vector2,id: int) -> void:
	var p: Vector2=(at-offset_ui)/scale_ui
	for entry: Dictionary in buttons:
		if entry.rect.has_point(p):
			var action: String=entry.action
			if action=="fire": holds.fire=true; fingers[id]="fire"
			game.command(action)
			get_viewport().set_input_as_handled(); return
	if game.mode!="play": return
	if p.distance_to(MOVE_CENTER)<STICK_RADIUS+15 and joy_id==-99:
		joy_id=id; joystick=stick_value(at,MOVE_CENTER); fingers[id]="move"
	elif p.distance_to(AIM_CENTER)<STICK_RADIUS+15 and aim_stick_id==-99:
		aim_stick_id=id; fingers[id]="aim_stick"; update_aim_stick(at)
	elif p.y>90 and p.y<510 and aim_id==-99:
		aim_id=id; game.update_aim(at); fingers[id]="aim"
		if id==-1: game.mouse_fire=true
	get_viewport().set_input_as_handled()
func release(id: int) -> void:
	if fingers.has(id):
		var action: String=fingers[id]; fingers.erase(id)
		if action=="fire": holds.fire=fingers.values().has("fire")
	if id==joy_id: joy_id=-99; joystick=Vector2.ZERO
	if id==aim_id: aim_id=-99
	if id==aim_stick_id: aim_stick_id=-99; aim_stick=Vector2.ZERO; aim_firing=false

func draw_throw_arc() -> void:
	var origin: Vector3=game.player.global_position+Vector3.UP
	var flat: Vector3=game.aim_point-origin; flat.y=0
	flat=flat.normalized()
	var velocity: Vector3=flat*clampf(origin.distance_to(game.aim_point),3,12)+Vector3.UP*7
	var at: Vector3=origin+flat*.6
	var previous: Vector2=(game.camera.unproject_position(at)-offset_ui)/scale_ui
	for i in range(22):
		velocity.y-=16*.07
		var next: Vector3=at+velocity*.07
		var hit: Dictionary=game.ray(at,next,29)
		if not hit.is_empty(): next=hit.position
		if game.camera.is_position_behind(next): break
		var screen: Vector2=(game.camera.unproject_position(next)-offset_ui)/scale_ui
		draw_line(previous,screen,Color(1,.8,.4,.65),2)
		previous=screen; at=next
		if not hit.is_empty(): draw_arc(screen,8,0,TAU,20,GOLD,2); break
