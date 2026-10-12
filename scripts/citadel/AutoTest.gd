extends Node
## Scripted run through the Sky Citadel. Start with `-- --autotest`
## (add `--shots=/dir` to save screenshots, `--quit-after-test` to exit),
## or open the web build with `?autotest`. Prints "CITADEL RESULT n/m PASS".
var game: Node
var results: Array = []
var shots: String = ""
var quit_after: bool = false

func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.trim_prefix("--shots=")
		if a == "--quit-after-test":
			quit_after = true
	run.call_deferred()

func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func check(name: String, ok: bool, info: String = "") -> void:
	results.append(ok)
	print("CITADEL ", "PASS " if ok else "FAIL ", name, "  ", info)

func shot(name: String) -> void:
	if shots.is_empty():
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [shots, name])

func place(pos: Vector3, yaw: float = 0.0) -> void:
	game.hero.global_position = pos
	game.hero.velocity = Vector3.ZERO
	game.hero.yaw = yaw
	game.hero.state = "idle"
	game.cam_pos = pos + Vector3(0, 5.6, 8.2)

func knight(i: int) -> CharacterBody3D:
	return game.enemies[i]

func run() -> void:
	await wait(0.8)
	await shot("00_title")
	game.start_game()
	await wait(0.6)
	check("hero and cast spawn", game.hero.hp == 100 and game.enemies.size() == 11 and game.ally != null)
	await shot("01_start")
	await stealth_tests()
	game.restart_with(game.hero_key)
	game.start_game()
	await wait(0.4)
	# Move with the left stick.
	var z0: float = game.hero.global_position.z
	game.hud.stick = Vector2(0, -1)
	await wait(0.7)
	game.hud.stick = Vector2.ZERO
	check("left stick moves the hero", game.hero.global_position.z < z0 - 2.0, "dz=%.2f" % (game.hero.global_position.z - z0))
	# Attack a knight.
	var k: CharacterBody3D = knight(0)
	place(k.global_position + Vector3(0, 0, 1.6), 0.0)
	k.active = true
	k.attack_cd = 9.0
	game.hud.pressed["attack"] = true
	await wait(0.25)
	await shot("02_attack")
	await wait(0.35)
	check("attack damages a knight", k.hp < k.max_hp, "hp=%d" % k.hp)
	# Block: held block soaks the hit.
	game.hud.holds["block"] = 1
	await wait(0.5)
	var hp0: float = game.hero.hp
	var st0: float = game.stamina
	game.hero.yaw = 0.0
	k.yaw = PI
	game.enemy_hits(k, 12.0, 3.0, -1.0)
	check("block stops damage", game.hero.hp == hp0 and game.stamina < st0, "hp %d st %d" % [game.hero.hp, game.stamina])
	await shot("03_block")
	# Parry: a fresh block right before the hit staggers the knight.
	game.hud.holds["block"] = 0
	await wait(0.15)
	game.hud.holds["block"] = 1
	await wait(0.05)
	game.enemy_hits(k, 12.0, 3.0, -1.0)
	check("early block parries", k.state == "stagger" and game.parries == 1, "state=%s" % k.state)
	game.hud.holds["block"] = 0
	await wait(0.2)
	# Dodge gives invulnerability frames.
	var k1: CharacterBody3D = knight(1)
	var k2: CharacterBody3D = knight(2)
	k1.attack_cd = 99.0
	k2.attack_cd = 99.0
	k.attack_cd = 99.0
	var hp_d: float = game.hero.hp
	game.hud.pressed["dodge"] = true
	await wait(0.06)
	game.enemy_hits(k, 12.0, 30.0, -1.0)
	check("dodge avoids a hit", game.hero.hp == hp_d and game.hero.state == "dodge", "state=%s" % game.hero.state)
	await wait(0.4)
	# Drag on the right side turns the camera.
	var yaw0: float = game.cam_yaw
	game.hud.look_delta = Vector2(160, 0)
	await wait(0.1)
	check("right-side drag turns the camera", absf(game.cam_yaw - yaw0) > 0.5, "yaw=%.2f" % game.cam_yaw)
	game.cam_yaw = 0.0
	# Tap to mark two knights, then charged dash through them.
	place(Vector3(0, 0.2, -10), 0.0)
	k1.global_position = Vector3(-2, 0.2, -16)
	k2.global_position = Vector3(2, 0.2, -18)
	await wait(0.4)
	game.tap_target(game.hud.project(k1.global_position + Vector3.UP * 1.0))
	game.tap_target(game.hud.project(k2.global_position + Vector3.UP * 1.0))
	check("tapping enemies marks them", game.marks.size() == 2, "marks=%d" % game.marks.size())
	var h1: float = k1.hp
	var h2: float = k2.hp
	game.hud.holds["skill"] = 1
	await wait(0.9)
	await shot("02b_charge")
	check("holding CHARGE fills the charge", game.charge >= 1.0, "charge=%.2f" % game.charge)
	game.hud.holds["skill"] = 0
	game.hud.released["skill"] = true
	await wait(0.3)
	await shot("02c_dash")
	await wait(0.4)
	check("charged dash hits every mark", k1.hp < h1 and k2.hp < h2, "%d %d" % [k1.hp, k2.hp])
	# Magic seeks the remaining marks.
	game.mana = 100.0
	var h3: float = k2.hp
	if k2.alive() and not (k2 in game.marks):
		game.marks.append(k2)
	game.hud.pressed["magic"] = true
	await wait(0.25)
	await shot("02d_magic")
	await wait(1.2)
	check("magic seeks a marked enemy", k2.hp < h3 or not k2.alive(), "hp=%d mana=%d" % [k2.hp, game.mana])
	# Potion heals and counts down.
	game.hero.hp = 50
	game.hud.pressed["potion"] = true
	await wait(0.1)
	check("potion heals", game.hero.hp == 90 and game.potions == 2, "hp=%d left=%d" % [game.hero.hp, game.potions])
	# Clear the courtyard and open the gate.
	for i in 3:
		knight(i).damage(999, knight(i).global_position + Vector3.FORWARD, 0)
	await wait(0.4)
	check("courtyard clear opens the bridge", game.section == 1 and not is_instance_valid(game.barriers[0]))
	# Jump the first bridge gap.
	place(Vector3(0, 0.2, -49.5), 0.0)
	await wait(0.3)
	game.hud.stick = Vector2(0, -1)
	await wait(0.22)
	game.hud.pressed["jump"] = true
	await wait(0.3)
	await shot("04_jump")
	await wait(0.6)
	game.hud.stick = Vector2.ZERO
	await wait(0.4)
	check("jump clears the bridge gap", game.hero.global_position.z < -55.0 and game.hero.global_position.y > -0.5, "pos=%s" % game.hero.global_position)
	# Falling into a gap costs health and returns you to the bridge.
	var hp1: float = game.hero.hp
	place(Vector3(0, 0.5, -53.3), 0.0)
	await wait(1.6)
	check("falling respawns on the bridge", game.hero.hp == hp1 - 15 and game.hero.global_position.y > -1.0, "hp=%d" % game.hero.hp)
	# Bridge and plaza.
	for i in range(3, 10):
		knight(i).damage(999, knight(i).global_position + Vector3.FORWARD, 0)
	await wait(0.4)
	await wait(0.3)
	check("sections advance to the throne", game.section == 3, "section=%d" % game.section)
	# Boss intro and shockwave.
	place(Vector3(0, 0.2, -140), 0.0)
	await wait(0.6)
	check("boss wakes when the hero enters", game.boss_seen and game.boss.active)
	await shot("05_boss")
	game.boss.attack_cd = 99.0
	game.boss.global_position = Vector3(0, 0.2, -150)
	game.boss.state = "idle"
	place(Vector3(0, 0.2, -146), 0.0)
	game.hero.hp = 100
	await wait(0.3)
	game.shockwave(Vector3(0, 0.0, -150), false)
	await wait(1.2)
	check("standing shockwave hurts", game.hero.hp < 100, "hp=%d" % game.hero.hp)
	game.hero.hp = 100
	game.hero.state = "idle"
	await wait(0.6)
	game.shockwave(Vector3(0, 0.0, -150), false)
	await wait(0.12)
	game.hud.pressed["jump"] = true
	await wait(0.2)
	await shot("06_dodge")
	await wait(1.0)
	check("jumping over the shockwave avoids it", game.hero.hp == 100, "hp=%d" % game.hero.hp)
	# Plunge attack from the air.
	game.boss.attack_cd = 99.0
	place(game.boss.global_position + Vector3(0, 0.2, 2.2), 0.0)
	var bhp: float = game.boss.hp
	game.hud.pressed["jump"] = true
	await wait(0.25)
	game.hud.pressed["attack"] = true
	await wait(0.9)
	check("air attack plunges into the boss", game.boss.hp < bhp, "boss hp=%d" % game.boss.hp)
	# Finish.
	game.boss.damage(9999, game.hero.global_position, 0)
	await wait(2.8)
	check("defeating the Dark Knight wins", game.mode == "win", "mode=%s" % game.mode)
	await shot("07_win")
	var passed: int = results.count(true)
	print("CITADEL RESULT %d/%d %s" % [passed, results.size(), "PASS" if passed == results.size() else "FAIL"])
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__cc={done:true,passed:%d,total:%d}" % [passed, results.size()])
	if quit_after:
		get_tree().quit()


func hold_guard(e: CharacterBody3D, pos: Vector3, yaw: float) -> void:
	## Freeze a patrol guard in place, facing a set way.
	e.global_position = pos
	e.velocity = Vector3.ZERO
	e.route = [Vector2(pos.x, pos.z)]
	e.route_i = 0
	e.gstate = "PATROL"
	e.suspicion = 0.0
	e.yaw = yaw

func tap(action: String) -> void:
	game.hud.pressed[action] = true
	game.hud.holds[action] = 1
	await wait(0.08)
	game.hud.holds[action] = 0
	game.hud.released[action] = true
	await wait(0.08)

func stealth_tests() -> void:
	check("starts hidden", game.stealth_status() == "HIDDEN", game.stealth_status())
	var g0: CharacterBody3D = knight(0)
	var g1: CharacterBody3D = knight(1)
	var g2: CharacterBody3D = knight(2)
	hold_guard(g0, Vector3(-11, 0.2, -2), 0.0)
	hold_guard(g1, Vector3(11, 0.2, -36), 0.0)
	hold_guard(g2, Vector3(-11, 0.2, -36), 0.0)
	# Crouch, then hold for crawl, then tap to stand.
	place(Vector3(0, 0.2, -4), 0.0)
	await wait(0.2)
	await tap("crouch")
	var cap: CapsuleShape3D = (game.hero.get_child(0) as CollisionShape3D).shape
	check("CROUCH lowers the hero", game.crouched and cap.height < 1.5, "h=%.2f" % cap.height)
	game.hud.pressed["crouch"] = true
	game.hud.holds["crouch"] = 1
	await wait(0.6)
	game.hud.holds["crouch"] = 0
	game.hud.released["crouch"] = true
	await wait(0.1)
	check("holding CROUCH crawls", game.prone and cap.height < 0.8, "prone=%s" % game.prone)
	game.hud.stick = Vector2(0, -1)
	await wait(0.5)
	await shot("s1_crawl")
	game.hud.stick = Vector2.ZERO
	await tap("crouch")
	check("tap again stands up", not game.prone and not game.crouched)
	# Wall hug on the low planter at (-6, -9): auto-crouch, slide, peek at the edge.
	place(Vector3(-6, 0.2, -7.5), 0.0)
	await wait(0.3)
	await tap("hug")
	check("WALL HUG snaps to cover", game.in_cover() and game.cover_low and game.crouched, "cover=%s low=%s" % [game.in_cover(), game.cover_low])
	var x0: float = game.hero.global_position.x
	game.hud.stick = Vector2(1, 0)
	await wait(1.4)
	await shot("s2_hug_slide")
	check("slides along the wall", game.in_cover() and game.hero.global_position.x > x0 + 1.0, "dx=%.2f" % (game.hero.global_position.x - x0))
	check("stops and peeks at the edge", game.peek_dir.length() > 0.5, "peek=%s" % game.peek_dir)
	game.hud.stick = Vector2.ZERO
	game.hud.holds["peek"] = 1
	await wait(0.6)
	await shot("s3_peek")
	check("holding PEEK looks around the corner", game.peeking and game.peek_dir.length() > 0.5)
	game.hud.holds["peek"] = 0
	await wait(0.1)
	# Knock on the wall: a guard within 11 m comes to look.
	hold_guard(g0, Vector3(2, 0.2, -16), 0.0)
	await tap("distract")
	check("DISTRACT knock draws a guard", g0.gstate == "INVESTIGATE", "state=%s" % g0.gstate)
	await wait(0.6)
	await shot("s4_investigate")
	hold_guard(g0, Vector3(-11, 0.2, -2), 0.0)
	await tap("hug")
	check("leaving low cover stands up", not game.in_cover() and not game.crouched)
	# Thrown distraction when not in cover.
	place(Vector3(0, 0.2, -6), 0.0)
	hold_guard(g2, Vector3(4, 0.2, -18), PI)
	await wait(0.2)
	await tap("distract")
	await wait(0.8)
	check("thrown pebble draws a guard", g2.gstate == "INVESTIGATE", "state=%s" % g2.gstate)
	hold_guard(g2, Vector3(-11, 0.2, -36), 0.0)
	# Low cover hides a crouched hero; standing up gets noticed.
	hold_guard(g1, Vector3(-6, 0.2, -14.5), PI)
	game.set_crouch(false)
	place(Vector3(-6, 0.2, -7.4), 0.0)
	await tap("crouch")
	await wait(1.2)
	check("crouched behind low cover stays hidden", g1.suspicion == 0.0 and game.stealth_status() == "HIDDEN", "sus=%.2f" % g1.suspicion)
	await tap("crouch")
	await wait(0.5)
	await shot("s5_seen")
	check("standing up in view raises suspicion", g1.suspicion > 0.2 and game.stealth_status() == "SUSPICIOUS", "sus=%.2f %s" % [g1.suspicion, game.stealth_status()])
	await wait(1.0)
	check("full suspicion raises the alarm", g1.active and game.stealth_status() == "ALERT", game.stealth_status())
	# Silent takedown from behind an unaware guard.
	for g: CharacterBody3D in [g0, g2]:
		g.active = false
		g.state = "idle"
	hold_guard(g0, Vector3(6, 0.2, -4), 0.0)
	g1.active = false
	g1.state = "idle"
	hold_guard(g1, Vector3(11, 0.2, -36), 0.0)
	place(Vector3(6, 0.2, -2.3), 0.0)
	await wait(0.2)
	game.hud.pressed["attack"] = true
	await wait(0.4)
	check("attacking an unaware guard is a silent takedown", not g0.alive() and game.takedowns == 1 and not g2.active, "takedowns=%d" % game.takedowns)
	await shot("s6_takedown")
