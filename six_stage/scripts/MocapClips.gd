extends RefCounted
## Turns baked motion-capture clips (assets/anim/clips.json: limb directions + torso turns per
## frame, made from Mixamo clips by tools/anim/bake.gd) into ordinary Animations for any
## Tripo-rigged character (Hip / Waist / Spine01 / L_Thigh ... bones). Works by aiming each
## limb bone along the captured direction from the character's own rest pose, so it does not
## matter that the source was a T-pose and these characters are A-pose.

const AIM_PAIRS: Dictionary = {
	"L_Upperarm": "L_Forearm", "L_Forearm": "L_Hand",
	"R_Upperarm": "R_Forearm", "R_Forearm": "R_Hand",
	"L_Thigh": "L_Calf", "L_Calf": "L_Foot",
	"R_Thigh": "R_Calf", "R_Calf": "R_Foot",
}
const ORDER: Array = ["Hip", "Waist", "Spine01", "Spine02", "Head",
	"L_Upperarm", "L_Forearm", "R_Upperarm", "R_Forearm",
	"L_Thigh", "L_Calf", "R_Thigh", "R_Calf"]

static func load_clips(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}

## Build one Animation per clip name. sk_path = track path to the skeleton from the player's root.
static func build(sk: Skeleton3D, sk_path: String, clips: Dictionary, names: Array) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	var idx := {}
	for i in sk.get_bone_count():
		idx[sk.get_bone_name(i)] = i
	for n: String in ORDER:
		if not idx.has(n):
			return lib
	# character frame in skeleton space
	var lt: Vector3 = sk.get_bone_global_rest(idx.L_Thigh).origin
	var rt: Vector3 = sk.get_bone_global_rest(idx.R_Thigh).origin
	var left: Vector3 = Vector3(lt.x - rt.x, 0, lt.z - rt.z).normalized()
	var up := Vector3.UP
	var fwd: Vector3 = left.cross(up).normalized()
	var right: Vector3 = -left
	var S := Basis(fwd, up, right)          # model (F,U,R) -> skeleton
	var rest_q := {}
	var parent_q := {}
	var rest_dir := {}
	for n: String in ORDER:
		var i: int = idx[n]
		rest_q[i] = sk.get_bone_rest(i).basis.orthonormalized().get_rotation_quaternion()
		var p: int = sk.get_bone_parent(i)
		parent_q[i] = sk.get_bone_global_rest(p).basis.orthonormalized().get_rotation_quaternion() if p >= 0 else Quaternion()
	for a: String in AIM_PAIRS:
		rest_dir[a] = (sk.get_bone_global_rest(idx[AIM_PAIRS[a]]).origin - sk.get_bone_global_rest(idx[a]).origin).normalized()
	var hip_i: int = idx.Hip
	var hip_h: float = sk.get_bone_global_rest(hip_i).origin.y
	var hip_rest: Vector3 = sk.get_bone_rest(hip_i).origin
	var hp: int = sk.get_bone_parent(hip_i)
	var hip_parent_inv: Basis = sk.get_bone_global_rest(hp).basis.inverse() if hp >= 0 else Basis.IDENTITY
	for name: String in names:
		if not clips.has(name):
			continue
		var c: Dictionary = clips[name]
		var frames: Array = c.frames
		var anim := Animation.new()
		anim.length = float(c.length)
		anim.loop_mode = Animation.LOOP_LINEAR if c.loop else Animation.LOOP_NONE
		var tracks := {}
		for n: String in ORDER:
			var t: int = anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(t, NodePath("%s:%s" % [sk_path, n]))
			tracks[n] = t
		var pt: int = anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(pt, NodePath("%s:Hip" % sk_path))
		var dt: float = anim.length / frames.size()
		for f in frames.size():
			var fr: Dictionary = frames[f]
			var time: float = f * dt
			var acc := {}
			for n: String in ORDER:
				var i: int = idx[n]
				var p: int = sk.get_bone_parent(i)
				var accp: Quaternion = Quaternion()
				var j: int = p
				while j >= 0 and not acc.has(j):
					j = sk.get_bone_parent(j)
				if j >= 0:
					accp = acc[j]
				var r: Quaternion
				if rest_dir.has(n) and fr.d.has(n):
					var v: Array = fr.d[n]
					var want: Vector3 = (S * Vector3(v[0], v[1], v[2])).normalized()
					want = accp.inverse() * want
					r = Quaternion(rest_dir[n], want.normalized())
				elif fr.t.has(n):
					var q: Array = fr.t[n]
					var bm: Basis = S * Basis(Quaternion(q[0], q[1], q[2], q[3])) * S.inverse()
					r = bm.get_rotation_quaternion()
				else:
					r = Quaternion()
				acc[i] = accp * r
				var pq: Quaternion = parent_q[i]
				anim.rotation_track_insert_key(tracks[n], time, (pq.inverse() * r * pq * (rest_q[i] as Quaternion)).normalized())
			var lift: float = float(fr.get("lift", 0.0)) * hip_h
			anim.position_track_insert_key(pt, time, hip_rest + hip_parent_inv * (up * lift))
		lib.add_animation(name, anim)
	return lib
