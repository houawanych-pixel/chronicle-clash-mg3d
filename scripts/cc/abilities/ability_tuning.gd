extends Resource
## CC powers (names are mandatory: Blast Orbs, Frost Pillar; Iron Grasp and Time Pin later).

@export var names: Dictionary = {"orb_sphere": "Blast Orb (Sphere)", "orb_cube": "Blast Orb (Cube)", "frost_pillar": "Frost Pillar"}
@export var orb_radius: float = 4.0
@export var orb_damage: float = 30.0
@export var orb_impulse: float = 9.0          # m/s at the centre, falls off to 0 at the edge
@export var sphere_reload_s: float = 2.5
@export var cube_reload_s: float = 3.5
@export var orb_fire_chance: float = 0.6       # each grass cell in the inner blast catches with this chance
@export var pillar_max: int = 3
@export var pillar_hp: int = 3
@export var pillar_size: Vector3 = Vector3(1.4, 2.6, 1.4)
@export var pillar_range: float = 12.0
@export var pillar_min_scale: float = 0.15
@export var pillar_cooldown_s: float = 0.6
