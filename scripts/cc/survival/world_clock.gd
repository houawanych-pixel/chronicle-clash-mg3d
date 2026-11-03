extends Node
## Autoload WorldClock: CC day/night. hour runs 0..24; one in-game minute per real second
## by default. Every OMEN_EVERY days the night turns into an Omen Night (the Ember Moon):
## from 23:30 to 00:15 cooking always crits, and the respawn signal fires at midnight.

signal hour_changed(hour: int)
signal day_changed(day: int)
signal omen_began
signal omen_midnight

const OMEN_EVERY: int = 7
const OMEN_START: float = 23.5
const OMEN_END: float = 0.25

var hour: float = 6.0
var day: int = 1
var minutes_per_second: float = 1.0
var paused: bool = false
var force_omen: bool = false     # tests and events can force an Omen Night
var _omen_on: bool = false

func _process(dt: float) -> void:
	if paused:
		return
	advance(dt * minutes_per_second / 60.0)

## Move the clock forward by some hours (signals fire on the way).
func advance(hours: float) -> void:
	var before: int = int(floor(hour))
	hour += hours
	while hour >= 24.0:
		hour -= 24.0
		day += 1
		day_changed.emit(day)
		if is_omen_day(day - 1) or is_omen_day(day):
			omen_midnight.emit()
	if int(floor(hour)) != before:
		hour_changed.emit(int(floor(hour)))
	var on: bool = is_omen_night()
	if on and not _omen_on:
		omen_began.emit()
	_omen_on = on

func is_omen_day(d: int) -> bool:
	return d > 0 and d % OMEN_EVERY == 0

## True during the Omen Night window: the late evening of an omen day, or the first
## minutes after its midnight.
func is_omen_night() -> bool:
	if force_omen:
		return true
	if hour >= OMEN_START and is_omen_day(day):
		return true
	if hour < OMEN_END and is_omen_day(day - 1):
		return true
	return false

func is_night() -> bool:
	return hour >= 20.0 or hour < 5.0

func set_time(d: int, h: float) -> void:
	day = d
	hour = fposmod(h, 24.0)
	_omen_on = is_omen_night()

func to_save() -> Dictionary:
	return {"hour": hour, "day": day}

func from_save(d: Dictionary) -> void:
	set_time(int(d.get("day", 1)), float(d.get("hour", 6.0)))
