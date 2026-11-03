extends StaticBody3D
## A burning brazier: a fire source (melts ice next to it). Strike it and it tips over,
## setting the grass in front alight.

var lit: bool = true
var tipped: bool = false
var hurtbox: Area3D
var bowl: MeshInstance3D
var flame: OmniLight3D
var team: String = "world"
var hitstop_left: float = 0.0

func _ready() -> void:
	add_to_group("cc_fire_source")
	var cs: CollisionShape3D = CollisionShape3D.new()
	var cy: CylinderShape3D = CylinderShape3D.new()
	cy.radius = 0.35
	cy.height = 1.1
	cs.shape = cy
	cs.position.y = 0.55
	add_child(cs)
	var iron: StandardMaterial3D = StandardMaterial3D.new()
	iron.albedo_color = Color("3a3434")
	iron.metallic = 0.5
	var stand: MeshInstance3D = MeshInstance3D.new()
	var sm: CylinderMesh = CylinderMesh.new()
	sm.top_radius = 0.08
	sm.bottom_radius = 0.22
	sm.height = 0.9
	stand.mesh = sm
	stand.material_override = iron
	stand.position.y = 0.45
	add_child(stand)
	bowl = MeshInstance3D.new()
	var bm: CylinderMesh = CylinderMesh.new()
	bm.top_radius = 0.42
	bm.bottom_radius = 0.2
	bm.height = 0.25
	bowl.mesh = bm
	bowl.material_override = iron
	bowl.position.y = 1.0
	add_child(bowl)
	var fm: StandardMaterial3D = StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color("ffb347")
	var f: MeshInstance3D = MeshInstance3D.new()
	var fs: SphereMesh = SphereMesh.new()
	fs.radius = 0.25
	fs.height = 0.6
	f.mesh = fs
	f.material_override = fm
	f.position.y = 1.3
	bowl.add_child(f)
	f.position = Vector3(0, 0.3, 0)
	flame = OmniLight3D.new()
	flame.light_color = Color("ffb347")
	flame.light_energy = 1.4
	flame.omni_range = 5.0
	flame.position.y = 1.5
	add_child(flame)
	hurtbox = Area3D.new()
	hurtbox.collision_layer = 16
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	hurtbox.set_meta("actor", self)
	var hs: CollisionShape3D = CollisionShape3D.new()
	var hb: BoxShape3D = BoxShape3D.new()
	hb.size = Vector3(0.9, 1.4, 0.9)
	hs.shape = hb
	hs.position.y = 0.7
	hurtbox.add_child(hs)
	add_child(hurtbox)

func alive() -> bool:
	return not tipped

## Struck: it tips away from the hitter and lights the ground there.
func take_hit(info: Dictionary) -> String:
	if tipped:
		return "none"
	tipped = true
	var away: Vector3 = global_position - (info.get("from", global_position - Vector3.FORWARD) as Vector3)
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	rotation.z = 1.4
	rotation.y = atan2(away.x, away.z)
	ChemistryService.ignite_at(global_position + away * 1.4, 1.2)
	CombatFx.spark(get_tree(), global_position + away * 1.0 + Vector3.UP * 0.4, Color("ffb347"), 30)
	return "hit"
