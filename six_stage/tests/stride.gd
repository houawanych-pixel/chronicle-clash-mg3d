extends SceneTree
## Natural ground speed of each clip: with the body held still at speed_scale 1, the planted
## (lowest) foot slides backwards at exactly the speed the clip was animated to travel.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var cam: Camera3D=Camera3D.new(); root.add_child(cam)
	for guard: bool in [false,true]:
		var a: Node3D=load("res://scripts/RigAvatar.gd").new(); a.guard=guard; root.add_child(a)
		for i in range(3): await process_frame
		var sk: Skeleton3D=a.find_children("*","Skeleton3D",true,false)[0]
		var lf: int=sk.find_bone("L_Foot"); var rf: int=sk.find_bone("R_Foot")
		for clip: String in ["walk","run"]:
			var name: String=("" if guard else "movement/")+clip
			a.animation.play(name); a.animation.speed_scale=1.0
			var dt: float=1.0/60; var samples: Array=[]; var pl: Vector3; var pr: Vector3; var dirsum: Vector2=Vector2.ZERO
			for f in range(400):
				a.animation.advance(dt)
				var l: Vector3=(sk.global_transform*sk.get_bone_global_pose(lf)).origin; var r: Vector3=(sk.global_transform*sk.get_bone_global_pose(rf)).origin
				if f>10:
					var low: Vector3=(l-pl) if l.y<r.y else (r-pr)
					if absf(l.y-r.y)>.03: samples.append(Vector2(low.x,low.z).length()/dt); dirsum+=Vector2(low.x,low.z)/dt
				pl=l; pr=r
			samples.sort()
			print("STRIDE ","guard" if guard else "kai"," ",clip," natural ground speed ~",snappedf(samples[samples.size()/2],.01)," m/s  mean planted-foot direction (x,z) ",(dirsum/samples.size()).snapped(Vector2.ONE*.01), " facing is -z")
		a.queue_free()
	quit()
