extends SceneTree
## Bakes clips into rig-independent pose tracks for the Chronicle Clash procedural rig:
## per frame, limb bone directions (+X forward, +Y up, +Z right) and torso turn deltas.
const MAPS := {
	"mixamo": {"L_Upperarm": ["LeftArm","LeftForeArm"], "L_Forearm": ["LeftForeArm","LeftHand"], "R_Upperarm": ["RightArm","RightForeArm"], "R_Forearm": ["RightForeArm","RightHand"],
		"L_Thigh": ["LeftUpLeg","LeftLeg"], "L_Calf": ["LeftLeg","LeftFoot"], "R_Thigh": ["RightUpLeg","RightLeg"], "R_Calf": ["RightLeg","RightFoot"],
		"turn": {"Hip": "Hips", "Waist": "Spine", "Spine01": "Spine1", "Spine02": "Spine2", "Head": "Head"}, "hips": "Hips", "lleg": "LeftUpLeg", "rleg": "RightUpLeg"},
	"mannequin": {"L_Upperarm": ["upperarm.l","lowerarm.l"], "L_Forearm": ["lowerarm.l","hand.l"], "R_Upperarm": ["upperarm.r","lowerarm.r"], "R_Forearm": ["lowerarm.r","hand.r"],
		"L_Thigh": ["thigh.l","calf.l"], "L_Calf": ["calf.l","foot.l"], "R_Thigh": ["thigh.r","calf.r"], "R_Calf": ["calf.r","foot.r"],
		"turn": {"Hip": "pelvis", "Waist": "spine_01", "Spine02": "spine_02", "Head": "head"}, "hips": "pelvis", "lleg": "thigh.l", "rleg": "thigh.r"},
	"kaykit": {"L_Upperarm": ["upperarm.l","lowerarm.l"], "L_Forearm": ["lowerarm.l","wrist.l"], "R_Upperarm": ["upperarm.r","lowerarm.r"], "R_Forearm": ["lowerarm.r","wrist.r"],
		"L_Thigh": ["upperleg.l","lowerleg.l"], "L_Calf": ["lowerleg.l","foot.l"], "R_Thigh": ["upperleg.r","lowerleg.r"], "R_Calf": ["lowerleg.r","foot.r"],
		"turn": {"Hip": "hips", "Waist": "spine", "Spine02": "chest", "Head": "head"}, "hips": "hips", "lleg": "upperleg.l", "rleg": "upperleg.r"},
	# Quaternius Universal Animation Library 1 & 2 (CC0), UE-mannequin-style names.
	# "blade": knuckle line pinky->index of the sword hand = the direction a gripped blade points.
	"ual": {"L_Upperarm": ["upperarm_l","lowerarm_l"], "L_Forearm": ["lowerarm_l","hand_l"], "R_Upperarm": ["upperarm_r","lowerarm_r"], "R_Forearm": ["lowerarm_r","hand_r"],
		"L_Thigh": ["thigh_l","calf_l"], "L_Calf": ["calf_l","foot_l"], "R_Thigh": ["thigh_r","calf_r"], "R_Calf": ["calf_r","foot_r"],
		"turn": {"Hip": "pelvis", "Waist": "spine_01", "Spine01": "spine_02", "Spine02": "spine_03", "Head": "Head"}, "hips": "pelvis", "lleg": "thigh_l", "rleg": "thigh_r",
		"blade": ["pinky_01_r", "index_01_r"], "hand": "hand_r"},
}
## [source file, map, clip in file, output name, loop]
const JOBS := [
	["res://src/Running.fbx", "mixamo", "mixamo_com", "mx_run", true],
	["res://src/Standard Walk.fbx", "mixamo", "mixamo_com", "mx_walk", true],
	["res://src/Idle.fbx", "mixamo", "mixamo_com", "mx_idle", true],
	["res://src/Sneaking Forward.fbx", "mixamo", "mixamo_com", "mx_sneak", true],
	["res://src/Sword And Shield Crouch Idle.fbx", "mixamo", "mixamo_com", "mx_crouch_idle", true],
	["res://src/Roll.fbx", "mixamo", "mixamo_com", "mx_roll", false],
	["res://src/Dodging Back.fbx", "mixamo", "mixamo_com", "mx_backstep", false],
	["res://src/Jump.fbx", "mixamo", "mixamo_com", "mx_jump", false],
	["res://src/Falling Idle.fbx", "mixamo", "mixamo_com", "mx_fall", true],
	["res://src/mannequin.glb", "mannequin", "run", "mq_run", true],
	["res://src/mannequin.glb", "mannequin", "idle", "mq_idle", true],
	["res://src/kaykit.glb", "kaykit", "Running_A", "kk_run_a", true],
	["res://src/kaykit.glb", "kaykit", "Running_B", "kk_run_b", true],
	["res://src/kaykit.glb", "kaykit", "Walking_A", "kk_walk", true],
	["res://src/kaykit.glb", "kaykit", "Idle", "kk_idle", true],
]
## CC0 combat and village clips (Quaternius UAL 1 & 2). Bake with -- --only=ual; merged into clips.json.
const UAL_JOBS := [
	["res://src/ual1.glb", "ual", "Sword_Idle", "ual_sword_idle", true],
	["res://src/ual1.glb", "ual", "Sword_Attack", "ual_sword_attack", false],
	["res://src/ual1.glb", "ual", "Hit_Chest", "ual_hit_chest", false],
	["res://src/ual1.glb", "ual", "Hit_Head", "ual_hit_head", false],
	["res://src/ual1.glb", "ual", "Death01", "ual_death", false],
	["res://src/ual1.glb", "ual", "Spell_Simple_Shoot", "ual_cast", false],
	["res://src/ual1.glb", "ual", "Sitting_Idle", "ual_sit", true],
	["res://src/ual1.glb", "ual", "Idle_Talking", "ual_talk", true],
	["res://src/ual2.glb", "ual", "Sword_Regular_A", "ual_slash_a", false],
	["res://src/ual2.glb", "ual", "Sword_Regular_A_Rec", "ual_slash_a_rec", false],
	["res://src/ual2.glb", "ual", "Sword_Regular_B", "ual_slash_b", false],
	["res://src/ual2.glb", "ual", "Sword_Regular_B_Rec", "ual_slash_b_rec", false],
	["res://src/ual2.glb", "ual", "Sword_Regular_C", "ual_slash_c", false],
	["res://src/ual2.glb", "ual", "Sword_Regular_Combo", "ual_combo", false],
	["res://src/ual2.glb", "ual", "Sword_Heavy_Combo", "ual_heavy_combo", false],
	["res://src/ual2.glb", "ual", "Sword_Block", "ual_block", false],
	["res://src/ual2.glb", "ual", "Sword_Dash", "ual_dash_slash", false],
	["res://src/ual2.glb", "ual", "Idle_Shield", "ual_shield_idle", true],
	["res://src/ual2.glb", "ual", "Idle_Shield_Break", "ual_shield_break", false],
	["res://src/ual2.glb", "ual", "Shield_OneShot", "ual_shield_bash", false],
	["res://src/ual2.glb", "ual", "Hit_Knockback", "ual_knockback", false],
	["res://src/ual2.glb", "ual", "TreeChopping", "ual_chop", true],
	["res://src/ual2.glb", "ual", "Farm_Harvest", "ual_harvest", false],
	["res://src/ual2.glb", "ual", "Farm_Watering", "ual_water", false],
	["res://src/ual2.glb", "ual", "Walk_Carry", "ual_carry", true],
]
const FPS := 30.0
func _initialize() -> void: run.call_deferred()
func r4(v: float) -> float: return snappedf(v, 0.0001)
func run() -> void:
	var out: Dictionary = {}
	var jobs: Array = JOBS
	if "--only=ual" in OS.get_cmdline_user_args():
		jobs = UAL_JOBS
		# keep the clips already baked (their sources aren't in the repo)
		if FileAccess.file_exists("res://clips.json"):
			out = JSON.parse_string(FileAccess.get_file_as_string("res://clips.json"))
	for job: Array in jobs:
		var s: Node = (load(job[0]) as PackedScene).instantiate()
		root.add_child(s)
		await process_frame
		var sk: Skeleton3D = s.find_children("*","Skeleton3D",true,false)[0]
		var ap: AnimationPlayer = s.find_children("*","AnimationPlayer",true,false)[0]
		var m: Dictionary = MAPS[job[1]]
		var idx := func(n: String) -> int: return sk.find_bone(n)
		# character frame from the rest pose: left = left hip - right hip
		var lrest: Vector3 = sk.get_bone_global_rest(idx.call(m.lleg)).origin
		var rrest: Vector3 = sk.get_bone_global_rest(idx.call(m.rleg)).origin
		var left: Vector3 = Vector3(lrest.x - rrest.x, 0, lrest.z - rrest.z).normalized()
		var up := Vector3.UP
		var fwd: Vector3 = left.cross(up).normalized()
		var right: Vector3 = -left
		# model (F,U,R) = rows of M
		var M := Basis(Vector3(fwd.x, up.x, right.x), Vector3(fwd.y, up.y, right.y), Vector3(fwd.z, up.z, right.z))
		var hip_i: int = idx.call(m.hips)
		var hip_h: float = sk.get_bone_global_rest(hip_i).origin.y
		if hip_h < 0.05: hip_h = (lrest.y + rrest.y) * 0.5 + 0.05
		var anim: Animation = ap.get_animation(job[2])
		ap.play(job[2])
		var n: int = maxi(2, int(round(anim.length * FPS)))
		var frames: Array = []
		var z0 := 0.0
		var z1 := 0.0
		var hand_prev := Vector3.INF
		var hit_t := 0.0
		var hit_v := 0.0
		for f in n:
			var t: float = anim.length * f / n
			ap.seek(t, true)
			var fr := {"d": {}, "t": {}}
			for key: String in m:
				if key in ["turn","hips","lleg","rleg","blade","hand"]: continue
				var a: int = idx.call(m[key][0]); var b: int = idx.call(m[key][1])
				var v: Vector3 = sk.get_bone_global_pose(b).origin - sk.get_bone_global_pose(a).origin
				var mv: Vector3 = (M.inverse() * v).normalized()
				mv = Vector3(fwd.dot(v), up.dot(v), right.dot(v)).normalized()
				fr.d[key] = [r4(mv.x), r4(mv.y), r4(mv.z)]
			var parent_delta := Basis.IDENTITY
			for tk: String in ["Hip","Waist","Spine01","Spine02","Head"]:
				if not m.turn.has(tk): continue
				var bi: int = idx.call(m.turn[tk])
				var gd: Basis = sk.get_bone_global_pose(bi).basis.orthonormalized() * sk.get_bone_global_rest(bi).basis.orthonormalized().inverse()
				var local: Basis = parent_delta.inverse() * gd
				parent_delta = gd
				# into model axes: B' = C * B * C^-1, C maps source coords to (F,U,R)
				var C := Basis(Vector3(fwd.x, up.x, right.x), Vector3(fwd.y, up.y, right.y), Vector3(fwd.z, up.z, right.z))
				var bm: Basis = C * local * C.inverse()
				var q: Quaternion = bm.get_rotation_quaternion()
				fr.t[tk] = [r4(q.x), r4(q.y), r4(q.z), r4(q.w)]
			if m.has("blade"):
				var bv: Vector3 = sk.get_bone_global_pose(idx.call(m.blade[1])).origin - sk.get_bone_global_pose(idx.call(m.blade[0])).origin
				var bm2: Vector3 = Vector3(fwd.dot(bv), up.dot(bv), right.dot(bv)).normalized()
				fr.d["blade"] = [r4(bm2.x), r4(bm2.y), r4(bm2.z)]
				# the strike: when the sword hand moves fastest relative to the hips
				var hpos: Vector3 = sk.get_bone_global_pose(idx.call(m.hand)).origin - sk.get_bone_global_pose(hip_i).origin
				if hand_prev != Vector3.INF:
					var v: float = hpos.distance_to(hand_prev) * FPS
					if v > hit_v:
						hit_v = v
						hit_t = t
				hand_prev = hpos
			var hp: Vector3 = sk.get_bone_global_pose(hip_i).origin
			fr["lift"] = r4((hp.y - hip_h) / hip_h)
			if f == 0: z0 = fwd.dot(hp)
			z1 = fwd.dot(hp)
			frames.append(fr)
		out[job[3]] = {"fps": FPS, "length": anim.length, "loop": job[4], "move": r4((z1 - z0) / hip_h / anim.length), "frames": frames}
		if m.has("blade"):
			out[job[3]]["hit"] = r4(hit_t)
		print("baked ", job[3], " frames ", n, " len ", anim.length, " move/hip/s ", out[job[3]].move, " fwd ", fwd)
		s.queue_free()
	var f2 := FileAccess.open("res://clips.json", FileAccess.WRITE)
	f2.store_string(JSON.stringify(out))
	f2.close()
	print("written")
	quit()
