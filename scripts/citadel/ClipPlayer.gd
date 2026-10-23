extends RefCounted
## Plays baked pose tracks (clips.json from tools/anim/bake.gd) on the procedural rig:
## sample(name, t) -> pose dict with limb directions, torso turns and "lift" (hip rise / hip height).
var clips: Dictionary = {}

func load_file(path: String) -> void:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if d is Dictionary:
		clips = d

func has(name: String) -> bool:
	return clips.has(name)

func length(name: String) -> float:
	return float(clips[name].length)

## Ground speed of the clip, in hip heights per second (0 for clips made in place).
func move_rate(name: String) -> float:
	return float(clips[name].move)

func sample(name: String, t: float) -> Dictionary:
	var c: Dictionary = clips[name]
	var frames: Array = c.frames
	var n: int = frames.size()
	var len: float = float(c.length)
	var u: float
	if c.loop:
		u = fposmod(t, len) / len * n
	else:
		u = clampf(t / len, 0.0, 0.9999) * (n - 1)
	var i0: int = int(floor(u)) % n
	var i1: int = (i0 + 1) % n if c.loop else mini(i0 + 1, n - 1)
	var k: float = u - floor(u)
	var a: Dictionary = frames[i0]
	var b: Dictionary = frames[i1]
	var p: Dictionary = {}
	for key: String in a.d:
		var va: Array = a.d[key]
		var vb: Array = b.d[key]
		p[key] = Vector3(va[0], va[1], va[2]).slerp(Vector3(vb[0], vb[1], vb[2]), k).normalized()
	for key: String in a.t:
		var qa: Array = a.t[key]
		var qb: Array = b.t[key]
		p[key] = Quaternion(qa[0], qa[1], qa[2], qa[3]).slerp(Quaternion(qb[0], qb[1], qb[2], qb[3]), k)
	p["lift"] = lerpf(float(a.lift), float(b.lift), k)
	return p

## Blend two poses (directions slerp, turns slerp, lift lerp).
static func mix(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var out: Dictionary = a.duplicate()
	for key: String in b:
		if not a.has(key):
			out[key] = b[key]
		elif a[key] is Vector3:
			out[key] = (a[key] as Vector3).slerp(b[key], k).normalized()
		elif a[key] is Quaternion:
			out[key] = (a[key] as Quaternion).slerp(b[key], k)
		elif a[key] is float:
			out[key] = lerpf(a[key], b[key], k)
	return out
