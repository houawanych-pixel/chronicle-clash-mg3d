extends CharacterBody3D
const AvatarScript = preload("res://scripts/Avatar.gd")
const Spatial = preload("res://scripts/StealthMath.gd")
const V = preload("res://scripts/Visuals.gd")
var game: Node
var avatar: Node3D
var health: float = 100
var grip: float = 100
var cloak_energy: float = 100
var cloaked: bool = false
var crouched: bool = false
var exposed_time: float = 0
var hurt_time: float = 0
var facing: Vector3 = Vector3.FORWARD
var mode: String = "ground"
var cover: Dictionary = {}
var peek: Vector3 = Vector3.ZERO
var cover_side: float = 1
var wall_pressure: float = 0
var cover_cooldown: float = 0
var anchor_body: Node3D
var anchor_local: Vector3
var anchor_normal_local: Vector3
var surface_normal: Vector3 = Vector3.BACK
var rope_length: float = 0
var tether: MeshInstance3D
var brace: bool = false
var foot_time: float = 0
var attack_time: float = 0
var last_safe: Vector3
var drop_cooldown: float = 0
func _ready() -> void:
	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = .3
	shape.height = 1.6
	col.shape = shape
	col.position.y = .8
	add_child(col)
	collision_layer = 2
	collision_mask = 1|16
	floor_snap_length = .25
	avatar = AvatarScript.new()
	add_child(avatar)
	tether = V.line(game.stage,Vector3.ZERO,Vector3.UP,Color("63f5f0"),.025)
	tether.visible = false
	V.ring(self,Vector3(0,.045,0),.4,Color("43aca6"))
func point() -> Vector2: return Vector2(global_position.x,global_position.z)
func anchor_point() -> Vector3:
	if is_instance_valid(anchor_body): return anchor_body.to_global(anchor_local)
	return global_position
func toggle_cover() -> void:
	if mode=="cover":
		cover.clear(); mode="ground"; cover_cooldown=.7; peek=Vector3.ZERO; return
	if mode!="ground" or global_position.y>.3: return
	cover = Spatial.cover_face(point(),game.walls,1.0)
	if cover.is_empty(): game.toast("Push against a wall or move closer to cover."); return
	global_position = Vector3(cover.point.x,global_position.y,cover.point.y)
	mode="cover"
	game.mark_goal("cover")
	game.sound("cover")
func toggle_cloak() -> void:
	if cloaked: cloaked=false
	elif cloak_energy>10: cloaked=true; game.mark_goal("cloak"); game.sound("cover")
	else: game.toast("Camouflage needs time to recharge.")
func hook() -> void:
	if mode in ["grapple","climb"]: return
	if game.aim_hit.is_empty(): game.toast("Aim at a solid surface to hook."); return
	var hit: Dictionary = game.aim_hit
	var at: Vector3 = hit.position
	var origin: Vector3 = global_position+Vector3.UP*.85
	if origin.distance_to(at)>28: game.toast("Hook out of range (28m)."); return
	var actual: Dictionary = game.ray(origin,at+(at-origin).normalized()*.15,29,[get_rid()])
	if actual.is_empty(): game.toast("No solid surface in reach."); return
	anchor_body = actual.collider as Node3D
	if not is_instance_valid(anchor_body): return
	anchor_local = anchor_body.to_local(actual.position)
	anchor_normal_local = anchor_body.global_basis.inverse()*actual.normal
	surface_normal = actual.normal
	rope_length = maxf(.9,origin.distance_to(actual.position))
	cover.clear()
	mode="grapple"
	game.sound("hook")
	game.toast("Tether attached. Hold HOOK to reel; BRACE at contact to climb.")
func drop(shaken: bool = false) -> void:
	if mode in ["grapple","climb"]:
		mode="ground"
		velocity += surface_normal*(3.5 if shaken else 1.5)
		anchor_body=null
		drop_cooldown=.65
		tether.visible=false
		if shaken: game.toast("Shaken off! Re-hook or recover on the floor.")
func begin_climb() -> void:
	mode="climb"
	velocity=Vector3.ZERO
	grip=maxf(0,grip-2)
	game.sound("cover",-15)
func tick(delta: float, move: Vector2) -> void:
	hurt_time=maxf(0,hurt_time-delta)
	exposed_time=maxf(0,exposed_time-delta)
	attack_time=maxf(0,attack_time-delta)
	cover_cooldown=maxf(0,cover_cooldown-delta)
	drop_cooldown=maxf(0,drop_cooldown-delta)
	brace=game.held("brace")
	if cloaked:
		cloak_energy=maxf(0,cloak_energy-delta*6)
		if cloak_energy<=0: cloaked=false; game.toast("Camouflage depleted.")
	else: cloak_energy=minf(100,cloak_energy+delta*4)
	var direction: Vector3 = Vector3(move.x,0,move.y)
	peek=Vector3.ZERO
	if mode in ["grapple","climb"] and not is_instance_valid(anchor_body): drop()
	if mode=="climb":
		_tick_climb(delta,move)
	elif mode=="grapple":
		_tick_grapple(delta,direction)
	else:
		var speed: float = 2.2 if crouched else 4.4
		if mode=="cover":
			var n: Vector2 = cover.normal
			var tangent: Vector2 = Vector2(-n.y,n.x)
			if move.dot(n)>.7: toggle_cover()
			else:
				direction=Vector3(tangent.x,0,tangent.y)*move.dot(tangent)
				speed=1.8
				var rect: Rect2=cover.wall
				var axis: int=1 if absf(n.x)>.5 else 0
				var proposed: float=point()[axis]+Vector2(direction.x,direction.z)[axis]*speed*delta
				if absf(move.dot(tangent))>.1: cover_side=signf(move.dot(tangent))
				if proposed<rect.position[axis]+.15 or proposed>rect.end[axis]-.15:
					peek=direction.normalized()
					direction=Vector3.ZERO
				facing=Vector3(n.x,0,n.y)
		velocity.x=direction.x*speed
		velocity.z=direction.z*speed
		velocity.y-=22*delta
		var landing_speed: float=velocity.y
		move_and_slide()
		if is_on_floor():
			if landing_speed < -14: damage(minf(25,(-landing_speed-14)*1.2))
			grip=minf(100,grip+delta*22)
			if global_position.y<.3: last_safe=global_position
		if mode=="ground":
			if direction.length()>.15: facing=direction.normalized()
			if is_on_wall() and direction.length()>.3 and cover_cooldown<=0 and global_position.y<.3:
				wall_pressure+=delta
				if wall_pressure>.22: toggle_cover(); wall_pressure=0
			else: wall_pressure=0
		foot_time-=delta
		if velocity.length()>2.6 and is_on_floor() and foot_time<=0:
			foot_time=.42; game.sound("step",-21); game.emit_noise(global_position,3.0)
	if grip<=0 and mode in ["climb","grapple"]: drop(true)
	if global_position.y< -4:
		global_position=last_safe+Vector3.UP*.1
		velocity=Vector3.ZERO
		drop()
		damage(12)
	if health<=0: game.fail_mission()
	_update_visual(delta)
func _tick_grapple(delta: float, direction: Vector3) -> void:
	var anchor: Vector3=anchor_point()
	var chest: Vector3=global_position+Vector3.UP*.85
	var delta_anchor: Vector3=anchor-chest
	surface_normal=(anchor_body.global_basis*anchor_normal_local).normalized()
	if game.held("hook"):
		rope_length=maxf(.7,rope_length-6.5*delta)
		velocity+=delta_anchor.normalized()*22*delta
	velocity.y-=12*delta
	velocity+=direction*10*delta
	velocity*=pow(.98,delta*60)
	if delta_anchor.length()>rope_length:
		velocity+=delta_anchor.normalized()*(delta_anchor.length()-rope_length)*18*delta
		var outward: float=velocity.dot(-delta_anchor.normalized())
		if outward>0: velocity+=delta_anchor.normalized()*outward
	velocity=velocity.limit_length(12)
	move_and_slide()
	grip=maxf(0,grip-delta*3)
	if brace and drop_cooldown<=0 and delta_anchor.length()<1.5 and absf(surface_normal.y)<.7: begin_climb()
	if delta_anchor.length()<1.0 and surface_normal.y>.65:
		global_position=anchor+Vector3.UP*.04
		velocity=Vector3.ZERO
		drop()
func _tick_climb(delta: float, move: Vector2) -> void:
	var at: Vector3=anchor_point()
	surface_normal=(anchor_body.global_basis*anchor_normal_local).normalized()
	var tangent: Vector3=Vector3.UP.cross(surface_normal).normalized()
	# In climb mode, screen up means climb up; horizontal uses visible surface tangent.
	if tangent.dot(game.camera.global_basis.x)<0: tangent=-tangent
	var speed: float=.6 if brace else 1.6
	var step: Vector3=(tangent*move.x+Vector3.UP*(-move.y))*speed*delta
	var wanted: Vector3=at+step
	var hit: Dictionary=game.ray(wanted+surface_normal*.8,wanted-surface_normal*1.3,17,[get_rid()])
	if not hit.is_empty() and absf(hit.normal.y)<.75:
		anchor_body=hit.collider
		anchor_local=anchor_body.to_local(hit.position)
		anchor_normal_local=anchor_body.global_basis.inverse()*hit.normal
		at=hit.position
		surface_normal=hit.normal
	else:
		var top: Dictionary=game.ray(wanted-surface_normal*.45+Vector3.UP*1.2,wanted-surface_normal*.45-Vector3.UP*.7,17,[get_rid()])
		if move.y<-.1 and not top.is_empty() and top.normal.y>.6:
			global_position=top.position+Vector3.UP*.05
			velocity=Vector3.ZERO; mode="ground"; anchor_body=null; cover_cooldown=1; return
	global_position=at+surface_normal*.45-Vector3.UP*.85
	facing=-surface_normal
	grip=maxf(0,grip-delta*(4.0 if move.length()>.1 else 1.5))
func _update_visual(delta: float) -> void:
	avatar.facing=facing
	avatar.move_speed=Vector2(velocity.x,velocity.z).length()
	avatar.opacity=1.0
	avatar.pose=-1
	avatar.height=1.9
	avatar.position=Vector3.ZERO
	var gear: Node=game.gear
	if mode=="cover":
		avatar.pose=(0 if cover_side>0 else 1) if avatar.move_speed<.15 else (2 if cover_side>0 else 3)
		avatar.position=Vector3(cover.normal.x,0,cover.normal.y)*.1
	elif mode=="climb": avatar.pose=12 if brace else 10
	elif mode=="grapple": avatar.pose=11
	elif crouched: avatar.pose=14; avatar.height=1.25
	elif gear.scope and gear.selected==7: avatar.pose=15
	elif gear.action_time>0:
		avatar.pose=(8 if int(gear.action_time*5)%2==0 else 7) if gear.action=="clear" else (6 if gear.action_time>gear.action_total*.4 else 7)
	elif gear.switch_time>0: avatar.pose=9
	elif gear.muzzle_time>0: avatar.pose=5
	elif game.held("fire") and gear.selected<4: avatar.pose=4
	if attack_time>0: avatar.pose=13
	if gear.action_time>0: avatar.pose=6
	elif gear.muzzle_time>0: avatar.pose=5
	elif game.aim_enabled and mode=="ground": avatar.pose=4; avatar.facing=(game.aim_point-global_position).normalized()
	avatar.tick(delta,game.camera)
	tether.visible=mode in ["climb","grapple"] and is_instance_valid(anchor_body)
	if tether.visible:
		var start: Vector3=global_position+Vector3.UP*1.2
		var end: Vector3=anchor_point()
		tether.global_position=(start+end)*.5
		tether.scale=Vector3(1,1,maxf(.01,start.distance_to(end)))
		if start.distance_to(end)>.01: tether.look_at(end,Vector3.UP if absf((end-start).normalized().y)<.99 else Vector3.RIGHT)
func damage(amount: float) -> void:
	if hurt_time>0: return
	health=maxf(0,health-amount)
	hurt_time=.65
	avatar.flash=.2
	game.sound("hurt",-10)
func strike() -> void:
	if attack_time>0 or brace: return
	attack_time=.4
	grip=maxf(0,grip-5)
	if is_instance_valid(game.titan): game.titan.strike(global_position+Vector3.UP)
