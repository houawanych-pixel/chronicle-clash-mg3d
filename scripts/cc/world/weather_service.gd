extends Node
## Autoload WeatherService (first cut: flags other systems read; the climate rolls come with
## the World Chemistry block).

signal weather_changed(is_precipitating: bool, is_thundering: bool, wind_vec: Vector3)

var is_precipitating: bool = false
var is_thundering: bool = false
var wind_vec: Vector3 = Vector3(1, 0, 0) * 2.0

func set_weather(rain: bool, thunder: bool = false, wind: Vector3 = Vector3.INF) -> void:
	is_precipitating = rain
	is_thundering = thunder
	if wind != Vector3.INF:
		wind_vec = wind
	weather_changed.emit(is_precipitating, is_thundering, wind_vec)
