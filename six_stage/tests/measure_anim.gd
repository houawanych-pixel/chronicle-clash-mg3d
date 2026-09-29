extends SceneTree
func _init() -> void:
	for path: String in ["res://assets/characters/guard.glb","res://assets/characters/kai.glb"]:
		var rig: Node3D=load(path).instantiate(); root.add_child(rig)
		var sk: Skeleton3D=rig.find_children("*","Skeleton3D",true,false)[0]
		var ap: AnimationPlayer=rig.find_children("*","AnimationPlayer",true,false)[0]
		print(path," skeleton path ",rig.get_path_to(sk)," global scale ",sk.global_basis.get_scale()," anim root ",ap.get_node(ap.root_node).name)
		for clip: String in ap.get_animation_list():
			var a: Animation=ap.get_animation(clip)
			for t in range(a.get_track_count()):
				if a.track_get_type(t)==Animation.TYPE_POSITION_3D:
					var n: int=a.track_get_key_count(t)
					var first: Vector3=a.track_get_key_value(t,0); var last: Vector3=a.track_get_key_value(t,n-1)
					var bone: int=sk.find_bone(str(a.track_get_path(t)).get_slice(":",1))
					var parent_pose: Transform3D=sk.get_bone_global_rest(sk.get_bone_parent(bone)) if sk.get_bone_parent(bone)>=0 else Transform3D()
					var travel: Vector3=sk.global_basis*(parent_pose.basis*(last-first))
					print("  ",clip," len ",snappedf(a.length,.01)," track ",a.track_get_path(t)," keys ",n," travel world ",travel," horizontal m ",snappedf(Vector2(travel.x,travel.z).length(),.01)," speed m/s ",snappedf(Vector2(travel.x,travel.z).length()/a.length,.01))
	quit()
