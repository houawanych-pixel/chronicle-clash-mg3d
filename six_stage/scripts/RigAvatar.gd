extends Node3D
var guard: bool=false
var height: float=1.9
var facing: Vector3=Vector3.FORWARD
var move_speed: float=0
var pose: int=-1
var opacity: float=1
var flash: float=0
var weapon_id: String="pistol"
var weapon_drawn: bool=true
var animation: AnimationPlayer
var rig: Node3D
var turn: Node3D
var muzzle: Marker3D
var current_clip: String=""
## Ground speed each clip is animated for at speed_scale 1 (measured with tests/stride.gd:
## planted foot speed with the body held still). Playback is scaled to the real move speed.
const WALK_CLIP_SPEED: float=1.1
const RUN_CLIP_SPEED: float=3.25
const RUN_FROM: float=2.0
func _ready() -> void:
	turn=Node3D.new();add_child(turn)
	rig=load("res://assets/characters/guard.glb" if guard else "res://assets/characters/kai.glb").instantiate();turn.add_child(rig)
	rig.scale=Vector3.ONE*1.0
	for node: Node in rig.find_children("*","AnimationPlayer",true,false): animation=node;break
	if not guard and animation:
		var template: Node3D=load("res://assets/characters/guard.glb").instantiate()
		var source: AnimationPlayer=template.find_children("*","AnimationPlayer",true,false)[0]
		var library: AnimationLibrary=AnimationLibrary.new()
		var target_skeleton: Skeleton3D=rig.find_children("*","Skeleton3D",true,false)[0]
		var source_skeleton: Skeleton3D=template.find_children("*","Skeleton3D",true,false)[0]
		for name: String in source.get_animation_list():
			var clip_copy: Animation=source.get_animation(name).duplicate(true)
			retarget(clip_copy,source_skeleton,target_skeleton)
			library.add_animation(name,clip_copy)
		animation.add_animation_library("movement",library)
		template.free()
	if animation:
		for clip: String in animation.get_animation_list():
			if clip.get_file() in ["walk","run","idle_guard","idle","crawl","crouch"]: animation.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
			if clip.get_file() in ["walk","run"]: strip_root_motion(animation.get_animation(clip))
	# glTF characters face +Z; the game's "facing" is -Z. Turn the model round so it walks forwards.
	rig.rotation.y=PI
	muzzle=Marker3D.new();turn.add_child(muzzle);muzzle.position=Vector3(.25,1.05,-.7)
func tick(delta: float,_camera: Camera3D) -> void:
	flash=maxf(0,flash-delta)
	if facing.length()>.1: turn.rotation.y=atan2(-facing.x,-facing.z)
	var clip: String="idle_guard"
	if move_speed>.2: clip="run" if move_speed>=RUN_FROM else "walk"
	if pose in [4,5]:clip="fire"
	elif pose in [13,22,23]:clip="punch"
	elif pose in [17,19]:clip="climb"
	elif pose==18:clip="dive"
	if animation:
		if not guard:clip="movement/"+clip
		if not animation.has_animation(clip):clip="idle" if animation.has_animation("idle") else animation.get_animation_list()[0]
		if current_clip!=clip:
			animation.play(clip,.15);current_clip=clip
		# Legs cycle at exactly the speed the body travels, so feet stay planted.
		if clip.get_file()=="walk": animation.speed_scale=clampf(move_speed/WALK_CLIP_SPEED,.5,2.2)
		elif clip.get_file()=="run": animation.speed_scale=clampf(move_speed/RUN_CLIP_SPEED,.5,2.0)
		else: animation.speed_scale=1.0
	rig.scale=Vector3.ONE*1.0
	if pose==18: rig.scale.y=1.0
## The walk/run clips were authored with forward travel baked into the hips: the body slid
## ~1.9 m ahead and snapped back every loop, and the run sat 0.8 m to one side. Keep only the
## vertical component so the character animates in place over its collision capsule.
func strip_root_motion(clip: Animation) -> void:
	for t in range(clip.get_track_count()):
		if clip.track_get_type(t)==Animation.TYPE_POSITION_3D and str(clip.track_get_path(t)).ends_with(":Hip"):
			for k in range(clip.track_get_key_count(t)):
				var v: Vector3=clip.track_get_key_value(t,k)
				clip.track_set_key_value(t,k,Vector3(0,0,v.z))
## Kai reuses the guard's clips, but 58 of Kai's 79 bones have a different rest pose, which bent
## the body (leaning, twisted limbs). Convert every rotation key through both rest poses:
## local_kai = inv(Rk(parent)) * Rg(parent) * local_guard * inv(Rg(bone)) * Rk(bone)
func retarget(clip: Animation,from: Skeleton3D,to: Skeleton3D) -> void:
	for t in range(clip.get_track_count()):
		var bone_name: String=str(clip.track_get_path(t)).get_slice(":",1)
		var fb: int=from.find_bone(bone_name); var tb: int=to.find_bone(bone_name)
		if fb<0 or tb<0: continue
		var fp: int=from.get_bone_parent(fb); var tp: int=to.get_bone_parent(tb)
		var rg_parent: Quaternion=from.get_bone_global_rest(fp).basis.get_rotation_quaternion() if fp>=0 else Quaternion.IDENTITY
		var rk_parent: Quaternion=to.get_bone_global_rest(tp).basis.get_rotation_quaternion() if tp>=0 else Quaternion.IDENTITY
		var rg: Quaternion=from.get_bone_global_rest(fb).basis.get_rotation_quaternion()
		var rk: Quaternion=to.get_bone_global_rest(tb).basis.get_rotation_quaternion()
		var pre: Quaternion=rk_parent.inverse()*rg_parent
		if clip.track_get_type(t)==Animation.TYPE_ROTATION_3D:
			var post: Quaternion=rg.inverse()*rk
			for k in range(clip.track_get_key_count(t)):
				var q: Quaternion=clip.track_get_key_value(t,k)
				clip.track_set_key_value(t,k,(pre*q*post).normalized())
		elif clip.track_get_type(t)==Animation.TYPE_POSITION_3D:
			var scale_ratio: float=to.get_bone_rest(tb).origin.length()/maxf(from.get_bone_rest(fb).origin.length(),.0001) if from.get_bone_rest(fb).origin.length()>.001 else 1.0
			for k in range(clip.track_get_key_count(t)):
				var v: Vector3=clip.track_get_key_value(t,k)
				clip.track_set_key_value(t,k,pre*v*clampf(scale_ratio,.5,2.0))
