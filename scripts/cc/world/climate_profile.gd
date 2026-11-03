extends Resource
## A climate: weather weights, temperature and how often the weather rerolls.

@export var id: String = "temperate"
@export var weights: Dictionary = {"clear": 50, "cloudy": 20, "rain": 15, "heavy_rain": 5, "snow": 0, "thunder": 10}
@export var temperature_c: float = 18.0
@export var reroll_s: float = 90.0
@export var wind: Vector3 = Vector3(2, 0, 0)
