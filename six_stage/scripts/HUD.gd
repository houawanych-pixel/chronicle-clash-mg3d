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
	game.lab.aim=false; game.fire_blocked=true; game.aim_acquired=false; holds.clear(); fingers.clear(); joystick=Vector2.ZERO; joy_id=-99; aim_id=-99; touch_aim_active=false; aim_firing=false; game.mouse_fire=false
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
	panel(Rect2(24,150,830,52)); center(Vector2(439,184),game.lab.objective(),24)
	label(Vector2(40,232),"%02d / 06   %s"%[game.room+1,game.rooms[game.room].name],20,CYAN,true)
	label(Vector2(40,261),"ACCESS  L%d   ·   ALERTS  %d"%[int(game.stage01.state.card),game.alarms],18,GOLD)
	buttons.append({"rect":Rect2(24,150,830,52),"action":"objectives"})
	draw_radar(Rect2(1010,20,230,175)); round_button(Vector2(932,68),40,"II","pause")
	button(Rect2(910,225,216,68),str(game.gear.current().name)+" "+str(game.gear.current().ammo),"weapon_slot",game.lab.drawn)
	round_button(Vector2(1196,260),46,"RELOAD","reload")
	button(Rect2(910,316,330,62),game.lab.item.to_upper()+"  "+str(game.lab.item_counts.get(game.lab.item,0)),"item_slot")
	round_button(Vector2(1160,612),90,"FIRE" if game.lab.drawn else "STRIKE","fire",game.held("fire"))
	round_button(Vector2(930,618),60,game.lab.context(),"action")
	round_button(Vector2(935,455),60,"STAND" if game.player.prone or game.player.crouched else "CROUCH","crouch",game.player.crouched or game.player.prone)
	round_button(Vector2(1110,455),55,"LOWER" if game.lab.aim else "AIM","aim",game.lab.aim)
	var mc: Vector2=move_center if joy_id!=-99 else Vector2(165,575)
	draw_circle(mc,78,Color(.02,.08,.12,.45)); draw_arc(mc,78,0,TAU,64,CYAN,2); draw_circle(mc+joystick*58,27,Color(CYAN,.7))
	draw_guide()
	if game.lab.aim:
		if game.lab.spectrum>0:
			draw_rect(Rect2(0,0,1280,720),Color(.05,.6,.12,.13) if game.lab.spectrum==1 else Color(.65,.12,.05,.13))
			label(Vector2(460,225),"NV FILTER" if game.lab.spectrum==1 else "THERMAL FILTER",28,CYAN)
		draw_circle(Vector2(640,360),3,GOLD); draw_arc(Vector2(640,360),9,0,TAU,20,Color(CYAN,.6),1)
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
	if game.player.mode=="swim":
		panel(Rect2(452,90,400,50));label(Vector2(470,125),"OXYGEN  %d%%"%game.lab.oxygen,28,CYAN,true)
	if not game.lab.wheel.is_empty(): draw_wheel()
	elif game.lab.objective_expanded: draw_objectives()
	elif game.mode=="puzzle": draw_puzzle()
	elif game.mode=="chambers": draw_chambers()
	elif game.mode=="checklist": draw_checklist()
	elif game.mode!="play": draw_modal()
func draw_radar(rect: Rect2) -> void:
	panel(rect)
	var r: Rect2=rect.grow(-12)
	for at: Vector3 in game.stage01.nodes:
		draw_rect(Rect2(map_point(Vector2(at.x,at.z),r),Vector2(1.6,1.5)),Color("37565d"))
	var goal: Vector3=game.stage01.current_point().at
	draw_circle(map_point(Vector2(goal.x,goal.z),r),5,Color("9bffbc"))
	for guard: Node3D in game.guards:
		if guard.health>0:
			var p: Vector2=map_point(guard.point(),r); draw_circle(p,4,Color("ff5252") if guard.state in ["CALL","CHASE"] else GOLD)
			var f: Vector2=Vector2(guard.facing.x,guard.facing.z)
			draw_colored_polygon(PackedVector2Array([p,p+f.rotated(-.65)*26,p+f.rotated(.65)*26]),Color(1,.6,.2,.2))
	for drone: Node3D in game.drones:
		if drone.health>0: draw_rect(Rect2(map_point(drone.point(),r)-Vector2(3,3),Vector2(6,6)),GOLD if drone.kind=="scout" else GOLD)
	for mine: Node3D in game.mines:
		if mine.kind=="claymore":
			var p: Vector2=map_point(Vector2(mine.position.x,mine.position.z),r);var d: Vector2=Vector2(mine.facing.x,mine.facing.z)
			draw_colored_polygon(PackedVector2Array([p,p+d.rotated(-.7)*20,p+d.rotated(.7)*20]),Color(.9,.3,.2,.3))
	draw_circle(map_point(game.player.point(),r),5,CYAN)
func map_point(at: Vector2,r: Rect2) -> Vector2: return r.position+(at+Vector2(34,34))/Vector2(68,68)*r.size
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
func big_button(rect: Rect2,value: String,action: String,size_px: int=54) -> void:
	var s: StyleBoxFlat=StyleBoxFlat.new(); s.bg_color=Color("1f8f58"); s.border_color=Color("7dffb0"); s.set_border_width_all(4); s.set_corner_radius_all(22)
	draw_style_box(s,rect); center(rect.get_center()+Vector2(0,size_px*.36),value,size_px,WHITE,true)
	buttons.append({"rect":rect,"action":action})
func draw_modal() -> void:
	draw_rect(Rect2(0,0,1280,720),Color(.015,.035,.05,.94)); buttons.clear()
	if game.mode=="title":
		center(Vector2(640,250),"HOVAGI",120,CYAN,true)
		big_button(Rect2(400,340,480,150),"START","continue",72)
		if game.stage01.saved: button(Rect2(70,600,260,70),"NEW GAME","new_game")
	elif game.mode=="brief":
		center(Vector2(640,200),"STAGE %02d"%(game.room+1),40,GOLD,true)
		center(Vector2(640,270),game.rooms[game.room].name,52,WHITE,true)
		center(Vector2(640,330),"Follow the green light.",34,Color("7dffb0"),true)
		big_button(Rect2(440,390,400,130),"GO","confirm",64)
	elif game.mode=="paused":
		center(Vector2(640,220),"PAUSED",64,WHITE,true)
		big_button(Rect2(440,290,400,120),"RESUME","confirm",52)
		button(Rect2(480,450,320,76),"RETRY CHECKPOINT","retry")
	elif game.mode in ["complete","victory"]:
		center(Vector2(640,200),"MISSION COMPLETE" if game.mode=="victory" else "STAGE CLEAR",64,Color("7dffb0"),true)
		center(Vector2(640,270),"TIME  %d:%02d     ALERTS  %d"%[int(game.elapsed)/60,int(game.elapsed)%60,game.alarms],32,WHITE)
		big_button(Rect2(440,330,400,130),"NEXT" if game.mode=="complete" else "PLAY AGAIN","confirm",56)
	else:
		center(Vector2(640,220),"CAUGHT",72,Color("ff7a7a"),true)
		big_button(Rect2(440,290,400,130),"TRY AGAIN","retry",52)
	button(Rect2(1030,600,200,70),"SOUND OFF" if not game.muted else "SOUND ON","mute")
func draw_puzzle() -> void:
	draw_rect(Rect2(0,0,1280,720),Color(.015,.035,.05,.96));buttons.clear()
	var c: RefCounted=game.stage01
	label(Vector2(95,115),"FACILITY INTERLOCK",36,CYAN,true)
	if c.puzzle=="grid":
		label(Vector2(95,192),"SECURITY CIRCUITS",30,WHITE,true)
		label(Vector2(95,255),"Maintenance log: isolate B, then A, then C.",27,GOLD)
		label(Vector2(95,305),"Sequence progress: %d / 3"%c.sequence.size(),27)
		for i in range(3):button(Rect2(95+i*360,380,320,90),"CIRCUIT "+["A","B","C"][i],"puzzle_"+str(i))
	elif c.puzzle=="cooling":
		label(Vector2(95,192),"COOLANT BALANCE",30,WHITE,true)
		label(Vector2(95,253),"Each valve toggles itself and its next neighbor (C wraps to A).",25)
		label(Vector2(95,303),"TARGET:   A ON    /    B OFF    /    C ON",29,GOLD)
		for i in range(3):button(Rect2(95+i*360,380,320,90),["A","B","C"][i]+("  ON" if c.valves[i] else "  OFF"),"puzzle_"+str(i),c.valves[i])
	else:
		label(Vector2(95,192),"CONVEYOR EMERGENCY STOP",30,WHITE,true)
		label(Vector2(95,254),"Stop the line during the green service window.",27,GOLD)
		var good: bool=fmod(c.clock,3)<1.2
		panel(Rect2(95,306,1080,48));draw_rect(Rect2(99,310,430,40),Color("2d977a"));draw_rect(Rect2(99+fmod(c.clock,3)/3*1065,305,8,50),WHITE)
		button(Rect2(310,396,620,88),"STOP LINE" if good else "WAIT FOR GREEN","puzzle_0",good)
	label(Vector2(95,535),c.puzzle_message,23,GOLD)
	button(Rect2(95,593,280,67),"STEP AWAY","puzzle_close")
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed: press(event.position,event.index)
		else: release(event.index)
	elif event is InputEventScreenDrag: drag(event.position,event.index)
	elif event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed: press(event.position,-1)
			else: release(-1)
		elif event.button_index==MOUSE_BUTTON_RIGHT: game.set_precision(event.pressed)
	elif event is InputEventMouseMotion:
		if aim_id==-1: drag(event.position,-1)
func press(at: Vector2,id: int) -> void:
	var p: Vector2=(at-offset_ui)/scale_ui
	for b: Dictionary in buttons:
		var hit: bool=p.distance_to(b.circle)<=b.radius+6 if b.has("circle") else b.rect.grow(6).has_point(p)
		if hit:
			var a: String=b.action; fingers[id]={"action":a,"start":Time.get_ticks_msec(),"long":false}
			if a=="fire":
				holds.fire=true; game.fire_tapped=true
				if game.lab.aim and not game.aim_acquired: game.fire_blocked=true
			elif a=="aim": game.toggle_aim()
			elif not a in ["weapon_slot","item_slot"]: game.command(a)
			get_viewport().set_input_as_handled(); return
	if game.mode!="play" or not game.lab.wheel.is_empty() or game.lab.objective_expanded: return
	if p.x<640 and p.y>215 and joy_id==-99 and id!=-1:
		if game.lab.aim: game.aim_acquired=true
		joy_id=id; move_center=p.clamp(Vector2(90,220),Vector2(585,625)); joystick=Vector2.ZERO; fingers[id]={"action":"move"}
	elif p.x>=640 and aim_id==-99 and (game.lab.aim or game.camera_controller.view=="vent"):
		aim_id=id; last_look=p; fingers[id]={"action":"look"}
		if not game.lab.aim: game.lab.yaw=atan2(-game.player.facing.x,-game.player.facing.z); game.lab.pitch=0
	elif id==-1 and game.lab.aim:
		aim_id=id; last_look=p; fingers[id]={"action":"look"}; game.aim_acquired=true
	get_viewport().set_input_as_handled()
func drag(at: Vector2,id: int) -> void:
	var p: Vector2=(at-offset_ui)/scale_ui
	if id==joy_id:
		joystick=((p-move_center)/78).limit_length()
		if joystick.length()<.1: joystick=Vector2.ZERO
	elif id==aim_id:
		game.lab.look(p-last_look); last_look=p; game.aim_acquired=true
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
	draw_rect(Rect2(0,0,1280,720),INK);buttons.clear();label(Vector2(65,70),"HISTORICAL BUILD 06 CHECKS",34,CYAN,true)
	for i in range(5):
		var id: int=game.lab.feature_page*5+i
		if id>=game.lab.features.size(): break
		var feature: String=game.lab.features[id];var entry: Dictionary=game.lab.evidence.get(feature,{})
		label(Vector2(65,130+i*91),feature,28,WHITE,true)
		label(Vector2(65,166+i*91),str(entry.get("status","UNFINISHED"))+" / "+str(entry.get("test","No passing test recorded")),24,CYAN if entry.get("status","")=="WORKING" else GOLD)
	button(Rect2(70,610,270,70),"PREVIOUS","features_prev");button(Rect2(380,610,270,70),"MENU","menu");button(Rect2(690,610,270,70),"NEXT","features_next")
## Green marker on the next objective; an arrow at the screen edge when it is out of view.
func draw_guide() -> void:
	if game.mode!="play" or game.lab.aim or not is_instance_valid(game.camera): return
	var target: Vector3=game.stage01.guide_point()+Vector3.UP*1.3
	if game.stage01.done(game.stage01.current_point().id): return
	var green: Color=Color("3dff7a")
	var behind: bool=game.camera.is_position_behind(target)
	var p: Vector2=(game.camera.unproject_position(target)-offset_ui)/scale_ui
	var metres: int=int(Vector2(game.player.global_position.x-target.x,game.player.global_position.z-target.z).length())
	var area: Rect2=Rect2(70,90,1140,540)
	if not behind and area.has_point(p):
		var d: PackedVector2Array=[p+Vector2(0,-20),p+Vector2(16,0),p+Vector2(0,20),p+Vector2(-16,0)]
		draw_colored_polygon(d,Color(green,.85)); draw_polyline(d+PackedVector2Array([d[0]]),Color.WHITE,2)
		center(p+Vector2(0,48),"%d m"%metres,24,green,true)
		return
	# Off screen: arrow on an oval around the middle of the screen, clear of the buttons.
	var c: Vector2=Vector2(640,380); var dir: Vector2=(p-c)
	if behind: dir=-dir
	if dir.length()<1: dir=Vector2(0,-1)
	dir=dir.normalized()
	var tip: Vector2=c+Vector2(dir.x*200,dir.y*150); var side: Vector2=Vector2(-dir.y,dir.x)
	var arrow: PackedVector2Array=[tip,tip-dir*46+side*26,tip-dir*46-side*26]
	draw_colored_polygon(arrow,Color(green,.9)); draw_polyline(arrow+PackedVector2Array([arrow[0]]),Color.WHITE,2)
	center(tip-dir*80+Vector2(0,8),"%d m"%metres,24,green,true)
