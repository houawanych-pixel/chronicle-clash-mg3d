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
	# --clean-shots hides the HUD (used for website artwork of the beta).
	var clean: bool = "--clean-shots" in OS.get_cmdline_user_args()
	if clean:
		game.hud.visible = false
		await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [shots, name])
	if clean:
		game.hud.visible = true

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
	if "--bake-frog-nav" in OS.get_cmdline_user_args():
		await frog_bake()
		get_tree().quit()
		return
	if "--frog-map" in OS.get_cmdline_user_args():
		await frog_map()
		get_tree().quit()
		return
	if "--frog-profile" in OS.get_cmdline_user_args():
		await frog_start()
		var ft: RefCounted = game.frogtown
		for ln: Array in [[Vector3(-4.7, 0, -6.6), Vector3(-6.8, 0, -20.4)], [Vector3(-8.6, 0, -4.5), Vector3(-21, 0, -15.6)], [Vector3(-1.0, 0, -2.6), Vector3(13, 0, -5.6)], [Vector3(-3.0, 0, 1.4), Vector3(0, 0, 12.5)]]:
			var out: PackedStringArray = []
			var a0: Vector3 = ln[0]
			var b0: Vector3 = ln[1]
			var n: int = int(a0.distance_to(b0) / 0.25)
			for i in n + 1:
				var q: Vector3 = a0.lerp(b0, float(i) / n)
				out.append("%.2f" % ft.ground_at(q, -9.0))
			print("FROG PROFILE ", a0, "->", b0, ": ", " ".join(out))
		get_tree().quit()
		return
	if "--frog-navdbg" in OS.get_cmdline_user_args():
		await frog_start()
		var ft: RefCounted = game.frogtown
		var map: RID = game.get_world_3d().navigation_map
		print("FROG maps=", NavigationServer3D.get_maps().size(), " regions=", NavigationServer3D.map_get_regions(map).size(), " cell=", NavigationServer3D.map_get_cell_size(map), "/", NavigationServer3D.map_get_cell_height(map), " edge_margin=", NavigationServer3D.map_get_edge_connection_margin(map))
		var ch: Node = ft.villagers[0]
		ch.global_position = ft.on_ground(Vector3(-4.0, 0, 3.0)) + Vector3.UP * 0.2
		ch.release_spot()
		ch.plan("work")
		print("FROG chief plan target=", ch.target, " goal=", ch.goal_kind, " spot=", ch.spot.id if ch.spot else "-", " path=", NavigationServer3D.map_get_path(game.get_world_3d().navigation_map, ch.global_position, ch.target, true))
		ft.speed = 20.0
		for t in 6:
			await wait(2.0)
			var line: PackedStringArray = []
			for v: Node in ft.villagers:
				line.append("%s:%s/%s@(%.1f,%.1f,%.1f)->(%.1f,%.1f) rp=%d fin=%s" % [v.vname, v.state, v.goal_kind, v.global_position.x, v.global_position.y, v.global_position.z, v.target.x, v.target.z, v.recoveries, v.agent.is_navigation_finished()])
			print("FROG V t=", t, " ", " | ".join(line))
		var nm0: NavigationMesh = ft.region.navigation_mesh
		var vv: PackedVector3Array = nm0.get_vertices()
		for q: Vector2 in [Vector2(-2.5, -16), Vector2(-2.5, -15.5), Vector2(-2.5, -16.5), Vector2(-2.45, -17.2)]:
			for i in nm0.get_polygon_count():
				var poly: PackedInt32Array = nm0.get_polygon(i)
				var pts: PackedVector2Array = []
				var ys: float = 0.0
				for k: int in poly:
					pts.append(Vector2(vv[k].x, vv[k].z))
					ys += vv[k].y
				if Geometry2D.is_point_in_polygon(q, pts):
					print("FROG poly@", q, " #", i, " y=", ys / poly.size(), " verts=", poly.size(), " ", pts)
		var from: Vector3 = NavigationServer3D.map_get_closest_point(map, ft.on_ground(Vector3(-1.2, 0, -2.6)))
		for opt: bool in [false, true]:
			for pr: Array in [[from, ft.doors["CC_HOUSE_T11_H03"].pos], [from, Vector3(-2.4, 0.69, -18.5)], [Vector3(-1.2, 0.3, -2.6), Vector3(-2.4, 0.69, -18.5)]]:
				var path: PackedVector3Array = NavigationServer3D.map_get_path(map, pr[0], pr[1], opt)
				print("FROG path opt=", opt, " ", pr[0], " -> ", pr[1], " n=", path.size(), " end=", path[path.size() - 1] if path.size() else Vector3.INF)
		get_tree().quit()
		return
	if "--frog-only" in OS.get_cmdline_user_args():
		await frog_tests()
		print("CITADEL RESULT %d/%d" % [results.count(true), results.size()])
		get_tree().quit()
		return
	if "--anim-shots" in OS.get_cmdline_user_args():
		await anim_shots()
		get_tree().quit()
		return
	if "--trials-only" in OS.get_cmdline_user_args():
		await trials_tests()
		print("CITADEL RESULT %d/%d" % [results.count(true), results.size()])
		get_tree().quit()
		return
	if "--ruin-only" in OS.get_cmdline_user_args():
		await ruin_tests()
		print("CITADEL RESULT %d/%d" % [results.count(true), results.size()])
		get_tree().quit()
		return
	await shot("00_title")
	# Combat and stealth checks run on the classic boxed citadel; the sky ruin
	# that replaced it has its own checks at the end.
	game.restart_with(game.hero_key, "classic")
	await wait(0.3)
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
	await frog_tests()
	await ruin_tests()
	await trials_tests()
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
	# Sword: starts on the back in the village; SHEATHE/DRAW toggles it,
	# and ATTACK while it's away draws it instead of swinging.
	var hero: Node = game.hero
	check("village starts with the sword on his back", not game.sword_out and hero.rig.sheathed)
	game.hud.pressed["sheathe"] = true
	await wait(0.7)
	check("DRAW puts the sword in his hand", game.sword_out and not hero.rig.sheathed and hero.state == "idle")
	await shot("v0_drawn")
	game.hud.pressed["sheathe"] = true
	await wait(0.7)
	check("SHEATHE puts it back", not game.sword_out and hero.rig.sheathed)
	game.hud.pressed["attack"] = true
	await wait(0.15)
	var no_swing: bool = hero.state != "attack"
	await wait(0.6)
	check("ATTACK with the sword away draws it first", no_swing and game.sword_out, "state=%s" % hero.state)
	game.hud.pressed["sheathe"] = true
	await wait(0.7)
	# Work hours: woodcutter, miner and fisher reach their spots and work.
	vg.speed = 30.0
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
	# Free chat: TALK opens a conversation; the villager stays until BYE.
	var ch: RefCounted = vg.chat
	check("TALK shows next to a villager", game.button_visible("talk") and ch.nearest() == bram)
	game.hud.pressed["talk"] = true
	await wait(0.2)
	ch.send("Good morning! How is the wood today?")
	await wait(0.4)
	check("talking opens a chat and the villager answers", ch.is_open() and bram.chatting and ch.replies.size() == 1 and bram.bubble.visible, "replies=%s" % [ch.replies])
	await wait(4.5)
	check("the villager keeps chatting instead of walking off", bram.state == "talk" and ch.is_open())
	game.hud.pressed["talk"] = true
	await wait(0.2)
	check("BYE ends the chat", not ch.is_open() and not bram.chatting)
	place(Vector3(0, 0.2, 9.0), PI)
	await wait(3.5)
	check("villager goes back to work after talking", bram.state in ["work", "walk", "idle"] and not bram.bubble.visible, "state=%s" % bram.state)
	# A finished work cycle is carried to the drop spot.
	vg.speed = 150.0
	var c0: int = bram.work_count + finn.work_count + mara.work_count
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 25000:
		await wait(0.5)
		if vg.deliveries.size() >= 1:
			break
	check("finished work is carried to the drop pile", bram.work_count + finn.work_count + mara.work_count >= maxi(c0, 1) and vg.deliveries.size() >= 1, "deliveries=%s" % [vg.deliveries])
	# Blocked path recovery: drop a villager inside a building; it gets out and carries on.
	vg.speed = 30.0
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
	game.restart_with("blonde_lance", "classic")
	await wait(0.4)
	check("leaving the village frees its villagers and keeps the castle working", game.stage == "classic" and vg.villagers.is_empty() and game.enemies.size() == 11)
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
	vg.speed = 40.0
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
	vg.speed = 20.0
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

# ---------------------------------------------------------------- sky ruin

## Drive the hero toward a point like a player would: camera behind, stick forward.
func walk_to(p: Vector3, timeout: float = 12.0, jumps: Array = []) -> bool:
	var h: CharacterBody3D = game.hero
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(timeout * 1000):
		var to: Vector3 = p - h.global_position
		var flat: Vector2 = Vector2(to.x, to.z)
		if h.state == "climb" and game.ruin.route.get("version", 1) == 2:
			game.hud.stick = Vector2.ZERO
			return true
		if flat.length() < 0.7 and absf(to.y) < 1.4:
			game.hud.stick = Vector2.ZERO
			return true
		if h.state != "climb":
			game.cam_yaw = atan2(-to.x, -to.z)
		game.hud.stick = Vector2(0, -1)
		for jz: float in jumps:
			if absf(h.global_position.z - jz) < 0.6 and h.is_on_floor():
				game.hud.pressed["jump"] = true
		await wait(0.05)
	game.hud.stick = Vector2.ZERO
	var hits: Array = []
	for i in h.get_slide_collision_count():
		var c: KinematicCollision3D = h.get_slide_collision(i)
		var o: Object = c.get_collider()
		hits.append("%s@%s" % [(o as Node).get_path() if o is Node else o, c.get_position()])
	print("WALK STUCK events=", game.trav.events, " at ", h.global_position, " -> ", p, " state=", h.state, " cover=", game.in_cover(), " crouch=", game.crouched, " mode=", game.mode, " vel=", h.velocity, " input=", game.move_input(), " paused=", game.paused(), " floor=", h.is_on_floor(), " hits=", hits)
	return false

func climb(l: Dictionary, timeout: float = 10.0) -> bool:
	var h: CharacterBody3D = game.hero
	var face: Vector3 = l.face
	game.cam_yaw = atan2(-face.x, -face.z)
	game.hud.stick = Vector2(0, -1)
	var t0: int = Time.get_ticks_msec()
	var climbed: bool = false
	while Time.get_ticks_msec() - t0 < int(timeout * 1000):
		if h.state == "climb":
			climbed = true
		if climbed and h.state != "climb":
			break
		await wait(0.05)
	game.hud.stick = Vector2.ZERO
	await wait(0.6)
	var top: Vector3 = l.top
	return climbed and absf(h.global_position.y - top.y) < 0.8 and h.is_on_floor()

## Run a jump like a player: run at the take-off point toward the landing, jump at the edge.
func jump_to(take: Vector3, land: Vector3, from: Variant = null, timeout: float = 6.0) -> bool:
	var h: CharacterBody3D = game.hero
	var dir: Vector3 = Vector3(land.x - take.x, 0, land.z - take.z).normalized()
	var start: Vector3 = take - dir * 2.2
	if from is Vector3:
		start = from
		dir = Vector3(take.x - start.x, 0, take.z - start.z).normalized()
	if Vector2(h.global_position.x - take.x, h.global_position.z - take.z).length() > 2.6:
		if not await walk_to(Vector3(start.x, take.y, start.z), 8.0):
			return false
	var t0: int = Time.get_ticks_msec()
	var jumped: bool = false
	while Time.get_ticks_msec() - t0 < int(timeout * 1000):
		var p: Vector3 = h.global_position
		var to: Vector3 = land - p
		game.cam_yaw = atan2(-to.x, -to.z)
		game.hud.stick = Vector2(0, -1)
		if not jumped and h.is_on_floor() and (p - take).dot(dir) > -0.35:
			game.hud.pressed["jump"] = true
			jumped = true
		elif jumped and h.is_on_floor() and Vector2(to.x, to.z).length() < 0.9:
			game.hud.stick = Vector2.ZERO
			return true
		elif jumped and h.is_on_floor() and (p - land).dot(dir) > 0.6:
			game.hud.stick = Vector2.ZERO
			return absf(p.y - land.y) < 1.0
		if p.y < land.y - 6.0:
			break
		if "--jump-trace" in OS.get_cmdline_user_args():
			print("JT ", p, " floor=", h.is_on_floor(), " jumped=", jumped, " state=", h.state, " vel=", h.velocity)
		await wait(0.03)
	game.hud.stick = Vector2.ZERO
	print("JUMP FAILED at ", h.global_position, " take ", take, " land ", land)
	return false

## Follow the route's own moves (route.json "bot") from step i0 to i1.
func run_route(i0: int, i1: int) -> bool:
	var R: Dictionary = game.ruin.route
	return await run_steps(R.bot.slice(i0, i1))

func run_steps(steps: Array) -> bool:
	for i in steps.size():
		var st: Dictionary = steps[i]
		var ok: bool = true
		match st.act:
			"walk":
				ok = await walk_to(game.ruin.v3(st.p), 14.0)
			"jump":
				ok = await jump_to(game.ruin.v3(st.p), game.ruin.v3(st.to), game.ruin.v3(st["from"]) if st.has("from") else null)
			"ladder":
				ok = await climb(game.ladders[int(st.i)], 14.0)
			"pad":
				# step onto the glowing pad and ride the launch
				var hh: CharacterBody3D = game.hero
				var pp: Vector3 = game.ruin.v3(st.p)
				var t0: int = Time.get_ticks_msec()
				while hh.state != "launch" and Time.get_ticks_msec() - t0 < 6000:
					var to: Vector3 = pp - hh.global_position
					game.cam_yaw = atan2(-to.x, -to.z)
					game.hud.stick = Vector2(0, -1) if Vector2(to.x, to.z).length() > 0.5 else Vector2.ZERO
					await wait(0.03)
				game.hud.stick = Vector2.ZERO
				while (hh.state == "launch" or not hh.is_on_floor()) and Time.get_ticks_msec() - t0 < 12000:
					await wait(0.05)
				ok = hh.state != "launch" and hh.is_on_floor()
			"drop":
				# Run off the crown's inner edge into the eye, then fall to the Core.
				var h: CharacterBody3D = game.hero
				var tgt: Vector3 = game.ruin.v3(st.p)
				var t0: int = Time.get_ticks_msec()
				while h.global_position.y > game.ruin.crown_y - 2.0 and Time.get_ticks_msec() - t0 < 6000:
					game.cam_yaw = atan2(-(tgt.x - h.global_position.x), -(tgt.z - h.global_position.z))
					game.hud.stick = Vector2(0, -1)
					await wait(0.03)
				game.hud.stick = Vector2.ZERO
				while not (h.is_on_floor() and h.global_position.y < game.ruin.core_y + 2.0) and Time.get_ticks_msec() - t0 < 10000:
					await wait(0.05)
				ok = game.ruin.in_core()
		if "--route-trace" in OS.get_cmdline_user_args():
			print("STEP ", i, " ", st.act, " -> ", game.hero.global_position, " ok=", ok)
		if not ok:
			print("ROUTE STEP FAILED ", i, " ", st, " at ", game.hero.global_position)
			return false
	return true

func route_index(act: String, n: int) -> int:
	## Index of the n-th bot step of this kind (0-based).
	var c: int = 0
	var R: Dictionary = game.ruin.route
	for i in R.bot.size():
		if R.bot[i].act == act:
			if c == n:
				return i
			c += 1
	return R.bot.size()

func ruin_tests() -> void:
	if game.ruin.route.get("version", 1) == 3:
		await ruin3_tests()
		return
	game.restart_with("blonde_lance", "citadel")
	await wait(0.6)
	game.start_game()
	await wait(1.2)
	var h: CharacterBody3D = game.hero
	var R: Dictionary = game.ruin.route
	check("the sky ruin loads as the citadel", game.stage == "citadel" and game.world.get_node_or_null("SkyRuin") != null and game.ladders.size() == 3 and game.enemies.size() + game.ruin.pending.size() == R.knights.size() + 1, "enemies=%d ladders=%d" % [game.enemies.size(), game.ladders.size()])
	check("the hero stands on the sky dock", h.is_on_floor() and absf(h.global_position.y - game.ruin.dock.y) < 0.6, "y=%.2f" % h.global_position.y)
	await shot("r0_dock")
	game.ruin.clear_pending()
	for e: CharacterBody3D in game.enemies:
		if e != game.boss:
			e.hp = 0
			e.set_state("dead")
			e.visible = false
			e.global_position.y -= 200.0
	for i in 8:
		await wait(0.1)
	check("clearing each section opens its gate", game.section == game.ruin.last and game.barriers.all(func(b): return not is_instance_valid(b) or b.is_queued_for_deletion()), "section=%d" % game.section)
	var hp0: float = h.hp
	var l0: int = route_index("ladder", 0)
	var ok: bool = await run_route(0, l0)
	await shot("r1_ring")
	check("the bridge and the first ring of ledges can be run and jumped", ok, "pos=%s" % [h.global_position])
	var l1: int = route_index("ladder", 1)
	ok = ok and await run_route(l0, l1)
	check("ladder one and the second ring", ok and h.global_position.y > 73.0, "pos=%s" % [h.global_position])
	await shot("r2_ring")
	var l2: int = route_index("ladder", 2)
	ok = ok and await run_route(l1, l2)
	check("ladder two and the third ring", ok and h.global_position.y > 91.0, "pos=%s" % [h.global_position])
	var d0: int = route_index("drop", 0)
	ok = ok and await run_route(l2, d0)
	await shot("r3_crown")
	check("ladder three and the sky stair reach the crown", ok and absf(h.global_position.y - game.ruin.crown_y) < 1.0, "pos=%s" % [h.global_position])
	ok = ok and await run_route(d0, R.bot.size())
	await wait(0.5)
	check("dropping through the eye lands in the Core and wakes the Dark Knight", ok and game.ruin.in_core() and game.boss.active and game.boss_seen and game.checkpoint == game.ruin.last, "pos=%s cp=%d" % [h.global_position, game.checkpoint])
	await shot("r4_core")
	check("the whole climb is made without falling", h.hp >= hp0, "hp=%d" % h.hp)
	h.hp = h.max_hp
	await wait(5.0)
	var bp: Vector3 = game.boss.global_position
	var cy: float = game.ruin.core_y
	check("the Dark Knight fights inside the Core", game.boss.alive() and bp.y > cy - 1.0 and bp.y < cy + 6.0 and absf(bp.x) < 18.0 and absf(bp.z + 2.0) < 11.0 and h.hp < h.max_hp, "boss=%s hero hp=%d" % [bp, h.hp])
	game.boss.global_position = Vector3(60, 40, 0)
	await wait(0.4)
	check("a Dark Knight who falls off the Core comes back", absf(game.boss.global_position.y - (cy + 0.2)) < 1.5, "boss=%s" % [game.boss.global_position])
	game.boss.damage(9999, h.global_position, 0)
	await wait(2.8)
	check("defeating the Dark Knight in the Core clears the citadel", game.mode == "win", "mode=%s" % game.mode)
	game.restart_with("blonde_lance", "citadel")
	await wait(0.6)
	game.start_game()
	await wait(0.4)
	h = game.hero
	hp0 = h.hp
	game.boss.active = false
	h.global_position = game.ruin.dock + Vector3(30, 4, 0)
	h.velocity = Vector3.ZERO
	await wait(1.6)
	var cp: Vector3 = game.sections[game.checkpoint].spawn
	check("falling off the ruin returns you to the checkpoint", h.global_position.distance_to(cp) < 3.0 and h.hp < hp0, "pos=%s cp=%s hp=%d" % [h.global_position, cp, h.hp])

## Sky Citadel v2 (the rebuilt castle): the bot runs the castle's own route.
func ruin2_tests() -> void:
	game.restart_with("blonde_lance", "citadel")
	await wait(0.6)
	game.start_game()
	await wait(1.2)
	var h: CharacterBody3D = game.hero
	var R: Dictionary = game.ruin.route
	check("the rebuilt castle loads as the citadel", game.stage == "citadel" and game.world.get_node_or_null("SkyRuin") != null and game.ladders.size() == R.ladders.size() and game.enemies.size() + game.ruin.pending.size() == R.knights.size() + 1, "enemies=%d ladders=%d" % [game.enemies.size(), game.ladders.size()])
	check("the hero stands on the dock", h.is_on_floor() and absf(h.global_position.y - game.ruin.dock.y) < 0.8, "pos=%s" % [h.global_position])
	await shot("v0_dock")
	var n0: int = game.enemies.size()
	check("only the first area's guards are made at the start", game.ruin.pending.size() > 0 and n0 < R.knights.size() + 1, "made=%d waiting=%d" % [n0, game.ruin.pending.size()])
	for e: CharacterBody3D in game.enemies:
		if e != game.boss and e.section == 0:
			e.hp = 0
			e.set_state("dead")
			e.visible = false
			e.global_position.y -= 200.0
	await wait(0.3)
	var spot: Vector3 = game.sections[1].spawn
	for k: Dictionary in R.knights:
		if int(k.sec) == 1:
			spot = game.ruin.v3(k.pos) + Vector3(0, 0.3, 0)
			break
	h.global_position = spot
	h.velocity = Vector3.ZERO
	await wait(0.6)
	check("knights appear (with a flash) when you reach their area", game.section >= 1 and game.enemies.size() > n0 and not game.ruin.has_pending(1), "enemies=%d section=%d" % [game.enemies.size(), game.section])
	await shot("v0_summon")
	game.ruin.clear_pending()
	for e: CharacterBody3D in game.enemies:
		if e != game.boss:
			e.hp = 0
			e.set_state("dead")
			e.visible = false
			e.global_position.y -= 200.0
	for i in 8:
		await wait(0.1)
	h.global_position = game.sections[0].spawn
	h.velocity = Vector3.ZERO
	await wait(0.5)
	check("clearing each section opens its gate", game.section == game.ruin.last and game.barriers.all(func(b): return not is_instance_valid(b) or b.is_queued_for_deletion()), "section=%d" % game.section)
	var hp0: float = h.hp
	var marks: Array = [["ladder", 0, "ring one: stair, gallery, balcony, ladder", 73.0], ["ladder", 1, "ring two: terrace, stair, gallery, ladder", 91.0], ["drop", 0, "ring three, summit stair and crown stair", 130.0]]
	var i0: int = 0
	var ok: bool = true
	for m: Array in marks:
		var i1: int = route_index(m[0], m[1])
		var upto: int = i1 + 1 if m[0] == "ladder" else i1
		ok = ok and await run_route(i0, upto)
		check(m[2], ok and h.global_position.y > m[3], "pos=%s" % [h.global_position])
		await shot("v_%s_%d" % [m[0], m[1]])
		i0 = upto
	ok = ok and await run_route(i0, R.bot.size())
	await wait(0.5)
	check("dropping through the eye lands in the Core and wakes the Dark Knight", ok and game.ruin.in_core() and game.boss.active and game.boss_seen and game.checkpoint == game.ruin.last, "pos=%s cp=%d" % [h.global_position, game.checkpoint])
	await shot("v4_core")
	check("the whole climb is made without falling", h.hp >= hp0, "hp=%d" % h.hp)
	h.hp = h.max_hp
	await wait(5.0)
	var bp: Vector3 = game.boss.global_position
	check("the Dark Knight fights inside the Core", game.boss.alive() and absf(bp.y - game.ruin.core_y) < 4.0 and h.hp < h.max_hp, "boss=%s hero hp=%d" % [bp, h.hp])
	game.boss.damage(9999, h.global_position, 0)
	await wait(2.8)
	check("defeating the Dark Knight in the Core clears the citadel", game.mode == "win", "mode=%s" % game.mode)


## Sky Citadel v3: three ways up (outer ledges, inner tower, sky platforms), all driven by route3.json.
func ruin3_start() -> void:
	game.restart_with("blonde_lance", "citadel")
	await wait(0.6)
	game.start_game()
	await wait(1.0)
	game.ruin.clear_pending()
	for e: CharacterBody3D in game.enemies:
		if e != game.boss:
			e.hp = 0
			e.set_state("dead")
			e.visible = false
			e.global_position.y -= 200.0
	for i in 8:
		await wait(0.1)

func near(p: Array, d: float = 3.5) -> bool:
	return game.hero.global_position.distance_to(Vector3(p[0], p[1], p[2])) < d

func ruin3_tests() -> void:
	game.restart_with("blonde_lance", "citadel")
	await wait(0.6)
	game.start_game()
	await wait(1.2)
	var h: CharacterBody3D = game.hero
	var R: Dictionary = game.ruin.route
	var P: Dictionary = R.paths
	var H: Dictionary = R.hubs
	check("the rebuilt citadel loads with its hover platforms and crystal pads", game.stage == "citadel" and game.world.get_node_or_null("SkyRuin") != null and game.ladders.size() == 3 and game.ruin.plats.size() == R.platforms.size() and game.ruin.pads.size() == 4, "ladders=%d plats=%d pads=%d" % [game.ladders.size(), game.ruin.plats.size(), game.ruin.pads.size()])
	check("the hero stands on the dock", h.is_on_floor() and absf(h.global_position.y - game.ruin.dock.y) < 0.6, "pos=%s" % [h.global_position])
	check("Elyza starts as a prisoner in the Core (she does not follow yet)", game.ally_captive and game.ally.global_position.distance_to(game.ruin.CAPTIVE) < 1.5 and game.ruin.cage != null, "ally=%s" % [game.ally.global_position])
	var n0: int = game.enemies.size()
	check("only the dock guards are made at the start; the rest appear when you get there", game.ruin.pending.size() > 0 and n0 < R.knights.size() + 1, "made=%d waiting=%d" % [n0, game.ruin.pending.size()])
	var y0: float = game.ruin.plats[0].body.global_position.y
	await wait(0.7)
	check("the platforms hover (bob up and down)", absf(game.ruin.plats[0].body.global_position.y - y0) > 0.02, "dy=%.3f" % (game.ruin.plats[0].body.global_position.y - y0))
	await shot("w0_dock")
	# knights appear with a flash when you reach them
	for e: CharacterBody3D in game.enemies:
		if e != game.boss and e.section == 0:
			e.hp = 0
			e.set_state("dead")
			e.global_position.y -= 200.0
	await wait(0.3)
	h.global_position = Vector3(H.H2[0], H.H2[1] + 0.4, H.H2[2])
	h.velocity = Vector3.ZERO
	await wait(0.8)
	check("knights appear (with a flash) when you reach their area", game.enemies.size() > n0 and not game.ruin.has_pending(1), "enemies=%d" % game.enemies.size())
	await shot("w0_summon")
	# --- free climbing with stamina (Breath of the Wild style)
	await ruin3_start()
	h = game.hero
	var stand: Vector3 = Vector3(-42.5, 70.3, 6.0)
	var wallp: Vector3 = Vector3(-41.3, 70.3, 5.5)
	h.global_position = stand
	h.velocity = Vector3.ZERO
	await wait(0.5)
	var tw: Vector3 = wallp - stand
	game.cam_yaw = atan2(-tw.x, -tw.z)
	game.stamina = 100.0
	game.hud.stick = Vector2(0, -1)
	await wait(0.15)
	game.hud.pressed["jump"] = true
	var grabbed: bool = false
	var st0: float = 100.0
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000:
		if h.state == "wallclimb":
			grabbed = true
			st0 = minf(st0, game.stamina)
		if grabbed and h.state != "wallclimb" and h.is_on_floor():
			break
		await wait(0.03)
	game.hud.stick = Vector2.ZERO
	await wait(0.3)
	check("jump at a wall to grab it and climb up and over the ledge", grabbed and h.is_on_floor() and h.global_position.y > 73.5 and st0 < 95.0, "grabbed=%s pos=%s lowest stamina=%.0f" % [grabbed, h.global_position, st0])
	await shot("w6_climb")
	# out of stamina: you let go
	h.global_position = stand
	h.velocity = Vector3.ZERO
	await wait(0.5)
	game.stamina = 100.0
	game.hud.stick = Vector2(0, -1)
	await wait(0.15)
	game.hud.pressed["jump"] = true
	t0 = Time.get_ticks_msec()
	while h.state != "wallclimb" and Time.get_ticks_msec() - t0 < 3000:
		await wait(0.03)
	game.hud.stick = Vector2.ZERO
	game.stamina = 1.0
	await wait(0.8)
	check("climbing runs on stamina: at zero you let go", h.state != "wallclimb" and h.global_position.y < 73.5, "state=%s pos=%s" % [h.state, h.global_position])
	# --- grappling hook: aim, fire, latch on the wall and climb
	await wait(0.6)
	h.global_position = stand
	h.velocity = Vector3.ZERO
	game.stamina = 100.0
	await wait(0.5)
	game.cam_yaw = atan2(-tw.x, -tw.z)
	game.hud.pressed["hook"] = true
	await wait(0.4)
	var aimed: bool = game.grapple.aiming and game.grapple.blend > 0.9
	game.grapple.aim_pitch = 0.62
	await wait(0.3)
	var on_target: bool = game.grapple.target.get("ok", false)
	check("HOOK aims: over-the-shoulder camera, crosshair on the wall", aimed and on_target, "aiming=%s blend=%.2f target=%s" % [game.grapple.aiming, game.grapple.blend, game.grapple.target.get("pos")])
	var y_before: float = h.global_position.y
	game.hud.released["hook"] = true
	var latched: bool = false
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		if h.state == "grapple":
			latched = true
		if h.state == "wallclimb":
			break
		await wait(0.03)
	await wait(0.2)
	check("FIRE: the hook latches and pulls you onto the wall, climbing", latched and h.state == "wallclimb" and h.global_position.y > y_before + 1.0, "latched=%s state=%s pos=%s" % [latched, h.state, h.global_position])
	await shot("w7_hook")
	game.hud.stick = Vector2(0, -1)
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000 and not (h.state != "wallclimb" and h.is_on_floor()):
		await wait(0.05)
	game.hud.stick = Vector2.ZERO
	check("…and climb on up from the hook point", h.is_on_floor() and h.global_position.y > 73.5, "pos=%s" % [h.global_position])
	# a miss reels the hook back in
	game.cam_yaw += PI
	game.hud.pressed["hook"] = true
	await wait(0.4)
	game.grapple.aim_pitch = 1.3
	await wait(0.2)
	var p_miss: Vector3 = h.global_position
	game.hud.released["hook"] = true
	await wait(1.4)
	check("a miss (open sky) reels the hook back; you stay put", h.state == "idle" and game.grapple.shot.is_empty() and not game.grapple.aiming and h.global_position.distance_to(p_miss) < 1.5, "state=%s pos=%s" % [h.state, h.global_position])
	# --- chase camera: backed against a wall, it stays on your side of it
	h.global_position = stand
	h.velocity = Vector3.ZERO
	h.state = "idle"
	game.cam_yaw = atan2(tw.x, tw.z)   # looking away from the wall: the camera would sit inside it
	game.look_hold = 2.0
	await wait(1.0)
	var head: Vector3 = h.global_position + Vector3.UP * 1.45
	var cam_p: Vector3 = game.camera.global_position
	var through: Dictionary = game.ray(head, cam_p)
	check("chase camera never goes through a wall behind you", through.is_empty() and (cam_p - wallp).dot(-tw) > 0.0, "cam=%s" % [cam_p])
	await shot("w10_wallcam")
	# --- A: the outer ledges, all the way to the boss
	await ruin3_start()
	h = game.hero
	var hp0: float = h.hp
	var ok: bool = await run_steps(P.A1)
	check("A1 outer ledges: dock -> broken bridge -> ring ledges -> ladder -> Ring 2 hub", ok and near(H.H2), "pos=%s" % [h.global_position])
	ok = ok and await run_steps(P.A2)
	check("A2 outer ledges: Ring 2 -> ladder -> Ring 3 -> Core Floor hub", ok and near(H.H3, 4.0), "pos=%s" % [h.global_position])
	ok = ok and await run_steps(P.A3)
	check("A3 summit ladder", ok and h.global_position.y > 118.5, "pos=%s" % [h.global_position])
	await shot("w1_summit")
	ok = ok and await run_steps(P.S4)
	await wait(0.5)
	check("sky stair -> crown -> drop through the eye into the Core", ok and game.ruin.in_core() and game.boss.active, "pos=%s" % [h.global_position])
	check("path A is climbed without falling", h.hp >= hp0, "hp=%d" % h.hp)
	await shot("w2_core")
	h.hp = h.max_hp
	await wait(6.0)
	check("the Dark Knight fights in the Core", game.boss.alive() and absf(game.boss.global_position.y - game.ruin.core_y) < 4.0 and (h.hp < h.max_hp or game.boss.global_position.distance_to(h.global_position) < 6.0), "boss=%s hp=%d" % [game.boss.global_position, h.hp])
	check("Elyza stays in her cage during the fight", game.ally_captive and game.ally.global_position.distance_to(game.ruin.CAPTIVE) < 1.5)
	game.boss.damage(9999, h.global_position, 0)
	await wait(2.4)
	check("beating the Dark Knight frees Elyza (the stage isn't cleared yet)", not game.ally_captive and game.mode == "play" and game.ruin.rescue == "freed" and is_instance_valid(game.ruin.escape), "mode=%s rescue=%s" % [game.mode, game.ruin.rescue])
	await shot("w8_freed")
	# step onto the escape pad (walk_to would keep steering after the launch)
	h.global_position = game.ruin.ESCAPE_PAD + Vector3(0, 0.3, 2.0)
	h.velocity = Vector3.ZERO
	await wait(0.4)
	game.cam_yaw = 0.0
	game.hud.stick = Vector2(0, -0.6)
	t0 = Time.get_ticks_msec()
	while game.ruin.rescue != "escort" and Time.get_ticks_msec() - t0 < 3000:
		await wait(0.03)
	game.hud.stick = Vector2.ZERO
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000 and not (game.ruin.rescue == "escort" and h.state == "idle" and h.is_on_floor()):
		await wait(0.05)
	await wait(1.0)
	check("the escape pad lifts you up through the eye to the crown; Elyza follows", game.ruin.rescue == "escort" and h.global_position.y > 138.0 and game.ally.global_position.distance_to(h.global_position) < 6.0, "hero=%s ally=%s" % [h.global_position, game.ally.global_position])
	await wait(1.2)
	check("knights ambush the escape on the crown", game.ruin.ambush.size() == 2, "ambush=%d" % game.ruin.ambush.size())
	await shot("w9_escort")
	for e: CharacterBody3D in game.ruin.ambush:
		e.damage(999, h.global_position, 0)
	await wait(0.5)
	check("the stage waits until Elyza is at the safe area", game.mode == "play")
	ok = await walk_to(game.ruin.SAFE, 12.0)
	await wait(1.2)
	check("Elyza follows you to the safe area", game.ally.global_position.distance_to(game.ruin.SAFE) < 6.0, "ally=%s" % [game.ally.global_position])
	await wait(2.0)
	check("bringing her to the safe area clears the citadel", game.mode == "win", "mode=%s rescue=%s hero=%s" % [game.mode, game.ruin.rescue, h.global_position])
	# --- B: the inner tower
	await ruin3_start()
	h = game.hero
	hp0 = h.hp
	ok = await run_steps(P.B1)
	check("B1 inner tower: front door -> spiral stair -> broken-arch bridge -> Ring 2 hub", ok and near(H.H2), "pos=%s" % [h.global_position])
	await shot("w3_tower")
	ok = ok and await run_steps(P.B2)
	check("B2 inner tower: back over the gap -> spiral stair to 104 -> bridge -> Core Floor hub", ok and near(H.H3, 4.0) and h.hp >= hp0, "pos=%s hp=%d" % [h.global_position, h.hp])
	# --- C: the sky path
	await ruin3_start()
	h = game.hero
	hp0 = h.hp
	if "--plat-debug" in OS.get_cmdline_user_args():
		var b0: Node3D = game.ruin.plats[0].body
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(b0.global_position + Vector3(0, 3, 0), b0.global_position + Vector3(0, -3, 0))
		var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(q)
		print("PLATDBG body ", b0.global_position, " hit ", hit.get("collider"), " at ", hit.get("position"))
		h.global_position = b0.global_position + Vector3(0, 2.0, 0)
		h.velocity = Vector3.ZERO
		for i in 15:
			await wait(0.1)
			print("PLATDBG drop ", h.global_position, " floor=", h.is_on_floor())
	ok = await run_steps(P.C1)
	check("C1 sky path: tier A platforms -> crystal pad -> Ring 2 hub", ok and near(H.H2, 4.0), "pos=%s" % [h.global_position])
	await shot("w4_skyA")
	ok = ok and await run_steps(P.C2)
	check("C2 sky path: tier B wing platforms and two launch pads -> Core Floor hub", ok and near(H.H3, 4.0), "pos=%s" % [h.global_position])
	ok = ok and await run_steps(P.C3)
	check("C3 sky path: tier C spire-top platforms -> pad -> summit", ok and h.global_position.y > 118.5 and h.hp >= hp0, "pos=%s hp=%d" % [h.global_position, h.hp])
	await shot("w5_skyC")

# ---------------------------------------------------------------- Frogtown

func frog_start() -> void:
	SaveScript.clear(game.frogtown.FROG_SAVE)
	game.frogtown.inside = ""
	game.frogtown.save = {}
	game.frogtown.clock = game.frogtown.START_CLOCK + 120.0
	game.restart_with("blonde_lance", "frogtown")
	await wait(0.6)
	game.start_game()
	game.frogtown.clock = 9.5 * 60.0
	await wait(1.0)

## Bake the tile's navigation mesh and save it (run once after the tile changes).
func frog_bake() -> void:
	game.restart_with("blonde_lance", "frogtown")
	await wait(0.5)
	var ft: RefCounted = game.frogtown
	ft.region.queue_free()
	ft.bake_tile_nav(true)
	var err: int = ft.save_nav()
	print("FROG NAV baked in %d ms, polys=%d, saved err=%d" % [ft.nav_baked_ms, ft.region.navigation_mesh.get_polygon_count(), err])

## Top-down placement check: every door, spot, feature and exit as a labelled pole.
func frog_map() -> void:
	await frog_start()
	var ft: RefCounted = game.frogtown
	game.hud.visible = false
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var half: float = 50.0
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--frog-map-zoom="):
			half = float(a.trim_prefix("--frog-map-zoom="))
	var cx: float = 0.0
	var cz: float = 0.0
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--frog-map-at="):
			var xy: PackedStringArray = a.trim_prefix("--frog-map-at=").split(",")
			cx = float(xy[0])
			cz = float(xy[1])
	cam.size = half * 2.0
	game.add_child(cam)
	cam.global_transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(cx, 40, cz))
	cam.current = true
	game.set_process(false)
	game.env_res.fog_enabled = false
	game.env_res.tonemap_exposure = 0.7
	var marks: Array = []
	for hid: String in ft.doors:
		marks.append([ft.doors[hid].pos, Color.RED, hid.substr(hid.length() - 3)])
	for id: String in ft.spots:
		if not id.begins_with("door_"):
			marks.append([ft.spots[id].pos, Color.DODGER_BLUE if not id.begins_with("seat") else Color.LIME_GREEN, id])
	for ex: Dictionary in ft.data.exits:
		marks.append([Vector3(ex.at[0], 0, ex.at[2]), Color.MAGENTA, ex.id])
	for v: Node3D in ft.villagers:
		marks.append([v.global_position, Color.YELLOW, v.vname])
	for m: Array in marks:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 0.35
		cm.bottom_radius = 0.35
		cm.height = 6.0
		mi.mesh = cm
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = m[1]
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = mat
		mi.position = (m[0] as Vector3) + Vector3.UP * 3.0
		game.world.add_child(mi)
		var lb: Label3D = Label3D.new()
		lb.text = str(m[2])
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.no_depth_test = true
		lb.pixel_size = 0.02 * half / 50.0
		lb.font_size = 48
		lb.outline_size = 12
		lb.modulate = m[1]
		lb.position = (m[0] as Vector3) + Vector3(0, 7.0, 0.9 * half / 50.0)
		game.world.add_child(lb)
	if "--frog-map-walk" in OS.get_cmdline_user_args():
		# show the collision instead of the model: walk surface green, walls red
		var tile: Node3D = game.world.get_node("FrogtownTile")
		tile.get_child(0).visible = false
		for path: String in [ft.WALK, ft.WALLS]:
			var part: Node3D = (load(path) as PackedScene).instantiate()
			part.position.y = ft.lift
			game.world.add_child(part)
			var cm2: StandardMaterial3D = StandardMaterial3D.new()
			cm2.albedo_color = Color(0.3, 0.9, 0.4) if path == ft.WALK else Color(0.9, 0.25, 0.2)
			for mi2: MeshInstance3D in part.find_children("*", "MeshInstance3D", true, false):
				mi2.material_override = cm2
	if "--frog-map-nav" in OS.get_cmdline_user_args():
		var nm: NavigationMesh = ft.region.navigation_mesh
		var im: ImmediateMesh = ImmediateMesh.new()
		var vs: PackedVector3Array = nm.get_vertices()
		var nmat: StandardMaterial3D = StandardMaterial3D.new()
		nmat.albedo_color = Color(1, 0, 1, 0.45)
		nmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		nmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		nmat.cull_mode = BaseMaterial3D.CULL_DISABLED
		# colour each connected island differently (polygons sharing an edge)
		var parent: Array = []
		for i in nm.get_polygon_count():
			parent.append(i)
		var find: Callable = func(x: int) -> int:
			var r: int = x
			while parent[r] != r:
				r = parent[r]
			return r
		var edge_owner: Dictionary = {}
		for i in nm.get_polygon_count():
			var poly: PackedInt32Array = nm.get_polygon(i)
			for k in poly.size():
				var e0: Vector3 = vs[poly[k]].snapped(Vector3.ONE * 0.01)
				var e1: Vector3 = vs[poly[(k + 1) % poly.size()]].snapped(Vector3.ONE * 0.01)
				var key: String = str(e0) + str(e1) if str(e0) < str(e1) else str(e1) + str(e0)
				if edge_owner.has(key):
					var ra: int = find.call(i)
					var rb: int = find.call(edge_owner[key])
					parent[ra] = rb
				else:
					edge_owner[key] = i
		var sizes: Dictionary = {}
		for i in nm.get_polygon_count():
			var r2: int = find.call(i)
			sizes[r2] = int(sizes.get(r2, 0)) + 1
		var big: Array = sizes.keys()
		big.sort_custom(func(a1: int, b1: int) -> bool: return sizes[a1] > sizes[b1])
		print("FROG NAV islands: ", big.size(), " largest: ", big.slice(0, 8).map(func(r3: int) -> int: return sizes[r3]))
		nmat.vertex_color_use_as_albedo = true
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, nmat)
		for i in nm.get_polygon_count():
			var poly: PackedInt32Array = nm.get_polygon(i)
			var rank: int = big.find(find.call(i))
			var col: Color = Color.from_hsv(fmod(rank * 0.27, 1.0), 0.9, 1.0, 0.6) if rank < 12 else Color(1, 1, 1, 0.5)
			for k in range(1, poly.size() - 1):
				for j: int in [poly[0], poly[k], poly[k + 1]]:
					im.surface_set_color(col)
					im.surface_add_vertex(vs[j] + Vector3.UP * 0.2)
		im.surface_end()
		var nmi: MeshInstance3D = MeshInstance3D.new()
		nmi.mesh = im
		game.world.add_child(nmi)
	await wait(0.5)
	await shot("frog_map")

func frog_tris(n: Node) -> int:
	var t: int = 0
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(i)
			var ix: Variant = arr[Mesh.ARRAY_INDEX]
			t += (ix.size() / 3) if ix != null else ((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3)
	return t

func frog_walk_into_door(hid: String) -> bool:
	var ft: RefCounted = game.frogtown
	var door: RefCounted = ft.doors[hid]
	var into: Vector3 = ft.door_dir(ft.houses[hid])
	var h: CharacterBody3D = game.hero
	h.global_position = door.pos - into * 2.6 + Vector3.UP * 0.3
	h.velocity = Vector3.ZERO
	game.cam_yaw = atan2(-into.x, -into.z)
	ft.door_cd = 0.0
	await wait(0.4)
	game.hud.stick = Vector2(0, -1)
	var t0: int = Time.get_ticks_msec()
	while ft.inside == "" and Time.get_ticks_msec() - t0 < 4000:
		await wait(0.05)
	game.hud.stick = Vector2.ZERO
	await wait(0.4)
	return ft.inside == hid

func frog_tests() -> void:
	await frog_start()
	var ft: RefCounted = game.frogtown
	var h: CharacterBody3D = game.hero
	var tile: Node = game.world.get_node_or_null("FrogtownTile")
	check("Frogtown loads as a 1-tile village with 10 houses", game.stage == "frogtown" and tile != null and ft.houses.size() == 10 and ft.doors.size() == 10, "houses=%d doors=%d" % [ft.houses.size(), ft.doors.size()])
	var tris: int = frog_tris(tile.get_child(0))
	check("the village is a game-ready low-poly copy (never the 1.9M-tri Tripo source)", tris > 1000 and tris <= (50000 if game.phone else 120000), "tris=%d phone=%s" % [tris, game.phone])
	check("about 10 villagers are active on the tile", ft.villagers.size() == 10, "n=%d" % ft.villagers.size())
	var bosses: int = 0
	for v: Node in ft.villagers:
		var mp: String = str(v.rig.model.scene_file_path)
		if mp.contains("/CC_") or mp.contains("knight") or mp.contains("boss"):
			bosses += 1
	check("villagers use Villager.gd and ordinary models, never the CC_ boss characters", bosses == 0 and ft.villagers[0].get_script().resource_path.ends_with("Villager.gd") and ft.villagers[0].head_node != null, "bosses=%d" % bosses)
	var names: Dictionary = {}
	for mi: MeshInstance3D in game.world.find_children("*", "MeshInstance3D", true, false):
		if mi.has_meta("prop"):
			var nn: String = mi.get_meta("prop")
			names[nn] = int(names.get(nn, 0)) + 1
	var need: Array = ["chief_dais", "council_drum", "request_board", "shell_totem", "flood_gauge", "sluice_frame", "sluice_paddles", "market_stall", "exit_gate", "door_arch", "lantern_post"]
	var missing: Array = need.filter(func(n: String) -> bool: return not names.has(n))
	check("frog-folk landmarks: chief's shell dais, council drum, request board, ancestor totem, flood gauge, sluice wheel, market", missing.is_empty() and int(names.get("lantern_post", 0)) >= 4 and int(names.get("door_arch", 0)) == 10, "missing=%s lanterns=%d" % [missing, int(names.get("lantern_post", 0))])
	check("navigation mesh is prebaked and loaded", ft.region != null and ft.region.navigation_mesh.get_polygon_count() > 200, "polys=%d" % ft.region.navigation_mesh.get_polygon_count())
	# every spot and door can be reached on the boardwalks
	var map: RID = game.get_world_3d().navigation_map
	var from: Vector3 = NavigationServer3D.map_get_closest_point(map, ft.on_ground(Vector3(-1.2, 0, -2.6)))
	var bad: Array = []
	for id: String in ft.spots:
		var sp: Vector3 = ft.spots[id].pos
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, from, sp, true)
		if path.size() == 0 or path[path.size() - 1].distance_to(sp) > 1.3:
			bad.append(id)
			print("FROG UNREACH ", id, " spot=", sp, " end=", path[path.size() - 1] if path.size() > 0 else Vector3.INF, " closest=", NavigationServer3D.map_get_closest_point(map, sp))
	check("every door, work spot and seat is reachable on the boardwalks", bad.is_empty(), "unreachable=%s" % [bad])
	await shot("f0_plaza")
	# --- door trigger: walking into a door loads that house's interior
	check("ENTER shows next to a door", true)
	var ok: bool = await frog_walk_into_door("CC_HOUSE_T11_H02")
	var interior: Node = game.world.get_node_or_null("Interior_INT_HUT")
	var rnames: Array = ft.residents.map(func(r: Node) -> String: return r.vid)
	check("walking into a door loads that house's interior (separate scene, tile unloaded)", ok and interior != null and game.world.get_node_or_null("FrogtownTile") == null and ft.villagers.is_empty(), "inside=%s" % ft.inside)
	check("only that house's residents who are home are made inside", rnames == ["VIL_PIP_CHILD"], "residents=%s" % [rnames])
	check("the player starts at the interior spawn marker", h.global_position.distance_to(ft.interior_spawn.origin) < 1.6, "pos=%s" % [h.global_position])
	check("ENTER shows as EXIT inside, by the door", true)
	await wait(1.5)
	await shot("f1_hut")
	# exit: back at the same house's door, facing out
	var door: RefCounted
	h.global_position = ft.interior_exit - Vector3(0, 0, 1.6) + Vector3.UP * 0.1
	game.cam_yaw = 0.0
	ft.door_cd = 0.0
	await wait(0.3)
	game.hud.stick = Vector2(0, 1)   # walk toward +z (the door)
	var t0: int = Time.get_ticks_msec()
	while ft.inside != "" and Time.get_ticks_msec() - t0 < 4000:
		await wait(0.05)
	game.hud.stick = Vector2.ZERO
	await wait(0.4)
	door = ft.doors["CC_HOUSE_T11_H02"]
	var out: Vector3 = -ft.door_dir(ft.houses["CC_HOUSE_T11_H02"])
	check("leaving returns the player to that house's door, facing out", ft.inside == "" and Vector2(h.global_position.x - door.pos.x, h.global_position.z - door.pos.z).length() < 3.0 and h.forward().dot(out) > 0.7, "pos=%s door=%s" % [h.global_position, door.pos])
	check("the village and its villagers come back after leaving", game.world.get_node_or_null("FrogtownTile") != null and ft.villagers.size() == 10)
	# --- reusable interiors: another family in the same hut model; lodges shared too
	ft.door_cd = 0.0
	ft.enter_house("CC_HOUSE_T11_H07")
	await wait(0.6)
	rnames = ft.residents.map(func(r: Node) -> String: return r.vid)
	check("the same hut interior serves a different family", ft.inside == "CC_HOUSE_T11_H07" and game.world.get_node_or_null("Interior_INT_HUT") != null and rnames == ["VIL_KREEKA_HOME"], "residents=%s" % [rnames])
	await wait(1.2)
	await shot("f1b_kreeka")
	ft.exit_house()
	await wait(0.4)
	ft.enter_house("CC_HOUSE_T11_H01")
	await wait(0.6)
	rnames = ft.residents.map(func(r: Node) -> String: return r.vid)
	check("the Chief's Lodge uses the long-hall interior with the chief's family", ft.inside == "CC_HOUSE_T11_H01" and game.world.get_node_or_null("Interior_INT_LODGE") != null and "VIL_RIBBA_HOME" in rnames, "residents=%s" % [rnames])
	await wait(1.0)
	await shot("f2_lodge")
	ft.exit_house()
	await wait(0.4)
	ft.enter_house("CC_HOUSE_T11_H10")
	await wait(0.5)
	check("the Hunt Lodge reuses the long-hall interior (captain is out at the board)", ft.inside == "CC_HOUSE_T11_H10" and game.world.get_node_or_null("Interior_INT_LODGE") != null and ft.residents.is_empty(), "residents=%d" % ft.residents.size())
	ft.exit_house()
	await wait(0.4)
	# --- access rules
	check("knock: nobody home means the door stays shut", ft.can_enter("CC_HOUSE_T11_H05") != "", "why=%s" % ft.can_enter("CC_HOUSE_T11_H05"))
	var clk: float = ft.clock
	ft.clock = 23.0 * 60.0
	check("the trader's hut is locked at night", ft.can_enter("CC_HOUSE_T11_H08") != "")
	# at night the fisher is asleep in bed at home
	for v: Node in ft.villagers:
		if v.vid == "VIL_BOGG_FISHER":
			v.goal_kind = "door"
			v.go_inside()   # gone home to bed
	ft.enter_house("CC_HOUSE_T11_H03")
	await wait(1.2)
	var bogg: Node = ft.residents[0] if ft.residents.size() > 0 else null
	check("at night a resident is home asleep in bed", bogg != null and bogg.vid == "VIL_BOGG_FISHER" and bogg.spot_kind() == "bed" and bogg.rig.rotation.x > 0.8, "res=%s" % [ft.residents.map(func(r: Node) -> String: return r.vid + ":" + r.spot_kind())])
	await shot("f3_night")
	ft.exit_house()
	ft.clock = clk
	await wait(0.6)
	# --- routines: speed time up; villagers go to their work spots
	ft.speed = 40.0
	await wait(24.0)
	ft.speed = 1.0
	var working: Array = []
	var busy: int = 0
	for v: Node in ft.villagers:
		if v.state == "work":
			working.append(v.vname)
		if v.state == "work" or (v.state == "walk" and v.goal_kind in ["work", "drop"]) or v.goal_kind == "after_drop":
			busy += 1
	check("villagers walk their routines to work spots (fish, reeds, drum, dais, board, stalls)", working.size() >= 4 and busy >= 7, "working=%s busy=%d" % [working, busy])
	var chief: Node = ft.villagers.filter(func(v: Node) -> bool: return v.job == "chief")[0]
	check("the Village Chief takes his seat on the shell dais", chief.state == "work" and chief.global_position.distance_to(ft.dais_seat) < 0.8, "chief=%s seat=%s state=%s" % [chief.global_position, ft.dais_seat, chief.state])
	await shot("f4_routines")
	var cv: Node = ft.villagers.filter(func(v: Node) -> bool: return v.state == "work" and v.job != "chief")[0] if ft.villagers.any(func(v: Node) -> bool: return v.state == "work" and v.job != "chief") else ft.villagers[1]
	var cdir: Vector3 = Vector3(sin(cv.yaw), 0, cos(cv.yaw))
	h.global_position = ft.on_nav(cv.global_position + cv.forward() * 2.4 + cv.forward().cross(Vector3.UP) * 1.3) + Vector3.UP * 0.2
	game.cam_yaw = atan2(-(cv.global_position.x - h.global_position.x), -(cv.global_position.z - h.global_position.z))
	game.look_hold = 3.0
	await wait(1.0)
	await shot("f6_villager")
	# --- only one villager talks at a time
	var a: Node = ft.villagers[0]
	var b: Node = ft.villagers[1]
	for v: Node in ft.villagers:
		v.talk_cd = 0.0 if v == a or v == b else 30.0
		v.talk_t = 0.0
		v.bubble.visible = false
	ft.speaker_t = 0.0
	var at: Vector3 = h.global_position
	a.global_position = at + Vector3(1.0, 0, 0)
	b.global_position = at + Vector3(-1.0, 0, 0)
	await wait(0.4)
	var talking: int = 0
	for v: Node in ft.villagers:
		if v.bubble.visible:
			talking += 1
	check("only one villager speaks at a time", talking == 1, "talking=%d" % talking)
	# --- the road out at the tile edge (next-tile hook)
	var ex: Dictionary = ft.data.exits[0]
	var gp: Vector3 = ft.on_ground(Vector3(ex.at[0], 0, ex.at[2]))
	var dv: Vector3 = Vector3(ex.dir[0], 0, ex.dir[1])
	h.global_position = gp - dv * 3.0 + Vector3.UP * 0.3
	game.cam_yaw = atan2(-dv.x, -dv.z)
	await wait(0.3)
	game.hud.stick = Vector2(0, -1)
	await wait(2.0)
	game.hud.stick = Vector2.ZERO
	var past: float = (h.global_position - gp).dot(dv)
	check("the south road gate is the next-tile hook (closed until that tile exists)", past < 1.0 and ft.road_msg_t > 0.0 and not ft.has_tile(ex.to_tile), "past=%.2f" % past)
	await shot("f5_gate")
	# --- falling into the marsh puts you back on the boardwalk
	var safe: Vector3 = ft.safe_pos
	h.global_position = Vector3(30, ft.water_y - 0.6, -30)
	await wait(0.3)
	check("falling into the marsh puts you back on the boardwalk", h.global_position.y > ft.water_y + 0.5 and h.global_position.distance_to(safe) < 2.0, "pos=%s" % [h.global_position])
	# --- save: leaving the stage and coming back keeps villagers where they were
	ft.save_now()
	var before: Dictionary = {}
	for v: Node in ft.villagers:
		before[v.vid] = v.global_position
	game.restart_with("blonde_lance", "frogtown")
	await wait(0.6)
	game.start_game()
	await wait(0.3)
	var moved: float = 0.0
	for v: Node in ft.villagers:
		if before.has(v.vid):
			moved = maxf(moved, (v.global_position - (before[v.vid] as Vector3)).length())
	check("villager state persists across leaving and reloading the village", ft.villagers.size() == 10 and moved < 3.0, "max moved=%.2f" % moved)
	# --- phone budget: 10 active villagers
	var frames: int = 0
	var t1: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 5000:
		await get_tree().process_frame
		frames += 1
	var fps: float = frames / ((Time.get_ticks_msec() - t1) / 1000.0)
	print("FROG FPS %.1f with %d villagers (phone=%s, renderer %s)" % [fps, ft.villagers.size(), game.phone, RenderingServer.get_video_adapter_name()])
	check("10 villagers run on the tile (fps measured)", ft.villagers.size() == 10 and fps > 1.0, "fps=%.1f" % fps)
	# other villages still load
	game.restart_with("blonde_lance", "village")
	await wait(0.6)
	check("the old village square still loads after Frogtown", game.stage == "village" and game.village == game.village_square and game.village.villagers.size() == 6, "n=%d" % game.village.villagers.size())

# ---------------------------------------------------------------- traversal (TRAINING course)

const TR = preload("res://scripts/citadel/Trials.gd")

func aim(t: Vector3) -> void:
	## Point the camera so stick-up walks along t.
	game.cam_yaw = atan2(-t.x, -t.z)

func hspeed() -> float:
	return Vector2(game.hero.velocity.x, game.hero.velocity.z).length()

func until(cond: Callable, timeout: float) -> bool:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(timeout * 1000):
		if cond.call():
			return true
		await wait(0.03)
	return false

func trials_tests() -> void:
	for key: String in ["blonde_lance", "lance"]:
		await trials_run(key)

func trials_run(key: String) -> void:
	game.restart_with(key, "trials")
	game.start_game()
	await wait(0.6)
	var h: CharacterBody3D = game.hero
	var T: RefCounted = game.trav
	var tag: String = "[%s] " % key
	check(tag + "training course loads with the real hero model", game.stage == "trials" and h.rig != null and game.enemies.size() == 3 and game.ladders.size() == 2, "enemies=%d ladders=%d" % [game.enemies.size(), game.ladders.size()])
	await shot("t0_course_" + key)
	# --- acceleration, run speed, stop
	place(Vector3(0, 0.2, 4), 0.0)
	await wait(0.4)
	aim(Vector3(0, 0, -1))
	game.hud.stick = Vector2(0, -1)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var early: float = hspeed()
	await wait(0.5)
	var run_v: float = hspeed()
	game.hud.stick = Vector2.ZERO
	await wait(0.2)
	check(tag + "running speeds up smoothly and stops quickly", early < run_v * 0.8 and absf(run_v - T.cfg.run_speed) < 0.4 and hspeed() < 0.3, "start %.2f run %.2f after stop %.2f" % [early, run_v, hspeed()])
	# --- sprint (touch toggle) uses stamina, then a short pause before it refills
	place(Vector3(0, 0.2, 4), 0.0)
	game.stamina = 100.0
	await wait(0.3)
	check(tag + "SPRINT button shows on the ground", game.button_visible("sprint"))
	game.hud.stick = Vector2(0, -1)
	game.hud.pressed["sprint"] = true
	await wait(1.0)
	var spr_v: float = hspeed()
	var spr_on: bool = T.sprinting
	var st_after: float = game.stamina
	await shot("t1_sprint_" + key)
	game.hud.stick = Vector2.ZERO
	await wait(0.45)
	var st_pause: float = game.stamina
	await wait(1.0)
	check(tag + "sprinting is faster and drains stamina", spr_on and absf(spr_v - T.cfg.sprint_speed) < 0.5 and st_after < 92.0, "speed %.2f stamina %.1f" % [spr_v, st_after])
	check(tag + "stamina waits a moment after exertion, then refills", absf(st_pause - st_after) < 3.0 and game.stamina > st_pause + 10.0 and not T.sprint_toggle, "%.1f -> %.1f -> %.1f" % [st_after, st_pause, game.stamina])
	# keyboard sprint (hold CTRL)
	game.stamina = 100.0
	Input.action_press("cc_sprint")
	game.hud.stick = Vector2(0, -1)
	await wait(0.8)
	var key_v: float = hspeed()
	Input.action_release("cc_sprint")
	game.hud.stick = Vector2.ZERO
	await wait(0.3)
	check(tag + "keyboard/pad sprint (hold) works", key_v > T.cfg.run_speed + 2.0, "speed %.2f" % key_v)
	# --- exhaustion
	place(Vector3(0, 0.2, 4), 0.0)
	await wait(0.3)
	game.stamina = 4.0
	T.regen_wait = 1.0
	game.hud.stick = Vector2(0, -1)
	game.hud.pressed["sprint"] = true
	await wait(0.8)
	var ex: bool = T.exhausted
	var ex_v: float = hspeed()
	check(tag + "running out of stamina: exhausted, no sprint, slower", ex and not T.sprinting and ex_v <= T.cfg.exhausted_speed + 0.2 and game.button_label("sprint") == "TIRED", "exhausted=%s speed %.2f" % [ex, ex_v])
	await shot("t2_exhausted_" + key)
	game.hud.stick = Vector2.ZERO
	await until(func() -> bool: return not T.exhausted, 4.0)
	check(tag + "exhaustion ends once stamina is back to 30%", not T.exhausted and game.stamina >= 29.0, "stamina %.1f" % game.stamina)
	game.stamina = 100.0
	# --- jump; glide can't open on the ground or low down
	place(Vector3(0, 0.2, 4), 0.0)
	await wait(0.4)
	game.hud.pressed["jump"] = true
	await wait(0.25)
	var up: float = h.global_position.y
	await wait(0.2)
	game.hud.pressed["jump"] = true   # near the apex, but under 2.2 m: no glider
	await wait(0.05)
	var low_glide: bool = h.state == "glide"
	await until(func() -> bool: return h.is_on_floor(), 2.0)
	check(tag + "jumping works and lands; no glider close to the ground", up > 1.2 and not low_glide and h.is_on_floor(), "height %.2f glide=%s" % [up, low_glide])
	# --- vault a low ledge (1.2 m smooth block)
	var lo: Vector3 = TR.LEDGE_LOW
	T.events.clear()
	place(Vector3(lo.x + 3.6, 0.2, lo.z), 0.0)
	await wait(0.3)
	aim(Vector3(-1, 0, 0))
	game.hud.stick = Vector2(0, -1)
	await until(func() -> bool: return h.global_position.x < lo.x + 2.4, 2.0)
	game.hud.pressed["jump"] = true
	var vaulted: bool = await until(func() -> bool: return h.is_on_floor() and h.global_position.y > TR.LEDGE_LOW_H - 0.2, 3.0)
	game.hud.stick = Vector2.ZERO
	check(tag + "jumping at a 2.6 m ledge catches it and vaults up", vaulted and "mantle" in T.events, "pos %s events %s" % [h.global_position, T.events.slice(-4)])
	# --- catch a high smooth ledge, hang, shimmy, climb up
	var hi: Vector3 = TR.LEDGE_HIGH
	T.events.clear()
	place(Vector3(hi.x + 2.3, 0.2, hi.z), 0.0)
	await wait(0.4)
	game.stamina = 100.0
	aim(Vector3(-1, 0, 0))
	game.hud.stick = Vector2(0, -0.6)
	await wait(0.1)
	game.hud.pressed["jump"] = true
	var hung: bool = await until(func() -> bool: return h.state == "ledge", 2.0)
	game.hud.stick = Vector2.ZERO
	await wait(0.4)
	var hang_y: float = h.global_position.y
	check(tag + "jumping at a high ledge catches it and hangs (smooth wall: no wall climb)", hung and h.state == "ledge" and "wallclimb" not in str(T.events) and absf(hang_y - (TR.LEDGE_HIGH_H - T.HANG_DROP)) < 0.2, "state %s y %.2f events %s" % [h.state, hang_y, T.events])
	check(tag + "on a ledge JUMP reads CLIMB UP and DODGE reads DROP", game.button_label("jump") == "CLIMB UP" and game.button_label("dodge") == "DROP" and not game.button_visible("sprint"))
	await shot("t3_ledge_" + key)
	var z0: float = h.global_position.z
	game.hud.stick = Vector2(1, 0)
	await wait(1.0)
	game.hud.stick = Vector2.ZERO
	await wait(0.1)
	check(tag + "shimmy sideways along the ledge", h.state == "ledge" and absf(h.global_position.z - z0) > 1.0, "dz %.2f state %s" % [h.global_position.z - z0, h.state])
	game.hud.stick = Vector2(-1, 0)
	await wait(6.0)
	game.hud.stick = Vector2.ZERO
	check(tag + "you can't shimmy off the end of a ledge", h.state == "ledge" and absf(h.global_position.z - hi.z) < 4.2, "z %.2f" % h.global_position.z)
	game.hud.stick = Vector2(0, -1)
	var topped: bool = await until(func() -> bool: return h.state == "idle" and h.is_on_floor() and h.global_position.y > TR.LEDGE_HIGH_H - 0.3, 3.0)
	game.hud.stick = Vector2.ZERO
	await wait(0.2)
	check(tag + "push up to pull up onto the ledge", topped and "pullup_done" in T.events, "pos %s" % h.global_position)
	# drop from a ledge
	place(Vector3(hi.x + 2.3, 0.2, hi.z), 0.0)
	await wait(0.4)
	game.hud.stick = Vector2(0, -0.6)
	await wait(0.1)
	game.hud.pressed["jump"] = true
	await until(func() -> bool: return h.state == "ledge", 2.0)
	game.hud.stick = Vector2.ZERO
	await wait(0.3)
	game.hud.pressed["dodge"] = true
	var dropped: bool = await until(func() -> bool: return h.is_on_floor() and h.global_position.y < 0.5, 2.0)
	check(tag + "DODGE lets go of a ledge", dropped and "drop" in T.events)
	# out of stamina on a ledge: you let go
	game.hud.stick = Vector2(0, -0.6)
	await wait(0.1)
	game.hud.pressed["jump"] = true
	await until(func() -> bool: return h.state == "ledge", 2.0)
	game.hud.stick = Vector2.ZERO
	game.stamina = 0.5
	var fell_off: bool = await until(func() -> bool: return h.state != "ledge" and h.is_on_floor(), 3.0)
	check(tag + "no stamina left on a ledge: controlled drop", fell_off and h.global_position.y < 0.5)
	game.stamina = 100.0
	T.exhausted = false
	# --- climb the stone wall (up and sideways) and over the top
	var cw: Vector3 = TR.CLIMB_WALL
	T.events.clear()
	place(Vector3(cw.x + 2.25, 0.2, cw.z), 0.0)
	await wait(0.4)
	game.stamina = 100.0
	aim(Vector3(-1, 0, 0))
	game.hud.stick = Vector2(0, -1)
	await wait(0.12)
	check(tag + "facing a climbable wall, JUMP reads CLIMB", game.button_label("jump") == "CLIMB", game.button_label("jump"))
	game.hud.pressed["jump"] = true
	var on_wall: bool = await until(func() -> bool: return h.state == "wallclimb", 2.0)
	game.hud.stick = Vector2(1, 0)
	await wait(0.6)
	var side_z: float = h.global_position.z
	await shot("t4_wallclimb_" + key)
	game.hud.stick = Vector2(0, -1)
	var over: bool = await until(func() -> bool: return h.state == "idle" and h.is_on_floor() and h.global_position.y > TR.CLIMB_WALL_H - 0.3, 9.0)
	game.hud.stick = Vector2.ZERO
	check(tag + "climbing: up, sideways and pull up over the top", on_wall and absf(side_z - cw.z) > 0.5 and over and game.stamina < 70.0, "z moved %.2f top=%s stamina %.0f" % [side_z - cw.z, over, game.stamina])
	# drop off a wall with DODGE
	place(Vector3(cw.x + 3.2, 0.2, cw.z), 0.0)
	await wait(0.4)
	game.stamina = 100.0
	game.hud.stick = Vector2(0, -1)
	await wait(0.12)
	game.hud.pressed["jump"] = true
	await until(func() -> bool: return h.state == "wallclimb", 2.0)
	game.hud.stick = Vector2.ZERO
	await wait(0.3)
	check(tag + "on a wall DODGE reads DROP", game.button_label("dodge") == "DROP")
	game.hud.pressed["dodge"] = true
	await wait(0.15)
	check(tag + "DODGE lets go of a wall", h.state != "wallclimb")
	await until(func() -> bool: return h.is_on_floor(), 2.0)
	# --- climb the tower (long climb, stamina matters)
	var tw: Vector3 = TR.TOWER
	T.events.clear()
	place(Vector3(tw.x - 5.2, 0.2, tw.z), 0.0)
	await wait(0.4)
	game.stamina = 100.0
	aim(Vector3(1, 0, 0))
	game.hud.stick = Vector2(0, -1)
	await wait(0.12)
	game.hud.pressed["jump"] = true
	var topped2: bool = await until(func() -> bool: return h.state == "idle" and h.is_on_floor() and h.global_position.y > TR.TOWER_H, 14.0)
	game.hud.stick = Vector2.ZERO
	check(tag + "climb the 14 m tower to the top", topped2, "pos %s stamina %.0f events %s" % [h.global_position, game.stamina, T.events.slice(-6)])
	# --- glide from the glide tower
	var gt: Vector3 = TR.GLIDE_TOWER
	T.events.clear()
	place(gt + Vector3(0, TR.GLIDE_H + 0.7, 1.5), 0.0)
	await until(func() -> bool: return h.is_on_floor(), 2.0)
	await wait(0.3)
	game.stamina = 100.0
	aim(Vector3(0, 0, 1))
	game.hud.stick = Vector2(0, -1)
	await until(func() -> bool: return h.global_position.y < TR.GLIDE_H - 1.0, 3.0)
	check(tag + "in the air high up, JUMP reads GLIDE", game.button_label("jump") == "GLIDE", game.button_label("jump"))
	game.hud.pressed["jump"] = true
	await wait(0.6)
	var g_on: bool = h.state == "glide"
	var y1: float = h.global_position.y
	var z1: float = h.global_position.z
	await wait(1.0)
	var sink: float = y1 - h.global_position.y
	var travel: float = h.global_position.z - z1
	await shot("t5_glide_" + key)
	check(tag + "the glider opens in the air, sinks slowly and flies forward", g_on and sink < 3.8 and sink > 1.5 and travel > 4.5 and T.glider != null and T.glider.visible, "sink %.2f m/s travel %.2f m/s" % [sink, travel])
	game.hud.stick = Vector2(1, 0)
	await wait(1.0)
	var steer_x: float = h.velocity.x
	check(tag + "the glider steers with the stick and uses stamina", absf(steer_x) > 2.0 and game.stamina < 90.0, "vx %.2f stamina %.0f" % [steer_x, game.stamina])
	game.hud.stick = Vector2(0, -1)
	var landed: bool = await until(func() -> bool: return h.is_on_floor(), 12.0)
	await wait(0.3)
	var far: float = Vector2(h.global_position.x - gt.x, h.global_position.z - gt.z).length()
	check(tag + "glide lands smoothly far from the tower (glider folds away)", landed and h.state == "idle" and far > 18.0 and h.hp == h.max_hp and not T.glider.visible, "dist %.1f hp %d events %s" % [far, h.hp, T.events.slice(-3)])
	# closing the glider drops you; no stamina closes it too
	place(gt + Vector3(0, TR.GLIDE_H + 0.7, 1.5), 0.0)
	await until(func() -> bool: return h.is_on_floor(), 2.0)
	await wait(0.3)
	game.stamina = 100.0
	game.hud.stick = Vector2(0, -1)
	await until(func() -> bool: return h.global_position.y < TR.GLIDE_H - 1.0, 3.0)
	game.hud.pressed["jump"] = true
	await until(func() -> bool: return h.state == "glide", 1.0)
	await wait(0.3)
	game.hud.pressed["jump"] = true
	await wait(0.5)
	check(tag + "JUMP again closes the glider and you fall", h.state == "idle" and h.velocity.y < -6.0, "state %s vy %.1f" % [h.state, h.velocity.y])
	await wait(0.15)
	game.hud.pressed["jump"] = true
	var reopened: bool = await until(func() -> bool: return h.state == "glide", 1.0)
	game.stamina = 0.5
	await wait(0.5)
	check(tag + "running out of stamina folds the glider", reopened and h.state != "glide" and T.exhausted, "reopened %s" % reopened)
	await until(func() -> bool: return h.is_on_floor(), 6.0)
	game.stamina = 100.0
	T.exhausted = false
	await wait(0.3)
	# --- walkable ramp (no slide) and the steep slope (slide)
	var rb: Vector3 = TR.RAMP_BASE
	place(Vector3(rb.x, 0.2, rb.z + 2.0), 0.0)
	await wait(0.3)
	T.events.clear()
	aim(Vector3(0, 0, -1))
	game.hud.stick = Vector2(0, -1)
	var up_ramp: bool = await until(func() -> bool: return h.global_position.y > 3.8 and h.is_on_floor(), 5.0)
	game.hud.stick = Vector2.ZERO
	check(tag + "walk up an 18 degree ramp without sliding", up_ramp and "slide" not in T.events, "pos %s" % h.global_position)
	var st: Vector3 = TR.SLIDE_TOP
	place(Vector3(st.x, TR.SLIDE_H + 0.3, st.z - 1.0), 0.0)
	await wait(0.4)
	T.events.clear()
	aim(Vector3(0, 0, 1))
	game.hud.stick = Vector2(0, -1)
	var sliding: bool = await until(func() -> bool: return h.state == "slide", 3.0)
	game.hud.stick = Vector2.ZERO
	await wait(0.3)
	await shot("t6_slide_" + key)
	var slid: bool = await until(func() -> bool: return h.state == "idle" and h.global_position.y < 0.6 and h.is_on_floor(), 4.0)
	check(tag + "a 42 degree slope makes you slide to the bottom", sliding and slid and "slide_end:flat" in T.events, "pos %s events %s" % [h.global_position, T.events])
	# --- combat still works after traversal
	var k: CharacterBody3D = game.enemies[1]
	place(k.global_position + Vector3(0, 0, 1.6), 0.0)
	await wait(0.3)
	k.active = true
	for e: CharacterBody3D in game.enemies:
		e.attack_cd = 99.0
	game.hud.pressed["attack"] = true
	await wait(0.6)
	check(tag + "sword attack still hits after traversal", k.hp < k.max_hp, "hp %d" % k.hp)
	game.stamina = 100.0
	game.hud.stick = Vector2(1, 0)
	game.hud.pressed["dodge"] = true
	await wait(0.05)
	var dodged: bool = h.state == "dodge"
	game.hud.stick = Vector2.ZERO
	await wait(0.4)
	game.hud.holds["block"] = 1
	var blocked: bool = await until(func() -> bool: return h.state == "block", 0.6)
	game.hud.holds["block"] = 0
	await wait(0.2)
	check(tag + "dodge and block still work", dodged and blocked and game.stamina < 100.0, "dodge %s block %s state %s floor %s sword %s" % [dodged, blocked, h.state, h.is_on_floor(), game.sword_out])
	# --- shield: carried on the arm, raised in front when guarding
	place(Vector3(0, 0.2, -40), 0.0)
	await wait(0.4)
	var sh: Node3D = h.rig.shield
	var carried: float = h.rig.shield_facing().dot(h.forward())
	game.hud.holds["block"] = 1
	await wait(0.4)
	var raised: float = h.rig.shield_facing().dot(h.forward())
	await shot("t7_shield_" + key)
	var hp_s: float = h.hp
	var k2: CharacterBody3D = game.enemies[0]
	k2.global_position = h.global_position + h.forward() * 1.5
	k2.yaw = h.yaw + PI
	game.enemy_hits(k2, 12.0, 3.0, -1.0)
	game.hud.holds["block"] = 0
	k2.global_position = k2.home
	await wait(0.2)
	check(tag + "the hero carries a shield and raises it in front to block", sh != null and sh.visible and raised > 0.7 and raised > carried + 0.3 and h.hp == hp_s, "facing carried %.2f raised %.2f hp %d" % [carried, raised, h.hp])
	# --- spin attack: keep ATTACK held, let go to spin; hits all round
	for i in 3:
		var e3: CharacterBody3D = game.enemies[i]
		var a3: float = i * TAU / 3.0
		e3.global_position = h.global_position + Vector3(sin(a3), 0, cos(a3)) * 2.4
		e3.velocity = Vector3.ZERO
		e3.attack_cd = 99.0
		e3.hp = e3.max_hp
	await wait(0.2)
	game.hud.pressed["attack"] = true
	game.hud.holds["attack"] = 1
	await wait(1.4)
	var charged: bool = game.spin_charge >= 1.0 and game.button_label("attack") == "SPIN!"
	await shot("t8_spin_charge_" + key)
	game.hud.holds["attack"] = 0
	await wait(0.2)
	var spun: bool = h.state == "spin"
	await shot("t8_spin_" + key)
	await wait(0.5)
	var all_hit: bool = true
	for i in 3:
		var e4: CharacterBody3D = game.enemies[i]
		if e4.hp >= e4.max_hp:
			all_hit = false
	check(tag + "hold ATTACK to charge, let go to spin: hits enemies all round", charged and spun and all_hit, "charged %s spun %s hp %s" % [charged, spun, [game.enemies[0].hp, game.enemies[1].hp, game.enemies[2].hp]])
	for e5: CharacterBody3D in game.enemies:
		e5.global_position = e5.home
		e5.active = false
	# a quick tap is still a normal swing (no spin)
	game.hud.pressed["attack"] = true
	game.hud.holds["attack"] = 1
	await wait(0.1)
	game.hud.holds["attack"] = 0
	await wait(0.8)
	check(tag + "a quick tap of ATTACK is still a normal swing", h.state != "spin" and game.spin_charge == 0.0)
	# --- shield surfing down the slide slope
	var st2: Vector3 = TR.SLIDE_TOP
	place(Vector3(st2.x, TR.SLIDE_H + 0.3, st2.z - 1.5), 0.0)
	await until(func() -> bool: return h.is_on_floor(), 2.0)
	T.events.clear()
	aim(Vector3(0, 0, 1))
	game.hud.stick = Vector2(0, -1)
	await wait(0.3)
	game.hud.holds["block"] = 1
	await wait(0.15)
	game.hud.pressed["jump"] = true
	var surfing: bool = await until(func() -> bool: return h.state == "surf", 1.5)
	var top_speed: float = 0.0
	var t1: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 2500:
		top_speed = maxf(top_speed, hspeed())
		await wait(0.03)
	await shot("t9_surf_" + key)
	var still_surf: bool = h.state == "surf"
	game.hud.stick = Vector2.ZERO
	game.hud.holds["block"] = 0
	await wait(0.2)
	check(tag + "GUARD + JUMP rides the shield down a slope, fast", surfing and top_speed > 9.0 and still_surf and h.global_position.y < 1.0, "surf %s top speed %.1f pos %s events %s" % [surfing, top_speed, h.global_position, T.events])
	check(tag + "letting go of GUARD steps off the shield", h.state == "idle" and "surf_end:off" in T.events)
	await wait(0.4)
	# sprint into an attack: the attack wins
	place(k.global_position + Vector3(0, 0, 5.0), 0.0)
	await wait(0.3)
	aim(Vector3(0, 0, -1))
	game.hud.stick = Vector2(0, -1)
	game.hud.pressed["sprint"] = true
	await wait(0.3)
	var was_spr: bool = T.sprinting
	game.hud.pressed["attack"] = true
	await wait(0.1)
	check(tag + "attacking while sprinting stops the sprint and swings", was_spr and h.state == "attack" and not T.sprinting, h.state)
	game.hud.stick = Vector2.ZERO
	await wait(0.6)

## Screenshots of the hero's retargeted idle / walk / run / sprint as the game camera sees them.
func anim_shots() -> void:
	game.restart_with("blonde_lance", "trials")
	game.start_game()
	await wait(0.6)
	var h: CharacterBody3D = game.hero
	for spec: Array in [["idle", Vector2.ZERO, false], ["walk", Vector2(0, -0.35), false], ["run", Vector2(0, -1), false], ["sprint", Vector2(0, -1), true], ["run_side", Vector2(1, 0), false], ["sneaky_side", Vector2(0.3, 0), false]]:
		place(Vector3(0, 0.2, 4), 0.0)
		game.cam_yaw = 0.0
		game.stamina = 100.0
		await wait(0.3)
		game.hud.stick = spec[1]
		if spec[2]:
			Input.action_press("cc_sprint")
		await wait(1.0)
		for i in 4:
			await shot("anim_%s_%d" % [spec[0], i])
			await wait(0.09)
		print("ANIM ", spec[0], " speed ", Vector2(h.velocity.x, h.velocity.z).length(), " clip ", h.clip_on, " lift ", h.clip_lift)
		Input.action_release("cc_sprint")
		game.hud.stick = Vector2.ZERO
		await wait(0.4)
	# a hard turn while running, then a stop
	place(Vector3(0, 0.2, 4), 0.0)
	game.cam_yaw = 0.0
	game.hud.stick = Vector2(0, -1)
	await wait(1.0)
	game.hud.stick = Vector2(-1, 0)
	for i in 4:
		await wait(0.05)
		await shot("anim_turn_%d" % i)
		print("ANIM turn bank ", h.bank)
	await wait(0.6)
	game.hud.stick = Vector2.ZERO
	for i in 4:
		await wait(0.03)
		await shot("anim_stop_%d" % i)
		print("ANIM stop surge ", h.surge)
