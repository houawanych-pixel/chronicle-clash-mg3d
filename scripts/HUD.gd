extends Control
const FONT=preload("res://assets/ui.ttf")
const BOLD=preload("res://assets/ui_bold.ttf")
const CYAN=Color("72e9df")
const WHITE=Color("edf4fa")
const GOLD=Color("ffce83")
const INK=Color(.02,.055,.085,.90)
var game: Node
var buttons: Array=[]
var text_sizes: Array[int]=[]
var holds: Dictionary={}
var fingers: Dictionary={}
var joystick: Vector2=Vector2.ZERO
var move_center: Vector2=Vector2(165,575)
var joy_id: int=-99
var aim_id: int=-99
var last_look: Vector2
var scale_ui: float=1
var offset_ui: Vector2=Vector2.ZERO
# Legacy aim fields retained for external regression fixtures, not touch controls.
var aim_stick: Vector2=Vector2.ZERO
var aim_direction: Vector2=Vector2(0,-1)
var touch_aim_active: bool=false
var aim_firing: bool=false
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter=Control.MOUSE_FILTER_IGNORE
func release_controls() -> void:
	holds.clear(); fingers.clear(); joystick=Vector2.ZERO; joy_id=-99; aim_id=-99; touch_aim_active=false; aim_firing=false; game.mouse_fire=false
func _process(_delta: float) -> void:
	for id: int in fingers.keys():
		var f: Dictionary=fingers[id]
		if f.action in ["weapon_slot","item_slot"] and not f.long and Time.get_ticks_msec()-f.start>=450:
			f.long=true; game.lab.open_wheel("weapon" if f.action=="weapon_slot" else "item"); break
func label(at: Vector2,value: String,size_px: int=28,color: Color=WHITE,bold: bool=false) -> void:
	text_sizes.append(size_px); draw_string(BOLD if bold else FONT,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px,color)
func center(at: Vector2,value: String,size_px: int=28,color: Color=WHITE,bold: bool=false) -> void:
	var font: Font=BOLD if bold else FONT
	label(at-Vector2(font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px).x/2,0),value,size_px,color,bold)
func panel(rect: Rect2,color: Color=INK) -> void:
	var s: StyleBoxFlat=StyleBoxFlat.new(); s.bg_color=color; s.border_color=Color("426778"); s.set_border_width_all(2); s.set_corner_radius_all(12); draw_style_box(s,rect)
func button(rect: Rect2,value: String,action: String,on: bool=false) -> void:
	panel(rect,Color(.08,.28,.30,.95) if on else INK); center(rect.get_center()+Vector2(0,9),value,22,CYAN if on else WHITE,true)
	buttons.append({"rect":rect,"action":action})
func round_button(at: Vector2,radius: float,value: String,action: String,on: bool=false) -> void:
	draw_circle(at,radius,Color(.07,.23,.26,.8) if on else INK); draw_arc(at,radius,0,TAU,64,CYAN if on else Color("9daebc"),3)
	center(at+Vector2(0,8),value,22,CYAN if on else WHITE,true)
	buttons.append({"rect":Rect2(at-Vector2.ONE*radius,Vector2.ONE*radius*2),"circle":at,"radius":radius,"action":action})
func bar(at: Vector2,value: float,title: String,color: Color) -> void:
	label(at,title+"  "+str(int(value)),28,WHITE,true)
	draw_rect(Rect2(at+Vector2(155,-20),Vector2(205,22)),Color("203848")); draw_rect(Rect2(at+Vector2(155,-20),Vector2(205*clampf(value/100,0,1),22)),color)
func _draw() -> void:
	var size: Vector2=get_viewport_rect().size
	# Insets on all sides also keep controls clear of rounded corners and notches.
	scale_ui=minf(size.x/1280,size.y/720); offset_ui=(size-Vector2(1280,720)*scale_ui)*.5
	draw_set_transform(offset_ui,0,Vector2.ONE*scale_ui); buttons.clear(); text_sizes.clear()
	if not is_instance_valid(game.player): return
	panel(Rect2(24,18,406,116)); bar(Vector2(42,58),game.player.health,"HP",Color("ed767b")); bar(Vector2(42,108),game.lab.stamina,"STA",CYAN)
	panel(Rect2(24,150,830,52)); center(Vector2(439,186),game.lab.objective(),28)
	buttons.append({"rect":Rect2(24,150,830,52),"action":"objectives"})
	draw_radar(Rect2(1010,20,230,175)); round_button(Vector2(932,68),40,"II","pause")
	button(Rect2(910,225,216,68),str(game.gear.current().name)+" "+str(game.gear.current().ammo),"weapon_slot",game.lab.drawn)
	round_button(Vector2(1196,260),43,"LOAD","reload")
	button(Rect2(910,316,330,62),game.lab.item.to_upper()+"  "+str(game.lab.item_counts.get(game.lab.item,0)),"item_slot")
	round_button(Vector2(1160,612),90,"FIRE" if game.lab.drawn else "STRIKE","fire",game.held("fire"))
	round_button(Vector2(930,618),60,game.lab.context(),"action")
	round_button(Vector2(935,455),60,"STAND" if game.player.prone or game.player.crouched else "CROUCH","crouch",game.player.crouched or game.player.prone)
	round_button(Vector2(1110,455),55,"AIM","aim",game.lab.aim)
	var mc: Vector2=move_center if joy_id!=-99 else Vector2(165,575)
	draw_circle(mc,78,Color(.02,.08,.12,.45)); draw_arc(mc,78,0,TAU,64,CYAN,2); draw_circle(mc+joystick*58,27,Color(CYAN,.7))
	if game.lab.aim:
		if game.lab.spectrum>0:
			draw_rect(Rect2(0,0,1280,720),Color(.05,.6,.12,.13) if game.lab.spectrum==1 else Color(.65,.12,.05,.13))
			label(Vector2(460,225),"NV FILTER" if game.lab.spectrum==1 else "THERMAL FILTER",28,CYAN)
		draw_line(Vector2(622,360),Vector2(658,360),CYAN,2); draw_line(Vector2(640,342),Vector2(640,378),CYAN,2)
		if game.lab.optic=="binoculars" or str(game.gear.current().id)=="sniper":
			draw_arc(Vector2(640,360),205,0,TAU,80,CYAN,3)
			button(Rect2(520,592,72,66),"−","zoom_out"); button(Rect2(614,592,72,66),"+","zoom_in"); button(Rect2(710,592,142,66),["DAY","NVG","THERMAL"][game.lab.spectrum],"spectrum")
			center(Vector2(640,235),"×%d   %dm"%[[2,4,8][game.lab.zoom],int(game.player.position.distance_to(game.aim_point))],28)
	if game.lab.oxygen<100: bar(Vector2(42,254),game.lab.oxygen,"O2",Color("79b4ec"))
	if game.notification_time>0:
		panel(Rect2(452,24,426,100)); var words: PackedStringArray=game.toast_text.split(" "); var line: String=""; var y: int=60
		for word: String in words:
			if FONT.get_string_size(line+word,HORIZONTAL_ALIGNMENT_LEFT,-1,28).x>390:
				label(Vector2(466,y),line,28,GOLD); line=""; y+=33
				if y>100: break
			line+=word+" "
		if y<=100: label(Vector2(466,y),line,28,GOLD)
	if not game.lab.wheel.is_empty(): draw_wheel()
	elif game.lab.objective_expanded: draw_objectives()
	elif game.mode=="chambers": draw_chambers()
	elif game.mode=="checklist": draw_checklist()
	elif game.mode!="play": draw_modal()
func draw_radar(rect: Rect2) -> void:
	panel(rect)
	var r: Rect2=rect.grow(-12)
	for wall: Rect2 in game.walls: draw_rect(Rect2(map_point(wall.position,r),wall.size/Vector2(32,24)*r.size),Color("496475"))
	for guard: Node3D in game.guards:
		if guard.health>0:
			var p: Vector2=map_point(guard.point(),r); draw_circle(p,4,GOLD)
			var f: Vector2=Vector2(guard.facing.x,guard.facing.z)
			draw_colored_polygon(PackedVector2Array([p,p+f.rotated(-.65)*26,p+f.rotated(.65)*26]),Color(1,.6,.2,.2))
	for drone: Node3D in game.drones:
		if drone.health>0: draw_rect(Rect2(map_point(drone.point(),r)-Vector2(3,3),Vector2(6,6)),GOLD if drone.kind=="scout" else Color("ff7878"))
	for mine: Node3D in game.mines:
		if mine.kind=="claymore":
			var p: Vector2=map_point(Vector2(mine.position.x,mine.position.z),r);var d: Vector2=Vector2(mine.facing.x,mine.facing.z)
			draw_colored_polygon(PackedVector2Array([p,p+d.rotated(-.7)*20,p+d.rotated(.7)*20]),Color(.9,.3,.2,.3))
	draw_circle(map_point(game.player.point(),r),5,CYAN)
func map_point(at: Vector2,r: Rect2) -> Vector2: return r.position+(at+Vector2(16,12))/Vector2(32,24)*r.size
func draw_wheel() -> void:
	panel(Rect2(235,120,670,565)); buttons.clear();center(Vector2(570,170),game.lab.wheel.to_upper()+" SELECT",34,WHITE,true)
	var names: Array=game.lab.item_counts.keys() if game.lab.wheel=="item" else game.gear.items.map(func(x: Dictionary): return x.name)
	for i in range(mini(6,names.size()-game.lab.wheel_page*6)):
		var index: int=i+game.lab.wheel_page*6; var angle: float=TAU*i/6-PI/2
		var at: Vector2=Vector2(570,398)+Vector2(cos(angle)*220,sin(angle)*170)
		button(Rect2(at-Vector2(100,32),Vector2(200,64)),str(names[index]).to_upper(),("item_"+str(names[index])) if game.lab.wheel=="item" else "equip_"+str(index))
	button(Rect2(280,608,155,55),"PREV","wheel_prev");button(Rect2(480,608,165,55),"CLOSE","wheel_close");button(Rect2(700,608,155,55),"NEXT","wheel_next")
func draw_objectives() -> void:
	panel(Rect2(155,210,700,380)); buttons.clear();label(Vector2(185,260),"OBJECTIVES",34,WHITE,true)
	var y: int=315
	for g: String in game.rooms[game.room].goals:
		label(Vector2(185,y),("✓ " if game.goals.has(g) else "○ ")+g.replace("_"," "),28);y+=44
	button(Rect2(620,514,185,56),"CLOSE","objectives")
func draw_modal() -> void:
	draw_rect(Rect2(0,0,1280,720),Color(.01,.025,.04,.95)); buttons.clear()
	label(Vector2(70,88),"CHRONICLE CLASH / VR LAB",40,CYAN,true)
	var title: String={"title":"INTEGRATED TESTBED","brief":"READY: "+game.rooms[game.room].name,"paused":"PAUSED","complete":"EXTRACTION COMPLETE","failed":"RETRY THE SIMULATION"}.get(game.mode,game.mode.to_upper())
	label(Vector2(70,150),title,34,WHITE,true)
	label(Vector2(70,220),"Hold WEAPON or ITEM to choose equipment.",28)
	label(Vector2(70,265),"Push a wall for cover. ACTION changes with context.",28)
	label(Vector2(70,310),"Tap AIM; drag the right side to look. FIRE to shoot.",28)
	label(Vector2(70,355),"Tap CROUCH, then move to crawl. Tap again to stand.",28)
	label(Vector2(70,410),game.rooms[game.room].tag,28,GOLD)
	var record: Dictionary=game.scores.get("record_"+str(game.room),{})
	if not record.is_empty():label(Vector2(780,355),"BEST %.1fs / %s"%[record.time,record.rank],28,CYAN)
	button(Rect2(70,450,295,66),"CHAMBERS","chambers");button(Rect2(395,450,295,66),"CHECKLIST","checklist");button(Rect2(720,450,450,66),"TEST: ALL OPEN" if game.lab.test_mode else "TRAINING MODE","test_mode")
	button(Rect2(70,536,295,80),"PLAY" if game.mode in ["title","brief"] else "RESUME" if game.mode=="paused" else "RETRY","confirm")
	button(Rect2(395,536,220,80),"RETRY","retry");button(Rect2(645,536,220,80),"MENU","menu");button(Rect2(895,536,280,80),"SOUND","mute")
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed: press(event.position,event.index)
		else: release(event.index)
	elif event is InputEventScreenDrag: drag(event.position,event.index)
	elif event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed: press(event.position,-1)
			else: release(-1)
		elif event.button_index==MOUSE_BUTTON_RIGHT and event.pressed: game.command("aim")
	elif event is InputEventMouseMotion:
		if aim_id==-1: drag(event.position,-1)
func press(at: Vector2,id: int) -> void:
	var p: Vector2=(at-offset_ui)/scale_ui
	for b: Dictionary in buttons:
		var hit: bool=p.distance_to(b.circle)<=b.radius+6 if b.has("circle") else b.rect.grow(6).has_point(p)
		if hit:
			var a: String=b.action; fingers[id]={"action":a,"start":Time.get_ticks_msec(),"long":false}
			if a=="fire": holds.fire=true
			elif not a in ["weapon_slot","item_slot"]: game.command(a)
			get_viewport().set_input_as_handled(); return
	if game.mode!="play" or not game.lab.wheel.is_empty() or game.lab.objective_expanded: return
	if p.x<640 and p.y>215 and joy_id==-99 and id!=-1:
		joy_id=id; move_center=p.clamp(Vector2(90,220),Vector2(585,625)); joystick=Vector2.ZERO; fingers[id]={"action":"move"}
	elif p.x>=640 and aim_id==-99 and (game.lab.aim or game.camera_controller.view=="vent"):
		aim_id=id; last_look=p; fingers[id]={"action":"look"}
		if not game.lab.aim: game.lab.yaw=atan2(-game.player.facing.x,-game.player.facing.z); game.lab.pitch=0
	elif id==-1: holds.fire=true; fingers[id]={"action":"fire"}
	get_viewport().set_input_as_handled()
func drag(at: Vector2,id: int) -> void:
	var p: Vector2=(at-offset_ui)/scale_ui
	if id==joy_id:
		joystick=((p-move_center)/78).limit_length()
		if joystick.length()<.1: joystick=Vector2.ZERO
	elif id==aim_id:
		game.lab.look(p-last_look); last_look=p
		if not game.lab.aim: game.player.facing=Vector3(-sin(game.lab.yaw),0,-cos(game.lab.yaw))
func release(id: int) -> void:
	if fingers.has(id):
		var f: Dictionary=fingers[id]; fingers.erase(id)
		if f.action=="weapon_slot" and not f.long: game.lab.drawn=not game.lab.drawn
		elif f.action=="item_slot" and not f.long: game.lab.use_item()
		holds.fire=false
		for other: Dictionary in fingers.values():
			if other.action=="fire": holds.fire=true
	if id==joy_id: joy_id=-99; joystick=Vector2.ZERO
	if id==aim_id: aim_id=-99

func draw_chambers() -> void:
	draw_rect(Rect2(0,0,1280,720),INK);buttons.clear();label(Vector2(65,70),"CHAMBERS / ALL OPEN" if game.lab.test_mode else "TRAINING / PROGRESSION",34,CYAN,true)
	var begin: int=game.lab.menu_page*6
	for i in range(6):
		var id: int=begin+i
		if id>=game.rooms.size(): break
		var locked: bool=not game.lab.test_mode and id>int(game.scores.get("unlocked",7))
		button(Rect2(70,110+i*76,1120,65),("LOCKED / " if locked else "")+game.rooms[id].name,"room_"+str(id))
	button(Rect2(70,610,270,70),"PREVIOUS","page_prev");button(Rect2(380,610,270,70),"MENU","menu");button(Rect2(690,610,270,70),"NEXT","page_next")
func draw_checklist() -> void:
	draw_rect(Rect2(0,0,1280,720),INK);buttons.clear();label(Vector2(65,70),"VERIFICATION / BUILD 06",34,CYAN,true)
	for i in range(5):
		var id: int=game.lab.feature_page*5+i
		if id>=game.lab.features.size(): break
		var feature: String=game.lab.features[id];var entry: Dictionary=game.lab.evidence.get(feature,{})
		label(Vector2(65,130+i*91),feature,28,WHITE,true)
		label(Vector2(65,166+i*91),str(entry.get("status","UNFINISHED"))+" / "+str(entry.get("test","No passing test recorded")),24,CYAN if entry.get("status","")=="WORKING" else GOLD)
	button(Rect2(70,610,270,70),"PREVIOUS","features_prev");button(Rect2(380,610,270,70),"MENU","menu");button(Rect2(690,610,270,70),"NEXT","features_next")
