extends Node
## Autoload CookingService: 1-5 ingredients make one meal.
##   pot:   hearts = raw x pot_heal_mult. If every buff ingredient shares one family, the meal
##          gets that timed buff (tier from total potency, duration from the ingredients).
##          Two or more families clash: a Murky Stew, raw hearts, no buff.
##          Crit chance = best ingredient crit + a bonus for how many went in. An Omen Night
##          always crits. A crit adds hearts, a tier, or time (whichever isn't maxed).
##   roast: open fire, hearts = raw x roast_heal_mult, never a buff, never a crit.
## Meals are dictionaries: {name, hearts, buff, tier, duration, crit, method, from}.

signal cooked(meal: Dictionary)

const CCData = preload("res://scripts/cc/survival/cc_data.gd")
const INGREDIENTS_PATH: String = "res://data/cc/ingredients.json"
const TUNING_PATH: String = "res://data/cc/cooking_tuning.tres"
const BUFF_NAMES: Dictionary = {
	"might": "Emberfire", "guard": "Ironhide", "hush": "Hushed", "swift": "Windstep",
}

var ingredients: Dictionary = {}
var tuning: Resource
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var crit_override: int = -1   # tests: -1 roll, 0 never, 1 always (an Omen Night still always crits)

func _ready() -> void:
	ingredients = CCData.load_json(INGREDIENTS_PATH)
	tuning = load(TUNING_PATH)
	rng.randomize()

func is_ingredient(id: String) -> bool:
	return ingredients.has(id)

func raw_hearts(ids: Array) -> float:
	var h: float = 0.0
	for id: String in ids:
		h += float((ingredients.get(id, {}) as Dictionary).get("hearts", 0.0))
	return h

## Cook a meal from ingredient ids (does not touch the inventory). Empty dict = refused.
func cook(ids: Array, method: String = "pot") -> Dictionary:
	if ids.is_empty() or ids.size() > int(tuning.max_ingredients):
		return {}
	for id: String in ids:
		if not ingredients.has(id):
			return {}
	var raw: float = raw_hearts(ids)
	var meal: Dictionary = {"hearts": 0.0, "buff": "", "tier": 0, "duration": 0.0, "crit": false,
		"method": method, "from": ids.duplicate(), "name": ""}
	if method == "roast":
		meal.hearts = snappedf(raw * float(tuning.roast_heal_mult), 0.25)
		meal.name = ("Roasted " + InventoryService.item_name(ids[0])) if ids.size() == 1 else "Roasted Medley"
		cooked.emit(meal)
		return meal
	var tags: Dictionary = {}
	var potency: int = 0
	var duration: float = 0.0
	var best_crit: int = 0
	var has_meat: bool = false
	for id: String in ids:
		var d: Dictionary = ingredients[id]
		var tag: String = str(d.get("tag", ""))
		if tag != "":
			tags[tag] = true
			potency += int(d.get("potency", 0))
			duration += float(d.get("duration", 0.0))
		best_crit = maxi(best_crit, int(d.get("crit", 0)))
		if InventoryService.defs.get(id, {}).get("cat", "") == "meat":
			has_meat = true
	if tags.size() > 1:
		meal.hearts = snappedf(raw * float(tuning.fail_heal_mult), 0.25)
		meal.name = "Murky Stew"
		meal.method = "fail"
		cooked.emit(meal)
		return meal
	meal.hearts = raw * float(tuning.pot_heal_mult)
	if tags.size() == 1:
		meal.buff = str(tags.keys()[0])
		meal.tier = tier_for(potency)
		# extra time from spice ingredients only counts toward a buff
		for id: String in ids:
			var d2: Dictionary = ingredients[id]
			if str(d2.get("tag", "")) == "":
				duration += float(d2.get("duration", 0.0))
		meal.duration = minf(duration, float(tuning.max_duration))
	var rates: Array[int] = tuning.count_crit_rates
	var chance: int = best_crit + rates[clampi(ids.size() - 1, 0, rates.size() - 1)]
	var crit: bool = rng.randi_range(0, 99) < chance
	if crit_override >= 0:
		crit = crit_override == 1
	if WorldClock.is_omen_night() or crit:
		apply_crit(meal)
	meal.hearts = snappedf(minf(float(meal.hearts), float(tuning.max_hearts)), 0.25)
	var base: String = "Hearty Stew" if has_meat else "Forager's Bowl"
	meal.name = (str(BUFF_NAMES.get(meal.buff, "")) + " " + base).strip_edges()
	cooked.emit(meal)
	return meal

func tier_for(potency: int) -> int:
	var t: int = 0
	var th: Array[int] = tuning.tier_thresholds
	for i in th.size():
		if potency >= th[i]:
			t = i + 1
	return maxi(t, 1)

## A crit improves one thing that still has room: hearts, the buff tier, or its time.
func apply_crit(meal: Dictionary) -> void:
	meal.crit = true
	var options: Array[String] = []
	if float(meal.hearts) < float(tuning.max_hearts):
		options.append("hearts")
	if meal.buff != "":
		if int(meal.tier) < tuning.tier_thresholds.size():
			options.append("tier")
		if float(meal.duration) < float(tuning.max_duration):
			options.append("time")
	if options.is_empty():
		return
	var pick: String = options[rng.randi_range(0, options.size() - 1)]
	meal.crit_bonus = pick
	match pick:
		"hearts":
			meal.hearts = float(meal.hearts) + float(tuning.crit_heart_bonus)
		"tier":
			meal.tier = int(meal.tier) + 1
		"time":
			meal.duration = minf(float(meal.duration) + float(tuning.crit_duration_bonus), float(tuning.max_duration))

## Cook from the inventory: takes the ingredients, adds the meal. Empty dict = not enough.
func cook_from_inventory(ids: Array, method: String = "pot") -> Dictionary:
	var meal: Dictionary = cook(ids, method)
	if meal.is_empty():
		return {}
	if not InventoryService.take_all(ids):
		return {}
	InventoryService.add_meal(meal)
	return meal
