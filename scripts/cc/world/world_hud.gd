extends "res://scripts/cc/combat/combat_hud.gd"
## World-slice HUD: the arena controls plus ABILITY / USE / THROW, a durability bar that
## flashes below 20 %, the active power and its reload, weather debug toggles and the
## bag-full swap prompt.

const EXTRA: Array = [
	{"id": "use", "c": Vector2(1080, 190), "r": 44.0, "label": "USE", "col": Color("6fc8ff")},
	{"id": "ability", "c": Vector2(1195, 190), "r": 40.0, "label": "POWER", "col": Color("6fc8ff")},
	{"id": "throw", "c": Vector2(965, 300), "r": 40.0, "label": "THROW", "col": Color("ffd27a")},
]
const DEBUG: Array = [["rain", "RAIN"], ["thunder", "STORM"], ["omen", "OMEN"], ["clear", "CLEAR"]]

func _ready() -> void:
	super._ready()
	for b: Dictionary in EXTRA:
		buttons.append(b.duplicate())

func debug_rect(i: int) -> Rect2:
	return Rect2(24 + i * 96, 112, 88, 40)

func down(id: int, p: Vector2) -> void:
	if arena.state == "play":
		for i in DEBUG.size():
			if debug_rect(i).has_point(p):
				arena.debug(str(DEBUG[i][0]))
				return
		if arena.swap_offer != "" and Rect2(arena_center_x() - 120, 250, 240, 60).has_point(p):
			arena.do_swap()
			return
	super.down(id, p)

func arena_center_x() -> float:
	return get_viewport_rect().size.x / scale_ui * 0.5

## Flashing when the weapon in hand is under 20 % life.
func durability_flash() -> bool:
	var pl: Node3D = arena.player
	return pl != null and pl.bag_slot >= 0 and pl.weapon_life_frac() < 0.2

func _draw() -> void:
	super._draw()
	if arena.state != "play":
		return
	var pl: Node3D = arena.player
	if pl == null:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * scale_ui)
	var frac: float = pl.weapon_life_frac()
	var col: Color = Color("bfe3ff")
	if durability_flash() and int(Time.get_ticks_msec() / 180) % 2 == 0:
		col = Color("ff4040")
	bar(Vector2(340, 34), 200, frac, col, str(pl.weapon.display_name).to_upper())
	var ab: String = AbilityService.active
	bar(Vector2(340, 74), 200, AbilityService.ready_frac(ab), Color("6fc8ff"), AbilityService.display_name(ab).to_upper())
	for i in DEBUG.size():
		var r: Rect2 = debug_rect(i)
		var on: bool = (DEBUG[i][0] == "rain" and WeatherService.kind in ["rain", "heavy_rain"]) or (DEBUG[i][0] == "thunder" and WeatherService.is_thundering) or (DEBUG[i][0] == "omen" and WorldClock.force_omen)
		draw_rect(r, Color(0.05, 0.15, 0.25, 0.9 if on else 0.6))
		draw_rect(r, Color("5fe3ff") if on else Color(1, 1, 1, 0.4), false, 2.0)
		txt(r.get_center() + Vector2(0, 7), str(DEBUG[i][1]), 18, Color.WHITE)
	txt(Vector2(arena_center_x(), 86), "%s  ·  %d°C  ·  wind %.0f" % [WeatherService.kind.to_upper().replace("_", " "), int(WeatherService.temperature()), WeatherService.wind_vec.length()], 20, Color("dfefff"))
	if arena.warn_t > 0.0:
		txt(Vector2(arena_center_x(), 220), "LIGHTNING!  DROP YOUR METAL", 34, Color("ffe14a"))
	if arena.swap_offer != "":
		var r2: Rect2 = Rect2(arena_center_x() - 120, 250, 240, 60)
		draw_rect(r2, Color(0.1, 0.1, 0.2, 0.9))
		draw_rect(r2, Color("ffd27a"), false, 3.0)
		txt(r2.get_center() + Vector2(0, 9), "BAG FULL: SWAP", 22, Color.WHITE)
