extends Node3D
const V=preload("res://scripts/Visuals.gd")
var game: Node
var active: bool=false
var clock: float=0
var shaking: bool=false
var warning: bool=false
var upper: Node3D
var targets: Array=[]
var shake_serial: int=-1
var limbs: Array=[]
func _ready() -> void:
	# Original training mannequin. Every physical segment is hookable.
	part(self,Vector3(-1.45,.65,.6),Vector3(1.9,1.3,3.0))
	part(self,Vector3(1.45,.65,.6),Vector3(1.9,1.3,3.0))
	part(self,Vector3(-1.45,3,0),Vector3(1.55,4.0,1.55))
	part(self,Vector3(1.45,3,0),Vector3(1.55,4.0,1.55))
	upper=Node3D.new(); add_child(upper); upper.position=Vector3(0,5.0,0)
	part(upper,Vector3(0,1.8,0),Vector3(4.5,4.1,2.25))
	part(upper,Vector3(0,5.15,0),Vector3(2.5,2.4,2.15))
	for side: float in [-1.0,1.0]:
		var arm: Node3D=Node3D.new(); upper.add_child(arm); arm.position=Vector3(side*2.7,2.9,0)
		part(arm,Vector3(side*.7,-.3,0),Vector3(1.8,1.8,1.8))
		part(arm,Vector3(side*1.2,-2.0,.2),Vector3(1.3,2.8,1.3))
		limbs.append(arm)
	add_target(upper,Vector3(-2.25,3.1,1.25),"shoulder")
	add_target(upper,Vector3(0,5.4,1.17),"head")
	V.label(self,Vector3(0,12.5,0),"TITAN / TRAINING SENTINEL",Color("7de6e1"),42)
func part(parent: Node3D, at: Vector3, size: Vector3) -> void:
	var body: StaticBody3D=V.solid(parent,at,size,Color("344b64"),true,true)
	body.collision_layer=16
	body.set_meta("titan",true)
func add_target(parent: Node3D, at: Vector3, id: String) -> void:
	var node: Node3D=Node3D.new(); parent.add_child(node); node.position=at
	var ring: MeshInstance3D=V.ring(node,Vector3.ZERO,.55,Color("ffc966")); ring.rotation.x=PI/2
	V.label(node,Vector3(0,.8,.1),id.to_upper(),Color("ffd77f"),25)
	targets.append({"node":node,"id":id,"hp":3,"ring":ring})
func start() -> void:
	active=true; clock=0; game.toast("Titan active. Yellow warning: hold BRACE before the shake.")
func tick(delta: float) -> void:
	if not active: return
	clock+=delta
	var phase: float=fmod(clock,10)
	warning=phase>=5 and phase<7
	shaking=phase>=7 and phase<8.5
	upper.rotation.z=sin(clock*1.1)*.035
	upper.rotation.x=sin(clock*.8)*.025
	if shaking: upper.rotation.z+=sin(clock*18)*.11
	for i in range(limbs.size()): limbs[i].rotation.z=sin(clock*1.3+i*PI)*(.14 if not shaking else .35)
	if shaking and shake_serial!=int(clock/10):
		shake_serial=int(clock/10)
		var p: CharacterBody3D=game.player
		if is_instance_valid(p.anchor_body) and p.anchor_body.has_meta("titan") and p.mode in ["climb","grapple"]:
			if p.brace and p.grip>=22:
				p.grip-=22; game.toast("Held on! Strike during recovery."); game.sound("cover")
			else: p.drop(true)
func strike(at: Vector3) -> void:
	if not active: game.toast("Start the titan exercise at the floor console first."); return
	if shaking: game.toast("Brace through the shake. Attack during recovery."); return
	for target: Dictionary in targets:
		if target.hp>0 and at.distance_to(target.node.global_position)<2.0:
			target.hp-=1
			game.sound("hit")
			game.flash_at(target.node.global_position)
			if target.hp<=0:
				target.ring.material_override=V.mat(Color("43e7b0"),.5)
				game.mark_goal("titan_"+target.id)
				game.toast(target.id.to_upper()+" disabled.")
			else: game.toast("Weak point hit! %d strikes left."%int(target.hp))
			return
	game.toast("Climb within reach of a gold weak point to strike.")
