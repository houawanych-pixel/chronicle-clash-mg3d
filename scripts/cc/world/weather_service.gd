extends Node
## Autoload WeatherService. Climate regions (climate_region.gd, group "cc_climate") hold a
## ClimateProfile; the PLAYER's position picks the region (camera position would be the other
## choice: the player is used so standing in a cold valley under a warm camera still chills).
## Each reroll_s the weather is rolled from the region's weights. Systems read the flags.

signal weather_changed(is_precipitating: bool, is_thundering: bool, wind_vec: Vector3)
signal climate_changed(profile: Resource)

const KINDS: Array[String] = ["clear", "cloudy", "rain", "heavy_rain", "snow", "thunder"]

var kind: String = "clear"
var is_precipitating: bool = false
var is_thundering: bool = false
var is_snowing: bool = false
var wind_vec: Vector3 = Vector3(2, 0, 0)
var climate: Resource
var probe: Node3D            # usually the player
var locked: bool = false     # debug toggles hold the weather
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _t: float = 0.0

func _ready() -> void:
	climate = load("res://data/cc/weather/temperate.tres")
	rng.randomize()

func _process(dt: float) -> void:
	var c: Resource = region_climate()
	if c != climate:
		climate = c
		climate_changed.emit(climate)
		if not locked:
			roll()
	_t += dt
	if not locked and climate != null and _t >= float(climate.reroll_s):
		roll()

func region_climate() -> Resource:
	if probe == null or not is_instance_valid(probe):
		return climate
	var best: Resource = load("res://data/cc/weather/temperate.tres")
	for r: Node in get_tree().get_nodes_in_group("cc_climate"):
		if r.contains(probe.global_position):
			best = r.profile
	return best

func temperature() -> float:
	return float(climate.temperature_c) if climate != null else 18.0

## Roll the weather from the current climate's weights.
func roll() -> String:
	_t = 0.0
	var w: Dictionary = climate.weights
	var total: float = 0.0
	for k: String in KINDS:
		total += float(w.get(k, 0))
	var r: float = rng.randf() * total
	var pick: String = "clear"
	for k: String in KINDS:
		r -= float(w.get(k, 0))
		if r <= 0.0:
			pick = k
			break
	apply(pick, climate.wind)
	return pick

func apply(k: String, wind: Vector3 = Vector3.INF) -> void:
	kind = k
	is_precipitating = k in ["rain", "heavy_rain", "thunder", "snow"]
	is_thundering = k == "thunder"
	is_snowing = k == "snow"
	if wind != Vector3.INF:
		wind_vec = wind
	weather_changed.emit(is_precipitating, is_thundering, wind_vec)

## Old flag setter (kept for the movement tests and debug buttons).
func set_weather(rain: bool, thunder: bool = false, wind: Vector3 = Vector3.INF) -> void:
	apply("thunder" if thunder else ("rain" if rain else "clear"), wind)
