extends Node
## Game-side client for the family server (server/family/server.js).
## Not switched on in the village yet: the live site has no family server, so
## the village runs on the local save (family_save.gd). See docs/FAMILY.md,
## "Integration steps", for wiring it in.
##
## - Every change is queued as an event with a unique id and stays in the
##   outbox until the server answers; after a disconnect the same ids are
##   resent, which the server treats as duplicates.
## - pull() replaces the local records with the server's (the server owns
##   time, births and aging); the local copy is only a cache.
## - No AI key or admin token is ever held here.

signal synced(rev: int)

var base_url: String = ""
var svc: RefCounted
var client_id: String = ""
var outbox: Array = []
var counter: int = 0
var last_error: String = ""

func setup(url: String, service: RefCounted, id: String) -> void:
	base_url = url.trim_suffix("/")
	svc = service
	client_id = id

func make_id() -> String:
	counter += 1
	return "%s:%d:%d" % [client_id, counter, Time.get_ticks_usec()]

func queue(type: String, args: Dictionary) -> String:
	var id: String = make_id()
	outbox.append({"id": id, "type": type, "args": args})
	return id

func call_server(method: int, path: String, body: Variant = null) -> Dictionary:
	var h: HTTPRequest = HTTPRequest.new()
	h.timeout = 8.0
	add_child(h)
	var data: String = JSON.stringify(body) if body != null else ""
	var err: Error = h.request(base_url + path, PackedStringArray(["Content-Type: application/json"]), method, data)
	if err != OK:
		h.queue_free()
		last_error = "request_failed"
		return {}
	var res: Array = await h.request_completed
	h.queue_free()
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS or int(res[1]) != 200:
		last_error = "http_%d_%d" % [int(res[0]), int(res[1])]
		return {}
	var parsed: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

## Send the outbox. Answered events leave it (accepted, duplicate or refused);
## if the server can't be reached they stay for the next try.
func flush() -> Array:
	if outbox.is_empty():
		return []
	var batch: Array = outbox.slice(0, 50)
	var r: Dictionary = await call_server(HTTPClient.METHOD_POST, "/v1/events", {"events": batch})
	if r.is_empty():
		return []
	var answered: Dictionary = {}
	for res: Dictionary in r.get("results", []):
		answered[str(res.get("id", ""))] = true
	outbox = outbox.filter(func(e: Dictionary) -> bool: return not answered.has(str(e.id)))
	return r.get("results", [])

## Take the server's records as the truth.
func pull() -> bool:
	var r: Dictionary = await call_server(HTTPClient.METHOD_GET, "/v1/state?since=%d" % int(svc.state.rev))
	if r.is_empty():
		return false
	if not bool(r.get("unchanged", false)):
		for k: String in ["npcs", "families", "relationships", "pregnancies"]:
			svc.state[k] = r.get(k, {})
		svc.state.rev = int(r.rev)
		svc.state = load("res://scripts/cc/family/family_save.gd").migrate(svc.state)
	synced.emit(int(svc.state.rev))
	return true
