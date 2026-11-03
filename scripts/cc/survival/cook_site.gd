extends Node3D
## A place to cook: with a pot it cooks meals (buffs possible); a bare campfire only roasts.

signal meal_ready(meal: Dictionary)

@export var has_pot: bool = true
var fire: OmniLight3D

func _ready() -> void:
	add_to_group("cc_cook_site")
	build()

func method() -> String:
	return "pot" if has_pot else "roast"

## Cook these ingredient ids from the inventory. Empty dict = not enough / refused.
func cook(ids: Array) -> Dictionary:
	var meal: Dictionary = CookingService.cook_from_inventory(ids, method())
	if not meal.is_empty():
		meal_ready.emit(meal)
	return meal

func build() -> void:
	var stone: StandardMaterial3D = StandardMaterial3D.new()
	stone.albedo_color = Color("77746e")
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_color = Color("6b4a2e")
	var flame: StandardMaterial3D = StandardMaterial3D.new()
	flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame.albedo_color = Color("ffb347")
	for i in 8:
		var a: float = i * TAU / 8.0
		var s: MeshInstance3D = MeshInstance3D.new()
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.22
		s.mesh = sm
		s.material_override = stone
		s.position = Vector3(cos(a) * 0.55, 0.08, sin(a) * 0.55)
		add_child(s)
	for i in 3:
		var l: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 0.06
		cm.bottom_radius = 0.07
		cm.height = 0.8
		l.mesh = cm
		l.material_override = wood
		l.rotation = Vector3(PI * 0.5, i * PI / 3.0, 0)
		l.position.y = 0.1
		add_child(l)
	var f: MeshInstance3D = MeshInstance3D.new()
	var fm: SphereMesh = SphereMesh.new()
	fm.radius = 0.2
	fm.height = 0.55
	f.mesh = fm
	f.material_override = flame
	f.position.y = 0.3
	add_child(f)
	fire = OmniLight3D.new()
	fire.light_color = Color("ffb347")
	fire.light_energy = 1.2
	fire.omni_range = 5.0
	fire.position.y = 0.6
	add_child(fire)
	if has_pot:
		var iron: StandardMaterial3D = StandardMaterial3D.new()
		iron.albedo_color = Color("2b2b30")
		iron.metallic = 0.6
		iron.roughness = 0.5
		var pot: MeshInstance3D = MeshInstance3D.new()
		var pm: SphereMesh = SphereMesh.new()
		pm.radius = 0.42
		pm.height = 0.62
		pm.is_hemisphere = false
		pot.mesh = pm
		pot.material_override = iron
		pot.position.y = 0.62
		add_child(pot)
		for s2: float in [-1.0, 1.0]:
			var leg: MeshInstance3D = MeshInstance3D.new()
			var lm: CylinderMesh = CylinderMesh.new()
			lm.top_radius = 0.03
			lm.bottom_radius = 0.03
			lm.height = 1.1
			leg.mesh = lm
			leg.material_override = iron
			leg.position = Vector3(0.55 * s2, 0.55, 0)
			add_child(leg)
