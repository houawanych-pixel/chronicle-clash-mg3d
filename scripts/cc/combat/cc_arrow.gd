extends Area3D
## An archer's arrow: flies straight (light drop), hits the first hurtbox it touches.

const HURTBOX_LAYER: int = 16

var shooter: Node3D
var damage: float = 10.0
var vel: Vector3 = Vector3.ZERO
var life: float = 3.0
var done: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = HURTBOX_LAYER | 1
	var cs: CollisionShape3D = CollisionShape3D.new()
	var s: SphereShape3D = SphereShape3D.new()
	s.radius = 0.15
	cs.shape = s
	add_child(cs)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.015
	cm.bottom_radius = 0.015
	cm.height = 0.8
	mi.mesh = cm
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color("d8c7a4")
	m.emission_enabled = true
	m.emission = Color("ffb347")
	m.emission_energy_multiplier = 0.6
	mi.material_override = m
	mi.rotation.x = PI * 0.5
	add_child(mi)
	area_entered.connect(_on_area)
	body_entered.connect(_on_body)

func launch(from: Vector3, v: Vector3) -> void:
	global_position = from
	vel = v
	look_at(from + v, Vector3.UP)

func _physics_process(dt: float) -> void:
	if done:
		return
	var s: float = TimeDilation.scale(false)
	vel.y -= 2.0 * dt * s
	global_position += vel * dt * s
	if vel.length() > 0.1:
		look_at(global_position + vel, Vector3.UP)
	life -= dt * s
	if life <= 0.0:
		queue_free()

func _on_area(a: Area3D) -> void:
	if done:
		return
	var target: Node3D = a.get_meta("actor", null) as Node3D
	if target == null or target == shooter or target.get("team") == "enemy":
		return
	done = true
	var info: Dictionary = {"damage": damage, "plane": "thrust", "hitstop_f": 4, "shake": 0.3, "stagger_f": 0,
		"knockback": 1.5, "heavy": false, "attacker": shooter, "from": global_position - vel.normalized(), "id": "arrow"}
	var r: String = target.take_hit(info)
	if r == "hit" or r == "guard":
		CombatFx.spark(get_tree(), global_position, Color("ffd27a"), 14)
		CombatFx.sound(get_tree(), "hit", -6.0)
		CombatFx.shake(get_tree(), 0.3)
	if r == "dodge":
		done = false
		return
	queue_free()

func _on_body(b: Node3D) -> void:
	if b is StaticBody3D:
		done = true
		queue_free()
