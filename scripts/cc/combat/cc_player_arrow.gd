extends Area3D
## Lance's arrow: a real ballistic arc. Head hits do double. An Ember Arrow sets grass alight
## where it lands, unless it is raining (then it fizzles out as it leaves the bow).

signal fizzled

var shooter: Node3D
var damage: float = 14.0
var drop: float = 9.8
var vel: Vector3 = Vector3.ZERO
var fire: bool = false
var lit: bool = false
var life: float = 4.0
var done: bool = false
var headshot_mult: float = 2.0
var result: String = ""        # tests: "head", "body", "ground"
var mesh: MeshInstance3D
var flame: OmniLight3D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 16 | 1
	var cs: CollisionShape3D = CollisionShape3D.new()
	var s: SphereShape3D = SphereShape3D.new()
	s.radius = 0.12
	cs.shape = s
	add_child(cs)
	mesh = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.012
	cm.bottom_radius = 0.012
	cm.height = 0.75
	mesh.mesh = cm
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color("d8c7a4")
	mesh.material_override = m
	mesh.rotation.x = PI * 0.5
	add_child(mesh)
	area_entered.connect(_on_area)
	body_entered.connect(_on_body)

func launch(from: Vector3, v: Vector3) -> void:
	global_position = from
	vel = v
	look_at(from + v, Vector3.UP)
	if fire:
		if WeatherService.is_precipitating:
			lit = false
			CombatFx.spark(get_tree(), from, Color("9fb4c4"), 8)
			fizzled.emit()
		else:
			lit = true
			flame = OmniLight3D.new()
			flame.light_color = Color("ffb347")
			flame.light_energy = 1.2
			flame.omni_range = 2.0
			add_child(flame)

func _physics_process(dt: float) -> void:
	if done:
		return
	var s: float = TimeDilation.scale(false)
	vel.y -= drop * dt * s
	global_position += vel * dt * s
	if vel.length() > 0.1:
		look_at(global_position + vel, Vector3.UP)
	life -= dt * s
	if lit and WeatherService.is_precipitating:
		lit = false
		if flame:
			flame.queue_free()
		fizzled.emit()
	if life <= 0.0:
		queue_free()

func _on_area(a: Area3D) -> void:
	if done:
		return
	var target: Node3D = a.get_meta("actor", null) as Node3D
	if target == null or target == shooter or target.get("team") == "player":
		return
	done = true
	var head: bool = target.get("height") != null and global_position.y >= target.global_position.y + float(target.height) * 0.78
	result = "head" if head else "body"
	var info: Dictionary = {"damage": damage * (headshot_mult if head else 1.0), "plane": "thrust", "hitstop_f": 4, "shake": 0.25,
		"stagger_f": 12, "knockback": 1.0, "heavy": false, "attacker": shooter, "from": global_position - vel.normalized(), "id": "arrow"}
	target.take_hit(info)
	CombatFx.spark(get_tree(), global_position, Color("ffd27a") if head else Color("ffffff"), 18 if head else 10)
	CombatFx.sound(get_tree(), "hit", -6.0)
	if lit:
		ChemistryService.ignite_at(global_position, 1.0)
	queue_free()

func _on_body(_b: Node3D) -> void:
	if done:
		return
	done = true
	result = "ground"
	if lit:
		ChemistryService.ignite_at(global_position, 1.2)
	queue_free()
