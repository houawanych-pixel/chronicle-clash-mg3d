extends RefCounted
## The CC survival systems placed in the ISLES world (scripts/cc/survival/*).
##   - Trees on Home Isle and Mist Isle: Lance's sword cuts them (a blade, slower than an axe).
##   - Wildlife: does on Home Isle, a boar below Crag Isle, hares on Dune Isle. Crouch to sneak;
##     sprinting is loud. Sword hits near the head count as head hits.
##   - Forage: mushrooms and herbs to pick up by walking over them.
##   - Camp pot by the start: COOK picks the best mix from your bag (up to 5) and cooks it.
##     POTION eats your best meal first when you have one.
##   - Stormrunner bike: BIKE summons it next to Lance (not at sea, not in the Mist Isle
##     sanctum). Stick up = throttle, down = brake, left/right steer, JUMP = jump,
##     hold GUARD = drift, hold DODGE = wheelie. BIKE again gets off; with an empty tank it
##     reads REFUEL and burns up to 5 wood / emberroot from your bag.

const TreeNode = preload("res://scripts/cc/survival/tree_node.gd")
const Wildlife = preload("res://scripts/cc/survival/wildlife_agent.gd")
const CookSite = preload("res://scripts/cc/survival/cook_site.gd")
const Bike = preload("res://scripts/cc/survival/bike.gd")
const Zone = preload("res://scripts/cc/survival/summon_zone.gd")

const HOME_TREES: Array = [Vector2(-10, -2), Vector2(-13, 6), Vector2(-6, -9), Vector2(9, -7), Vector2(12, 2), Vector2(-15, 12), Vector2(6, -12)]
const MIST_TREES: Array = [Vector2(-12, -50), Vector2(-4, -53), Vector2(-9, -44)]
const HERD: Array = [["mossback_doe", Vector2(8, 10)], ["mossback_doe", Vector2(-12, 1)], ["bristle_boar", Vector2(40, -2)], ["dune_hare", Vector2(-44, 30)], ["dune_hare", Vector2(-38, 38)]]
const FORAGE: Array = [
	["field_mushroom", Vector2(-8, 4)], ["field_mushroom", Vector2(-11, -6)], ["field_mushroom", Vector2(10, -3)],
	["emberroot", Vector2(-4, -10)], ["emberroot", Vector2(13, 6)], ["emberroot", Vector2(-14, 9)],
	["ironcap", Vector2(42, -9)], ["ironcap", Vector2(52, -2)],
	["hushleaf", Vector2(-6, -46)], ["hushleaf", Vector2(-11, -52)],
	["windthistle", Vector2(-45, 34)], ["windthistle", Vector2(-40, 28)],
	["sunpear", Vector2(4, -6)], ["saltbloom", Vector2(44, 40)], ["sparkcoal", Vector2(47, -8)],
]
const POT_AT: Vector2 = Vector2(-3, 12)
const SANCTUM_AT: Vector2 = Vector2(-8, -48)
const PICK_R: float = 1.3
const COOK_R: float = 2.6

var isles: RefCounted
var game: Node
var root: Node3D
var trees: Array = []
var animals: Array = []
var forage: Array = []         # [{node, item}]
var pot: Node3D
var bike: CharacterBody3D
var riding: bool = false
var sword_tool: Resource
var forage_mat: Dictionary = {}

func _init(i: RefCounted) -> void:
	isles = i
	game = i.game

func build(parent: Node3D) -> void:
	root = Node3D.new()
	root.name = "Survival"
	parent.add_child(root)
	trees.clear()
	animals.clear()
	forage.clear()
	riding = false
	bike = null
	InventoryService.clear()
	sword_tool = load("res://data/cc/tools/sword.tres")
	var oak: Resource = load("res://data/cc/trees/oak.tres")
	var pine: Resource = load("res://data/cc/trees/pine.tres")
	var i: int = 0
	for p: Vector2 in HOME_TREES + MIST_TREES:
		var t: StaticBody3D = TreeNode.new()
		t.tree = oak if i % 3 != 2 else pine
		t.seed_value = 300 + i
		root.add_child(t)
		t.global_position = isles.ground_point(p) - Vector3.UP * 0.45
		trees.append(t)
		i += 1
	pot = CookSite.new()
	pot.has_pot = true
	root.add_child(pot)
	pot.global_position = isles.ground_point(POT_AT) - Vector3.UP * 0.4
	var z: Node3D = Zone.new()
	z.tag = "sanctum"
	z.radius = 9.0
	root.add_child(z)
	z.global_position = Vector3(SANCTUM_AT.x, 0, SANCTUM_AT.y)
	for f: Array in FORAGE:
		add_forage(str(f[0]), f[1])

func spawn_animals() -> void:
	for h: Array in HERD:
		var a: CharacterBody3D = Wildlife.new()
		a.species = h[0]
		a.wander_radius = 4.0
		root.add_child(a)
		a.global_position = isles.ground_point(h[1]) + Vector3.UP * 0.2
		a.threat = game.hero
		a.noise_fn = hero_noise
		animals.append(a)

## How loud Lance is right now: crouch/crawl is quiet, sprinting and riding are loud.
func hero_noise() -> float:
	var h: CharacterBody3D = game.hero
	if h == null:
		return 0.0
	if riding:
		return 1.0
	if game.prone:
		return 0.05
	if game.crouched:
		return 0.15
	if game.trav.sprinting:
		return 1.0
	var s: float = Vector2(h.velocity.x, h.velocity.z).length()
	return clampf(0.1 + s / 7.0, 0.1, 0.8)

func add_forage(item: String, p: Vector2) -> void:
	var n: Node3D = Node3D.new()
	n.name = "Forage"
	root.add_child(n)
	n.global_position = isles.ground_point(p) - Vector3.UP * 0.4
	var col: Color = {"field_mushroom": Color("e9dcc4"), "emberroot": Color("e2552f"), "ironcap": Color("6f7f92"),
		"hushleaf": Color("5fb7a0"), "windthistle": Color("c6a5e8"), "sunpear": Color("f2c94c"),
		"saltbloom": Color("f4f1ea"), "sparkcoal": Color("2b2536")}.get(item, Color.WHITE)
	if not forage_mat.has(item):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = col
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 0.25
		forage_mat[item] = m
	var stem: MeshInstance3D = MeshInstance3D.new()
	var sm: CylinderMesh = CylinderMesh.new()
	sm.top_radius = 0.04
	sm.bottom_radius = 0.06
	sm.height = 0.25
	stem.mesh = sm
	stem.material_override = forage_mat[item]
	stem.position.y = 0.12
	n.add_child(stem)
	var cap: MeshInstance3D = MeshInstance3D.new()
	var cm: SphereMesh = SphereMesh.new()
	cm.radius = 0.16
	cm.height = 0.16 if item.ends_with("mushroom") or item == "ironcap" else 0.3
	cap.mesh = cm
	cap.material_override = forage_mat[item]
	cap.position.y = 0.28
	n.add_child(cap)
	forage.append({"node": n, "item": item})

# ---------------------------------------------------------------- per frame

func progress(dt: float) -> void:
	var h: CharacterBody3D = game.hero
	if h == null:
		return
	var hp: Vector3 = h.global_position
	for j in range(forage.size() - 1, -1, -1):
		var f: Dictionary = forage[j]
		var n: Node3D = f.node
		n.rotation.y += dt * 1.2
		if riding:
			continue
		var d: Vector3 = n.global_position - hp
		if Vector2(d.x, d.z).length() < PICK_R and absf(d.y) < 2.0:
			InventoryService.add(str(f.item), 1)
			game.hud.popup("+1 " + InventoryService.item_name(str(f.item)), Color("bff2c8"))
			game.sound("chip", -10)
			n.queue_free()
			forage.remove_at(j)
	if riding and bike != null:
		seat_hero(h)

func near_pot() -> bool:
	var h: CharacterBody3D = game.hero
	return h != null and pot != null and h.global_position.distance_to(pot.global_position) < COOK_R

# ---------------------------------------------------------------- cooking

## Best mix the bag can make: the buff family you have most of (with fillers), else food.
func pick_ingredients() -> Array:
	var bag: Dictionary = {}
	for id: String in InventoryService.stacks:
		if CookingService.is_ingredient(id):
			bag[id] = InventoryService.count(id)
	if bag.is_empty():
		return []
	var fams: Dictionary = {}
	for id: String in bag:
		var tag: String = str(CookingService.ingredients[id].get("tag", ""))
		if tag != "":
			fams[tag] = int(fams.get(tag, 0)) + int(bag[id])
	var out: Array = []
	var best_tag: String = ""
	var best_n: int = 0
	for tag: String in fams:
		if int(fams[tag]) > best_n:
			best_n = int(fams[tag])
			best_tag = tag
	var take: Callable = func(id: String) -> void:
		while out.size() < 5 and int(bag.get(id, 0)) > 0:
			out.append(id)
			bag[id] = int(bag[id]) - 1
	if best_tag != "":
		for id: String in bag.keys():
			if str(CookingService.ingredients[id].get("tag", "")) == best_tag:
				take.call(id)
	# fill with the most filling untagged things (meat first)
	var plain: Array = []
	for id: String in bag.keys():
		if str(CookingService.ingredients[id].get("tag", "")) == "":
			plain.append(id)
	plain.sort_custom(func(a: String, b: String) -> bool: return float(CookingService.ingredients[a].hearts) > float(CookingService.ingredients[b].hearts))
	for id: String in plain:
		take.call(id)
	return out

func cook() -> void:
	var ids: Array = pick_ingredients()
	if ids.is_empty():
		game.hud.popup("NOTHING TO COOK", Color("ff8a8a"))
		return
	var meal: Dictionary = pot.cook(ids)
	if meal.is_empty():
		return
	var line: String = "%s  (+%s hearts" % [meal.name, str(meal.hearts)]
	if meal.buff != "":
		line += ", %s %d for %d:%02d" % [str(meal.buff).to_upper(), int(meal.tier), int(meal.duration) / 60, int(meal.duration) % 60]
	line += ")"
	game.hud.popup("CRITICAL COOK!" if meal.crit else "COOKED", Color("ffe08a"))
	game.say("tip", line)
	game.sound("win", -10)

## Eat the meal that heals most. Returns true if one was eaten.
func eat(f: CharacterBody3D) -> bool:
	if InventoryService.meals.is_empty():
		return false
	var best: int = 0
	for i in InventoryService.meals.size():
		if float(InventoryService.meals[i].hearts) > float(InventoryService.meals[best].hearts):
			best = i
	var m: Dictionary = InventoryService.take_meal(best)
	var heal: float = float(m.hearts) * 8.0
	f.hp = minf(f.max_hp, f.hp + heal)
	game.hud.popup("%s  +%d" % [str(m.name).to_upper(), int(heal)], Color("7dffcf"))
	if str(m.buff) != "":
		game.say("tip", "%s %d active for %d:%02d." % [str(m.buff).to_upper(), int(m.tier), int(m.duration) / 60, int(m.duration) % 60])
	game.sound("chip", -6)
	return true

# ---------------------------------------------------------------- sword

## The sword also cuts trees and hits animals in front of Lance.
func sword_hit(f: CharacterBody3D, reach: float) -> bool:
	var hit: bool = false
	var fwd: Vector3 = f.forward()
	var pos: Vector3 = f.global_position
	for t: StaticBody3D in trees:
		if t.is_felled:
			continue
		var to: Vector3 = t.global_position - pos
		to.y = 0.0
		if to.length() < minf(reach, 1.9) + 0.3 and (to.length() < 0.5 or fwd.dot(to.normalized()) > 0.4):
			var d: float = t.hit(sword_tool, pos)
			hit = true
			game.fx.sparks(pos + fwd * 0.8 + Vector3.UP * 1.1, Color("d9b98a"), 10, 5.0, -fwd)
			game.sound("knock", -8)
			if t.is_felled:
				game.hud.popup("TIMBER!  +%s" % InventoryService.item_name(str(t.tree.wood_item)), Color("f4e3b0"))
			elif d > 0.0:
				game.hud.number(t.global_position + Vector3.UP * 1.6, str(int(d)), Color("d9b98a"))
			break
	for a: CharacterBody3D in animals:
		if not a.alive():
			continue
		var to2: Vector3 = a.global_position - pos
		to2.y = 0.0
		if to2.length() > reach + 0.4 or (to2.length() > 0.5 and fwd.dot(to2.normalized()) < 0.35):
			continue
		var tip: Vector3 = pos + fwd * minf(to2.length(), reach) + Vector3.UP * 1.0
		var part: String = "head" if tip.distance_to(a.head_position()) < tip.distance_to(a.global_position + Vector3.UP * 0.8 * a.size) else "body"
		var was_quiet: bool = a.unaware()
		a.take_hit(10.0, part, pos)
		hit = true
		game.fx.sparks(a.global_position + Vector3.UP * 0.8 * a.size, Color("ffd27a"), 12, 6.0)
		if not a.alive():
			game.hud.popup(("SNEAK HUNT!  " if was_quiet else "") + str(a.data.get("name", "")).to_upper(), Color("ffe08a"))
	return hit

# ---------------------------------------------------------------- bike

func bike_label() -> String:
	var h: CharacterBody3D = game.hero
	if h == null or not h.alive() or isles.aboard:
		return ""
	if riding:
		if bike.fuel <= 0.0 and refuel_items().size() > 0 and bike.speed < 1.0:
			return "REFUEL"
		return "GET OFF"
	return "BIKE"

func refuel_items() -> Array:
	var out: Array = []
	for id: String in ["sparkcoal", "oak_wood", "pine_wood", "emberroot", "boar_tusk"]:
		var n: int = InventoryService.count(id)
		for k in n:
			if out.size() >= 5:
				return out
			out.append(id)
	return out

func bike_button(f: CharacterBody3D) -> void:
	match bike_label():
		"BIKE":
			summon(f)
		"GET OFF":
			dismount(f)
		"REFUEL":
			var added: float = bike.refuel(refuel_items())
			game.hud.popup("FUEL +%d%%" % int(added), Color("ffd27a"))

func summon(f: CharacterBody3D) -> void:
	var at: Vector3 = f.global_position + f.forward() * 1.6
	var deny: Array = load("res://data/cc/bike_tuning.tres").summon_deny_tags
	var why: String = Bike.summon_block_reason(game.get_tree(), at, deny)
	if why == "" and isles.field.top_at(at.x, at.z) < 0.2:
		why = "deep_water"
	if why != "":
		game.hud.popup("CAN'T SUMMON HERE", Color("ff8a8a"))
		game.say("tip", "The Stormrunner won't come to a %s." % why.replace("_", " "))
		return
	if bike == null:
		bike = Bike.new()
		root.add_child(bike)
	else:
		bike.visible = true
		bike.process_mode = Node.PROCESS_MODE_INHERIT
	bike.global_position = Vector3(at.x, isles.field.top_at(at.x, at.z) + 0.6, at.z)
	bike.speed = 0.0
	bike.yaw = f.yaw
	bike.travel_yaw = bike.yaw
	bike.velocity = Vector3.ZERO
	riding = true
	f.collision_layer = 0
	f.collision_mask = 0
	f.set_state("idle")
	game.sound("pulse", -6)
	game.hud.popup("STORMRUNNER", Color("7fd4ff"))
	game.say_once("bike_how", "tip", "Stick: throttle, brake, steer. JUMP jumps, hold GUARD to drift, hold DODGE to wheelie.")

func dismount(f: CharacterBody3D) -> void:
	riding = false
	f.collision_layer = 1
	f.collision_mask = 1
	var side: Vector3 = Vector3(cos(bike.yaw), 0, -sin(bike.yaw))
	var p: Vector3 = bike.global_position + side * 1.1
	f.global_position = Vector3(p.x, maxf(isles.field.top_at(p.x, p.z), 0.0) + 0.4, p.z)
	f.velocity = Vector3.ZERO
	bike.throttle = 0.0
	bike.brake = 1.0
	bike.steer = 0.0
	bike.visible = false
	bike.process_mode = Node.PROCESS_MODE_DISABLED

## Ride: stick and buttons drive the bike; Lance sits on it.
func ride(f: CharacterBody3D, mv: Vector2, playing: bool) -> void:
	var hud: Control = game.hud
	if not playing:
		mv = Vector2.ZERO
	bike.throttle = clampf(-mv.y, 0.0, 1.0)
	bike.brake = clampf(mv.y, 0.0, 1.0)
	# steer against the camera's view so "right" on the stick turns right on screen
	bike.steer = clampf(mv.x, -1.0, 1.0)
	if playing and (hud.take("jump") or Input.is_action_just_pressed("cc_jump")):
		bike.jump = true
	bike.drift = playing and (hud.held("block") or Input.is_action_pressed("cc_block"))
	bike.wheelie = playing and (hud.held("dodge") or Input.is_action_pressed("cc_dodge"))
	hud.take("dodge")
	hud.take("attack")
	seat_hero(f)
	if bike.global_position.y < -0.6 and isles.field.top_at(bike.global_position.x, bike.global_position.z) < -0.3:
		# rode into the sea: back to the last dry spot
		dismount(f)
		f.global_position = isles.last_safe
		game.hud.popup("SPLASH", Color("bfe9ff"))
	elif bike.global_position.y > 0.2:
		isles.last_safe = bike.global_position + Vector3.UP * 0.3

func seat_hero(f: CharacterBody3D) -> void:
	var back: Vector3 = Vector3(sin(bike.yaw), 0, cos(bike.yaw))
	f.global_position = bike.global_position + Vector3.UP * 0.55 + back * 0.15
	f.velocity = Vector3.ZERO
	f.yaw = bike.yaw
	if f.state not in ["idle", "hurt", "dead"]:
		f.set_state("idle")

func shift(d: Vector3) -> void:
	if riding and bike != null:
		bike.global_position += d
