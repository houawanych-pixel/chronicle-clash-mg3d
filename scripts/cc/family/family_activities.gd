extends RefCounted
## What children do through the village day, and when a parent has to drop
## their work for them. Pure functions of (records, game hour), so the result
## is the same on every client and after a reload. Routines resume on their
## own: once a need's time window passes, the parent's normal schedule wins
## again and Villager.gd re-plans back to work.
##
## Activity kinds a child can have:
##   home, nap, sleep           stay inside the family home
##   play_near_home, play       play outside (near the door / around the plaza)
##   lessons                    learning from the elder near the plaza
##   apprentice                 follow a parent at their (non-combat) work
##   eat, family_meal           meals (outside seat / at home with parents)
## Future kinds (no location exists for them yet): "zoo_visit", "outing".

const FUTURE_KINDS: Array = ["zoo_visit", "outing"]

static func in_window(h: float, start: float, length: float) -> bool:
	return h >= start and h < start + length

static func child_activity(stage: String, h: float) -> String:
	match stage:
		"newborn":
			return "home"
		"crawling_infant", "early_walker":
			if h < 7.0 or h >= 19.0:
				return "sleep"
			if in_window(h, 13.0, 1.5):
				return "nap"
			if in_window(h, 9.0, 2.0) or in_window(h, 15.0, 2.0):
				return "play_near_home"
			return "home"
		"toddler":
			if h < 7.0 or h >= 19.5:
				return "sleep"
			if in_window(h, 12.0, 1.0):
				return "eat"
			if in_window(h, 13.0, 1.0):
				return "nap"
			if in_window(h, 18.0, 1.0):
				return "play"          # park walk with a parent
			return "play_near_home"
		"child":
			if h < 6.5 or h >= 20.5:
				return "sleep"
			if in_window(h, 9.0, 3.0):
				return "lessons"
			if in_window(h, 12.0, 1.0):
				return "eat"
			if in_window(h, 18.0, 0.75):
				return "family_meal"
			return "play"
		"adolescent":
			if h < 6.0 or h >= 21.5:
				return "sleep"
			if in_window(h, 12.0, 1.0):
				return "eat"
			if in_window(h, 18.0, 0.75):
				return "family_meal"
			if in_window(h, 8.0, 4.0) or in_window(h, 13.0, 4.0):
				return "apprentice"
			return "play"
	return ""

static func stays_inside(kind: String) -> bool:
	return kind in ["home", "nap", "sleep", "family_meal"]

## Which parent slot (0 or 1) takes a need, so two parents share the work.
## If the other parent is gone, the one left does everything.
static func takes_turn(parent_slot: int, turn: int, both_alive: bool) -> bool:
	return not both_alive or (turn % 2) == parent_slot

## The need (if any) that pulls this parent away from their routine now.
## children: the parent's living children as records, each with "_both" (both
## parents alive) and "_slot" (this parent's index in parent_ids) added.
## Returns {} or {"kind", "child_id", "where": "home"|"plaza", "carry": bool}.
static func parent_need(children: Array, h: float) -> Dictionary:
	for c: Dictionary in children:
		var stage: String = str(c.life_stage)
		var slot: int = int(c._slot)
		var both: bool = bool(c._both)
		var id: String = str(c.npc_id)
		match stage:
			"newborn":
				var feeds: Array = [6.0, 9.0, 12.0, 15.0, 18.0, 21.0]
				for i: int in feeds.size():
					if in_window(h, feeds[i], 0.5) and takes_turn(slot, i, both):
						return {"kind": "feed", "child_id": id, "where": "home", "carry": false}
				if in_window(h, 19.0, 1.0) and takes_turn(slot, 0, both):
					return {"kind": "carry_walk", "child_id": id, "where": "plaza", "carry": true}
			"crawling_infant", "early_walker":
				var meals: Array = [7.0, 12.0, 18.0]
				for i: int in meals.size():
					if in_window(h, meals[i], 0.5) and takes_turn(slot, i, both):
						return {"kind": "feed", "child_id": id, "where": "home", "carry": false}
				if in_window(h, 18.75, 0.5) and takes_turn(slot, 1, both):
					return {"kind": "put_to_sleep", "child_id": id, "where": "home", "carry": false}
			"toddler":
				if in_window(h, 18.0, 1.0) and takes_turn(slot, 0, both):
					return {"kind": "park_walk", "child_id": id, "where": "plaza", "carry": false}
				if in_window(h, 19.25, 0.5) and takes_turn(slot, 1, both):
					return {"kind": "put_to_sleep", "child_id": id, "where": "home", "carry": false}
			"child":
				if in_window(h, 18.0, 0.75):
					return {"kind": "family_meal", "child_id": id, "where": "home", "carry": false}
				if in_window(h, 17.0, 1.0) and takes_turn(slot, 1, both):
					return {"kind": "teach", "child_id": id, "where": "plaza", "carry": false}
			"adolescent":
				if in_window(h, 18.0, 0.75):
					return {"kind": "family_meal", "child_id": id, "where": "home", "carry": false}
	return {}
