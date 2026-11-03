extends Node
## Spaces enemies round the player and paces their attacks.
## Melee foes take evenly spaced slots on a ring (radius = their keep distance); archers use
## their own wider ring. Slots keep each foe near the angle it already has, so when one dies
## the rest slide round the ring instead of stepping in. Only max_attackers melee foes may
## be attacking at once, with a short global gap between turns.

@export var max_attackers: int = 1
@export var turn_gap_s: float = 0.6

var attackers: Array = []
var _gap: float = 0.0
var _slots: Dictionary = {}   # enemy -> angle
var _recalc: float = 0.0

func _ready() -> void:
	add_to_group("cc_tactics")

func _physics_process(dt: float) -> void:
	_gap = maxf(0.0, _gap - dt * TimeDilation.scale(false))
	_recalc -= dt
	if _recalc <= 0.0:
		_recalc = 0.25
		assign()
	var keep: Array = []
	for a: Variant in attackers:
		if is_instance_valid(a) and (a as Node).alive():
			keep.append(a)
	attackers = keep

func player() -> Node3D:
	return get_tree().get_first_node_in_group("cc_player") as Node3D

func fighters(archers: bool) -> Array:
	var out: Array = []
	for e: Node in get_tree().get_nodes_in_group("cc_enemy"):
		if e.is_queued_for_deletion():
			continue
		if e.alive() and e.brain_state == "battle" and bool(e.profile.is_archer) == archers:
			out.append(e)
	return out

func assign() -> void:
	var p: Node3D = player()
	if p == null:
		return
	_slots.clear()
	for archers: bool in [false, true]:
		var list: Array = fighters(archers)
		if list.is_empty():
			continue
		var angs: Array = []
		for e: Node3D in list:
			var to: Vector3 = e.global_position - p.global_position
			angs.append([atan2(to.z, to.x), e])
		angs.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		var n: int = angs.size()
		var step: float = TAU / n
		# keep the ring where it already is: start from the first foe's own angle
		var base: float = float(angs[0][0])
		var avg_off: float = 0.0
		for i in n:
			avg_off += wrapf(float(angs[i][0]) - (base + i * step), -PI, PI)
		base += avg_off / n
		for i in n:
			_slots[angs[i][1]] = base + i * step

func slot_for(e: Node3D) -> Vector3:
	var p: Node3D = player()
	if p == null:
		return e.global_position
	var a: float
	if _slots.has(e):
		a = float(_slots[e])
	else:
		var to: Vector3 = e.global_position - p.global_position
		a = atan2(to.z, to.x)
	var r: float = float(e.profile.keep_dist_m)
	return p.global_position + Vector3(cos(a), 0, sin(a)) * r

func reset() -> void:
	attackers.clear()
	_slots.clear()
	_gap = 0.0

func may_attack(e: Node3D) -> bool:
	if e.profile.is_archer:
		return true
	if e in attackers:
		return true
	return attackers.size() < max_attackers and _gap <= 0.0

func claim(e: Node3D) -> void:
	if not e.profile.is_archer and not e in attackers:
		attackers.append(e)

func release(e: Node3D) -> void:
	if e in attackers:
		attackers.erase(e)
		_gap = turn_gap_s
