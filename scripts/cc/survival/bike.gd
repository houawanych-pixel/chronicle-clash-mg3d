extends CharacterBody3D
## Stormrunner, the CC motorcycle (arcade handling, tuning in res://data/cc/bike_tuning.tres).
## Inputs each frame: throttle 0..1, brake 0..1, steer -1..1 (right = +), jump (tap),
## drift (hold), wheelie (hold).
## Fuel (0..100 %) drains only while the throttle is open AND the wheels are on the ground;
## a full tank lasts tank_seconds at full throttle. Empty = no drive, it just coasts.
## Refuel with up to refuel_max_items items (values in res://data/cc/fuel.json), capped at 100.
## Drifts start only above drift_enter_speed and end below drift_exit_speed.

signal fuel_changed(fuel: float)
signal out_of_fuel
signal drift_started
signal drift_ended
signal jumped

const CCData = preload("res://scripts/cc/survival/cc_data.gd")
const TUNING_PATH: String = "res://data/cc/bike_tuning.tres"
const FUEL_PATH: String = "res://data/cc/fuel.json"
const GRAVITY: float = 20.0

var tuning: Resource
var fuel_values: Dictionary = {}
var fuel: float = 100.0
var speed: float = 0.0          # forward speed along the travel direction
var yaw: float = 0.0            # where the bike points
var travel_yaw: float = 0.0     # where it is going (differs while drifting)
var drifting: bool = false
var wheelie_t: float = 0.0
var wheelie_lock: bool = false
var jump_cd: float = 0.0
var grounded_override: int = -1  # tests: -1 = real floor check, 0 = air, 1 = ground
var _empty_said: bool = false
# input
var throttle: float = 0.0
var brake: float = 0.0
var steer: float = 0.0
var jump: bool = false
var drift: bool = false
var wheelie: bool = false
# look
var frame_root: Node3D
var front_wheel: Node3D
var rear_wheel: Node3D

func _ready() -> void:
	tuning = load(TUNING_PATH)
	fuel_values = CCData.load_json(FUEL_PATH)
	add_to_group("cc_bike")
	travel_yaw = yaw
	var cs: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.9
	cs.shape = cap
	cs.rotation.x = PI * 0.5
	cs.position.y = 0.45
	add_child(cs)
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(50)
	build_body()

func grounded() -> bool:
	if grounded_override >= 0:
		return grounded_override == 1
	return is_on_floor()

# ---------------------------------------------------------------- fuel

## Burn fuel for dt seconds. Only with the throttle open on the ground. Returns % used.
func fuel_tick(dt: float, thr: float, on_ground: bool) -> float:
	if thr <= 0.0 or not on_ground or fuel <= 0.0:
		return 0.0
	var use: float = minf(fuel, 100.0 * thr * dt / float(tuning.tank_seconds))
	fuel -= use
	fuel_changed.emit(fuel)
	if fuel <= 0.0 and not _empty_said:
		_empty_said = true
		out_of_fuel.emit()
	return use

## How much a list of items would add (%). Unknown items add nothing.
func refuel_value(ids: Array) -> float:
	var v: float = 0.0
	for id: String in ids:
		v += float(fuel_values.get(id, 0.0))
	return v

## Refuel from the inventory. Returns the % actually added (0 if refused).
func refuel(ids: Array) -> float:
	if ids.is_empty() or ids.size() > int(tuning.refuel_max_items):
		return 0.0
	for id: String in ids:
		if not fuel_values.has(id):
			return 0.0
	if not InventoryService.take_all(ids):
		return 0.0
	var before: float = fuel
	fuel = minf(100.0, fuel + refuel_value(ids))
	if fuel > 0.0:
		_empty_said = false
	fuel_changed.emit(fuel)
	return fuel - before

# ---------------------------------------------------------------- handling

## Drift rules, on their own so they can be checked: returns whether it is drifting now.
func drift_tick(on_ground: bool) -> bool:
	var want: bool = drift and on_ground and absf(steer) > 0.2
	if not drifting and want and speed >= float(tuning.drift_enter_speed):
		drifting = true
		drift_started.emit()
	elif drifting and (not drift or speed <= float(tuning.drift_exit_speed) or not on_ground):
		drifting = false
		drift_ended.emit()
	return drifting

func _physics_process(dt: float) -> void:
	step(dt)

func step(dt: float) -> void:
	var t: Resource = tuning
	var on_ground: bool = grounded()
	jump_cd = maxf(0.0, jump_cd - dt)
	# drive
	var drive: bool = throttle > 0.0 and on_ground and fuel > 0.0
	fuel_tick(dt, throttle, on_ground)
	if drive:
		speed += float(t.accel) * throttle * dt
	elif on_ground:
		speed = move_toward(speed, 0.0, float(t.coast_drag) * dt)
	if brake > 0.0 and on_ground:
		speed = move_toward(speed, 0.0, float(t.brake) * brake * dt)
	speed = clampf(speed, 0.0, float(t.max_speed))
	# steer (needs some speed; tighter when slow)
	drift_tick(on_ground)
	var k: float = clampf(speed / float(t.max_speed), 0.0, 1.0)
	var rate: float = lerpf(float(t.steer_rate), float(t.steer_high_speed), k)
	if drifting:
		rate *= float(t.drift_steer_mult)
		speed = move_toward(speed, 0.0, 1.5 * dt)
	var roll_in: float = clampf(speed / 2.0, 0.0, 1.0)
	if on_ground:
		yaw -= steer * rate * roll_in * dt
	# travel follows the heading; in a drift it lags behind (the rear slides out)
	var follow: float = 1.0 - exp(-(2.0 if drifting else 14.0) * (1.0 - (float(t.drift_slip) if drifting else 0.0)) * dt)
	travel_yaw = lerp_angle(travel_yaw, yaw, follow)
	# wheelie
	if wheelie_t > 0.0:
		wheelie_t -= dt
		if wheelie_t <= 0.0 or not wheelie:
			wheelie_t = 0.0
	elif wheelie and not wheelie_lock and throttle > 0.0 and on_ground and speed >= float(t.wheelie_min_speed) and fuel > 0.0:
		wheelie_t = float(t.wheelie_time)
		wheelie_lock = true
	if not wheelie:
		wheelie_lock = false
	# jump
	if jump and on_ground and jump_cd <= 0.0:
		velocity.y = float(t.jump_speed)
		jump_cd = float(t.jump_interval)
		jumped.emit()
	jump = false
	if not on_ground:
		velocity.y -= GRAVITY * dt
	elif velocity.y <= 0.0:
		velocity.y = -1.0
	var dir: Vector3 = Vector3(-sin(travel_yaw), 0, -cos(travel_yaw))
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if is_inside_tree():
		move_and_slide()
		if get_slide_collision_count() > 0:
			for i in get_slide_collision_count():
				var n: Vector3 = get_slide_collision(i).get_normal()
				if n.y < 0.5 and n.dot(dir) < -0.6:
					speed *= 0.4     # hit a wall
	rotation.y = yaw
	animate(dt)

func wheelie_on() -> bool:
	return wheelie_t > 0.0

func speed_kph() -> float:
	return speed * 3.6

# ---------------------------------------------------------------- summon

## Why the bike can't be summoned at a point ("" = it can). Zones are nodes in group
## "cc_zone" with a tag and a radius (summon_zone.gd).
static func summon_block_reason(tree: SceneTree, at: Vector3, deny: Array) -> String:
	for z: Node in tree.get_nodes_in_group("cc_zone"):
		var zone: Node3D = z as Node3D
		if zone == null:
			continue
		var tag: String = str(zone.get("tag"))
		if not deny.has(tag):
			continue
		var d: Vector3 = at - zone.global_position
		d.y = 0.0
		if d.length() <= float(zone.get("radius")):
			return tag
	return ""

# ---------------------------------------------------------------- look

func build_body() -> void:
	frame_root = Node3D.new()
	add_child(frame_root)
	var paint: StandardMaterial3D = StandardMaterial3D.new()
	paint.albedo_color = Color("2e6f8e")
	paint.metallic = 0.5
	paint.roughness = 0.35
	var metal: StandardMaterial3D = StandardMaterial3D.new()
	metal.albedo_color = Color("c9c2b0")
	metal.metallic = 0.8
	metal.roughness = 0.3
	var tyre: StandardMaterial3D = StandardMaterial3D.new()
	tyre.albedo_color = Color("1d1d22")
	tyre.roughness = 0.9
	var seat: StandardMaterial3D = StandardMaterial3D.new()
	seat.albedo_color = Color("5a3a26")
	var glow: StandardMaterial3D = StandardMaterial3D.new()
	glow.albedo_color = Color("ffd27a")
	glow.emission_enabled = true
	glow.emission = Color("ffb347")
	glow.emission_energy_multiplier = 1.5
	front_wheel = wheel(Vector3(0, 0.36, -0.78), tyre, metal)
	rear_wheel = wheel(Vector3(0, 0.36, 0.72), tyre, metal)
	# swept body: a long teardrop tank, tail and nose cowl
	var tank: MeshInstance3D = shaped(Vector3(0.2, 0.17, 0.62), paint)
	tank.position = Vector3(0, 0.82, -0.12)
	tank.rotation.x = 0.12
	frame_root.add_child(tank)
	var tail: MeshInstance3D = shaped(Vector3(0.15, 0.08, 0.42), paint)
	tail.position = Vector3(0, 0.88, 0.5)
	tail.rotation.x = -0.25
	frame_root.add_child(tail)
	var cowl: MeshInstance3D = shaped(Vector3(0.18, 0.2, 0.22), paint)
	cowl.position = Vector3(0, 0.95, -0.66)
	cowl.rotation.x = 0.5
	frame_root.add_child(cowl)
	var lamp: MeshInstance3D = shaped(Vector3(0.07, 0.07, 0.04), glow)
	lamp.position = Vector3(0, 0.95, -0.86)
	frame_root.add_child(lamp)
	var sad: MeshInstance3D = shaped(Vector3(0.15, 0.06, 0.3), seat)
	sad.position = Vector3(0, 0.98, 0.22)
	frame_root.add_child(sad)
	for s: float in [-1.0, 1.0]:
		var fork: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 0.025
		cm.bottom_radius = 0.025
		cm.height = 0.7
		fork.mesh = cm
		fork.material_override = metal
		fork.position = Vector3(0.09 * s, 0.68, -0.7)
		fork.rotation.x = 0.35
		frame_root.add_child(fork)
	var bar: MeshInstance3D = MeshInstance3D.new()
	var bm: CylinderMesh = CylinderMesh.new()
	bm.top_radius = 0.02
	bm.bottom_radius = 0.02
	bm.height = 0.62
	bar.mesh = bm
	bar.material_override = metal
	bar.rotation.z = PI * 0.5
	bar.position = Vector3(0, 1.08, -0.55)
	frame_root.add_child(bar)

func shaped(r: Vector3, m: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 14
	sm.rings = 7
	mi.mesh = sm
	mi.scale = r
	mi.material_override = m
	return mi

func wheel(at: Vector3, tyre: Material, hub: Material) -> Node3D:
	var n: Node3D = Node3D.new()
	n.position = at
	frame_root.add_child(n)
	var t: MeshInstance3D = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = 0.24
	tm.outer_radius = 0.36
	tm.rings = 18
	tm.ring_segments = 8
	t.mesh = tm
	t.material_override = tyre
	t.rotation.z = PI * 0.5
	n.add_child(t)
	var h: MeshInstance3D = MeshInstance3D.new()
	var hm: CylinderMesh = CylinderMesh.new()
	hm.top_radius = 0.1
	hm.bottom_radius = 0.1
	hm.height = 0.12
	h.mesh = hm
	h.material_override = hub
	h.rotation.z = PI * 0.5
	n.add_child(h)
	return n

func animate(dt: float) -> void:
	var spin: float = speed * dt / 0.36
	front_wheel.rotation.x -= spin
	rear_wheel.rotation.x -= spin
	var lean: float = -steer * clampf(speed / 10.0, 0.0, 1.0) * (0.55 if drifting else 0.35)
	frame_root.rotation.z = lerpf(frame_root.rotation.z, lean, 1.0 - exp(-8.0 * dt))
	var pitch: float = deg_to_rad(float(tuning.wheelie_angle)) if wheelie_on() else 0.0
	frame_root.rotation.x = lerpf(frame_root.rotation.x, pitch, 1.0 - exp(-10.0 * dt))
	frame_root.position.z = 0.0
	if wheelie_on():
		frame_root.position = Vector3(0, 0.0, 0.0)
