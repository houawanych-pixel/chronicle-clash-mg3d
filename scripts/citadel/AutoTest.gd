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
	await wait(0.19)
	await shot("02_attack")
	await wait(0.06)
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
	await forest_tests()
	await village_tests()
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


func forest_tests() -> void:
	game.restart_with("lance", "forest")
	await wait(0.3)
	await shot("f0_title")
	game.start_game()
	await wait(0.5)
	var hunter: CharacterBody3D = game.boss
	check("forest stage loads with Lance, Eliza and Blonde Lance", game.stage == "forest" and game.hero_key == "lance" and hunter.kind == "hunter" and game.grass.size() > 4 and game.enemies.size() == 7, "enemies=%d grass=%d" % [game.enemies.size(), game.grass.size()])
	var ks: Array = game.enemies.filter(func(e: Variant) -> bool: return e.kind == "knight")
	for i in ks.size():
		hold_guard(ks[i], Vector3(-12 + i * 0.1, 0.2, 4.0 - i * 0.5), PI)
	hold_guard(hunter, Vector3(12, 0.2, -110), 0.0)
	await shot("f1_start")
	# Eliza keeps up.
	game.hud.stick = Vector2(0, -1)
	await wait(1.2)
	game.hud.stick = Vector2.ZERO
	await wait(0.6)
	check("Eliza follows close behind", game.ally.global_position.distance_to(game.hero.global_position) < 3.0, "d=%.2f" % game.ally.global_position.distance_to(game.hero.global_position))
	# Tall grass: crouched you vanish, standing you are seen.
	var g: CharacterBody3D = ks[0]
	hold_guard(g, Vector3(-3, 0.2, -25), PI / 2.0)
	place(Vector3(-8.5, 0.2, -25), 0.0)
	game.set_crouch(true)
	await wait(1.2)
	check("crouched in tall grass stays hidden", game.hero_in_grass() and g.suspicion == 0.0 and game.stealth_status() == "HIDDEN", "sus=%.2f" % g.suspicion)
	check("Eliza crouches with you", game.ally.rig.position.y < -0.15, "y=%.2f" % game.ally.rig.position.y)
	await shot("f2_grass")
	game.set_crouch(false)
	await wait(0.5)
	check("standing in the grass gets noticed", g.suspicion > 0.2, "sus=%.2f" % g.suspicion)
	hold_guard(g, Vector3(-12, 0.2, 4), PI)
	await wait(0.3)
	# Boulders are cover.
	place(Vector3(-1.5, 0.2, -14.9), 0.0)
	await wait(0.3)
	await tap("hug")
	check("wall hug works on a boulder", game.in_cover() and not game.cover_low, "cover=%s" % game.in_cover())
	await shot("f3_rock")
	await tap("hug")
	# Spotted in the open: alarm and two knights from behind.
	var before: int = game.enemies.size()
	hold_guard(g, Vector3(4, 0.2, -30), PI)
	place(Vector3(4, 0.2, -24), 0.0)
	await wait(1.6)
	var extra: Array = game.enemies.filter(func(e: Variant) -> bool: return e.has_meta("reinforcement"))
	check("being spotted calls knights in from behind", g.active and game.enemies.size() == before + 2 and extra.size() == 2 and extra[0].global_position.z > -24.0, "n=%d" % game.enemies.size())
	await shot("f4_alarm")
	# Hide in the grass and they lose you.
	for e: CharacterBody3D in extra:
		e.global_position = Vector3(12, 0.2, 2)
		e.attack_cd = 99.0
	g.attack_cd = 99.0
	place(Vector3(-9.5, 0.2, -32), 0.0)
	game.set_crouch(true)
	await wait(5.8)
	check("hidden long enough, the guard gives up the chase", not g.active and g.gstate in ["INVESTIGATE", "SEARCH", "PATROL"], "active=%s state=%s" % [g.active, g.gstate])
	game.set_crouch(false)
	for e: CharacterBody3D in extra:
		e.damage(999, e.global_position + Vector3.FORWARD, 0)
	# Blonde Lance sweeps closer into the grass than the knights.
	place(Vector3(-10, 0.2, -60), 0.0)
	game.set_crouch(true)
	hold_guard(g, Vector3(-10, 0.2, -57.6), 0.0)
	g.yaw = PI
	hold_guard(hunter, Vector3(-12.5, 0.2, -60), -PI / 2.0)
	await wait(0.6)
	check("Blonde Lance spots you in the grass up close; knights don't", hunter.suspicion > 0.2 and g.suspicion == 0.0, "hunter=%.2f knight=%.2f" % [hunter.suspicion, g.suspicion])
	await shot("f5_hunter")
	hold_guard(g, Vector3(-12, 0.2, 4), PI)
	await wait(1.0)
	check("Blonde Lance attacks when he finds you", hunter.active, "active=%s" % hunter.active)
	game.set_crouch(false)
	# He breaks off when hurt and turns up further on.
	hunter.damage(hunter.max_hp * 0.4, game.hero.global_position, 0)
	await wait(0.3)
	check("Blonde Lance retreats when hurt and reappears ahead", not hunter.active and hunter.global_position.z < -80.0 and hunter.alive(), "z=%.1f" % hunter.global_position.z)
	# Knights go for Eliza when she is closer.
	var k2: CharacterBody3D = ks[1]
	k2.active = true
	k2.global_position = game.ally.global_position + Vector3(0, 0, 1.2)
	k2.yaw = 0.0
	var ahp: float = game.ally.hp
	place(game.ally.global_position + Vector3(0, 0, -4), 0.0)
	game.ally.global_position = k2.global_position + Vector3(0, 0, -1.2)
	k2.yaw = 0.0
	game.enemy_hits(k2, 12.0, 3.0, -1.0)
	check("knights can hit Eliza", game.ally.hp < ahp, "hp=%d" % game.ally.hp)
	game.ally.damage(999, k2.global_position, 0)
	await wait(1.6)
	check("losing Eliza fails the stage", game.mode == "dead" and game.fail_text == "SHE WAS CAPTURED", game.fail_text)
	await shot("f6_captured")
	game.respawn()
	await wait(0.3)
	check("retry restores Eliza", game.mode == "play" and game.ally.alive() and game.ally.hp == game.ally.max_hp)
	# Reach the forest edge.
	for e: CharacterBody3D in game.enemies:
		e.attack_cd = 99.0
		if e.alive() and e != hunter:
			hold_guard(e, Vector3(-12, 0.2, 4), PI)
	place(Vector3(0, 0.2, -108), 0.0)
	game.hud.stick = Vector2(0, -1)
	await wait(0.8)
	game.hud.stick = Vector2.ZERO
	await wait(2.0)
	check("reaching the forest edge escapes", game.mode == "win" and game.win_text == "ESCAPED THE FOREST", "mode=%s" % game.mode)
	await shot("f7_escaped")


const SaveScript = preload("res://scripts/citadel/VillageSave.gd")

func vill(id: String) -> Node:
	for v: Node in game.village.villagers:
		if v.vid == id:
			return v
	return null

func village_tests() -> void:
	SaveScript.clear()
	game.restart_with("blonde_lance", "village")
	await wait(0.3)
	game.start_game()
	await wait(0.6)
	var vg: RefCounted = game.village
	check("village loads with 6 villagers in Village Square", game.stage == "village" and vg.block == "square" and vg.villagers.size() == 6, "n=%d" % vg.villagers.size())
	check("village has a walkable navigation mesh", vg.region != null and vg.region.navigation_mesh.get_polygon_count() > 20, "polys=%d" % vg.region.navigation_mesh.get_polygon_count())
	await shot("v0_square")
	# Work hours: woodcutter, miner and fisher reach their spots and work.
	vg.speed = 6.0
	place(Vector3(0, 0.2, 9.0), PI)
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 25000:
		await wait(0.5)
		if vill("sq_bram").state == "work" and vill("sq_mara").state == "work" and vill("sq_finn").state == "work":
			break
	var bram: Node = vill("sq_bram")
	var mara: Node = vill("sq_mara")
	var finn: Node = vill("sq_finn")
	check("woodcutter chops a tree", bram.state == "work" and bram.spot != null and bram.spot.kind == "tree", "state=%s" % bram.state)
	check("miner mines a rock", mara.state == "work" and mara.spot != null and mara.spot.kind == "rock", "state=%s" % mara.state)
	check("fisher fishes from the dock", finn.state == "work" and finn.spot != null and finn.spot.kind == "fish", "state=%s" % finn.state)
	await shot("v1_work")
	# No two villagers on one spot, and a held spot can't be taken.
	var held: Dictionary = {}
	var clash: bool = false
	for v: Node in vg.villagers:
		if v.spot:
			if held.has(v.spot.id):
				clash = true
			held[v.spot.id] = true
	check("work spots are never shared", not clash and not bram.spot.claim(mara), "held=%s" % [held.keys()])
	# Talking: the hero walks up, the villager stops, speaks, then goes back to work.
	place(bram.global_position + (bram.spot.pos - bram.spot.look).normalized() * 1.5, 0.0)
	await wait(0.4)
	check("villager stops to talk when the hero comes close", bram.state == "talk" and bram.bubble.visible, "state=%s" % bram.state)
	await shot("v2_talk")
	place(Vector3(0, 0.2, 9.0), PI)
	await wait(3.5)
	check("villager goes back to work after talking", bram.state in ["work", "walk", "idle"] and not bram.bubble.visible, "state=%s" % bram.state)
	# A finished work cycle is carried to the drop spot.
	vg.speed = 30.0
	var c0: int = bram.work_count + finn.work_count + mara.work_count
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 25000:
		await wait(0.5)
		if vg.deliveries.size() >= 1:
			break
	check("finished work is carried to the drop pile", bram.work_count + finn.work_count + mara.work_count > c0 and vg.deliveries.size() >= 1, "deliveries=%s" % [vg.deliveries])
	# Blocked path recovery: drop a villager inside a building; it gets out and carries on.
	vg.speed = 6.0
	var lia: Node = vill("sq_lia")
	lia.global_position = Vector3(-12, 0.3, -13.0)
	lia.go_to(Vector3(0, 0, 4), "point")
	await wait(9.0)
	check("a stuck villager recovers and moves on", lia.recoveries > 0 and lia.global_position.distance_to(Vector3(-12, 0, -13)) > 2.0, "recov=%d pos=%s" % [lia.recoveries, lia.global_position])
	# Save, leave the village, come back: everyone is where they were.
	vg.speed = 1.0
	await wait(0.5)
	var before: Dictionary = {}
	for v: Node in vg.villagers:
		before[v.vid] = [v.global_position, v.state, v.work_count]
	var clock_before: float = vg.clock
	game.restart_with("blonde_lance", "citadel")
	await wait(0.4)
	check("leaving the village frees its villagers and keeps the castle working", game.stage == "citadel" and vg.villagers.is_empty() and game.enemies.size() == 11)
	await wait(1.0)
	game.restart_with("blonde_lance", "village")
	await wait(0.4)
	game.start_game()
	await wait(0.2)
	var moved: float = 0.0
	var same_state: int = 0
	for v: Node in vg.villagers:
		var b: Array = before[v.vid]
		moved = maxf(moved, v.global_position.distance_to(b[0]))
		if v.state == b[1] or (b[1] == "talk"):
			same_state += 1
	check("reopening the village restores villagers and the clock", absf(vg.clock - clock_before) < 2.0 and moved < 1.6 and same_state >= 5, "moved=%.2f same=%d clock=%.1f/%.1f" % [moved, same_state, vg.clock, clock_before])
	# Walk off the east road into Mill Lane, then back.
	place(Vector3(18.5, 0.2, 0.0), -PI / 2.0)
	game.hud.stick = Vector2(1, 0)
	await wait(1.2)
	game.hud.stick = Vector2.ZERO
	await wait(0.4)
	check("the east road loads Mill Lane with its own villagers", vg.block == "mill" and vg.villagers.size() == 6 and vill("ml_wes") != null and game.hero.global_position.x < -10.0, "block=%s x=%.1f" % [vg.block, game.hero.global_position.x])
	vg.speed = 8.0
	place(Vector3(-14, 0.2, 0.0), -PI / 2.0)
	t0 = Time.get_ticks_msec()
	var farmed: bool = false
	var milled: bool = false
	while Time.get_ticks_msec() - t0 < 25000:
		await wait(0.5)
		farmed = farmed or (vill("ml_ada").state == "work" and vill("ml_ada").spot.kind == "field")
		milled = milled or vill("ml_wes").state == "inside"
		if farmed and milled:
			break
	check("farmers tend the field and the miller goes into the windmill", farmed and milled, "farm=%s mill=%s" % [farmed, milled])
	await shot("v3_mill")
	vg.speed = 1.0
	place(Vector3(-18.5, 0.2, 0.0), PI / 2.0)
	game.hud.stick = Vector2(-1, 0)
	await wait(1.2)
	game.hud.stick = Vector2.ZERO
	await wait(0.4)
	check("the west road leads back to Village Square", vg.block == "square" and vill("sq_bram") != null and game.hero.global_position.x > 10.0, "block=%s" % vg.block)
	# Villagers never leave their block.
	var inside: bool = true
	for v: Node in vg.villagers:
		if absf(v.global_position.x) > 20.5 or absf(v.global_position.z) > 20.5:
			inside = false
	check("villagers stay inside their own block", inside)
	# Night: everyone heads home and goes inside.
	vg.clock = floor(vg.clock / 1440.0) * 1440.0 + 21.6 * 60.0
	vg.speed = 4.0
	t0 = Time.get_ticks_msec()
	var asleep: int = 0
	while Time.get_ticks_msec() - t0 < 30000:
		await wait(0.5)
		asleep = 0
		for v: Node in vg.villagers:
			if v.state == "inside":
				asleep += 1
		if asleep == vg.villagers.size():
			break
	check("at night villagers go home and inside", asleep == vg.villagers.size(), "inside=%d" % asleep)
	await shot("v4_night")
	vg.speed = 1.0
	SaveScript.clear()
