extends SceneTree
func _init() -> void:
	var k: Skeleton3D=load("res://assets/characters/kai.glb").instantiate().find_children("*","Skeleton3D",true,false)[0]
	var g: Skeleton3D=load("res://assets/characters/guard.glb").instantiate().find_children("*","Skeleton3D",true,false)[0]
	var diff: int=0; var maxd: float=0; var worst: String=""
	for b in range(k.get_bone_count()):
		var n: String=k.get_bone_name(b); var gb: int=g.find_bone(n)
		if gb<0: print("REST missing in guard: ",n); continue
		var a: float=k.get_bone_rest(b).basis.get_rotation_quaternion().angle_to(g.get_bone_rest(gb).basis.get_rotation_quaternion())
		var t: float=k.get_bone_rest(b).origin.distance_to(g.get_bone_rest(gb).origin)
		if a>0.02 or t>0.01: diff+=1
		if a>maxd: maxd=a; worst=n
	print("REST bones differing: ",diff," of ",k.get_bone_count()," max angle deg ",rad_to_deg(maxd)," at ",worst)
	quit()
