extends RefCounted
## Aging from authoritative real timestamps. Nothing here counts frames or
## game minutes, so a child keeps growing while the game is closed, and
## catching up after a long absence walks through every missed stage once,
## in order, with the time each one really happened.

static func age_days(birth: int, now: int, cfg: Resource) -> int:
	if birth < 0:
		return -1
	return int(floor(float(maxi(0, now - birth)) / cfg.seconds_per_day))

static func stage_index_for_days(days: int, cfg: Resource) -> int:
	var i: int = 0
	for k: int in cfg.stage_start_days.size():
		if days >= cfg.stage_start_days[k]:
			i = k
	return i

static func stage_for(birth: int, now: int, cfg: Resource) -> String:
	if birth < 0:
		return "adult"
	return cfg.stage_names[stage_index_for_days(age_days(birth, now, cfg), cfg)]

## When stage k begins for someone born at `birth`.
static func stage_starts_at(birth: int, k: int, cfg: Resource) -> int:
	return birth + int(float(cfg.stage_start_days[k]) * cfg.seconds_per_day)

## Bring one record up to `now`. Returns the transitions added this call
## (each {stage, at}); calling again with the same `now` adds nothing.
## Never moves a record backwards (clock skew) and stops for the dead.
static func advance(npc: Dictionary, now: int, cfg: Resource) -> Array:
	var out: Array = []
	var birth: int = int(npc.get("birth_timestamp", -1))
	if birth < 0 or bool(npc.get("age_locked", false)):
		return out
	var log: Array = npc.get("stage_log", [])
	var last: int = -1
	if not log.is_empty():
		last = cfg.stage_index(str(log[log.size() - 1].get("stage", "")))
	var limit: int = now
	if not bool(npc.get("alive", true)) and int(npc.get("died_at", -1)) >= 0:
		limit = mini(now, int(npc.died_at))
	var target: int = maxi(last, stage_index_for_days(age_days(birth, limit, cfg), cfg))
	for k: int in range(last + 1, target + 1):
		var tr: Dictionary = {"stage": cfg.stage_names[k], "at": stage_starts_at(birth, k, cfg)}
		log.append(tr)
		out.append(tr)
	npc["stage_log"] = log
	if target >= 0:
		npc["life_stage"] = cfg.stage_names[target]
	return out
