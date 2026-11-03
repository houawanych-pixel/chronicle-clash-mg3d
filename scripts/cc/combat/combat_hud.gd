extends Control
## Arena touch controls (and status). Left side: floating move stick. Right side: ATTACK
## (tap = light, hold = charge), DODGE, GUARD (hold), LOCK, plus CROUCH / SPRINT toggles.
## Dragging empty right-side screen turns the camera. Keyboard: WASD, J attack (hold to
## charge), K guard, L dodge, Tab lock, Shift sprint, C crouch, R restart.

const FONT = preload("res://assets/ui_bold.ttf")
const BTN: Array = [
	{"id": "attack", "c": Vector2(1150, 590), "r": 84.0, "label": "ATTACK", "col": Color("ffcf6a")},
	{"id": "dodge", "c": Vector2(990, 520), "r": 56.0, "label": "DODGE", "col": Color("5fe3ff")},
	{"id": "guard", "c": Vector2(1060, 410), "r": 56.0, "label": "GUARD", "col": Color("5fe3ff")},
	{"id": "lock", "c": Vector2(1195, 410), "r": 46.0, "label": "LOCK", "col": Color("ff7a8a")},
	{"id": "crouch", "c": Vector2(990, 650), "r": 42.0, "label": "CROUCH", "col": Color("bff2c8")},
	{"id": "sprint", "c": Vector2(860, 650), "r": 42.0, "label": "SPRINT", "col": Color("ffe14a")},
	{"id": "jump", "c": Vector2(860, 525), "r": 52.0, "label": "JUMP", "col": Color("5fe3ff")},
	{"id": "aim", "c": Vector2(1195, 300), "r": 40.0, "label": "AIM", "col": Color("ffd27a")},
	{"id": "weapon", "c": Vector2(1080, 300), "r": 40.0, "label": "WEAPON", "col": Color("d8b45a")},
]

var arena: Node
var buttons: Array = BTN.duplicate(true)
var stick: Vector2 = Vector2.ZERO
var stick_id: int = -99
var stick_origin: Vector2 = Vector2(190, 565)
var held: Dictionary = {}
var fingers: Dictionary = {}
var crouch_on: bool = false
var sprint_on: bool = false
var scale_ui: float = 1.0
var offset_x: float = 0.0
var msg: String = ""
var msg_t: float = 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func ui(p: Vector2) -> Vector2:
	return (p - Vector2(offset_x, 0)) / scale_ui

func btn_pos(b: Dictionary) -> Vector2:
	var vs: Vector2 = get_viewport_rect().size
	var w: float = vs.x / scale_ui
	return Vector2(b.c.x + (w - 1280.0), b.c.y)

func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		var t: InputEventScreenTouch = e
		if t.pressed:
			down(t.index, ui(t.position))
		else:
			up(t.index)
	elif e is InputEventScreenDrag:
		var d: InputEventScreenDrag = e
		move(d.index, ui(d.position), d.relative / scale_ui)

func down(id: int, p: Vector2) -> void:
	if arena.state != "play":
		arena.menu_tap(p)
		return
	for b: Dictionary in buttons:
		if p.distance_to(btn_pos(b)) < float(b.r) + 10.0:
			fingers[id] = b.id
			held[b.id] = true
			match b.id:
				"attack":
					arena.player.press("attack")
				"dodge":
					arena.player.press("dodge")
				"guard":
					arena.player.press("guard")
				"lock":
					arena.player.press("lock")
				"jump":
					arena.player.press("jump")
				"aim":
					arena.player.press("aim")
				"weapon":
					arena.player.press("weapon")
				"crouch":
					crouch_on = not crouch_on
					sprint_on = false
				"sprint":
					sprint_on = not sprint_on
					crouch_on = false
				_:
					if arena.has_method("hud_button"):
						arena.hud_button(str(b.id))
			return
	if p.x < 640.0 and stick_id == -99:
		stick_id = id
		stick_origin = p
		stick = Vector2.ZERO
		fingers[id] = "stick"
	else:
		fingers[id] = "look"

func move(id: int, p: Vector2, rel: Vector2) -> void:
	match fingers.get(id, ""):
		"stick":
			stick = ((p - stick_origin) / 100.0).limit_length(1.0)
		"look":
			arena.camera.look_drag += rel

func up(id: int) -> void:
	var f: String = fingers.get(id, "")
	if f == "stick":
		stick_id = -99
		stick = Vector2.ZERO
	elif held.has(f):
		held[f] = false
	fingers.erase(id)

func feed(pl: Node3D) -> void:
	var mv: Vector2 = stick
	var k: Vector2 = Vector2(Input.get_axis("cca_left", "cca_right"), Input.get_axis("cca_up", "cca_down"))
	if k.length() > 0.1:
		mv = k.limit_length(1.0)
	pl.inp.move = mv
	if Input.is_action_just_pressed("cca_attack"):
		pl.press("attack")
	if Input.is_action_just_pressed("cca_dodge"):
		pl.press("dodge")
	if Input.is_action_just_pressed("cca_guard"):
		pl.press("guard")
	if Input.is_action_just_pressed("cca_lock"):
		pl.press("lock")
	if Input.is_action_just_pressed("cca_jump"):
		pl.press("jump")
	if Input.is_action_just_pressed("cca_aim"):
		pl.press("aim")
	if Input.is_action_just_pressed("cca_weapon"):
		pl.press("weapon")
	if Input.is_action_just_pressed("cca_crouch"):
		crouch_on = not crouch_on
	pl.inp.attack_held = held.get("attack", false) or Input.is_action_pressed("cca_attack")
	pl.inp.guard_held = held.get("guard", false) or Input.is_action_pressed("cca_guard")
	pl.inp.sprint = sprint_on or Input.is_action_pressed("cca_sprint")
	pl.inp.crouch = crouch_on

func say(s: String) -> void:
	msg = s
	msg_t = 2.2

func _process(dt: float) -> void:
	var vs: Vector2 = get_viewport_rect().size
	scale_ui = vs.y / 720.0
	msg_t = maxf(0.0, msg_t - dt)
	queue_redraw()

func txt(at: Vector2, s: String, size: int, col: Color) -> void:
	var w: float = FONT.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string_outline(FONT, at - Vector2(w * 0.5, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0, 0, 0, 0.8))
	draw_string(FONT, at - Vector2(w * 0.5, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func bar(at: Vector2, w: float, v: float, col: Color, label: String) -> void:
	draw_rect(Rect2(at, Vector2(w, 16)), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(at + Vector2(2, 2), Vector2((w - 4) * clampf(v, 0.0, 1.0), 12)), col)
	draw_string(FONT, at + Vector2(0, -4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * scale_ui)
	var w: float = get_viewport_rect().size.x / scale_ui
	var pl: Node3D = arena.player
	if pl != null:
		bar(Vector2(24, 34), 300, pl.hp / pl.max_hp, Color("ff3b4f"), "HEALTH")
		bar(Vector2(24, 74), 300, StaminaPool.value / StaminaPool.max_value, Color("ffe14a"), "STAMINA")
	txt(Vector2(w * 0.5, 42), arena.title_text(), 28, Color("f4e3b0"))
	if TimeDilation.active():
		txt(Vector2(w * 0.5, 120), "FLURRY!  ATTACK!" if pl.flurry_target != null else "", 40, Color("7dffcf"))
	if msg_t > 0.0:
		txt(Vector2(w * 0.5, 170), msg, 34, Color(1, 1, 1, clampf(msg_t, 0.0, 1.0)))
	if arena.state != "play":
		draw_rect(Rect2(0, 0, w, 720), Color(0, 0.02, 0.06, 0.55))
		for mb: Dictionary in arena.menu():
			var r: Rect2 = mb.rect
			draw_rect(r, Color(0.05, 0.15, 0.25, 0.9))
			draw_rect(r, Color("5fe3ff"), false, 3.0)
			txt(r.get_center() + Vector2(0, 10), str(mb.label), 28, Color.WHITE)
		txt(Vector2(w * 0.5, 200), arena.menu_title(), 52, Color("ffe08a"))
		return
	# stick
	draw_arc(stick_origin, 100, 0, TAU, 48, Color(1, 1, 1, 0.35), 4)
	draw_circle(stick_origin + stick * 100.0, 34, Color(1, 1, 1, 0.35))
	for b: Dictionary in buttons:
		var c: Vector2 = btn_pos(b)
		var on: bool = held.get(b.id, false) or (b.id == "crouch" and crouch_on) or (b.id == "sprint" and sprint_on) or (b.id == "lock" and pl != null and pl.lock_target != null) or (b.id == "aim" and pl != null and pl.aiming)
		draw_circle(c, b.r, Color(0.05, 0.14, 0.24, 0.85 if on else 0.55))
		draw_arc(c, b.r, 0, TAU, 48, b.col, 4)
		var label: String = str(b.label)
		if b.id == "attack" and pl != null and (pl.state == "heavy_charge" or pl.charging_loop):
			label = "RELEASE"
		if b.id == "jump" and pl != null:
			label = {"glide": "CLOSE", "climb": "LEAP"}.get(pl.state, "JUMP" if pl.is_on_floor() else "GLIDE")
		if b.id == "weapon" and pl != null:
			label = {"one_hand": "SWORD", "two_hand": "GREAT", "spear": "SPEAR"}.get(pl.weapon_class, "WEAPON")

		txt(c + Vector2(0, 8), label, 20 if float(b.r) < 80 else 28, Color.WHITE)
