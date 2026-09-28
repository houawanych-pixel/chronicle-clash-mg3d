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
func _ready() -> void:
	turn=Node3D.new();add_child(turn)
	rig=load("res://assets/characters/guard.glb" if guard else "res://assets/characters/kai.glb").instantiate();turn.add_child(rig)
	rig.scale=Vector3.ONE*1.0
	for node: Node in rig.find_children("*","AnimationPlayer",true,false): animation=node;break
	if not guard and animation:
		var template: Node3D=load("res://assets/characters/guard.glb").instantiate()
		var source: AnimationPlayer=template.find_children("*","AnimationPlayer",true,false)[0]
		var library: AnimationLibrary=AnimationLibrary.new()
		for name: String in source.get_animation_list():
			var clip_copy: Animation=source.get_animation(name).duplicate()
			library.add_animation(name,clip_copy)
		animation.add_animation_library("movement",library)
		template.free()
	if animation:
		for clip: String in animation.get_animation_list():
			if clip.get_file() in ["walk","run","idle_guard","idle","crawl","crouch"]: animation.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
	muzzle=Marker3D.new();turn.add_child(muzzle);muzzle.position=Vector3(.25,1.05,-.7)
func tick(delta: float,_camera: Camera3D) -> void:
	flash=maxf(0,flash-delta)
	if facing.length()>.1: turn.rotation.y=atan2(-facing.x,-facing.z)
	var clip: String="idle_guard"
	if move_speed>.2: clip="run" if move_speed>4 else "walk"
	if pose in [4,5]:clip="fire"
	elif pose in [13,22,23]:clip="punch"
	elif pose in [17,19]:clip="climb"
	elif pose==18:clip="dive"
	if animation:
		if not guard:clip="movement/"+clip
		if not animation.has_animation(clip):clip="idle" if animation.has_animation("idle") else animation.get_animation_list()[0]
		if current_clip!=clip:
			animation.play(clip,.15);current_clip=clip
		animation.speed_scale=clampf(move_speed/2.8,.6,1.6) if clip in ["walk","run"] else 1.0
	rig.scale=Vector3.ONE*1.0
	if pose==18: rig.scale.y=1.0
