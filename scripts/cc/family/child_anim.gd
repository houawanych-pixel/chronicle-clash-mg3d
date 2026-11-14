extends RefCounted
## Animation states for village-born children and parents, mapped onto the
## existing procedural rig (Rig.gd + Poses.gd). Every state is a code-made
## PLACEHOLDER pose until real clips exist; MANIFEST lists what each state
## needs. No clip paths are assumed: "clip" stays "" until an asset is added
## and validated (tests check every state has a pose and no missing path).
const P = preload("res://scripts/citadel/Poses.gd")

const STATES: Array = ["newborn_idle", "newborn_cry", "parent_carry", "crawl", "stand", "first_steps",
	"toddler_walk", "child_walk", "child_play", "teen_walk", "adult_walk"]

## Per state: the clip to use once it exists, and what stands in for it now.
const MANIFEST: Dictionary = {
	"newborn_idle": {"clip": "", "now": "swaddled bundle mesh, gentle bob (no rig)"},
	"newborn_cry": {"clip": "", "now": "bundle wobble + caption; no cry audio yet"},
	"parent_carry": {"clip": "", "now": "Poses.carry with the bundle at the chest"},
	"crawl": {"clip": "", "now": "Poses.crawl on a tilted small rig"},
	"stand": {"clip": "", "now": "Poses.idle_free"},
	"first_steps": {"clip": "", "now": "slow run_free, arms out, wobble"},
	"toddler_walk": {"clip": "", "now": "run_free at low speed, arms out a little"},
	"child_walk": {"clip": "", "now": "run_free"},
	"child_play": {"clip": "", "now": "hop/skip loop from run_free + wave"},
	"teen_walk": {"clip": "", "now": "run_free with a slouch"},
	"adult_walk": {"clip": "", "now": "run_free (same as the cast)"},
}

## Body model per stage. Every entry is a PLACEHOLDER: the adult village
## models shown at a smaller height. They are not child models and are
## flagged as missing in docs/FAMILY.md; they only keep the village readable.
const BODY: Dictionary = {
	"newborn": {"kind": "bundle", "placeholder": true},
	"crawling_infant": {"kind": "rig", "placeholder": true},
	"early_walker": {"kind": "rig", "placeholder": true},
	"toddler": {"kind": "rig", "placeholder": true},
	"child": {"kind": "rig", "placeholder": true},
	"adolescent": {"kind": "rig", "placeholder": true},
	"adult": {"kind": "rig", "placeholder": false},
}

static func state_for(stage: String, moving: bool, playing: bool, crying: bool = false) -> String:
	match stage:
		"newborn":
			return "newborn_cry" if crying else "newborn_idle"
		"crawling_infant":
			return "crawl"
		"early_walker":
			return "first_steps" if moving else "stand"
		"toddler":
			if playing:
				return "child_play"
			return "toddler_walk" if moving else "stand"
		"child":
			if playing:
				return "child_play"
			return "child_walk" if moving else "stand"
		"adolescent":
			return "teen_walk" if moving else "stand"
	return "adult_walk" if moving else "stand"

## Rig tilt (radians about X) and drop as a share of body height.
static func tilt_for(state: String) -> Vector2:
	if state == "crawl":
		return Vector2(-1.42, 0.12)
	return Vector2.ZERO

static func pose(state: String, t: float, phase: float, speed: float) -> Dictionary:
	match state:
		"crawl":
			return P.crawl(phase, clampf(speed, 0.0, 1.0))
		"stand":
			return P.idle_free(t)
		"first_steps":
			var p: Dictionary = P.run_free(phase, 0.18)
			var w: float = sin(t * 3.1) * 0.12
			p["L_Upperarm"] = P.d(0.35, -0.15 + w, -1.0)
			p["R_Upperarm"] = P.d(0.35, -0.15 - w, 1.0)
			p["L_Forearm"] = P.d(1.0, 0.1, -0.4)
			p["R_Forearm"] = P.d(1.0, 0.1, 0.4)
			p["Spine02"] = P.lean(0.1 + w * 0.5)
			return p
		"toddler_walk":
			var p: Dictionary = P.run_free(phase, 0.32)
			p["L_Upperarm"] = P.d(0.1, -1.0, -0.6)
			p["R_Upperarm"] = P.d(0.1, -1.0, 0.6)
			return p
		"child_walk":
			return P.run_free(phase, clampf(speed, 0.25, 0.6))
		"child_play":
			var hop: Dictionary = P.run_free(t * 9.0, 0.75)
			if fmod(t, 3.0) < 1.0:
				hop["R_Upperarm"] = P.d(0.2, 1.0, 0.4)
				hop["R_Forearm"] = P.d(0.1, 1.0, 0.2 + sin(t * 9.0) * 0.4)
			return hop
		"teen_walk":
			var p: Dictionary = P.run_free(phase, clampf(speed, 0.2, 0.5))
			p["Spine02"] = P.lean(0.12)
			p["Head"] = P.lean(0.1)
			return p
		"adult_walk":
			return P.run_free(phase, speed)
		"parent_carry":
			return P.carry(phase, speed)
	return {}   # newborn states: no rig, the bundle mesh moves instead

## A soft swaddled bundle: two shapes, cheap, obviously a placeholder.
static func make_bundle(color: Color = Color("efe6d2")) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "BabyBundle"
	var body: MeshInstance3D = MeshInstance3D.new()
	var cap: CapsuleMesh = CapsuleMesh.new()
	cap.radius = 0.11
	cap.height = 0.42
	body.mesh = cap
	body.rotation.z = PI / 2.0
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	body.material_override = m
	root.add_child(body)
	var face: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.14
	face.mesh = sm
	var fm: StandardMaterial3D = StandardMaterial3D.new()
	fm.albedo_color = Color("e8c4a0")
	face.material_override = fm
	face.position = Vector3(0.17, 0.03, 0)
	root.add_child(face)
	return root
