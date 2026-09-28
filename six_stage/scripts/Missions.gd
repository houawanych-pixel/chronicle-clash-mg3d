extends RefCounted
const V=preload("res://scripts/Visuals.gd")
var game: Node3D
var locker: Vector3=Vector3(-3,0,9)
var hidden: bool=false
var backup_guards: Array=[]
var quiet: float=0
var active: bool=false
var shadow: Rect2=Rect2(-14,-10,4,3)
func _init(g: Node3D) -> void: game=g
func build() -> void:
	hidden=false;backup_guards.clear();quiet=0;active=false
	V.solid(game.stage,locker+Vector3.UP,Vector3(1.2,2,.5),Color("204959"),false)
	V.label(game.stage,locker+Vector3.UP*2.4,"LOCKER",Color("92d9ca"),32)
	if game.room in [4,15]:
		V.solid(game.stage,Vector3(10,.6,-7.5),Vector3(1.4,.12,1),Color("437b72"),false)
		for x: float in [8.8,11.2]:
			game.spawn_guard([Vector2(x,-7.5),Vector2(x,-6)])
			var g: Node3D=game.guards.back();g.home=g.position;g.seated=true;g.backup=true;g.state="SEATED";backup_guards.append(g)
	V.box(game.stage,Vector3(-12,.01,-8.5),Vector3(4,.015,3),V.mat(Color("080f19")))
func in_shadow(at: Vector3) -> bool: return shadow.has_point(Vector2(at.x,at.z))
func toggle_locker() -> void:
	if not hidden and game.player.position.distance_to(locker)>1.6:return
	hidden=not hidden;game.player.avatar.visible=not hidden
	if hidden: game.mark_goal("locker");game.toast("Concealed. ACTION exits. A guard who saw you enter can find you.")
func support(at: Vector3) -> void:
	if backup_guards.is_empty():return
	active=true;quiet=0;game.mark_goal("backup");game.support_count+=1
	for g: Node3D in backup_guards:
		if g.health<=0:continue
		g.seated=false;g.returning=false;g.state="INVESTIGATE";g.last_known=at;g.search_time=20;g.path_time=0;g.radio_used=true
func tick(delta: float) -> void:
	if game.lab.motion.tier=="sneak" and game.player.velocity.length()>.15:game.mark_goal("sneak")
	if game.player.prone and game.in_vent(game.player.position):game.mark_goal("vent")
	if hidden:
		game.player.avatar.visible=false
		for g: Node3D in game.guards:
			if g.health>0 and g.last_known.distance_to(locker)<2 and g.position.distance_to(locker)<2: hidden=false;game.player.damage(15);game.toast("Guard found your hiding place!")
	if not active:return
	var seen: bool=false
	for g: Node3D in game.guards:seen=seen or g.seeing
	quiet=0 if seen else quiet+delta
	if quiet>20:
		for g: Node3D in backup_guards:
			if g.health>0:g.returning=true;g.state="RETURN";g.suspicion=0
		active=false;game.toast("All clear: backup returns to the card table.")
func record() -> void:
	var key: String="record_"+str(game.room);var old: Dictionary=game.scores.get(key,{})
	var kills: int=0
	for g: Node3D in game.guards:
		if g.health<=0 and g.reaction.text!="Z Z Z": kills+=1
	var rank: String="S" if game.alarms==0 and kills==0 else "A" if game.alarms==0 else "B"
	if old.is_empty() or game.elapsed<float(old.time):game.scores[key]={"time":game.elapsed,"alarms":game.alarms,"kills":kills,"rank":rank}
	if game.room>=7:game.scores.unlocked=maxi(int(game.scores.get("unlocked",7)),game.room+1)
