extends Control
## Touch HUD for the Sky Citadel, following the owner's control plan:
## left stick moves; right side holds the action buttons; dragging an empty
## part of the right side looks around; tapping an enemy marks it (up to 3).
## Layout is authored at 720 px tall. Left-side items stick to the left edge,
## right-side items to the right edge, so wide phones keep thumbs in reach.
const FONT = preload("res://assets/ui.ttf")
const BOLD = preload("res://assets/ui_bold.ttf")
const CYAN: Color = Color("5fe3ff")
const GOLD: Color = Color("d8b45a")
const WHITE: Color = Color("eef7ff")
const INK: Color = Color(0.03, 0.08, 0.16, 0.82)
const HP: Color = Color("ff3b4f")
const MP: Color = Color("27c8ff")
const ST: Color = Color("ffe14a")
const MAGIC_C: Color = Color("b48cff")

## Right-hand buttons, authored for a 1280-wide screen and shifted to the right edge.
const BUTTONS: Array = [
	{"id": "attack", "c": Vector2(1150, 590), "r": 88.0, "label": "ATTACK", "glyph": "sword", "color": Color("ffcf6a")},
	{"id": "jump", "c": Vector2(976, 652), "r": 54.0, "label": "JUMP", "glyph": "jump", "color": Color("5fe3ff")},
	{"id": "dodge", "c": Vector2(996, 516), "r": 54.0, "label": "DODGE", "glyph": "dodge", "color": Color("5fe3ff")},
	{"id": "block", "c": Vector2(1076, 424), "r": 54.0, "label": "GUARD", "glyph": "shield", "color": Color("5fe3ff")},
	{"id": "skill", "c": Vector2(1196, 412), "r": 54.0, "label": "CHARGE", "glyph": "charge", "color": Color("ffcf6a")},
	{"id": "magic", "c": Vector2(1222, 292), "r": 44.0, "label": "MAGIC", "glyph": "magic", "color": Color("b48cff")},
	{"id": "potion", "c": Vector2(1118, 300), "r": 42.0, "label": "POTION", "glyph": "potion", "color": Color("7dffcf")},
]
## Stealth actions, top-left like the concept screens (ported MG actions).
const STEALTH_BUTTONS: Array = [
	{"id": "crouch", "rect": Rect2(14, 12, 100, 92), "label": "CROUCH", "glyph": "crouch"},
	{"id": "hug", "rect": Rect2(122, 12, 100, 92), "label": "WALL HUG", "glyph": "hug"},
	{"id": "peek", "rect": Rect2(14, 112, 100, 92), "label": "PEEK", "glyph": "peek"},
	{"id": "distract", "rect": Rect2(122, 112, 100, 92), "label": "DISTRACT", "glyph": "distract"},
]
## The pause button sits beside the stats panel (centre group).
const PAUSE_C: Vector2 = Vector2(866, 40)
const STICK_HOME: Vector2 = Vector2(190, 565)
const STICK_R: float = 105.0

var game: Node
var scale_ui: float = 1.0
var offset_ui: Vector2 = Vector2.ZERO
var W: float = 1280.0
var dx_c: float = 0.0
var dx_r: float = 0.0
var group_dx: float = 0.0
var stick: Vector2 = Vector2.ZERO
var stick_id: int = -99
var stick_origin: Vector2 = STICK_HOME
var look_delta: Vector2 = Vector2.ZERO
var pressed: Dictionary = {}
var released: Dictionary = {}
var holds: Dictionary = {}
var fingers: Dictionary = {}
var menu_buttons: Array = []
var lines: Array = []
var line_t: float = 0.0
var popups: Array = []
var numbers: Array = []
var portraits: Dictionary = {}
var title_tex: Texture2D
var clock: float = 0.0
var hurt_flash: float = 0.0
var fade: float = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for who: String in ["blonde_lance", "lance", "ally", "boss"]:
		var path: String = "res://assets/citadel/portrait_%s.png" % who
		if ResourceLoader.exists(path):
			portraits[who] = load(path)
	if ResourceLoader.exists("res://assets/citadel/title.jpg"):
		title_tex = load("res://assets/citadel/title.jpg")

# ---------------------------------------------------------------- input API

func take(action: String) -> bool:
	if pressed.get(action, false):
		pressed[action] = false
		return true
	return false

func took_release(action: String) -> bool:
	if released.get(action, false):
		released[action] = false
		return true
	return false

func held(action: String) -> bool:
	return holds.get(action, 0) > 0

func take_look() -> Vector2:
	var d: Vector2 = look_delta
	look_delta = Vector2.ZERO
	return d

func release() -> void:
	pressed.clear()
	released.clear()
	holds.clear()
	fingers.clear()
	stick = Vector2.ZERO
	stick_id = -99
	stick_origin = STICK_HOME
	look_delta = Vector2.ZERO

func layout(vs: Vector2) -> void:
	if vs.x / vs.y >= 1280.0 / 720.0:
		scale_ui = vs.y / 720.0
		offset_ui = Vector2.ZERO
	else:
		scale_ui = vs.x / 1280.0
		offset_ui = Vector2(0, (vs.y - 720.0 * scale_ui) * 0.5)
	W = vs.x / scale_ui
	dx_c = (W - 1280.0) * 0.5
	dx_r = W - 1280.0

func to_ui(p: Vector2) -> Vector2:
	return (p - offset_ui) / scale_ui

func button_pos(b: Dictionary) -> Vector2:
	return (b.c as Vector2) + Vector2(dx_r, 0)

func _input(event: InputEvent) -> void:
	layout(get_viewport_rect().size)
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		if t.pressed:
			finger_down(t.index, to_ui(t.position))
		else:
			finger_up(t.index, to_ui(t.position))
	elif event is InputEventScreenDrag:
		var dr: InputEventScreenDrag = event
		finger_move(dr.index, to_ui(dr.position))
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			var id: int = 1000 + mb.button_index
			if mb.pressed:
				finger_down(id, to_ui(mb.position))
			else:
				finger_up(id, to_ui(mb.position))
	elif event is InputEventMouseMotion:
		for id: int in [1001, 1002]:
			if fingers.has(id):
				finger_move(id, to_ui((event as InputEventMouseMotion).position))

func finger_down(id: int, p: Vector2) -> void:
	if game.mode != "play":
		for b: Dictionary in menu_buttons:
			if (b.rect as Rect2).has_point(p):
				menu_action(b.action)
				return
		return
	if p.distance_to(PAUSE_C + Vector2(dx_c, 0)) < 42:
		game.mode = "paused"
		release()
		return
	for sb: Dictionary in STEALTH_BUTTONS:
		if (sb.rect as Rect2).grow(4).has_point(p):
			var sa: String = sb.id
			fingers[id] = {"kind": "button", "action": sa}
			pressed[sa] = true
			holds[sa] = holds.get(sa, 0) + 1
			return
	for b: Dictionary in BUTTONS:
		if p.distance_to(button_pos(b)) <= b.r * 1.12:
			var a: String = b.id
			fingers[id] = {"kind": "button", "action": a}
			pressed[a] = true
			holds[a] = holds.get(a, 0) + 1
			return
	if p.x < W * 0.45 and stick_id == -99:
		stick_id = id
		fingers[id] = {"kind": "stick"}
		stick_origin = p
		stick = Vector2.ZERO
		return
	fingers[id] = {"kind": "look", "start": p, "last": p, "t": Time.get_ticks_msec(), "moved": 0.0}

func finger_move(id: int, p: Vector2) -> void:
	if not fingers.has(id):
		return
	var f: Dictionary = fingers[id]
	if f.kind == "stick":
		var d: Vector2 = p - stick_origin
		if d.length() > STICK_R:
			stick_origin = p - d.normalized() * STICK_R
			d = p - stick_origin
		var v: Vector2 = d / STICK_R
		stick = v if v.length() > 0.12 else Vector2.ZERO
	elif f.kind == "look":
		var step: Vector2 = p - (f.last as Vector2)
		f.moved = f.moved + step.length()
		f.last = p
		if f.moved > 14.0:
			look_delta += step

func finger_up(id: int, p: Vector2) -> void:
	if not fingers.has(id):
		return
	var f: Dictionary = fingers[id]
	fingers.erase(id)
	match f.kind:
		"stick":
			stick_id = -99
			stick = Vector2.ZERO
			stick_origin = STICK_HOME
		"button":
			var a: String = f.action
			holds[a] = maxi(0, holds.get(a, 0) - 1)
			if holds[a] == 0:
				released[a] = true
		"look":
			if f.moved <= 14.0 and Time.get_ticks_msec() - int(f.t) < 350:
				game.tap_target(p)

func menu_action(a: String) -> void:
	game.sound("bleep", -10)
	match a:
		"play":
			game.start_game()
		"hero_blonde_lance", "hero_lance":
			var key: String = a.trim_prefix("hero_")
			if key != game.hero_key:
				game.restart_with(key)
		"stage_citadel":
			if game.stage != "citadel":
				game.restart_with("blonde_lance", "citadel")
		"stage_forest":
			if game.stage != "forest":
				game.restart_with("lance", "forest")
		"stage_village":
			if game.stage != "village":
				game.restart_with(game.hero_key if game.hero_key != "" else "blonde_lance", "village")
		"resume":
			game.mode = "play"
			release()
		"restart":
			game.restart_with(game.hero_key)
			game.start_game()
		"retry":
			game.respawn()
		"again":
			game.restart_with(game.hero_key)
			game.mode = "title"
		"labs":
			get_tree().change_scene_to_file("res://scenes/main.tscn")
		"mute":
			game.muted = not game.muted

# ---------------------------------------------------------------- messages

func dialogue(who: String, text_s: String) -> void:
	lines.append({"who": who, "text": text_s})
	while lines.size() > 3:
		lines.pop_front()
	if lines.size() == 1:
		line_t = 0.0

func popup(text_s: String, color: Color) -> void:
	popups.append({"text": text_s, "color": color, "t": 0.0})

func number(pos: Vector3, text_s: String, color: Color) -> void:
	numbers.append({"pos": pos, "text": text_s, "color": color, "t": 0.0})

func _process(dt: float) -> void:
	clock += dt
	hurt_flash = maxf(0.0, hurt_flash - dt * 2.5)
	fade = maxf(0.0, fade - dt * 1.8)
	if game.mode == "play" or game.mode == "dead":
		if lines.size() > 0:
			line_t += dt
			var dur: float = 2.4 + (lines[0].text as String).length() * 0.035
			if line_t > dur:
				lines.pop_front()
				line_t = 0.0
		for p: Dictionary in popups.duplicate():
			p.t += dt
			if p.t > 1.2:
				popups.erase(p)
		for n: Dictionary in numbers.duplicate():
			n.t += dt
			if n.t > 0.9:
				numbers.erase(n)

# ---------------------------------------------------------------- drawing helpers

func group(dx: float) -> void:
	group_dx = dx
	draw_set_transform(offset_ui + Vector2(dx * scale_ui, 0), 0, Vector2.ONE * scale_ui)

func text(at: Vector2, s: String, size_px: int, color: Color, bold: bool = true, align: int = 0) -> void:
	var f: Font = BOLD if bold else FONT
	var w: float = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var x: float = at.x - (w * 0.5 if align == 0 else (w if align == 1 else 0.0))
	draw_string_outline(f, Vector2(x, at.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 6, Color(0, 0, 0, 0.55))
	draw_string(f, Vector2(x, at.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

func frame(r: Rect2, fill: Color = INK, edge: Color = Color(0.37, 0.89, 1.0, 0.75)) -> void:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	draw_style_box(s, r)
	draw_line(r.position + Vector2(14, 0), r.position + Vector2(r.size.x * 0.3, 0), GOLD, 3)
	draw_line(r.end - Vector2(14, 0), r.end - Vector2(r.size.x * 0.3, 0), GOLD, 3)

func seg_bar(at: Vector2, w: float, value: float, maxv: float, color: Color, label: String) -> void:
	text(at + Vector2(0, 16), label, 18, WHITE, true, -1)
	var x0: float = at.x + 100
	var segs: int = 14
	var sw: float = (w - 100 - 46) / segs
	var filled: float = clampf(value / maxv, 0, 1) * segs
	for i in segs:
		var r: Rect2 = Rect2(x0 + i * sw, at.y + 2, sw - 3, 16)
		draw_rect(r, Color(0.1, 0.16, 0.24, 0.9))
		var f: float = clampf(filled - i, 0, 1)
		if f > 0:
			draw_rect(Rect2(r.position, Vector2(r.size.x * f, r.size.y)), color)
	text(Vector2(at.x + w - 4, at.y + 16), str(int(round(value))), 18, WHITE, true, 1)

func glyph(kind: String, c: Vector2, r: float) -> void:
	match kind:
		"sword":
			draw_line(c + Vector2(-r * 0.32, r * 0.32), c + Vector2(r * 0.34, -r * 0.34), WHITE, 7)
			draw_line(c + Vector2(-r * 0.44, r * 0.12), c + Vector2(-r * 0.12, r * 0.44), GOLD, 6)
		"shield":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.3, -r * 0.34), c + Vector2(r * 0.3, -r * 0.34), c + Vector2(r * 0.3, 0), c + Vector2(0, r * 0.36), c + Vector2(-r * 0.3, 0)]), Color(WHITE, 0.9))
		"jump":
			draw_line(c + Vector2(0, r * 0.32), c + Vector2(0, -r * 0.3), WHITE, 6)
			draw_polyline(PackedVector2Array([c + Vector2(-r * 0.24, -r * 0.08), c + Vector2(0, -r * 0.34), c + Vector2(r * 0.24, -r * 0.08)]), WHITE, 6)
		"dodge":
			for i in 3:
				var o: float = (i - 1) * r * 0.22
				draw_polyline(PackedVector2Array([c + Vector2(o - r * 0.12, -r * 0.24), c + Vector2(o + r * 0.12, 0), c + Vector2(o - r * 0.12, r * 0.24)]), Color(WHITE, 0.5 + i * 0.25), 5)
		"charge":
			draw_line(c + Vector2(-r * 0.36, r * 0.1), c + Vector2(r * 0.36, -r * 0.1), WHITE, 6)
			draw_polyline(PackedVector2Array([c + Vector2(r * 0.1, -r * 0.32), c + Vector2(r * 0.38, -r * 0.1), c + Vector2(r * 0.14, r * 0.14)]), GOLD, 5)
		"magic":
			for i in 6:
				var a: float = i * TAU / 6.0 + clock
				draw_line(c, c + Vector2(cos(a), sin(a)) * r * 0.32, Color(MAGIC_C, 0.95), 4)
			draw_circle(c, r * 0.14, WHITE)
		"potion":
			draw_circle(c + Vector2(0, r * 0.08), r * 0.26, Color("7dffcf"))
			draw_rect(Rect2(c + Vector2(-r * 0.09, -r * 0.38), Vector2(r * 0.18, r * 0.22)), WHITE)

func round_btn(b: Dictionary) -> void:
	var c: Vector2 = b.c
	var r: float = b.r
	var color: Color = b.color
	var on: bool = held(b.id)
	var ready: bool = game.button_ready(b.id)
	draw_circle(c, r, Color(0.05, 0.14, 0.24, 0.85 if on else 0.55))
	draw_arc(c, r, 0, TAU, 64, color if ready else Color(0.5, 0.55, 0.6, 0.7), 4.0, true)
	draw_arc(c, r - 9, 0, TAU, 64, Color(GOLD, 0.55 if ready else 0.2), 2.0, true)
	var fill: float = game.button_fill(b.id)
	if fill > 0.0:
		draw_arc(c, r + 6, -PI / 2, -PI / 2 + TAU * fill, 64, color, 6.0, true)
	glyph(b.glyph, c, r)
	text(c + Vector2(0, r * 0.84), b.label, 18 if r < 80 else 24, WHITE if ready else Color(WHITE, 0.55))
	var badge: String = game.button_badge(b.id)
	if badge != "":
		var bc: Vector2 = c + Vector2(r * 0.72, -r * 0.72)
		draw_circle(bc, 15, Color("0b2a44"))
		draw_arc(bc, 15, 0, TAU, 24, color, 2, true)
		text(bc + Vector2(0, 7), badge, 18, WHITE)

func menu_btn(r: Rect2, label: String, action: String, primary: bool = false) -> void:
	frame(r, Color(0.06, 0.2, 0.3, 0.92) if primary else INK, CYAN if primary else Color(0.6, 0.75, 0.9, 0.6))
	text(r.get_center() + Vector2(0, 10), label, 28 if primary else 24, CYAN if primary else WHITE)
	menu_buttons.append({"rect": Rect2(r.position + Vector2(group_dx, 0), r.size), "action": action})

func project(p: Vector3) -> Vector2:
	## Screen position in the left-group (full width) space.
	var cam: Camera3D = game.camera
	if cam.is_position_behind(p):
		return Vector2(-999, -999)
	return to_ui(cam.unproject_position(p))

# ---------------------------------------------------------------- frame

func _draw() -> void:
	layout(get_viewport_rect().size)
	menu_buttons.clear()
	if game.hero == null:
		return
	group(0)
	if game.mode == "title":
		draw_title()
		return
	draw_world_marks()
	if fade > 0.0:
		draw_rect(Rect2(-10, -10, W + 20, 740), Color(0, 0, 0, clampf(fade, 0, 1)))
	if hurt_flash > 0.0:
		# Red edge flash when the hero is hit.
		for i in 6:
			var w2: float = 18.0 + i * 16.0
			var a3: float = hurt_flash * 0.12 * (1.0 - i / 6.0)
			draw_rect(Rect2(0, 0, W, w2), Color(1, 0.1, 0.15, a3))
			draw_rect(Rect2(0, 720 - w2, W, w2), Color(1, 0.1, 0.15, a3))
			draw_rect(Rect2(0, 0, w2, 720), Color(1, 0.1, 0.15, a3))
			draw_rect(Rect2(W - w2, 0, w2, 720), Color(1, 0.1, 0.15, a3))
	if game.fx.combo_hits >= 2 and game.mode == "play":
		var cx: float = W - 280
		var pulse: float = 1.0 + 0.25 * clampf((game.fx.combo_t - 1.35) * 4.0, 0, 1)
		text(Vector2(cx, 268), str(game.fx.combo_hits), int(64 * pulse), Color("ffd27a"), true, 1)
		text(Vector2(cx + 8, 262), "HITS", 24, WHITE, true, -1)
	group(dx_c)
	draw_stats()
	draw_map(Rect2(545, 588, 190, 120))
	if game.mode == "play":
		draw_dialogue()
		group(0)
		draw_left()
		group(dx_r)
		for b: Dictionary in BUTTONS:
			round_btn(b)
	group(dx_c)
	for i in popups.size():
		var p: Dictionary = popups[i]
		var a: float = 1.0 - clampf((p.t - 0.8) / 0.4, 0, 1)
		text(Vector2(640, 300 - p.t * 30 + i * 52), p.text, 44, Color(p.color, a))
	if game.mode == "paused":
		draw_rect(Rect2(-2000, -200, 5280, 1120), Color(0, 0.02, 0.06, 0.6))
		text(Vector2(640, 220), "PAUSED", 56, WHITE)
		menu_btn(Rect2(500, 270, 280, 70), "RESUME", "resume", true)
		menu_btn(Rect2(500, 355, 280, 62), "RESTART", "restart")
		menu_btn(Rect2(500, 430, 280, 62), "MG LABS (OLD)", "labs")
		menu_btn(Rect2(500, 505, 280, 56), "SOUND: " + ("OFF" if game.muted else "ON"), "mute")
		text(Vector2(640, 610), "Tap an enemy to mark it (up to 3). Hold CHARGE, release to dash through marks.", 18, Color(WHITE, 0.85), false)
		text(Vector2(640, 638), "MAGIC seeks marked enemies. Drag the right side to look around.", 18, Color(WHITE, 0.85), false)
	elif game.mode == "dead" and game.dead_timer > 1.2:
		draw_rect(Rect2(-2000, -200, 5280, 1120), Color(0.08, 0, 0.02, 0.55))
		text(Vector2(640, 300), game.fail_text, 64, Color("ff6a7a"))
		text(Vector2(640, 350), "Back to the last checkpoint with full health.", 24, WHITE, false)
		menu_btn(Rect2(500, 395, 280, 72), "RETRY", "retry", true)
	elif game.mode == "win":
		draw_rect(Rect2(-2000, -200, 5280, 1120), Color(0, 0.03, 0.08, 0.6))
		text(Vector2(640, 230), game.win_text, 64, Color("ffe08a"))
		var secs: int = int(game.time_played)
		if game.stage == "forest":
			text(Vector2(640, 290), "Time %d:%02d    Silent takedowns %d" % [secs / 60, secs % 60, game.takedowns], 28, WHITE, false)
		else:
			text(Vector2(640, 290), "Time %d:%02d    Parries %d" % [secs / 60, secs % 60, game.parries], 28, WHITE, false)
		menu_btn(Rect2(500, 340, 280, 72), "PLAY AGAIN", "again", true)
		menu_btn(Rect2(500, 425, 280, 62), "MG LABS (OLD)", "labs")

func draw_title() -> void:
	if title_tex:
		var ts: Vector2 = title_tex.get_size()
		var k: float = maxf(W / ts.x, 720.0 / ts.y) * 1.03
		var sz: Vector2 = ts * k
		draw_texture_rect(title_tex, Rect2(Vector2(W * 0.5, 360) - sz * 0.5 + Vector2(sin(clock * 0.2) * 10, 0), sz), false)
	draw_rect(Rect2(-10, -200, W + 20, 1120), Color(0.0, 0.03, 0.1, 0.42))
	draw_rect(Rect2(-10, 440, W + 20, 680), Color(0.0, 0.02, 0.08, 0.5))
	group(dx_c)
	text(Vector2(640, 150), "CHRONICLE CLASH", 84, Color("f4e3b0"))
	text(Vector2(640, 196), "SWORD DEMO", 26, CYAN)
	var stages: Array = [["citadel", "SKY CITADEL", "Sword fights to the Dark Knight", "boss"], ["forest", "FOREST ESCAPE", "Sneak Eliza out. Blonde Lance hunts you", "ally"], ["village", "VILLAGE", "Watch the villagers live their day", "lance"]]
	for i in stages.size():
		var st: Array = stages[i]
		var sr: Rect2 = Rect2(175 + i * 315, 392, 300, 82)
		var son: bool = game.stage == st[0]
		frame(sr, Color(0.06, 0.22, 0.32, 0.95) if son else INK, CYAN if son else Color(0.6, 0.7, 0.85, 0.5))
		if portraits.has(st[3]):
			var tex: Texture2D = portraits[st[3]]
			var tsz: Vector2 = tex.get_size()
			draw_texture_rect_region(tex, Rect2(sr.position + Vector2(8, 8), Vector2(66, 66)), Rect2(Vector2((tsz.x - tsz.y) * 0.5, 0), Vector2(tsz.y, tsz.y)))
		text(sr.position + Vector2(84, 36), st[1], 24, CYAN if son else WHITE, true, -1)
		text(sr.position + Vector2(84, 62), st[2], 14, Color(WHITE, 0.8), false, -1)
		menu_buttons.append({"rect": Rect2(sr.position + Vector2(group_dx, 0), sr.size), "action": "stage_" + st[0]})
	if game.stage == "forest":
		text(Vector2(640, 525), "You play LANCE. Blonde Lance is the hunter.", 20, WHITE, false)
		menu_btn(Rect2(510, 585, 260, 76), "PLAY", "play", true)
		text(Vector2(640, 700), "Crouch in tall grass to hide  ·  rocks are cover  ·  keep Eliza close", 19, Color(WHITE, 0.8), false)
		group(dx_r)
		menu_btn(Rect2(1040, 640, 210, 54), "MG LABS (OLD)", "labs")
		return
	var keys: Array = ["blonde_lance", "lance"]
	for i in keys.size():
		var k2: String = keys[i]
		var r: Rect2 = Rect2(370 + i * 290, 496, 250, 70)
		var on: bool = game.hero_key == k2
		frame(r, Color(0.06, 0.22, 0.32, 0.95) if on else INK, CYAN if on else Color(0.6, 0.7, 0.85, 0.5))
		if portraits.has(k2):
			draw_texture_rect(portraits[k2], Rect2(r.position + Vector2(6, 6), Vector2(58, 58)), false)
		text(r.position + Vector2(160, 45), game.HEROES[k2].name, 22, CYAN if on else WHITE)
		menu_buttons.append({"rect": Rect2(r.position + Vector2(group_dx, 0), r.size), "action": "hero_" + k2})
	menu_btn(Rect2(510, 585, 260, 76), "PLAY", "play", true)
	text(Vector2(640, 700), "Left stick moves  ·  drag right side to look  ·  tap enemies to mark", 19, Color(WHITE, 0.8), false)
	group(dx_r)
	menu_btn(Rect2(1040, 640, 210, 54), "MG LABS (OLD)", "labs")

func draw_stats() -> void:
	var r: Rect2 = Rect2(450, 8, 380, 90)
	frame(r)
	seg_bar(Vector2(464, 16), 352, game.hero.hp, game.hero.max_hp, HP, "HEALTH")
	seg_bar(Vector2(464, 42), 352, game.mana, 100, MP, "MANA")
	seg_bar(Vector2(464, 68), 352, game.stamina, 100, ST, "STAMINA")
	var goal: String = game.sections[game.section].goal if game.section < game.sections.size() else ""
	var gr: Rect2 = Rect2(480, 104, 320, 32)
	frame(gr, Color(0.03, 0.1, 0.18, 0.75))
	text(gr.get_center() + Vector2(0, 7), goal.to_upper(), 16, CYAN)
	if game.mode == "play":
		draw_pause()
	if game.stage == "village":
		var cr: Rect2 = Rect2(530, 142, 220, 32)
		frame(cr, Color(0.03, 0.1, 0.18, 0.78), Color("ffd27a"))
		var hr: float = game.village.hour()
		var icon: String = "☾" if hr < 6.0 or hr >= 20.0 else "☀"
		text(cr.get_center() + Vector2(0, 7), icon + "  " + game.village.clock_text(), 17, Color("ffe7b0"))
	var st: String = game.stealth_status()
	if st != "":
		var sc: Color = {"HIDDEN": Color("3dffb0"), "SUSPICIOUS": Color("ffb03b"), "ALERT": Color("ff4060")}[st]
		var sr: Rect2 = Rect2(500, 142, 280, 34)
		if game.boss_seen:
			sr.position.y = 180
		frame(sr, Color(0.02, 0.1, 0.12, 0.8), sc)
		draw_circle(sr.position + Vector2(26, 17), 8, sc)
		draw_circle(sr.position + Vector2(26, 17), 3, Color(0.02, 0.1, 0.12))
		text(sr.get_center() + Vector2(10, 8), "STEALTH: " + st, 19, sc)
	if game.stage == "forest" and game.ally != null:
		var ar: Rect2 = Rect2(290, 70, 150, 26)
		frame(ar, Color(0.03, 0.1, 0.18, 0.8), Color("bfe9ff"))
		draw_rect(Rect2(ar.position + Vector2(60, 9), Vector2(80, 9)), Color(0.15, 0.2, 0.3))
		draw_rect(Rect2(ar.position + Vector2(60, 9), Vector2(80 * game.ally.hp / game.ally.max_hp, 9)), Color("bfe9ff"))
		text(ar.position + Vector2(8, 19), "ELIZA", 14, WHITE, true, -1)
	if game.boss_seen and game.boss.alive() and game.boss.visible:
		var br: Rect2 = Rect2(370, 142, 540, 32)
		frame(br, Color(0.12, 0.02, 0.04, 0.8), Color("ff3346"))
		draw_rect(Rect2(br.position + Vector2(150, 9), Vector2(374, 14)), Color(0.2, 0.05, 0.08))
		draw_rect(Rect2(br.position + Vector2(150, 9), Vector2(374 * game.boss.hp / game.boss.max_hp, 14)), Color("ff3346"))
		text(br.position + Vector2(14, 23), game.boss_name, 18, Color("ffb0b8"), true, -1)

func draw_left() -> void:
	var base: Vector2 = stick_origin
	draw_circle(base, STICK_R, Color(0.05, 0.14, 0.24, 0.35))
	draw_arc(base, STICK_R, 0, TAU, 64, Color(CYAN, 0.7), 3, true)
	draw_arc(base, STICK_R - 12, 0, TAU, 64, Color(GOLD, 0.45), 2, true)
	for a: float in [0.0, PI / 2, PI, PI * 1.5]:
		draw_circle(base + Vector2(cos(a), sin(a)) * (STICK_R - 26), 6, Color(CYAN, 0.8))
	var knob: Vector2 = base + stick * STICK_R
	draw_circle(knob, 44, Color(0.55, 0.88, 1.0, 0.9))
	draw_circle(knob, 34, Color(0.75, 0.95, 1.0, 0.95))
	text(base + Vector2(0, STICK_R + 30), "MOVE", 20, WHITE)
	for sb: Dictionary in STEALTH_BUTTONS:
		stealth_btn(sb)

func stealth_btn(sb: Dictionary) -> void:
	var r: Rect2 = sb.rect
	var on: bool = held(sb.id) or game.stealth_on(sb.id)
	frame(r, Color(0.06, 0.22, 0.32, 0.9) if on else Color(0.03, 0.08, 0.16, 0.7), CYAN if on else Color(0.37, 0.89, 1.0, 0.55))
	var c: Vector2 = r.get_center() + Vector2(0, -12)
	var col: Color = Color(WHITE, 0.95)
	match sb.glyph:
		"crouch":
			draw_circle(c + Vector2(6, -16), 7, col)
			draw_polyline(PackedVector2Array([c + Vector2(4, -8), c + Vector2(-8, 4), c + Vector2(6, 8), c + Vector2(-2, 20)]), col, 5)
			draw_line(c + Vector2(-8, 4), c + Vector2(-16, 18), col, 5)
		"hug":
			draw_rect(Rect2(c + Vector2(10, -22), Vector2(6, 44)), Color(GOLD, 0.9))
			draw_circle(c + Vector2(0, -15), 7, col)
			draw_line(c + Vector2(2, -7), c + Vector2(2, 12), col, 5)
			draw_line(c + Vector2(2, 12), c + Vector2(-6, 22), col, 5)
			draw_line(c + Vector2(2, 12), c + Vector2(8, 22), col, 5)
		"peek":
			draw_arc(c, 16, PI * 1.1, PI * 1.9, 20, col, 4)
			draw_arc(c, 16, PI * 0.1, PI * 0.9, 20, col, 4)
			draw_circle(c, 7, CYAN)
		"distract":
			draw_circle(c + Vector2(0, 6), 13, Color(GOLD, 0.95))
			draw_rect(Rect2(c + Vector2(-5, -12), Vector2(10, 7)), col)
			draw_circle(c + Vector2(17, -10), 4, CYAN)
	text(Vector2(r.get_center().x, r.end.y - 10), sb.label, 15, WHITE)
	if sb.id == "peek":
		text(r.position + Vector2(r.size.x - 22, 18), "HOLD", 11, CYAN)

func draw_pause() -> void:
	draw_circle(PAUSE_C, 28, INK)
	draw_arc(PAUSE_C, 28, 0, TAU, 40, Color(CYAN, 0.7), 2, true)
	draw_rect(Rect2(PAUSE_C + Vector2(-9, -11), Vector2(6, 22)), WHITE)
	draw_rect(Rect2(PAUSE_C + Vector2(3, -11), Vector2(6, 22)), WHITE)

func draw_world_marks() -> void:
	for e: CharacterBody3D in game.enemies:
		if not e.alive() or not e.visible:
			continue
		var head: Vector2 = project(e.global_position + Vector3.UP * (e.height + 0.45))
		if head.x < -100:
			continue
		var col: Color = Color("ff3346") if e.state in ["windup", "leap"] else Color(1, 0.25, 0.25, 0.85)
		var s: float = 13.0 if e.state in ["windup", "leap"] else 9.0
		draw_colored_polygon(PackedVector2Array([head + Vector2(-s, -s * 1.3), head + Vector2(s, -s * 1.3), head]), col)
		if e.stealth and not e.active and (e.suspicion > 0.05 or e.gstate in ["INVESTIGATE", "SEARCH"]):
			text(head + Vector2(0, -24), "?", 30, Color("ffb03b"))
			draw_arc(head + Vector2(0, -34), 20, -PI / 2, -PI / 2 + TAU * e.suspicion, 24, Color("ffb03b"), 3, true)
		if e.kind != "boss" and (e.active or e.hp < e.max_hp):
			var w: float = 70
			draw_rect(Rect2(head + Vector2(-w / 2, -s * 1.3 - 14), Vector2(w, 7)), Color(0.1, 0.05, 0.08, 0.85))
			draw_rect(Rect2(head + Vector2(-w / 2, -s * 1.3 - 14), Vector2(w * e.hp / e.max_hp, 7)), HP)
		var mark: int = game.marks.find(e)
		if mark >= 0:
			var mid: Vector2 = project(e.global_position + Vector3.UP * e.height * 0.55)
			var rr: float = 46.0 + 4.0 * sin(clock * 6.0)
			draw_arc(mid, rr, 0, TAU, 48, Color(CYAN, 0.95), 3, true)
			for i in 3:
				var a: float = -PI / 2 + i * TAU / 3.0 + clock * 1.5
				draw_circle(mid + Vector2(cos(a), sin(a)) * rr, 6, CYAN if i <= mark else Color(CYAN, 0.25))
			text(mid + Vector2(rr + 12, -rr + 10), str(mark + 1), 22, CYAN)
	for n: Dictionary in numbers:
		var p: Vector2 = project(n.pos)
		if p.x < -100:
			continue
		var a2: float = 1.0 - clampf((n.t - 0.5) / 0.4, 0, 1)
		var pop: float = 1.0 + 0.5 * clampf(1.0 - n.t * 8.0, 0, 1)
		var big: bool = n.text.is_valid_int() and int(n.text) >= 40
		text(p + Vector2(0, -n.t * 70), n.text, int((52 if big else 42) * pop), Color(Color("ffd27a") if big else n.color, a2))
	if game.charge > 0.0:
		var hp2: Vector2 = project(game.hero.global_position + Vector3.UP * 2.3)
		draw_arc(hp2, 26, -PI / 2, -PI / 2 + TAU * game.charge, 40, Color("ffcf6a"), 6, true)
		if game.charge >= 1.0:
			text(hp2 + Vector2(0, -34), "READY", 18, Color("ffcf6a"))

func draw_dialogue() -> void:
	if lines.is_empty():
		return
	var l: Dictionary = lines[0]
	var who: String = l.who
	var slide: float = clampf(line_t * 6.0, 0, 1)
	if who == "tip":
		var tr: Rect2 = Rect2(250, 182, 780, 46)
		frame(tr, Color(0.03, 0.12, 0.2, 0.9 * slide))
		text(tr.position + Vector2(390, 30), l.text, 17, Color(WHITE, slide), false)
		return
	var left: bool = who != "ally" and who != "boss" and who != "hunter"
	var w: float = 340
	var r: Rect2
	if left:
		group(0)
		r = Rect2(14 - (1.0 - slide) * 440, 214, w, 118)
	else:
		group(dx_r)
		r = Rect2(1280 - 16 - w + (1.0 - slide) * 440, 10, w, 118)
	var edge: Color = Color("ff3346") if who in ["boss", "hunter"] else CYAN
	frame(r, INK, edge)
	var key: String = game.hero_key if who == "hero" else ("blonde_lance" if who == "hunter" else who)
	var pr: Rect2 = Rect2(r.position + Vector2(8, 8), Vector2(102, 102))
	if portraits.has(key):
		var tex: Texture2D = portraits[key]
		var ts: Vector2 = tex.get_size()
		draw_texture_rect_region(tex, pr, Rect2(Vector2((ts.x - ts.y) * 0.5, 0), Vector2(ts.y, ts.y)))
	for i in 7:
		var bh: float = 3 + absf(sin(clock * 9.0 + i * 1.3)) * 9
		draw_rect(Rect2(r.position + Vector2(122 + i * 6, 20 - bh * 0.5), Vector2(3, bh)), Color(edge, 0.9))
	draw_multiline_string(BOLD, r.position + Vector2(122, 50), l.text, HORIZONTAL_ALIGNMENT_LEFT, w - 134, 18, 3, WHITE)
	group(dx_c)

func draw_map(r: Rect2) -> void:
	frame(r, Color(0.02, 0.1, 0.18, 0.78))
	text(Vector2(r.get_center().x, r.position.y + 18), "N", 16, WHITE)
	var hero: Vector3 = game.hero.global_position
	var k: float = 2.2
	var c: Vector2 = r.get_center() + Vector2(0, 8)
	var zones: Array = game.map_zones
	for z: Rect2 in zones:
		var zr: Rect2 = Rect2(c + (z.position - Vector2(hero.x, hero.z)) * k, z.size * k)
		zr = zr.intersection(r.grow(-6))
		if zr.size.x > 0 and zr.size.y > 0:
			draw_rect(zr, Color(0.37, 0.89, 1.0, 0.12))
			draw_rect(zr, Color(0.37, 0.89, 1.0, 0.5), false, 1.5)
	for e: CharacterBody3D in game.enemies:
		if not e.alive():
			continue
		var p: Vector2 = c + Vector2(e.global_position.x - hero.x, e.global_position.z - hero.z) * k
		if r.grow(-6).has_point(p):
			if e.stealth and not e.active:
				# Vision cone on the map (40° half-angle, patrol range).
				var fw: Vector3 = e.forward()
				var a0: float = atan2(fw.z, fw.x)
				var reach: float = minf(game.patrol.range_limit(e) * k, 26.0)
				var pts: PackedVector2Array = PackedVector2Array([p])
				for i in 7:
					var a: float = a0 + deg_to_rad(lerpf(-e.vision_half, e.vision_half, i / 6.0))
					pts.append(p + Vector2(cos(a), sin(a)) * reach)
				draw_colored_polygon(pts, Color(1, 0.2, 0.3, 0.3) if e.seeing else Color(1, 0.7, 0.2, 0.22))
			draw_circle(p, 5 if e.kind == "boss" else 3.5, CYAN if e in game.marks else Color("ff3346"))
	if game.stage == "village":
		for v: Node3D in game.village.villagers:
			if not v.visible:
				continue
			var vp: Vector2 = c + Vector2(v.global_position.x - hero.x, v.global_position.z - hero.z) * k
			if r.grow(-6).has_point(vp):
				draw_circle(vp, 3.5, Color("7dffcf"))
	var f: Vector3 = game.hero.forward()
	var dir: Vector2 = Vector2(f.x, f.z)
	var side: Vector2 = Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([c + dir * 10, c - dir * 6 + side * 6, c - dir * 6 - side * 6]), CYAN)
