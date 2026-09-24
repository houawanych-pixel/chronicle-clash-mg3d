extends Node3D
## Articulated 3D blockout. Skeleton3D + BoneAttachment3D + AnimationPlayer.
## There are no camera-facing sprites or directional image swaps.
var guard: bool=false
var clock: float=0
var height: float=1.9
var facing: Vector3=Vector3.FORWARD
var move_speed: float=0
var pose: int=-1
var opacity: float=1
var flash: float=0
var rig: Skeleton3D
var animation: AnimationPlayer
var turn: Node3D
var muzzle: Marker3D
var magazine: MeshInstance3D
var spare_magazine: MeshInstance3D
var bones: Dictionary={}
var attachments: Dictionary={}
var skin_material: StandardMaterial3D
var current_clip: String=""
func material(hex: String) -> StandardMaterial3D:
	var m: StandardMaterial3D=StandardMaterial3D.new()
	m.albedo_color=Color(hex); m.roughness=.8
	return m
func bone(id: String,parent: String,at: Vector3) -> void:
	var index: int=rig.get_bone_count()
	rig.add_bone(id); bones[id]=index
	if not parent.is_empty(): rig.set_bone_parent(index,bones[parent])
	rig.set_bone_rest(index,Transform3D(Basis.IDENTITY,at))
	var attachment: BoneAttachment3D=BoneAttachment3D.new()
	rig.add_child(attachment); attachment.bone_name=id; attachment.bone_idx=index; attachments[id]=attachment
func mesh(id: String,at: Vector3,size: Vector3,mat: Material,rounded: bool=false) -> MeshInstance3D:
	var n: MeshInstance3D=MeshInstance3D.new()
	if rounded:
		var shape: SphereMesh=SphereMesh.new(); shape.radius=.5; shape.height=1.0; shape.radial_segments=12; shape.rings=6
		n.mesh=shape; n.scale=size
	else:
		var shape: BoxMesh=BoxMesh.new(); shape.size=size; n.mesh=shape
	n.material_override=mat; n.position=at; attachments[id].add_child(n)
	return n
func _ready() -> void:
	turn=Node3D.new(); turn.name="Facing"; add_child(turn)
	rig=Skeleton3D.new(); rig.name="Rig"; turn.add_child(rig)
	bone("hips","",Vector3(0,.93,0))
	bone("chest","hips",Vector3(0,.28,0))
	bone("neck","chest",Vector3(0,.30,0))
	bone("head","neck",Vector3(0,.17,0))
	for side: String in ["l","r"]:
		var sign_x: float=-1.0 if side=="l" else 1.0
		bone("thigh_"+side,"hips",Vector3(sign_x*.13,-.03,0))
		bone("shin_"+side,"thigh_"+side,Vector3(0,-.39,0))
		bone("foot_"+side,"shin_"+side,Vector3(0,-.40,0))
		bone("arm_"+side,"chest",Vector3(sign_x*.29,.20,0))
		bone("forearm_"+side,"arm_"+side,Vector3(0,-.28,0))
		bone("hand_"+side,"forearm_"+side,Vector3(0,-.27,0))
	rig.reset_bone_poses()
	var cloth: Material=material("273444" if guard else "1d3445")
	var armor: Material=material("56616a" if guard else "486779")
	var dark: Material=material("131e28")
	var accent: Material=material("eaa052" if guard else "48d6c6")
	var skin: Material=material("b88c70" if guard else "d6aa91")
	skin_material=armor
	mesh("hips",Vector3(0,0,0),Vector3(.39,.27,.28),cloth,true)
	mesh("hips",Vector3(0,.10,0),Vector3(.43,.08,.31),dark)
	mesh("hips",Vector3(0,.10,-.175),Vector3(.11,.07,.04),accent)
	mesh("chest",Vector3(0,.07,0),Vector3(.51,.48,.31),cloth,true)
	mesh("chest",Vector3(0,.08,-.16),Vector3(.39,.32,.095),armor)
	mesh("chest",Vector3(0,.20,-.215),Vector3(.23,.035,.025),accent)
	for x: float in [-.12,0,.12]: mesh("chest",Vector3(x,-.04,-.225),Vector3(.085,.12,.08),dark)
	mesh("chest",Vector3(0,.10,.19),Vector3(.32,.35,.12),dark)
	mesh("neck",Vector3.ZERO,Vector3(.13,.19,.13),skin,true)
	mesh("head",Vector3(0,.025,0),Vector3(.29,.34,.28),skin,true)
	mesh("head",Vector3(0,-.035,-.133),Vector3(.20,.09,.045),dark)
	mesh("head",Vector3(0,.065,.03),Vector3(.33,.28,.30),material("38434b" if guard else "b9bdc4"),true)
	mesh("head",Vector3(0,.055,-.139),Vector3(.25,.065,.045),accent)
	mesh("head",Vector3(.16,-.01,0),Vector3(.065,.14,.10),dark,true)
	for side: String in ["l","r"]:
		mesh("thigh_"+side,Vector3(0,-.18,0),Vector3(.20,.41,.23),cloth,true)
		mesh("shin_"+side,Vector3(0,-.17,0),Vector3(.17,.38,.20),cloth,true)
		mesh("shin_"+side,Vector3(0,-.04,-.095),Vector3(.16,.14,.06),armor,true)
		mesh("foot_"+side,Vector3(0,-.035,-.075),Vector3(.20,.15,.34),dark,true)
		mesh("arm_"+side,Vector3(0,-.12,0),Vector3(.19,.30,.20),cloth,true)
		mesh("arm_"+side,Vector3(0,-.015,0),Vector3(.23,.16,.24),armor,true)
		mesh("forearm_"+side,Vector3(0,-.12,0),Vector3(.14,.27,.15),cloth,true)
		mesh("hand_"+side,Vector3(0,-.035,0),Vector3(.13,.15,.14),dark,true)
	# Pistol points down the arm's local -Y axis. Raising the arm aims it forward.
	mesh("hand_r",Vector3(0,-.10,-.04),Vector3(.085,.27,.105),armor)
	mesh("hand_r",Vector3(0,-.012,.055),Vector3(.075,.08,.16),dark)
	magazine=mesh("hand_r",Vector3(0,.005,.14),Vector3(.062,.055,.07),dark)
	spare_magazine=mesh("hand_l",Vector3(0,-.09,0),Vector3(.06,.16,.075),dark)
	spare_magazine.visible=false
	muzzle=Marker3D.new(); attachments.hand_r.add_child(muzzle); muzzle.position=Vector3(0,-.245,-.04)
	animation=AnimationPlayer.new(); animation.name="Animations"; turn.add_child(animation)
	var library: AnimationLibrary=AnimationLibrary.new(); animation.add_animation_library("",library)
	make_clip(library,"idle",1.6,true,{"arm_r":Vector3(.25,0,-.05),"arm_l":Vector3(0,0,.08)})
	make_clip(library,"walk",.72,true,{"arm_r":Vector3(.35,0,-.04)},true)
	make_clip(library,"aim",.8,true,{"arm_r":Vector3(1.45,0,-.05),"forearm_r":Vector3(.10,0,0),"arm_l":Vector3(1.03,0,-.40),"forearm_l":Vector3(.65,0,-.25)})
	make_clip(library,"walk_aim",.72,true,{"arm_r":Vector3(1.45,0,-.05),"forearm_r":Vector3(.10,0,0),"arm_l":Vector3(1.03,0,-.40),"forearm_l":Vector3(.65,0,-.25)},true)
	make_clip(library,"cover_walk",.9,true,{"arm_r":Vector3(.65,0,-.22),"forearm_r":Vector3(.7,0,0),"arm_l":Vector3(.15,0,.35),"head":Vector3(0,.45,0)},true)
	make_clip(library,"fire",.22,false,{"arm_r":Vector3(1.45,0,-.05),"forearm_r":Vector3(.1,0,0),"arm_l":Vector3(1.03,0,-.4),"forearm_l":Vector3(.65,0,-.25)})
	make_clip(library,"cover",1.2,true,{"arm_r":Vector3(.65,0,-.22),"forearm_r":Vector3(.7,0,0),"arm_l":Vector3(.15,0,.35),"thigh_l":Vector3(.10,0,.08),"thigh_r":Vector3(-.1,0,-.08),"head":Vector3(0,.45,0)})
	make_clip(library,"reload",1.3,false,{"arm_r":Vector3(.9,0,-.28),"forearm_r":Vector3(.6,0,-.2),"arm_l":Vector3(.3,0,-.25),"forearm_l":Vector3(.65,0,-.65),"head":Vector3(-.2,0,0)})
	make_clip(library,"crouch",1.0,true,{"thigh_l":Vector3(-.7,0,0),"thigh_r":Vector3(-.7,0,0),"shin_l":Vector3(1.25,0,0),"shin_r":Vector3(1.25,0,0),"chest":Vector3(-.15,0,0),"arm_r":Vector3(.6,0,0)})
	make_clip(library,"prone",1.2,true,{"arm_r":Vector3(1.1,0,0),"arm_l":Vector3(1.1,0,0)})
	make_clip(library,"crawl",1.4,true,{"arm_r":Vector3(1.1,0,0),"arm_l":Vector3(1.1,0,0)},true)
	make_clip(library,"box_climb",.65,false,{"arm_r":Vector3(1.6,0,-.1),"arm_l":Vector3(1.6,0,.1),"forearm_r":Vector3(.35,0,0),"forearm_l":Vector3(.35,0,0),"thigh_l":Vector3(-.8,0,0),"shin_l":Vector3(1.0,0,0)})
	animation.play("idle")
func make_clip(library: AnimationLibrary,id: String,duration: float,loop: bool,poses: Dictionary,walking: bool=false) -> void:
	var clip: Animation=Animation.new(); clip.length=duration
	clip.loop_mode=Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	for name: String in bones:
		var track: int=clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track,NodePath("Rig:"+name))
		for step in range(5):
			var phase: float=float(step)/4.0
			var rotation: Vector3=poses.get(name,Vector3.ZERO)
			if walking:
				if name=="thigh_l": rotation.x=sin(phase*TAU)*.55
				if name=="thigh_r": rotation.x=-sin(phase*TAU)*.55
				if name=="shin_l": rotation.x=maxf(0,-sin(phase*TAU))*.6
				if name=="shin_r": rotation.x=maxf(0,sin(phase*TAU))*.6
				if name=="arm_l" and not poses.has(name): rotation.x=-sin(phase*TAU)*.4
			if id=="reload":
				if name=="arm_l": rotation.x+=sin(phase*PI)*.8
				if name=="forearm_l": rotation.z-=sin(phase*PI)*.45
				if name=="head": rotation.y=sin(phase*PI)*.15
			if id=="fire" and name=="arm_r": rotation.x+=sin(phase*PI)*.22
			clip.rotation_track_insert_key(track,phase*duration,Quaternion.from_euler(rotation))
	library.add_animation(id,clip)
func tick(delta: float,_camera: Camera3D) -> void:
	clock+=delta
	var desired: float=atan2(-facing.x,-facing.z)
	turn.rotation.y=lerp_angle(turn.rotation.y,desired,minf(1,delta*14))
	var clip: String="walk" if move_speed>.15 else "idle"
	if pose in [0,1,2,3]: clip="cover_walk" if move_speed>.15 else "cover"
	elif pose==4: clip="walk_aim" if move_speed>.15 else "aim"
	elif pose==5: clip="fire"
	elif pose in [6,7,8]: clip="reload"
	elif pose==14: clip="crouch"
	elif pose==17: clip="box_climb"
	elif pose==18: clip="crawl" if move_speed>.15 else "prone"
	if clip!=current_clip:
		animation.play(clip,.12); current_clip=clip
	elif not animation.is_playing() and clip=="fire": animation.play("aim",.08)
	animation.speed_scale=clampf(move_speed/3.5,.55,1.4) if clip=="walk" else 1.0
	turn.position.y=-.22 if clip=="crouch" else 0.0
	# The rig lies along local -Z; yaw still follows movement.
	rig.rotation.x=-PI/2 if pose==18 else 0.0
	rig.position=Vector3(0,.32,.85) if pose==18 else Vector3.ZERO
	if pose in [1,3]: rig.set_bone_pose_rotation(bones.head,Quaternion.from_euler(Vector3(0,-.45,0)))
	var reloading: bool=clip=="reload" and animation.current_animation_position>.2 and animation.current_animation_position<.95
	magazine.visible=not reloading; spare_magazine.visible=reloading
	flash=maxf(0,flash-delta)
	skin_material.emission_enabled=flash>0
	skin_material.emission=Color("9f3f31")
