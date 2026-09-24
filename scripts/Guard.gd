extends CharacterBody3D
const AvatarScript=preload("res://scripts/Avatar.gd")
const V=preload("res://scripts/Visuals.gd")
const Spatial=preload("res://scripts/StealthMath.gd")
var game: Node
var route: Array=[]
var route_index: int=1
var health: float=100
var state: String="PATROL"
var suspicion: float=0
var facing: Vector3=Vector3.FORWARD
var last_known: Vector3
var radio_time: float=0
var radio_used: bool=false
var shot_time: float=0
var search_time: float=0
var lost_time: float=0
var path_time: float=0
var path: PackedVector2Array
var mark_time: float=0
var seeing: bool=false
var avatar: Node3D
var reaction: Label3D
var cone: MeshInstance3D
var cone_mat: StandardMaterial3D
var cone_timer: float=0
var stun: float=0
var step_clock: float=0
func _ready() -> void:
	var col: CollisionShape3D=CollisionShape3D.new()
	var capsule: CapsuleShape3D=CapsuleShape3D.new()
	capsule.radius=.35; capsule.height=1.7
	col.shape=capsule; col.position.y=.85; add_child(col)
	collision_layer=4; collision_mask=1|16
	avatar=AvatarScript.new(); avatar.guard=true; add_child(avatar)
	reaction=V.label(self,Vector3(0,2.1,0),"",Color("ffcf75"),55)
	cone=MeshInstance3D.new(); add_child(cone); cone.top_level=true
	cone_mat=StandardMaterial3D.new()
	cone_mat.albedo_color=Color(1,.7,.2,.16)
	cone_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	cone_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	cone_mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	cone.material_override=cone_mat
	cone.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if route.size()>1:
		var dir: Vector2=route[1]-route[0]
		facing=Vector3(dir.x,0,dir.y).normalized()
func point() -> Vector2: return Vector2(global_position.x,global_position.z)
func hear(at: Vector3) -> void:
	if health<=0 or state in ["CALL","CHASE"]: return
	last_known=at; state="INVESTIGATE"; search_time=5; path_time=0
func receive_hit(amount: float, _weapon: String, _at: Vector3) -> void:
	if health<=0: return
	health-=amount; avatar.flash=.2; stun=.25
	last_known=game.player.global_position
	if health<=0:
		game.mark_goal("guard_down")
		state="DOWN"; collision_layer=0; cone.visible=false; reaction.text=""
		game.sound("guard_down",-12)
	else:
		# Damage interrupts an in-progress radio transmission.
		radio_time=0; state="INVESTIGATE"; search_time=5; suspicion=.65; path_time=0
func knock_out() -> void:
	health=0; state="DOWN"; collision_layer=0; cone.visible=false; reaction.text="Z Z Z"; radio_time=0; seeing=false; game.mark_goal("guard_down")
func tick(delta: float) -> void:
	mark_time=maxf(0,mark_time-delta)
	if health<=0:
		avatar.rotation.z=lerpf(avatar.rotation.z,PI/2,minf(delta*8,1))
		avatar.height=1.9
		avatar.tick(delta,game.camera)
		return
	step_clock+=delta
	stun=maxf(0,stun-delta)
	shot_time=maxf(0,shot_time-delta)
	if stun>0:
		seeing=false; velocity=Vector3.ZERO; reaction.text="STUN"; avatar.pose=13; avatar.tick(delta,game.camera); return
	var target: Vector3=game.player.target_point()
	var eye: Vector3=global_position+Vector3.UP*1.4
	var to_player: Vector3=target-eye
	var flat: Vector3=Vector3(to_player.x,0,to_player.z)
	var range_limit: float=8.8
	if game.player.prone: range_limit*=.5
	elif game.player.crouched: range_limit*=.8
	if game.player.cloaked and game.player.exposed_time<=0: range_limit=1.5
	seeing=to_player.length()<range_limit and (flat.length()<.7 or facing.dot(flat.normalized())>cos(deg_to_rad(40))) and game.clear_sight(eye,target)
	if seeing:
		suspicion=minf(1,suspicion+delta*1.15)
		last_known=game.player.global_position; lost_time=0
		if suspicion>=1 and not state in ["CALL","CHASE"]:
			state="CHASE" if radio_used else "CALL"
			radio_time=2.6; game.alarms+=1; game.sound("alarm",-12)
			game.toast("Guard identified you — interrupt the radio call!")
	else:
		lost_time+=delta; suspicion=maxf(0,suspicion-delta*.3)
	if state=="CALL":
		radio_time-=delta
		reaction.text="RADIO %.1f"%radio_time
		if radio_time<=0:
			radio_used=true; state="CHASE"; game.call_support(last_known)
	elif state=="CHASE":
		reaction.text="!"
		if seeing and shot_time<=0:
			shot_time=1.05
			game.tracer(eye,target,Color("ff8072"),.08)
			game.sound("pistol",-16)
			game.player.damage(10)
		if lost_time>2.0:
			state="INVESTIGATE"; search_time=6; path_time=0
	elif state in ["INVESTIGATE","SEARCH"]: reaction.text="?"
	else: reaction.text="?" if suspicion>.05 else ("MARKED" if mark_time>0 else "")
	velocity.x=0
	velocity.z=0
	var dest: Vector3=Vector3.ZERO
	if state=="PATROL":
		var p: Vector2=route[route_index]
		dest=Vector3(p.x,0,p.y)
	elif state in ["INVESTIGATE","CHASE"]: dest=last_known
	if state=="SEARCH":
		search_time-=delta; facing=facing.rotated(Vector3.UP,delta*.85)
		if search_time<=0: state="PATROL"; path_time=0
	elif state!="CALL" and stun<=0:
		var flat_dest: Vector2=Vector2(dest.x,dest.z)
		if point().distance_to(flat_dest)<.45:
			if state=="PATROL": route_index=(route_index+1)%route.size(); path_time=0
			elif state=="INVESTIGATE": state="SEARCH"
		else:
			path_time-=delta
			if path_time<=0:
				path=game.route_to(point(),flat_dest); path_time=.6
			while path.size()>0 and point().distance_to(path[0])<.25: path.remove_at(0)
			if not path.is_empty():
				var d: Vector2=(path[0]-point()).normalized()
				var direct: Vector3=Vector3(d.x,0,d.y)
				facing=facing.lerp(direct,minf(delta*7,1)).normalized()
				var speed: float=3.0 if state=="CHASE" else 1.55
				velocity=Vector3(d.x*speed,velocity.y-20*delta,d.y*speed)
				move_and_slide()
	else: velocity=Vector3.ZERO
	avatar.pose=5 if shot_time>.85 else -1
	avatar.facing=facing; avatar.move_speed=Vector2(velocity.x,velocity.z).length()
	avatar.tick(delta,game.camera)
	cone_timer-=delta
	if cone_timer<=0: update_cone(); cone_timer=.12
func update_cone() -> void:
	if DisplayServer.get_name()=="headless" or health<=0: return
	var mesh: ImmediateMesh=ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var start: Vector3=global_position+Vector3.UP*.09
	for i in range(20):
		var points: Array=[]
		for j in [i,i+1]:
			var dir: Vector3=facing.rotated(Vector3.UP,lerpf(-.7,.7,float(j)/20))
			var hit: Dictionary=game.ray(start+Vector3.UP*.8,start+Vector3.UP*.8+dir*8.8,17)
			var end: Vector3=hit.get("position",start+dir*8.8)
			end.y=start.y
			points.append(end)
		mesh.surface_add_vertex(start); mesh.surface_add_vertex(points[0]); mesh.surface_add_vertex(points[1])
	mesh.surface_end(); cone.mesh=mesh
	cone_mat.albedo_color=Color(1,.2,.3,.2) if state in ["CALL","CHASE"] else Color(1,.68,.2,.14)
