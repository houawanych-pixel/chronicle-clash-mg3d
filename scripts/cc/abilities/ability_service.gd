extends Node
## Autoload AbilityService: one power active at a time (ABILITY cycles, USE uses it).
##   Blast Orb (Sphere / Cube): first USE places an orb in front (a sphere rolls, a cube
##   stays put), the next USE sets it off. Reload starts after the blast (2.5 s / 3.5 s).
##   Frost Pillar: USE raises an ice pillar from the nearest water ahead (up to 3; a 4th
##   breaks the oldest). Pillars block movement and melt next to fire.

signal changed

const BlastOrb = preload("res://scripts/cc/abilities/blast_orb.gd")
const FrostPillar = preload("res://scripts/cc/abilities/frost_pillar.gd")
const ORDER: Array[String] = ["orb_sphere", "orb_cube", "frost_pillar"]

var tuning: Resource
var active: String = "orb_sphere"
var reload: Dictionary = {"orb_sphere": 0.0, "orb_cube": 0.0, "frost_pillar": 0.0}
var orbs: Dictionary = {}       # kind -> live orb (placed, not yet blown)
var pillars: Array = []
var blasts: int = 0

func _ready() -> void:
	tuning = load("res://data/cc/abilities/ability_tuning.tres")

func display_name(id: String) -> String:
	return str(tuning.names.get(id, id))

func reset() -> void:
	for k: String in orbs:
		if is_instance_valid(orbs[k]):
			(orbs[k] as Node).queue_free()
	orbs.clear()
	for p: Variant in pillars:
		if is_instance_valid(p):
			(p as Node).queue_free()
	pillars.clear()
	for k: String in reload:
		reload[k] = 0.0
	active = "orb_sphere"

func cycle() -> void:
	active = ORDER[(ORDER.find(active) + 1) % ORDER.size()]
	changed.emit()

func _process(dt: float) -> void:
	for k: String in reload:
		reload[k] = maxf(0.0, float(reload[k]) - dt)
	pillars = pillars.filter(func(p: Variant) -> bool: return is_instance_valid(p))

func ready_frac(id: String) -> float:
	var full: float = float(tuning.sphere_reload_s) if id == "orb_sphere" else (float(tuning.cube_reload_s) if id == "orb_cube" else float(tuning.pillar_cooldown_s))
	return 1.0 - clampf(float(reload[id]) / full, 0.0, 1.0)

## Use the active power for this user (the player). Returns what happened.
func use(user: Node3D) -> String:
	match active:
		"orb_sphere", "orb_cube":
			var live: Variant = orbs.get(active, null)
			if live != null and is_instance_valid(live):
				(live as Node).explode()
				return "detonated"
			if float(reload[active]) > 0.0:
				return "reloading"
			var o: RigidBody3D = BlastOrb.new()
			o.kind = active
			user.get_parent().add_child(o)
			o.global_position = user.global_position + user.forward() * 1.2 + Vector3.UP * 1.0
			o.linear_velocity = user.forward() * (3.0 if active == "orb_sphere" else 1.0) + Vector3.UP * 1.5
			o.exploded.connect(_on_orb_exploded.bind(active))
			orbs[active] = o
			return "placed"
		"frost_pillar":
			if float(reload.frost_pillar) > 0.0:
				return "reloading"
			var at: Vector3 = water_point(user)
			if at == Vector3.INF:
				return "no water"
			var p: StaticBody3D = FrostPillar.new()
			user.get_parent().add_child(p)
			p.raise_at(at)
			pillars.append(p)
			while pillars.size() > int(tuning.pillar_max):
				var old: Variant = pillars.pop_front()
				if is_instance_valid(old):
					(old as Node).shatter()
			reload.frost_pillar = float(tuning.pillar_cooldown_s)
			return "pillar"
	return ""

func _on_orb_exploded(kind: String) -> void:
	orbs.erase(kind)
	blasts += 1
	reload[kind] = float(tuning.sphere_reload_s) if kind == "orb_sphere" else float(tuning.cube_reload_s)

## The nearest water surface point straight ahead of the user (within range).
func water_point(user: Node3D) -> Vector3:
	var f: Vector3 = user.forward()
	var d: float = 1.5
	while d <= float(tuning.pillar_range):
		var p: Vector3 = user.global_position + f * d
		for w: Node in user.get_tree().get_nodes_in_group("cc_water"):
			if w.contains(Vector3(p.x, w.surface_y(), p.z)):
				return Vector3(p.x, w.surface_y(), p.z)
		d += 0.5
	return Vector3.INF
