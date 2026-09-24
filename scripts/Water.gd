extends RefCounted
const V=preload("res://scripts/Visuals.gd")
var game: Node3D
var pool: Rect2=Rect2(-8,-8,8,8)
var enabled: bool=false
var dive: bool=false
func _init(g: Node3D) -> void:game=g
func build_floor() -> void:
	enabled=game.rooms[game.room].get("kind","")=="water";dive=false
	if not enabled:
		V.solid(game.stage,Vector3(0,-.3,0),Vector3(32,.6,24),Color("122a40"),true);return
	# Four physical decks leave a real hole; pool floor is four metres down.
	for part: Array in [[Vector3(-12,-.3,0),Vector3(8,.6,24)],[Vector3(8,-.3,0),Vector3(16,.6,24)],[Vector3(-4,-.3,-10),Vector3(8,.6,4)],[Vector3(-4,-.3,6),Vector3(8,.6,12)],[Vector3(-4,-4.3,-4),Vector3(8,.6,8)]]:
		V.solid(game.stage,part[0],part[1],Color("122a40"),true)
	var m: StandardMaterial3D=StandardMaterial3D.new();m.albedo_color=Color(.05,.5,.65,.3);m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	V.box(game.stage,Vector3(-4,-.15,-4),Vector3(8,.03,8),m)
	V.label(game.stage,Vector3(-4,1,.8),"WATER / ACTION DIVES",Color("7ee1e7"),32)
func inside() -> bool:return enabled and pool.has_point(game.player.point()) and game.player.position.y<.15
func context() -> String:
	if not inside():return ""
	return "CLIMB OUT" if game.player.position.z>-.9 and game.player.position.y>-.6 else "SURFACE" if dive else "DIVE"
func action() -> void:
	var p=game.player
	if context()=="CLIMB OUT":
		p.position=Vector3(p.position.x,.05,.6);p.mode="ground";p.velocity=Vector3.ZERO;dive=false;game.mark_goal("water_exit")
	else:dive=not dive;game.mark_goal("dive" if dive else "surface")
func tick(delta: float,move: Vector2) -> bool:
	var p=game.player
	if not inside():
		if p.mode=="swim":p.mode="ground"
		game.lab.oxygen=minf(100,game.lab.oxygen+delta*30);return false
	p.mode="swim";p.prone=false;p.crouched=false;p.body_shape.shape.height=1.6;p.body_shape.position.y=.8
	var direction: Vector3=Vector3(move.x,0,move.y)
	var y_speed: float=-1.2 if dive else clampf((-.35-p.position.y)*3,-2,2)
	if game.lab.aim and dive:y_speed=game.lab.look_direction().y*2
	p.velocity=direction*2+Vector3.UP*y_speed;p.move_and_slide();game.mark_goal("swim")
	if p.position.y< -1.3:
		game.lab.oxygen=maxf(0,game.lab.oxygen-delta*12)
		if game.lab.oxygen<=0:p.damage(8*delta)
	else:game.lab.oxygen=minf(100,game.lab.oxygen+delta*25)
	p.avatar.pose=18;p.avatar.tick(delta,game.camera);return true
