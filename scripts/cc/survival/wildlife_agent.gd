extends CharacterBody3D
## CC wildlife: Idle -> Graze -> Alert -> Flee -> Dead.
## Awareness (0..1) builds when it sees the threat (cone x sight range; sneaking shrinks the
## range) or hears it (hearing range x noise). Alert = it stops and stares; full awareness
## or a loud close approach = it bolts. Hits on an unaware animal and head hits do extra
## damage. On death its drop table rolls straight into the inventory (an unaware kill gets
## bonus rolls).

signal state_changed(state: String)
signal died(species: String, drops: Dictionary, stealth: bool)

const CCData = preload("res://scripts/cc/survival/cc_data.gd")
const GRAVITY: float = 20.0

@export var species: String = "mossback_doe"
@export var wander_radius: float = 6.0

var data: Dictionary = {}
var state: String = "idle"
var state_t: float = 0.0
var state_len: float = 2.0
var awareness: float = 0.0
var hp: float = 10.0
var threat: Node3D
var noise_fn: Callable = func() -> float: return 0.5   # threat's noise now, 0 (still) .. 1 (loud)
var home: Vector3
var target: Vector3
var yaw: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var body_root: Node3D
var head: Node3D
var size: float = 1.0
var killed_unaware: bool = false

static var _species: Dictionary = {}
static var _drops: Dictionary = {}

static func species_db() -> Dictionary:
	if _species.is_empty():
		_species = CCData.load_json("res://data/cc/wildlife.json")
	return _species

static func drop_db() -> Dictionary:
	if _drops.is_empty():
		_drops = CCData.load_json("res://data/cc/drop_tables.json")
	return _drops

func _ready() -> void:
	data = species_db().get(species, {})
	hp = float(data.get("hp", 10))
	size = float(data.get("size", 1.0))
	rng.seed = hash(str(global_position) + species)
	home = global_position
	target = home
	yaw = rng.randf() * TAU
	add_to_group("cc_wildlife")
	build_body()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.32 * size
	cap.height = maxf(1.1 * size, cap.radius * 2.0 + 0.01)
	cs.shape = cap
	cs.rotation.x = PI * 0.5
	cs.position.y = 0.75 * size
	add_child(cs)
	floor_snap_length = 0.4
	set_state("idle", rng.randf_range(1.0, 3.0))

## Body from rounded, stretched pieces: barrel body, neck, head, four tapered legs.
func build_body() -> void:
	var col: Color = Color(str(data.get("color", "8a6a46")))
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
	var dark: StandardMaterial3D = StandardMaterial3D.new()
	dark.albedo_color = col.darkened(0.45)
	body_root = Node3D.new()
	body_root.scale = Vector3.ONE * size
	add_child(body_root)
	var torso: MeshInstance3D = blob(Vector3(0.36, 0.34, 0.62), m)
	torso.position = Vector3(0, 0.82, 0)
	body_root.add_child(torso)
	var neck: MeshInstance3D = blob(Vector3(0.14, 0.3, 0.14), m)
	neck.position = Vector3(0, 1.08, -0.5)
	neck.rotation.x = -0.6
	body_root.add_child(neck)
	head = Node3D.new()
	head.position = Vector3(0, 1.32, -0.68)
	body_root.add_child(head)
	var skull: MeshInstance3D = blob(Vector3(0.15, 0.15, 0.24), m)
	head.add_child(skull)
	var nose: MeshInstance3D = blob(Vector3(0.07, 0.07, 0.07), dark)
	nose.position = Vector3(0, -0.03, -0.22)
	head.add_child(nose)
	for s: float in [-1.0, 1.0]:
		var ear: MeshInstance3D = blob(Vector3(0.04, 0.12, 0.03), dark)
		ear.position = Vector3(0.1 * s, 0.14, 0.05)
		ear.rotation.z = -0.4 * s
		head.add_child(ear)
	for p: Vector3 in [Vector3(-0.2, 0, -0.38), Vector3(0.2, 0, -0.38), Vector3(-0.2, 0, 0.4), Vector3(0.2, 0, 0.4)]:
		var leg: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 0.07
		cm.bottom_radius = 0.035
		cm.height = 0.62
		cm.radial_segments = 6
		leg.mesh = cm
		leg.material_override = m
		leg.position = p + Vector3(0, 0.33, 0)
		leg.name = "Leg"
		body_root.add_child(leg)

func blob(r: Vector3, m: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.scale = r
	mi.material_override = m
	return mi

func head_position() -> Vector3:
	return head.global_position

func set_state(s: String, length: float = 0.0) -> void:
	if s == state and length <= 0.0:
		return
	state = s
	state_t = 0.0
	state_len = length
	state_changed.emit(s)

func alive() -> bool:
	return state != "dead"

func unaware() -> bool:
	return state in ["idle", "graze"] and awareness < 0.35

# ---------------------------------------------------------------- senses

func sense(dt: float) -> void:
	if threat == null or not is_instance_valid(threat):
		awareness = maxf(0.0, awareness - dt * 0.25)
		return
	var noise: float = clampf(float(noise_fn.call()), 0.0, 1.0)
	var to: Vector3 = threat.global_position - global_position
	to.y = 0.0
	var d: float = to.length()
	var fwd: Vector3 = Vector3(-sin(yaw), 0, -cos(yaw))
	var sight: float = float(data.get("sight", 12.0)) * lerpf(0.4, 1.0, noise)
	var half: float = deg_to_rad(float(data.get("sight_half", 60.0)))
	var sees: bool = d < sight and (d < 0.01 or fwd.angle_to(to) < half)
	var hears: bool = d < float(data.get("hearing", 10.0)) * noise
	var shy: float = float(data.get("shy", 1.0))
	if sees or hears:
		var gain: float = (0.9 if sees else 0.0) + (1.4 * noise if hears else 0.0)
		gain *= 1.0 + clampf(1.0 - d / maxf(sight, 1.0), 0.0, 1.0)   # closer = faster
		awareness = minf(1.0, awareness + gain * shy * dt)
	else:
		awareness = maxf(0.0, awareness - dt * (0.25 if state != "flee" else 0.08))

# ---------------------------------------------------------------- brain

func _physics_process(dt: float) -> void:
	state_t += dt
	if not is_on_floor():
		velocity.y -= GRAVITY * dt
	else:
		velocity.y = -0.5
	if state == "dead":
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * dt)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * dt)
		body_root.rotation.z = move_toward(body_root.rotation.z, PI * 0.5, dt * 4.0)
		move_and_slide()
		return
	sense(dt)
	var speed: float = 0.0
	match state:
		"idle":
			if state_t > state_len:
				if rng.randf() < 0.55:
					set_state("graze", rng.randf_range(2.5, 5.0))
				else:
					var a: float = rng.randf() * TAU
					target = home + Vector3(cos(a), 0, sin(a)) * rng.randf_range(1.0, wander_radius)
					set_state("walk", 6.0)
		"graze":
			if state_t > state_len:
				set_state("idle", rng.randf_range(1.0, 3.0))
		"walk":
			var to: Vector3 = target - global_position
			to.y = 0.0
			if to.length() < 0.5 or state_t > state_len:
				set_state("idle", rng.randf_range(1.0, 3.0))
			else:
				face(to, dt, 3.0)
				speed = float(data.get("walk", 1.2))
		"alert":
			if threat != null:
				face(threat.global_position - global_position, dt, 6.0)
			if awareness < 0.2:
				set_state("idle", 1.0)
		"flee":
			if threat != null:
				var away: Vector3 = global_position - threat.global_position
				away.y = 0.0
				face(away, dt, 8.0)
				speed = float(data.get("run", 7.0))
				if away.length() > float(data.get("sight", 12.0)) * 2.2 and state_t > 3.0:
					home = global_position
					awareness = 0.3
					set_state("alert", 0.0)
			elif state_t > 5.0:
				set_state("idle", 1.0)
	if state in ["idle", "graze", "walk"] and awareness >= 0.35:
		set_state("alert", 0.0)
	if state == "alert" and awareness >= 1.0:
		set_state("flee", 0.0)
	if state != "flee" and threat != null and awareness > 0.6:
		var d: float = (threat.global_position - global_position).length()
		if d < 3.0:
			set_state("flee", 0.0)
	var fwd: Vector3 = Vector3(-sin(yaw), 0, -cos(yaw))
	velocity.x = fwd.x * speed
	velocity.z = fwd.z * speed
	move_and_slide()
	rotation.y = yaw
	animate(speed)

func face(dir: Vector3, dt: float, rate: float) -> void:
	if dir.length() < 0.01:
		return
	var want: float = atan2(-dir.x, -dir.z)
	yaw = lerp_angle(yaw, want, 1.0 - exp(-rate * dt))

func animate(speed: float) -> void:
	var t: float = Time.get_ticks_msec() * 0.001
	var k: float = 0.0
	if speed > 0.1:
		k = clampf(speed / 6.0, 0.25, 1.0)
	var i: int = 0
	for c: Node in body_root.get_children():
		if c.name.begins_with("Leg"):
			var ph: float = t * (6.0 + speed * 1.6) + (PI if i % 2 == 0 else 0.0) + (PI * 0.5 if i >= 2 else 0.0)
			(c as Node3D).rotation.x = sin(ph) * 0.6 * k
			i += 1
	var graze: float = 1.0 if state == "graze" else 0.0
	head.position.y = lerpf(head.position.y, lerpf(1.32, 0.55, graze), 0.1)
	head.rotation.x = lerpf(head.rotation.x, 0.9 * graze, 0.1)

# ---------------------------------------------------------------- damage and drops

## A hit. part = "head" or "body". Returns damage dealt.
func take_hit(dmg: float, part: String, from_pos: Vector3) -> float:
	if not alive():
		return 0.0
	var was_unaware: bool = unaware()
	var d: float = dmg
	if part == "head":
		d *= float(data.get("headshot_mult", 2.0))
	if was_unaware:
		d *= float(data.get("unaware_mult", 2.0))
	hp -= d
	if hp <= 0.0:
		die(was_unaware)
	else:
		awareness = 1.0
		if threat == null:
			var tn: Node3D = Node3D.new()
			add_child(tn)
			tn.global_position = from_pos
			threat = tn
		set_state("flee", 0.0)
	return d

func die(stealth: bool) -> void:
	killed_unaware = stealth
	set_state("dead", 0.0)
	var drops: Dictionary = roll_drops(str(data.get("drops", species)), stealth, rng)
	for item: String in drops:
		InventoryService.add(item, int(drops[item]))
	died.emit(species, drops, stealth)

static func roll_drops(table_id: String, stealth: bool, r: RandomNumberGenerator) -> Dictionary:
	var t: Dictionary = drop_db().get(table_id, {})
	var out: Dictionary = {}
	var rolls: int = int(t.get("rolls", 1)) + (int(t.get("stealth_bonus_rolls", 0)) if stealth else 0)
	for i in rolls:
		for e: Dictionary in t.get("entries", []):
			if r.randf() <= float(e.get("chance", 1.0)):
				var n: int = r.randi_range(int(e.get("min", 1)), int(e.get("max", 1)))
				out[e.item] = int(out.get(e.item, 0)) + n
	return out
