extends Area3D
## A thrown weapon: spins through the air, hits the first foe for double damage and breaks
## (unless the weapon survives throws, then it drops to the ground).

var thrower: Node3D
var damage: float = 20.0
var weapon_id: String = ""
var life: float = 1.0
var keeps: bool = false
var vel: Vector3 = Vector3.ZERO
var done: bool = false
var t: float = 0.0
var mesh: MeshInstance3D
var hit_target: Node3D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 16 | 1
	var cs: CollisionShape3D = CollisionShape3D.new()
	var s: SphereShape3D = SphereShape3D.new()
	s.radius = 0.35
	cs.shape = s
	add_child(cs)
	area_entered.connect(_on_area)
	body_entered.connect(_on_body)

func launch(from: Vector3, v: Vector3, length: float) -> void:
	global_position = from
	vel = v
	mesh = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.08, maxf(length, 0.3), 0.03)
	mesh.mesh = bm
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color("dfe6f0")
	m.metallic = 0.8
	mesh.material_override = m
	add_child(mesh)

func _physics_process(dt: float) -> void:
	if done:
		return
	t += dt
	vel.y -= 6.0 * dt
	global_position += vel * dt
	mesh.rotation.x += dt * 20.0
	if t > 2.5:
		queue_free()

func _on_area(a: Area3D) -> void:
	if done:
		return
	var target: Node3D = a.get_meta("actor", null) as Node3D
	if target == null or target == thrower or target.get("team") == "player":
		return
	done = true
	hit_target = target
	var info: Dictionary = {"damage": damage, "plane": "thrust", "hitstop_f": 6, "shake": 0.45, "stagger_f": 30,
		"knockback": 3.0, "heavy": true, "attacker": thrower, "from": global_position - vel.normalized(), "id": "throw"}
	target.take_hit(info)
	CombatFx.spark(get_tree(), global_position, Color("ffffff"), 26)
	CombatFx.sound(get_tree(), "hit", -2.0)
	CombatFx.shake(get_tree(), 0.45)
	queue_free()

func _on_body(b: Node3D) -> void:
	if done or b == thrower or b is CharacterBody3D:
		return
	done = true
	queue_free()
