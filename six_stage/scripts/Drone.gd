extends CharacterBody3D
const V=preload("res://scripts/Visuals.gd")
var game: Node3D
var kind: String="scout"
var disabled: float=0
var health: float=70
var state: String="PATROL"
var suspicion: float=0
var cooldown: float=0
var alarm_latched: bool=false
var clock: float=0
var seeing: bool=false
var heading: Vector3=Vector3.FORWARD
var route: Array=[]
var next_point: int=1
var hull: Node3D
var rotors: Array=[]
var searchlight: SpotLight3D
var beam: MeshInstance3D
var label: Label3D
var beam_direction: Vector3=Vector3.DOWN
func _ready() -> void:
	collision_layer=4; collision_mask=17
	health=70 if kind=="scout" else 280 if kind=="master" else 105 # pistol does 35: exactly 2 / 3 hits.
	route=[Vector3(-11,3.3,-6),Vector3(-4,3.3,-6)] if kind=="scout" else [Vector3(7,2.7,6),Vector3(12,2.7,6)]
	if kind in ["dog","kamikaze","master"]:
		var start: Vector3=Vector3(-2,.5,-8) if kind=="dog" else Vector3(-4,3.2,-9) if kind=="kamikaze" else Vector3(1,4.8,-8)
		route=[start,start+Vector3(4,0,0)]
	position=route[0]
	var col: CollisionShape3D=CollisionShape3D.new(); var sphere: SphereShape3D=SphereShape3D.new(); sphere.radius=.65; col.shape=sphere; add_child(col)
	hull=Node3D.new(); add_child(hull)
	if kind=="master": hull.scale=Vector3.ONE*1.8
	var color: Color=Color("e8bc62") if kind=="scout" else Color("dd675a")
	V.box(hull,Vector3.ZERO,Vector3(.8,.3,.6),V.mat(color))
	V.box(hull,Vector3(0,-.15,-.34),Vector3(.2,.18,.15),V.mat(Color("6ef8ee"),1))
	for x in [-.6,.6]:
		for z in [-.45,.45]:
			var rotor: MeshInstance3D=V.box(hull,Vector3(x,.12,z),Vector3(.72,.04,.12),V.mat(Color("97b6c9"))); rotors.append(rotor)
	if kind=="dog":
		for rotor: Node3D in rotors: rotor.visible=false
		for x: float in [-.35,.35]:
			for z: float in [-.3,.3]: V.box(hull,Vector3(x,-.3,z),Vector3(.12,.55,.12),V.mat(Color("6d8d9e")))
	V.box(hull,Vector3.ZERO,Vector3(1.3,.08,.12),V.mat(Color("304656")))
	label=V.label(self,Vector3(0,.8,0),kind.to_upper(),color,23)
	searchlight=SpotLight3D.new(); add_child(searchlight); searchlight.light_color=color; searchlight.light_energy=2; searchlight.spot_range=8; searchlight.spot_angle=25; searchlight.shadow_enabled=true
	var cone: CylinderMesh=CylinderMesh.new(); cone.top_radius=.04; cone.bottom_radius=2.2; cone.height=5.5
	beam=MeshInstance3D.new(); searchlight.add_child(beam); beam.mesh=cone; beam.position.z=-2.75; beam.rotation.x=PI/2
	var m: StandardMaterial3D=StandardMaterial3D.new(); m.albedo_color=Color(color,.075); m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; m.cull_mode=BaseMaterial3D.CULL_DISABLED
	beam.material_override=m; beam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func point() -> Vector2: return Vector2(position.x,position.z)
func can_see_player() -> bool:
	var to: Vector3=game.player.target_point()-global_position
	return to.length()<8 and to.normalized().dot(beam_direction)>cos(deg_to_rad(25)) and game.clear_sight(global_position,game.player.target_point())
func tick(delta: float) -> void:
	clock+=delta; cooldown=maxf(0,cooldown-delta)
	if health<=0:
		velocity.y-=9.8*delta; move_and_slide()
		hull.rotation.z=lerpf(hull.rotation.z,1.1,minf(1,delta*3))
		return
	if disabled>0:
		disabled=maxf(0,disabled-delta);seeing=false;state="DISABLED";label.text="CHAFF %.0f"%disabled;return
	for rotor: Node3D in rotors: rotor.rotation.y+=delta*30
	var to: Vector3=route[next_point]-position
	if to.length()<.3: next_point=1-next_point
	if to.length()>.05:
		heading=Vector3(to.x,0,to.z).normalized()
		velocity=to.normalized()*(.8 if kind=="scout" else 1.0)
		move_and_slide()
	beam_direction=(Vector3.DOWN+heading*.65).normalized()
	searchlight.look_at(global_position+beam_direction,Vector3.FORWARD)
	seeing=can_see_player()
	# Attack drones track a visible target in a wider forward arc; walls still occlude.
	if kind in ["attack","dog","kamikaze","master"]:
		var target: Vector3=game.player.target_point()-position
		var flat: Vector3=Vector3(target.x,0,target.z)
		seeing=target.length()<10 and (flat.length()<1 or heading.dot(flat.normalized())>-.1) and game.clear_sight(position,game.player.target_point())
	if game.lab.missions.hidden or (game.player.cloaked and game.player.exposed_time<=0): seeing=false
	if seeing:
		suspicion=minf(1,suspicion+delta)
		if kind=="scout" and suspicion>=1 and not alarm_latched:
			alarm_latched=true; game.alarms+=1; game.sound("alarm",-12)
			for guard: Node3D in game.guards: guard.hear(game.player.global_position)
			game.call_support(game.player.position); game.toast("Scout drone raised the alarm!")
		if kind in ["attack","master"] and cooldown<=0:
			cooldown=.35 if kind=="master" else 1.2; game.tracer(global_position,game.player.target_point(),Color("ff7263"),.1); game.sound("pistol",-15); game.player.damage(8)
		if kind in ["dog","kamikaze"]:
			var chase: Vector3=game.player.target_point()-position
			if kind=="dog": chase.y=0
			velocity=chase.normalized()*(4.2 if kind=="dog" else 5.5);move_and_slide()
			if chase.length()<1.4 and cooldown<=0:
				if kind=="kamikaze": receive_hit(999,"self",position);game.blast(position,3,70,"kamikaze")
				else: game.player.damage(12);cooldown=.9
	else:
		suspicion=maxf(0,suspicion-delta*.6)
		if suspicion<=0: alarm_latched=false
	state="ALERT" if (kind=="attack" and seeing) or alarm_latched else ("SEARCH" if suspicion>.05 else "PATROL")
	label.text=kind.to_upper()+ (" !" if state=="ALERT" else " ?" if state=="SEARCH" else "")
func receive_hit(amount: float,_weapon: String,_at: Vector3) -> void:
	if health<=0: return
	health=maxf(0,health-amount)
	if health<=0:
		game.mark_goal(kind+"_down");state="DOWN"; seeing=false; collision_layer=0; velocity=Vector3.ZERO
		searchlight.visible=false; label.text=kind.to_upper()+" DOWN"
		game.sound("guard_down",-12); game.toast(kind.capitalize()+" drone down.")
