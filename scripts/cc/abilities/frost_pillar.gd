extends StaticBody3D
## A Frost Pillar: rises from the water, blocks the way, breaks after a few hits and melts
## next to fire (it shrinks; below the minimum size it's gone).

var hp: int = 3
var team: String = "world"
var hitstop_left: float = 0.0
var size: Vector3
var melt: float = 1.0          # 1 = full size
var rise: float = 0.0
var base_y: float = 0.0
var hurtbox: Area3D

func _ready() -> void:
	var t: Resource = AbilityService.tuning
	hp = int(t.pillar_hp)
	size = t.pillar_size
	add_to_group("cc_pillar")
	var cs: CollisionShape3D = CollisionShape3D.new()
	var b: BoxShape3D = BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position.y = size.y * 0.5
	add_child(cs)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = size.x * 0.45
	cm.bottom_radius = size.x * 0.6
	cm.height = size.y
	cm.radial_segments = 6
	mi.mesh = cm
	mi.position.y = size.y * 0.5
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.75, 0.92, 1.0, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.emission_enabled = true
	m.emission = Color("9fe6ff")
	m.emission_energy_multiplier = 0.25
	mi.material_override = m
	add_child(mi)
	hurtbox = Area3D.new()
	hurtbox.collision_layer = 16
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	hurtbox.set_meta("actor", self)
	var hs: CollisionShape3D = CollisionShape3D.new()
	var hb: BoxShape3D = BoxShape3D.new()
	hb.size = size * 1.05
	hs.shape = hb
	hs.position.y = size.y * 0.5
	hurtbox.add_child(hs)
	add_child(hurtbox)

func raise_at(p: Vector3) -> void:
	base_y = p.y - 0.4
	global_position = Vector3(p.x, base_y - size.y, p.z)
	rise = 0.0

func alive() -> bool:
	return hp > 0

func take_hit(_info: Dictionary) -> String:
	hp -= 1
	CombatFx.spark(get_tree(), global_position + Vector3.UP * size.y * 0.6 * melt, Color("cfefff"), 18)
	if hp <= 0:
		shatter()
	return "none"

func shatter() -> void:
	CombatFx.spark(get_tree(), global_position + Vector3.UP * size.y * 0.5 * melt, Color("e6f8ff"), 40)
	CombatFx.sound(get_tree(), "chip", -4.0)
	queue_free()

func _physics_process(dt: float) -> void:
	if rise < 1.0:
		rise = minf(1.0, rise + dt * 4.0)
		global_position.y = base_y - size.y * (1.0 - rise) * melt
	var heat: float = ChemistryService.heat_near(global_position + Vector3.UP * 0.8, 2.5)
	if heat > 0.0:
		melt -= float(ChemistryService.tuning.ice_melt_fire) * dt * 0.35 * minf(heat, 3.0)
		if melt < float(AbilityService.tuning.pillar_min_scale):
			queue_free()
			return
		scale = Vector3.ONE * melt
