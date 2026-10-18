extends RefCounted
## Free conversation with a villager. On the web build the chat panel, mic,
## voice and brain calls live in web/village_chat.js (the Echo Vision brain);
## this side picks who you talk to, keeps them standing with you, gives the
## brain their context, and shows their replies in the speech bubble.
## Off the web (desktop tests) a villager answers with their own stock lines.

const TALK_RANGE: float = 3.0
const LEAVE_RANGE: float = 5.0

var game: Node
var village: RefCounted
var target: Node = null
var js_ready: bool = false
var update_t: float = 0.0
var said: Array = []        # what the hero said (for tests and logs)
var replies: Array = []     # what villagers answered
var pending: Array = []     # desktop: queued stock replies

func _init(g: Node, v: RefCounted) -> void:
	game = g
	village = v

func is_open() -> bool:
	return target != null

func web() -> bool:
	return OS.has_feature("web")

func ensure_js() -> void:
	if js_ready or not web():
		return
	var src: String = FileAccess.get_file_as_string("res://web/village_chat.js")
	if src != "":
		JavaScriptBridge.eval(src, true)
		js_ready = true

## The villager the TALK button would open, or null.
func nearest() -> Node:
	if not village.active or game.hero == null or not game.hero.alive():
		return null
	var best: Node = null
	var bd: float = TALK_RANGE
	for v: Node in village.villagers:
		if not is_instance_valid(v) or v.state == "inside" or not v.visible:
			continue
		var d: float = v.global_position.distance_to(game.hero.global_position)
		if d < bd:
			bd = d
			best = v
	return best

func start(v: Node) -> void:
	if v == null:
		return
	if target:
		stop()
	target = v
	v.begin_chat()
	said.clear()
	replies.clear()
	if web():
		ensure_js()
		JavaScriptBridge.eval("window.ccChat && ccChat.open(%s)" % JSON.stringify(JSON.stringify(context(v))), true)
	game.sound("chip", -12)

func stop() -> void:
	if target == null:
		return
	if is_instance_valid(target):
		target.end_chat()
	target = null
	pending.clear()
	if web() and js_ready:
		JavaScriptBridge.eval("window.ccChat && ccChat.close()", true)

## Desktop/test path: what the hero says gets a stock line back.
func send(text: String) -> void:
	if target == null:
		return
	if web() and js_ready:
		JavaScriptBridge.eval("window.ccChat && ccChat.send(%s)" % JSON.stringify(text), true)
		return
	said.append(text)
	var lines: Array = target.LINES.get(target.job, target.LINES.wanderer)
	pending.append(lines[randi() % lines.size()])

func tick(dt: float) -> void:
	if target == null:
		return
	if not is_instance_valid(target) or not village.active or target.state == "inside" \
			or game.hero == null or not game.hero.alive() \
			or target.global_position.distance_to(game.hero.global_position) > LEAVE_RANGE:
		stop()
		return
	if web() and js_ready:
		var raw: Variant = JavaScriptBridge.eval("window.ccChat ? ccChat.poll() : ''", true)
		var s: String = str(raw) if raw != null else ""
		if s != "":
			var evs: Variant = JSON.parse_string(s)
			if typeof(evs) == TYPE_ARRAY:
				for e: Variant in evs:
					handle(e)
		update_t += dt
		if update_t > 6.0 and target:
			update_t = 0.0
			JavaScriptBridge.eval("window.ccChat && ccChat.update(%s)" % JSON.stringify(JSON.stringify(context(target))), true)
	elif not pending.is_empty():
		handle({"t": "reply", "text": pending.pop_front()})

func handle(e: Variant) -> void:
	if typeof(e) != TYPE_DICTIONARY or target == null:
		return
	match str(e.get("t", "")):
		"reply":
			var text: String = str(e.get("text", ""))
			replies.append(text)
			target.say(text, clampf(2.5 + text.length() * 0.07, 3.0, 12.0))
		"said":
			said.append(str(e.get("text", "")))
		"closed":
			stop()

## Who this villager is and what is going on around them, for the brain.
func context(v: Node) -> Dictionary:
	var block: Dictionary = village.BLOCKS[village.block]
	var others: Array = []
	for o: Node in village.villagers:
		if o != v:
			others.append("%s the %s" % [o.vname, o.job])
	var h: float = village.hour()
	var part: String = "night"
	if h >= 5.0 and h < 12.0:
		part = "morning"
	elif h >= 12.0 and h < 17.0:
		part = "afternoon"
	elif h >= 17.0 and h < 21.0:
		part = "evening"
	var m: int = int(fmod(village.clock, 1440.0))
	var hero_def: Dictionary = game.HEROES.get(game.hero_key, {})
	var seed: int = absi(hash(v.vid))
	return {
		"id": v.vid,
		"name": v.vname,
		"job": v.job,
		"female": v.female,
		"persona": v.persona,
		"place": block.title,
		"time": "%d:%02d" % [m / 60, m % 60],
		"daypart": part,
		"doing": v.doing_text(),
		"carrying": v.carrying,
		"neighbours": ", ".join(others),
		"hero": str(hero_def.get("name", "the knight")).capitalize(),
		"sword": game.sword_out,
		"fallback": v.LINES.get(v.job, v.LINES.wanderer),
		"seed": seed,
		"pitch": v.voice_pitch,
		"rate": v.voice_rate,
	}
