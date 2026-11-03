extends RigidBody3D
## A Blast Orb. Sphere rolls, cube sits. Goes off on the second USE, or when struck.
## Blast: knocks physics props away, hurts fighters, may light grass.

signal exploded

var kind: String = "orb_sphere"
var team: String = "world"
var hitstop_left: float = 0.0
var hurtbox: Area3D
var done: bool = false

func _ready() -> void:
	var t: Resource = AbilityService.tuning
	mass = 2.0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var mi: MeshInstance3D = MeshInstance3D.new()
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color("2b4a8c")
	m.emission_enabled = true
	m.emission = Color("6fc8ff")
	m.emission_energy_multiplier = 0.8
	if kind == "orb_sphere":
		var s: SphereShape3D = SphereShape3D.new()
		s.radius = 0.35
		cs.shape = s
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = 0.35
		sm.height = 0.7
		mi.mesh = sm
	else:
		var b: BoxShape3D = BoxShape3D.new()
		b.size = Vector3(0.6, 0.6, 0.6)
		cs.shape = b
		var bm: BoxMesh = BoxMesh.new()
		bm.size = b.size
		mi.mesh = bm
		var pm: PhysicsMaterial = PhysicsMaterial.new()
		pm.friction = 1.0
		physics_material_override = pm
	mi.material_override = m
	add_child(cs)
	add_child(mi)
	hurtbox = Area3D.new()
	hurtbox.collision_layer = 16
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	hurtbox.set_meta("actor", self)
	var hs: CollisionShape3D = CollisionShape3D.new()
	var hsp: SphereShape3D = SphereShape3D.new()
	hsp.radius = 0.5
	hs.shape = hsp
	hurtbox.add_child(hs)
	add_child(hurtbox)
	add_to_group("cc_orb")

func alive() -> bool:
	return not done

## Struck by a weapon: it goes off.
func take_hit(_info: Dictionary) -> String:
	explode()
	return "none"

func explode() -> void:
	if done:
		return
	done = true
	var t: Resource = AbilityService.tuning
	var p: Vector3 = global_position
	var r: float = float(t.orb_radius)
	for n: Node in get_tree().get_nodes_in_group("cc_prop"):
		var b: RigidBody3D = n as RigidBody3D
		if b == null:
			continue
		var d: Vector3 = b.global_position - p
		var dist: float = d.length()
		if dist < r and dist > 0.01:
			var k: float = 1.0 - dist / r
			b.apply_central_impulse((d.normalized() + Vector3.UP * 0.5).normalized() * float(t.orb_impulse) * k * b.mass)
	for g: String in ["cc_player", "cc_enemy"]:
		for n2: Node in get_tree().get_nodes_in_group(g):
			var a: Node3D = n2 as Node3D
			if a.global_position.distance_to(p) < r and a.alive():
				a.apply_damage(float(t.orb_damage) * (1.0 - a.global_position.distance_to(p) / r), p, 4.0)
	# the hot core can light grass close in
	if not WeatherService.is_precipitating:
		for f: Variant in ChemistryService.fields:
			if not is_instance_valid(f):
				continue
			var fld: Node = f
			for c: int in fld.cells_within(p, r * 0.5):
				if fld.state[c] == 0 and ChemistryService.rng.randf() < float(t.orb_fire_chance):
					fld.state[c] = 1
					fld.dirty = true
	CombatFx.spark(get_tree(), p, Color("9fd8ff"), 50)
	CombatFx.spark(get_tree(), p, Color("ffb347"), 30)
	CombatFx.sound(get_tree(), "explosion", -2.0)
	CombatFx.shake(get_tree(), 0.7)
	exploded.emit()
	queue_free()
