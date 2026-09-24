extends RefCounted
## Same perspective projection in both views avoids a projection pop while blending.
const SWITCH_TIME: float=.4
const ENTER_DELAY: float=.12
const EXIT_DELAY: float=.20
const CAMERA_RADIUS: float=.20
var game: Node3D
var mode: String="overhead"
var candidate: String="overhead"
var view: String="overhead"
var last_cover_side: float=1
var candidate_time: float=0
var initialized: bool=false
var transition_time: float=SWITCH_TIME
var start_position: Vector3
var start_rotation: Quaternion
var start_fov: float=52
var reveal: Vector3=Vector3.ZERO
var last_hard_cut: bool=false
var hard_cuts: int=0
var switches: int=0
var probe: SphereShape3D=SphereShape3D.new()
func _init(owner_game: Node3D) -> void:
	game=owner_game; probe.radius=CAMERA_RADIUS
func reset() -> void:
	initialized=false; view="overhead"; reveal=Vector3.ZERO; candidate_time=0; switches=0; hard_cuts=0
func roof_at(point: Vector3) -> bool:
	return not game.ray(point+Vector3.UP*1.95,point+Vector3.UP*40,17).is_empty()
func covered() -> bool:
	var at: Vector3=game.player.global_position
	if roof_at(at): return true
	# Exit boundary is wider than entry: a small doorway wobble cannot flip modes.
	if mode=="follow":
		for offset: Vector3 in [Vector3(.24,0,0),Vector3(-.24,0,0),Vector3(0,0,.24),Vector3(0,0,-.24)]:
			if roof_at(at+offset): return true
	return false
func motion_fraction(from: Vector3,to: Vector3) -> float:
	var q: PhysicsShapeQueryParameters3D=PhysicsShapeQueryParameters3D.new()
	q.shape=probe; q.transform=Transform3D(Basis.IDENTITY,from); q.collision_mask=17; q.margin=.015
	var space: PhysicsDirectSpaceState3D=game.get_world_3d().direct_space_state
	if not space.intersect_shape(q,1).is_empty(): return 0
	q.motion=to-from
	var fractions: PackedFloat32Array=space.cast_motion(q)
	return fractions[0] if not fractions.is_empty() else 1.0
func path_blocked(from: Vector3,to: Vector3) -> bool:
	return motion_fraction(from,to)<.999
func safe_position(focus: Vector3,wanted: Vector3) -> Vector3:
	var fraction: float=motion_fraction(focus,wanted)
	return focus.lerp(wanted,maxf(0,fraction-.025)) if fraction<.999 else wanted
func update(delta: float) -> void:
	var p: CharacterBody3D=game.player
	var camera: Camera3D=game.camera
	last_hard_cut=false
	var wanted_mode: String="follow" if covered() else "overhead"
	if not initialized:
		mode=wanted_mode; candidate=mode; initialized=true; transition_time=SWITCH_TIME
	elif wanted_mode!=mode:
		if candidate!=wanted_mode: candidate=wanted_mode; candidate_time=0
		candidate_time+=delta
		if candidate_time>=(ENTER_DELAY if wanted_mode=="follow" else EXIT_DELAY):
			mode=wanted_mode; candidate_time=0; switches+=1
			transition_time=0; start_position=camera.position; start_rotation=camera.quaternion; start_fov=camera.fov
	else: candidate=mode; candidate_time=0
	var wanted_view: String="aim" if game.lab.aim else "vent" if p.prone and game.in_vent(p.global_position) else ("cover" if p.mode=="cover" else mode)
	if wanted_view!=view or (wanted_view=="cover" and p.cover_side!=last_cover_side):
		view=wanted_view; last_cover_side=p.cover_side
		transition_time=0; start_position=camera.position; start_rotation=camera.quaternion; start_fov=camera.fov
	var center: Vector3=p.global_position+Vector3.UP*(.45 if p.prone else 1.05)
	var focus: Vector3=center
	var position: Vector3
	var fov: float
	reveal=Vector3.ZERO
	if view=="aim":
		position=p.target_point(); focus=position+game.lab.look_direction()*5
		fov=[40.0,22.0,12.0][game.lab.zoom] if game.lab.optic=="binoculars" or str(game.gear.current().id)=="sniper" else 70
	elif view=="vent":
		position=p.global_position+Vector3.UP*.43
		var forward: Vector3=p.facing; forward.y=0
		focus=position+forward.normalized()*2; fov=75
	elif view=="cover":
		var normal: Vector3=Vector3(p.cover.normal.x,0,p.cover.normal.y)
		var tangent: Vector3=Vector3(-normal.z,0,normal.x)*p.cover_side
		# Restore Build 03's exact composition; only active wall movement/peek
		# adds the side bias. Stationary cover retains its low-angle perspective.
		var amount: float=1.0 if p.cover_motion.length()>.1 or p.peek.length()>.1 else 0.0
		reveal=tangent*1.4*amount+p.peek*2
		focus=p.global_position+Vector3.UP*1.2+reveal
		position=safe_position(center,p.global_position+normal*5.5-tangent*3.0*amount+Vector3.UP*2.8)
		fov=58
	elif mode=="overhead":
		position=safe_position(center,center+Vector3(0,17,10)); fov=52
	else:
		position=safe_position(center,center+Vector3.BACK*4.6+Vector3.UP*1.35); fov=66
	var target_basis: Basis=Transform3D.IDENTITY.looking_at(focus-position,Vector3.UP).basis
	var target_rotation: Quaternion=target_basis.get_rotation_quaternion()
	camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	if transition_time<SWITCH_TIME:
		# Test the complete intended camera sweep, not just the next tiny frame step.
		if path_blocked(camera.position,position):
			camera.position=position; camera.quaternion=target_rotation; camera.fov=fov
			transition_time=SWITCH_TIME; last_hard_cut=true; hard_cuts+=1
		else:
			transition_time=minf(SWITCH_TIME,transition_time+delta)
			var t: float=transition_time/SWITCH_TIME; t=t*t*(3-2*t)
			camera.position=start_position.lerp(position,t)
			camera.quaternion=start_rotation.slerp(target_rotation,t); camera.fov=lerpf(start_fov,fov,t)
	else:
		var next: Vector3=camera.position.lerp(position,1-exp(-delta*10))
		if path_blocked(camera.position,next):
			camera.position=position; camera.quaternion=target_rotation; last_hard_cut=true; hard_cuts+=1
		else:
			camera.position=next; camera.quaternion=camera.quaternion.slerp(target_rotation,1-exp(-delta*10))
		camera.fov=fov
	p.avatar.visible=not view in ["vent","aim"]
