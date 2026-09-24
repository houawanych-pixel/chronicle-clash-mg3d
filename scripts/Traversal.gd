extends RefCounted
const V=preload("res://scripts/Visuals.gd")
var game: Node3D
var grabbers: Array=[]
var anchor: Dictionary={}
var pushed: StaticBody3D
var tier: String="walk"
var airborne: float=0
var air_velocity: Vector3=Vector3.ZERO
var exhausted: float=0
func _init(g: Node3D) -> void: game=g
func build() -> void:
	grabbers.clear();anchor.clear();pushed=null
	V.solid(game.stage,Vector3(-12,1.15,-1),Vector3(3,2.3,2),Color("4b6374"),true)
	grabbers.append({"kind":"ledge","a":Vector3(-13.2,2.3,.43),"b":Vector3(-10.8,2.3,.43),"normal":Vector3.BACK})
	V.solid(game.stage,Vector3(-9,2.7,9),Vector3(5,.15,.15),Color("74d2ce"),false)
	for x: float in [-11.5,-6.5]: V.solid(game.stage,Vector3(x,1.35,9),Vector3(.12,2.7,.12),Color("446578"),false)
	grabbers.append({"kind":"bar","a":Vector3(-11.1,2.7,9),"b":Vector3(-6.9,2.7,9),"normal":Vector3.BACK})
	V.solid(game.stage,Vector3(-14,1.9,5),Vector3(.18,3.8,.18),Color("79c4c8"),false)
	grabbers.append({"kind":"pole","a":Vector3(-14,.9,5.6),"b":Vector3(-14,3.4,5.6),"normal":Vector3.BACK})
	V.label(game.stage,Vector3(-12,3.1,-1),"LEDGE",Color("ffe1a2"),36)
	V.label(game.stage,Vector3(-9,3.3,9),"HANG / SHIMMY",Color("ffe1a2"),36)
func speed(move: Vector2) -> float:
	var p=game.player
	if p.prone: tier="crawl"; return 1.1
	if game.lab.aim: tier="aim"; return 1.3
	if p.crouched: tier="sneak"; return 1.4
	var m: float=move.length()
	var keyboard: bool=game.hud.joy_id==-99 and Input.get_connected_joypads().is_empty()
	tier="sneak" if m<.5 or Input.is_action_pressed("sneak") else "run" if (m>.87 and not keyboard) or Input.is_action_pressed("run") else "walk"
	if tier=="run" and (game.lab.stamina<2 or exhausted>0): tier="walk"; exhausted=maxf(exhausted,1.0) if game.lab.stamina<2 else exhausted
	return 6.4 if tier=="run" else 2.3 if tier=="sneak" else 3.6
func nearest_grab() -> Dictionary:
	var p=game.player
	for g: Dictionary in grabbers:
		var at: Vector3=Geometry3D.get_closest_point_to_segment(p.position+Vector3.UP*1.4,g.a,g.b)
		if (p.position+Vector3.UP*1.4).distance_to(at)<.85: return {"at":at,"spec":g}
	return {}
func jump() -> void:
	var p=game.player
	if p.prone or p.mode!="ground" or not p.is_on_floor() or game.lab.stamina<8: return
	p.velocity.y=7.5; airborne=1.0; air_velocity=p.facing*(6.4 if tier=="run" else 3.4);game.lab.stamina-=8;game.mark_goal("jump")
func grab() -> bool:
	var result: Dictionary=nearest_grab()
	if result.is_empty() or game.lab.stamina<=0: return false
	anchor=result.spec.duplicate();airborne=0;var p=game.player;p.mode="hang";p.velocity=Vector3.ZERO
	p.body_shape.shape.height=1.2;p.body_shape.position.y=.6
	p.position=result.at-Vector3.UP*1.4;p.cover.clear();game.mark_goal("hang");return true
func drop() -> void:
	var p=game.player;p.mode="ground";p.velocity=Vector3(0,-1,0);p.cover_cooldown=.6;airborne=-.7
	p.body_shape.shape.height=1.6;p.body_shape.position.y=.8;anchor.clear();game.mark_goal("drop")
func pull_up() -> bool:
	if anchor.get("kind","")!="ledge": return false
	var p=game.player;var landing: Vector3=p.position-anchor.normal*.9;landing.y=anchor.a.y+.04
	var shape: CapsuleShape3D=CapsuleShape3D.new();shape.radius=.3;shape.height=1.6
	var q=PhysicsShapeQueryParameters3D.new();q.shape=shape;q.transform=Transform3D(Basis.IDENTITY,landing+Vector3.UP*.81);q.collision_mask=17
	if not game.get_world_3d().direct_space_state.intersect_shape(q).is_empty(): return false
	p.body_shape.shape.height=1.6;p.body_shape.position.y=.8;p.mantle_from=p.position;p.mantle_raised=Vector3(p.position.x,landing.y,p.position.z);p.mantle_to=landing;p.mantle_time=0;p.mode="mantle";game.mark_goal("pull_up");return true
func near_crate() -> StaticBody3D:
	for crate: StaticBody3D in game.crates:
		if crate.position.distance_to(game.player.position+Vector3.UP*.6)<2: return crate
	return null
func tick(delta: float,move: Vector2) -> bool:
	var p=game.player;exhausted=maxf(0,exhausted-delta)
	if airborne<0: airborne=minf(0,airborne+delta)
	elif airborne>0:
		airborne=maxf(0,airborne-delta)
		if p.mode=="ground" and p.position.y>.3 and grab(): return true
	if p.mode=="hang":
		game.lab.stamina=maxf(0,game.lab.stamina-10*delta)
		if game.lab.stamina<=0 or move.y>.65: drop();return true
		if anchor.kind=="pole":
			p.position.y=clampf(p.position.y-move.y*delta,anchor.a.y-1.4,anchor.b.y-1.4)
			if move.y<-.2: game.mark_goal("pipe")
		else:
			p.position.x=clampf(p.position.x+move.x*1.3*delta,anchor.a.x,anchor.b.x)
			if absf(move.x)>.1: game.mark_goal("shimmy")
			if move.y<-.6: pull_up()
		return true
	if p.mode=="push" and is_instance_valid(pushed):
		var step: Vector3=Vector3(move.x,0,move.y)*delta
		var size: Vector3=pushed.get_meta("size");var shape=BoxShape3D.new();shape.size=size-Vector3(.03,.06,.03)
		var q=PhysicsShapeQueryParameters3D.new();q.shape=shape;q.transform=Transform3D(Basis.IDENTITY,pushed.position+step);q.collision_mask=17;q.exclude=[pushed.get_rid()]
		if game.get_world_3d().direct_space_state.intersect_shape(q,1).is_empty():
			pushed.position+=step;p.position+=step
			if step.length()>.001: game.mark_goal("push_pull")
		return true
	if tier=="run" and move.length()>.1: game.lab.stamina=maxf(0,game.lab.stamina-14*delta)
	return false
