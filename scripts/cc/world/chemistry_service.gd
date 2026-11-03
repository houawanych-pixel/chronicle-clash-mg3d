extends Node
## Autoload ChemistryService.
##   Fire: grass fields (grass_field.gd) are grids of fuel cells. A burning cell burns its fuel
##   down and lights neighbours; downwind neighbours light far more often (WeatherService
##   wind). Rain puts burning cells out and stops any new spread.
##   Updraft: a fire column lifts an open glider above it (updraft_at()).
##   Lightning: in a thunderstorm, carrying a metal weapon draws a strike: a warning crackle
##   first, then the hit. Wooden gear is safe.
##   Shock: a shock in water reaches electric_water_radius_mult times as far.
##   Heat: frost pillars melt near fire (heat_near()).

signal ignited(field: Node, cells: int)
signal lightning_warn(at: Vector3, target: Node3D)
signal lightning_strike(at: Vector3, target: Node3D)

var tuning: Resource
var fields: Array = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _tick: float = 0.0
var _bolt_t: float = 0.0
var _warn: Dictionary = {}       # {target, t, at}
var strikes: int = 0
var warns: int = 0

func _ready() -> void:
	tuning = load("res://data/cc/chem/world_tuning.tres")
	rng.seed = 42

func register(f: Node) -> void:
	if not f in fields:
		fields.append(f)

func unregister(f: Node) -> void:
	fields.erase(f)

func reset() -> void:
	fields = fields.filter(func(f: Variant) -> bool: return is_instance_valid(f))
	_warn.clear()
	_bolt_t = 0.0
	strikes = 0
	warns = 0

func _physics_process(dt: float) -> void:
	_tick += dt
	while _tick >= float(tuning.tick_s):
		_tick -= float(tuning.tick_s)
		for f: Variant in fields.duplicate():
			if is_instance_valid(f):
				fire_tick(f, float(tuning.tick_s))
			else:
				fields.erase(f)
	lightning_tick(dt)

# ---------------------------------------------------------------- fire

func ignite_at(p: Vector3, radius: float) -> int:
	if WeatherService.is_precipitating:
		return 0
	var n: int = 0
	var r: float = radius + float(tuning.fire_extra_radius)
	for f: Variant in fields:
		if not is_instance_valid(f):
			continue
		var fld: Node = f
		for c: int in fld.cells_within(p, r):
			if fld.state[c] == 0 and fld.fuel[c] > 0.0:
				fld.state[c] = 1
				n += 1
		if n > 0:
			fld.dirty = true
			ignited.emit(fld, n)
	return n

func fire_tick(f: Node, dt: float) -> void:
	var rain: bool = WeatherService.is_precipitating
	var wind: Vector3 = WeatherService.wind_vec
	var wdir: Vector2 = Vector2(wind.x, wind.z).normalized() if Vector2(wind.x, wind.z).length() > 0.05 else Vector2.ZERO
	var nx: int = f.nx
	var nz: int = f.nz
	var to_light: Array[int] = []
	var any: bool = false
	for c in nx * nz:
		if f.state[c] != 1:
			continue
		any = true
		if rain:
			f.fuel[c] = maxf(0.0, f.fuel[c] - float(tuning.rain_quench_per_s) * dt * 0.2)
			f.state[c] = 0 if f.fuel[c] > 0.0 else 2   # put out
			continue
		f.fuel[c] -= float(tuning.burn_speed_rate) * dt
		if f.fuel[c] <= 0.0:
			f.fuel[c] = 0.0
			f.state[c] = 2
		var cx: int = c % nx
		@warning_ignore("integer_division")
		var cz: int = c / nx
		for dz in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if dx == 0 and dz == 0:
					continue
				var x: int = cx + dx
				var z: int = cz + dz
				if x < 0 or z < 0 or x >= nx or z >= nz:
					continue
				var j: int = z * nx + x
				if f.state[j] != 0 or f.fuel[j] <= 0.0:
					continue
				var d: Vector2 = Vector2(dx, dz).normalized()
				var along: float = d.dot(wdir)
				var k: float = 1.0 + float(tuning.wind_bias) * maxf(0.0, along) - 0.75 * maxf(0.0, -along)
				if rng.randf() < float(tuning.fire_heat_transfer) * k * dt / float(tuning.tick_s) * 0.5:
					to_light.append(j)
	for j: int in to_light:
		f.state[j] = 1
	if any or not to_light.is_empty():
		f.dirty = true

func burning_count() -> int:
	var n: int = 0
	for f: Variant in fields:
		if is_instance_valid(f):
			n += (f as Node).count_state(1)
	return n

func burning_near(p: Vector3, r: float) -> int:
	var n: int = 0
	for f: Variant in fields:
		if not is_instance_valid(f):
			continue
		for c: int in (f as Node).cells_within(p, r):
			if (f as Node).state[c] == 1:
				n += 1
	return n

## Lift for a glider at p from fire columns below it.
func updraft_at(p: Vector3) -> float:
	var best: float = 0.0
	for f: Variant in fields:
		if not is_instance_valid(f):
			continue
		var fld: Node = f
		if p.y - fld.global_position.y > float(tuning.updraft_height):
			continue
		var n: int = 0
		for c: int in fld.cells_within(Vector3(p.x, fld.global_position.y, p.z), 3.0):
			if fld.state[c] == 1:
				n += 1
		best = maxf(best, minf(float(tuning.updraft_max), float(n) * float(tuning.wind_lift_rate)))
	return best

## Heat at p (0 = none): burning cells and fire sources close by.
func heat_near(p: Vector3, r: float = 2.5) -> float:
	var h: float = float(burning_near(p, r)) * 0.2
	for s: Node in get_tree().get_nodes_in_group("cc_fire_source"):
		if (s as Node3D).global_position.distance_to(p) < r + 0.5 and s.get("lit") != false:
			h += 1.0
	return h

# ---------------------------------------------------------------- lightning

func carries_metal(n: Node) -> bool:
	return n.has_method("carries_metal") and n.carries_metal()

func lightning_tick(dt: float) -> void:
	if not WeatherService.is_thundering:
		_warn.clear()
		_bolt_t = 0.0
		return
	if not _warn.is_empty():
		_warn.t = float(_warn.t) - dt
		var tgt: Node3D = _warn.target
		if is_instance_valid(tgt):
			_warn.at = tgt.global_position
		if float(_warn.t) <= 0.0:
			var at: Vector3 = _warn.at
			_warn.clear()
			strike(at, tgt if is_instance_valid(tgt) and carries_metal(tgt) else null)
		return
	_bolt_t += dt
	if _bolt_t < float(tuning.lightning_interval_s):
		return
	_bolt_t = 0.0
	var p: Node3D = get_tree().get_first_node_in_group("cc_player") as Node3D
	var target: Node3D = null
	if p != null and carries_metal(p):
		target = p
	else:
		# a metal prop near the player draws it instead
		var best: float = float(tuning.lightning_distance)
		for m: Node in get_tree().get_nodes_in_group("cc_metal"):
			var mn: Node3D = m as Node3D
			if p != null and mn.global_position.distance_to(p.global_position) < best:
				best = mn.global_position.distance_to(p.global_position)
				target = mn
	if target == null:
		return
	warns += 1
	_warn = {"target": target, "t": float(tuning.lightning_warn_s), "at": target.global_position}
	lightning_warn.emit(target.global_position, target)
	CombatFx.spark(get_tree(), target.global_position + Vector3.UP * 2.2, Color("bfe3ff"), 16)
	CombatFx.sound(get_tree(), "pulse", -10.0)

func strike(at: Vector3, target: Node3D) -> void:
	strikes += 1
	CombatFx.spark(get_tree(), at + Vector3.UP * 1.0, Color("e6f4ff"), 60)
	CombatFx.sound(get_tree(), "explosion", -2.0)
	CombatFx.shake(get_tree(), 0.9)
	if target != null and target.has_method("apply_damage"):
		target.apply_damage(float(tuning.lightning_damage), at + Vector3.UP * 3.0, 0.0)
	ignite_at(at, 1.0)
	if in_water(at):
		shock(at, 1.5, float(tuning.lightning_damage) * 0.5)
	lightning_strike.emit(at, target)

# ---------------------------------------------------------------- shock and water

func in_water(p: Vector3) -> bool:
	for w: Node in get_tree().get_nodes_in_group("cc_water"):
		if w.contains(p):
			return true
	return false

func shock_radius(p: Vector3, radius: float) -> float:
	return radius * (float(tuning.electric_water_radius_mult) if in_water(p) else 1.0)

## A shock at p: hits every fighter within the (water-boosted) radius. Returns the radius used.
func shock(p: Vector3, radius: float, damage: float) -> float:
	var r: float = shock_radius(p, radius)
	for g: String in ["cc_player", "cc_enemy"]:
		for n: Node in get_tree().get_nodes_in_group(g):
			var a: Node3D = n as Node3D
			if a.global_position.distance_to(p) <= r and a.has_method("apply_damage") and a.alive():
				a.apply_damage(damage, p, 1.0)
	CombatFx.spark(get_tree(), p, Color("9fe6ff"), 30)
	return r
