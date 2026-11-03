extends Resource
## One kind of tree (data for CC tree cutting). How much chopping it takes, what it leaves,
## and how it looks. chop_mult scales a tool's power by its kind: 0 means that kind can't cut it.

@export var id: String = "oak"
@export var display_name: String = "Oak"
@export var hp: float = 30.0
@export var chop_mult: Dictionary = {"axe": 1.0, "blade": 0.4, "blunt": 0.0}
@export var wood_item: String = "oak_wood"
@export var wood_min: int = 2
@export var wood_max: int = 3
@export var trunk_height: float = 4.2
@export var trunk_radius: float = 0.28
@export var stump_height: float = 0.45
@export var canopy_radius: float = 1.7
@export var log_mass: float = 60.0
@export var bark_color: Color = Color("6b4a2e")
@export var leaf_color: Color = Color("4f8f3a")
