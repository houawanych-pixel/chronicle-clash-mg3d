extends Node
## Autoload InventoryService: stacked materials plus unique cooked meals.
## Item definitions come from res://data/cc/items.json.

signal item_changed(id: String, count: int)
signal meal_added(meal: Dictionary)
signal meal_removed(meal: Dictionary)

const CCData = preload("res://scripts/cc/survival/cc_data.gd")
const ITEMS_PATH: String = "res://data/cc/items.json"
const MEAL_SLOTS: int = 60

var defs: Dictionary = {}
var stacks: Dictionary = {}      # item id -> count
var meals: Array[Dictionary] = []

func _ready() -> void:
	load_defs()

func load_defs() -> void:
	defs = CCData.load_json(ITEMS_PATH)

func item_name(id: String) -> String:
	var d: Dictionary = defs.get(id, {})
	return str(d.get("name", id))

func stack_max(id: String) -> int:
	var d: Dictionary = defs.get(id, {})
	return int(d.get("stack", 999))

func count(id: String) -> int:
	return int(stacks.get(id, 0))

func has(id: String, n: int = 1) -> bool:
	return count(id) >= n

## Adds up to n; returns how many fit (stacks cap at the item's limit).
func add(id: String, n: int = 1) -> int:
	if n <= 0:
		return 0
	var room: int = stack_max(id) - count(id)
	var put: int = mini(n, maxi(room, 0))
	if put > 0:
		stacks[id] = count(id) + put
		item_changed.emit(id, count(id))
	return put

func remove(id: String, n: int = 1) -> bool:
	if not has(id, n):
		return false
	var left: int = count(id) - n
	if left <= 0:
		stacks.erase(id)
	else:
		stacks[id] = left
	item_changed.emit(id, left)
	return true

## Removes every id in the list (repeats count) only if all are there.
func take_all(ids: Array) -> bool:
	var need: Dictionary = {}
	for id: String in ids:
		need[id] = int(need.get(id, 0)) + 1
	for id: String in need:
		if not has(id, int(need[id])):
			return false
	for id: String in need:
		remove(id, int(need[id]))
	return true

func add_meal(meal: Dictionary) -> bool:
	if meals.size() >= MEAL_SLOTS:
		return false
	meals.append(meal)
	meal_added.emit(meal)
	return true

func take_meal(i: int) -> Dictionary:
	if i < 0 or i >= meals.size():
		return {}
	var m: Dictionary = meals[i]
	meals.remove_at(i)
	meal_removed.emit(m)
	return m

func clear() -> void:
	stacks.clear()
	meals.clear()

func to_save() -> Dictionary:
	return {"stacks": stacks.duplicate(), "meals": meals.duplicate(true)}

func from_save(d: Dictionary) -> void:
	stacks = (d.get("stacks", {}) as Dictionary).duplicate()
	meals.clear()
	for m: Dictionary in d.get("meals", []):
		meals.append(m)
