extends RefCounted
## Pregnancy rules. The dice are seeded from the event id, so the server,
## the local save and any replay all agree on the same outcome.
const Profile = preload("res://scripts/cc/family/family_profile.gd")

static func rolls_conception(event_id: String, chance: float) -> bool:
	return Profile.unit("conceive:" + event_id) < chance

static func carrier_of(a: Dictionary, b: Dictionary) -> Dictionary:
	if bool(a.get("can_carry", false)):
		return a
	if bool(b.get("can_carry", false)):
		return b
	return {}

static func active_for(state: Dictionary, npc_id: String) -> Dictionary:
	for p: Dictionary in state.pregnancies.values():
		if str(p.status) == "active" and str(p.carrier_id) == npc_id:
			return p
	return {}

static func active_count(state: Dictionary) -> int:
	var n: int = 0
	for p: Dictionary in state.pregnancies.values():
		if str(p.status) == "active":
			n += 1
	return n

static func new_pregnancy(event_id: String, carrier: String, partner: String, family_id: String, at: int, cfg: Resource) -> Dictionary:
	return {
		"pregnancy_id": "preg_" + event_id,
		"carrier_id": carrier,
		"partner_id": partner,
		"family_id": family_id,
		"conceived_at": at,
		"due_at": at + int(cfg.pregnancy_days * cfg.seconds_per_day),
		"status": "active",            # active, born
		"baby_id": "",
	}

static func baby_id_for(pregnancy_id: String) -> String:
	return "npc_" + pregnancy_id
