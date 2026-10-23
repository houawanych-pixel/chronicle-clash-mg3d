extends CharacterBody3D
## Hero, ally, knight and boss share this body. The game drives the hero
## from input; everyone else runs a small state machine here.
const RigScript = preload("res://scripts/citadel/Rig.gd")
const P = preload("res://scripts/citadel/Poses.gd")
const GRAVITY: float = 26.0

var game: Node
var kind: String = "knight"
var rig: Node3D
var hp: float = 100.0
var max_hp: float = 100.0
var yaw: float = 0.0
var state: String = "idle"
var state_t: float = 0.0
var state_len: float = 0.0
var anim_t: float = 0.0
var run_phase: float = 0.0
var speed_now: float = 0.0
## Retargeted clips (hero): shared walk/run phase, hip bob, and the hip height they are scaled to.
var loco_phase: float = 0.0
var clip_lift: float = 0.0
var clip_on: bool = false
var hip_h: float = 0.0
## Turn bank and start/stop lean (BotW-style: lean into turns, dip forward to start, sit back to stop).
var last_yaw: float = 0.0
var last_hs: float = 0.0
var bank: float = 0.0
var surge: float = 0.0
var flash: float = 0.0
var flash_color: Color = Color.WHITE
var combo: int = 0
var hit_done: bool = false
var attack_cd: float = 1.0
var dmg: float = 12.0
var move_speed: float = 3.6
var reach: float = 2.3
var active: bool = false
var section: int = 0
var home: Vector3
var dead_t: float = 0.0
var plunge_t: float = 0.0
var slam_count: int = 0
var heal_cd: float = 6.0
var hurt_cd: float = 0.0
var height: float = 1.8
# Stealth patrol state (see Patrol.gd, ported from the MG Guard.gd).
var stealth: bool = false
var route: Array = []
var route_i: int = 0
var gstate: String = ""
var suspicion: float = 0.0
var last_known: Vector3
var search_t: float = 0.0
var seeing: bool = false
var cone: MeshInstance3D
var cone_t: float = 0.0
var vision_range: float = 9.5
var vision_half: float = 40.0

func setup(g: Node, k: String, model: String, h: float, blade: Color, blade_len: float) -> void:
	game = g
	kind = k
	height = h
	var shape: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.38 * h / 1.8
	cap.height = h
	shape.shape = cap
	shape.position.y = h * 0.5
	add_child(shape)
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50)
	rig = Node3D.new()
	rig.set_script(RigScript)
	add_child(rig)
	rig.setup(model, h, blade, blade_len, 0.8 if k in ["hero", "boss"] else 0.15)
	if k == "hero":
		rig.add_shield(blade)
	home = global_position

func forward() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))

func face_toward(p: Vector3, dt: float, rate: float = 10.0) -> void:
	var to: Vector3 = p - global_position
	to.y = 0
	if to.length() < 0.01:
		return
	var want: float = atan2(-to.x, -to.z)
	yaw = lerp_angle(yaw, want, 1.0 - exp(-rate * dt))

func set_state(s: String, length: float = 0.0) -> void:
	state = s
	state_t = 0.0
	state_len = length
	hit_done = false

func alive() -> bool:
	return state != "dead"

func busy() -> bool:
	return state in ["attack", "plunge", "hurt", "stagger", "windup", "strike", "recover", "leap", "slam", "cast"]

func damage(amount: float, from: Vector3, stagger_time: float = 0.25) -> void:
	if not alive():
		return
	hp -= amount
	flash = 1.0
	flash_color = Color(1, 0.95, 0.85)
	var push: Vector3 = global_position - from
	push.y = 0
	if push.length() > 0.01:
		velocity += push.normalized() * (2.5 if kind != "boss" else 0.6)
	game.spawn_number(global_position + Vector3.UP * height * 1.05, amount, kind == "hero")
	if hp <= 0:
		hp = 0
		set_state("dead")
		dead_t = 0.0
		rig.trail_on = false
		game.on_death(self)
		return
	if kind == "boss":
		if state in ["recover", "idle", "chase"] and stagger_time > 0.6:
			set_state("stagger", stagger_time)
		return
	if stagger_time > 0.0:
		set_state("stagger" if stagger_time > 0.5 else "hurt", stagger_time)

func _physics_process(dt: float) -> void:
	if game == null or game.paused():
		return
	state_t += dt
	anim_t += dt
	flash = maxf(0.0, flash - dt * 4.0)
	if not is_on_floor() and state not in ["wallclimb", "grapple", "glide", "ledge", "pullup"]:
		velocity.y -= GRAVITY * dt
	match kind:
		"hero":
			game.hero_tick(self, dt)
		"ally":
			ally_tick(dt)
		"boss":
			boss_tick(dt)
		_:
			knight_tick(dt)
	if state == "dead":
		velocity.x = move_toward(velocity.x, 0, 20 * dt)
		velocity.z = move_toward(velocity.z, 0, 20 * dt)
	move_and_slide()
	# Nobody stands on anyone's head: slide off another character's top.
	for i in get_slide_collision_count():
		var c: KinematicCollision3D = get_slide_collision(i)
		var other: Object = c.get_collider()
		if other is CharacterBody3D and c.get_normal().y > 0.4:
			var away: Vector3 = global_position - (other as Node3D).global_position
			away.y = 0
			if away.length() < 0.05:
				away = Vector3(1, 0, 0)
			global_position += away.normalized() * 6.0 * dt
			velocity.y = minf(velocity.y, -3.0)
			break
	animate(dt)

## Idle / walk / run / sprint from the retargeted Mixamo clips (Running, Standard Walk, Idle):
## walk and run share one phase so they blend in step; the phase advances by distance covered,
## so the feet match the ground speed up to a natural cadence (2.3 strides a second), then the stride lengthens.
func loco_clip(dt: float, hs: float) -> Dictionary:
	var C: RefCounted = game.clips
	if hip_h <= 0.0:
		var hi: int = rig.sk.find_bone("Hip")
		hip_h = (rig.model.transform * rig.sk.get_bone_global_rest(hi)).origin.y if hi >= 0 else height * 0.55
	var w: float = clampf((hs - 1.6) / 2.4, 0.0, 1.0)
	var walk_stride: float = C.move_rate("mx_walk") * hip_h * C.length("mx_walk")
	var run_stride: float = C.move_rate("mx_run") * hip_h * C.length("mx_run")
	var stride: float = lerpf(walk_stride, run_stride, w)
	loco_phase = fposmod(loco_phase + dt * minf(hs / maxf(stride, 0.1), 2.3), 1.0)
	var moving: Dictionary = C.mix(C.sample("mx_walk", loco_phase * C.length("mx_walk")), C.sample("mx_run", loco_phase * C.length("mx_run")), w)
	var p: Dictionary = C.mix(C.sample("mx_idle", anim_t), moving, clampf(hs / 1.0, 0.0, 1.0))
	if game.trav.sprinting:
		p["Spine01"] = (p.get("Spine01", Quaternion()) as Quaternion) * P.lean(0.18)
	elif game.trav.exhausted and hs > 0.5:
		p["Spine01"] = (p.get("Spine01", Quaternion()) as Quaternion) * P.lean(0.3)
	# Sword out (Link-style carry): lean into the run, the shield arm stays across the body
	# (half the swing, forearm forward) so the shield rides in front-left instead of flapping.
	if not unarmed() and hs > 0.5:
		var k: float = clampf((hs - 0.5) / 3.0, 0.0, 1.0)
		p["Spine01"] = (p.get("Spine01", Quaternion()) as Quaternion) * P.lean(0.1 * k)
		var ua: Vector3 = p.get("L_Upperarm", P.d(0, -1, -0.3))
		p["L_Upperarm"] = ua.slerp(P.d(0.25, -0.9, -0.45), 0.55 * k).normalized()
		var fa: Vector3 = p.get("L_Forearm", P.d(0.5, -0.6, -0.1))
		p["L_Forearm"] = fa.slerp(P.d(0.85, 0.15, 0.35), 0.6 * k).normalized()
	# lean into turns (bank about the forward axis) and with speed changes (forward to start, back to stop)
	var yaw_rate: float = wrapf(yaw - last_yaw, -PI, PI) / maxf(dt, 0.001)
	last_yaw = yaw
	var accel: float = (hs - last_hs) / maxf(dt, 0.001)
	last_hs = hs
	var run_k: float = clampf(hs / 6.0, 0.0, 1.0)
	bank = lerpf(bank, clampf(-yaw_rate * 0.06, -0.3, 0.3) * run_k, 1.0 - exp(-8.0 * dt))
	surge = lerpf(surge, clampf(accel * 0.012, -0.18, 0.2), 1.0 - exp(-6.0 * dt))
	var tilt: Quaternion = Quaternion(Vector3(1, 0, 0), bank) * P.lean(surge)
	p["Hip"] = tilt * (p.get("Hip", Quaternion()) as Quaternion)
	clip_lift = float(p.get("lift", 0.0)) * hip_h
	# the sword trails back and down from the hand while running, hangs low and forward when standing
	var fore: Vector3 = p.get("R_Forearm", P.d(0, -1, 0))
	var held: Vector3 = (fore * 0.05 + P.d(-0.85, -0.2, 0.45)).normalized()
	p["blade"] = P.d(0.7, -0.25, 0.25).slerp(held, clampf(hs / 1.5, 0.0, 1.0))
	return p

## Hero with the sword on his back walks and stands with loose arms.
func unarmed() -> bool:
	return kind == "hero" and not game.sword_out

func animate(dt: float) -> void:
	var pose: Dictionary
	var rate: float = 14.0
	clip_on = false
	var t: float = clampf(state_t / maxf(state_len, 0.001), 0.0, 1.0)
	match state:
		"attack":
			pose = P.slash(combo, t)
			rate = 30.0
		"plunge":
			pose = P.plunge(clampf(state_t * 3.0, 0, 1))
			rate = 25.0
		"dodge":
			pose = P.run(state_t * 26.0, 1.0)
			pose["Spine01"] = P.lean(0.45)
			rate = 30.0
		"dashchain":
			pose = P.slash(combo, clampf(0.25 + plunge_t / 0.24 * 0.75, 0, 1))
			rate = 40.0
		"block":
			pose = P.shield_block(anim_t) if kind == "hero" else P.block(anim_t)
			rate = 24.0
		"spin":
			pose = P.spin(t)
			rate = 30.0
		"surf":
			pose = P.surf(anim_t)
			rate = 14.0
		"windup", "leap":
			pose = P.windup(t)
			rate = 16.0
		"strike", "slam":
			pose = P.strike(t)
			rate = 34.0
		"recover":
			pose = P.idle(anim_t, false)
		"hurt":
			pose = P.hurt(t)
			rate = 20.0
		"stagger":
			pose = P.stagger(state_t)
			rate = 18.0
		"dead":
			pose = P.dead()
			rate = 8.0
		"cast":
			pose = P.cast(anim_t)
		"climb", "wallclimb":
			pose = P.climb(game.climb_phase)
			rate = 18.0
		"glide":
			pose = P.glide(anim_t)
			rate = 12.0
		"ledge":
			pose = P.ledge_hang(game.climb_phase)
			rate = 16.0
		"pullup":
			pose = P.pullup(clampf(state_t / maxf(game.trav.pull.get("dur", 0.5), 0.05), 0.0, 1.0))
			rate = 22.0
		"slide":
			pose = P.slide(anim_t)
			rate = 12.0
		"grapple":
			pose = P.airborne(4.0)
			pose["R_Upperarm"] = P.d(1.0, 0.45, 0.2)
			pose["R_Forearm"] = P.d(1.0, 0.5, 0.0)
			rate = 18.0
		_:
			var hs: float = Vector2(velocity.x, velocity.z).length()
			speed_now = lerpf(speed_now, clampf(hs / 6.0, 0.0, 1.0), 1.0 - exp(-10.0 * dt))
			if kind == "hero" and game.prone:
				run_phase += dt * 6.0 * speed_now / 0.25
				pose = P.crawl(run_phase, clampf(speed_now / 0.25, 0, 1))
			elif kind == "hero" and game.in_cover() and not game.cover_low:
				pose = P.hug(game.cover_side, speed_now > 0.05, game.peeking)
			elif kind == "hero" and game.crouched:
				run_phase += dt * 7.0 * speed_now / 0.45
				pose = P.crouch(run_phase, clampf(speed_now / 0.45, 0, 1))
			elif not is_on_floor() and kind == "hero":
				pose = P.airborne(velocity.y)
			elif kind == "hero" and game.trav.land_t > 0.0 and is_on_floor():
				pose = P.land(game.trav.land_t)
			elif kind == "hero" and game.clips != null and game.clips.has("mx_run"):
				pose = loco_clip(dt, hs)
				rate = 30.0
				clip_on = true
			elif kind == "hero" and game.trav.sprinting and speed_now > 0.5:
				run_phase += dt * 13.5
				pose = P.sprint(run_phase)
			elif speed_now > 0.08:
				run_phase += dt * (5.0 + 6.5 * speed_now)
				pose = P.run_free(run_phase, speed_now) if unarmed() else P.run(run_phase, speed_now)
				if kind == "hero" and game.trav.exhausted:
					pose["Spine01"] = P.lean(0.38)
			else:
				pose = P.idle_free(anim_t) if unarmed() else P.idle(anim_t, kind != "ally")
			if kind == "hero" and game.draw_t > 0.0 and state == "idle" and is_on_floor():
				var dp: Dictionary = P.reach_back(1.0 - game.draw_t / game.DRAW_TIME)
				for key: String in ["R_Upperarm", "R_Forearm", "blade", "Spine02"]:
					pose[key] = dp[key]
			if kind == "ally" and game.ally_captive:
				pose = P.crouch(0.0, 0.0)
			if kind == "ally" and game.stage == "forest" and game.hero_low():
				run_phase += dt * 6.0 * speed_now / 0.45
				pose = P.crouch(run_phase, clampf(speed_now / 0.45, 0, 1))
	rig.rotation.y = yaw
	if state == "dead":
		dead_t += dt
		rig.rotation.x = lerpf(rig.rotation.x, PI / 2.0 * 0.92, 1.0 - exp(-6.0 * dt))
		rig.position.y = lerpf(rig.position.y, 0.25, 1.0 - exp(-6.0 * dt))
		if kind != "hero" and dead_t > 2.2:
			rig.position.y -= dt * 0.6
			if dead_t > 3.6:
				visible = false
	else:
		var tilt: float = 0.0
		var drop: float = 0.0
		if kind == "hero" and state in ["idle", "block"]:
			if game.prone:
				tilt = -1.42
				drop = 0.22
			elif game.crouched or (game.in_cover() and game.cover_low):
				drop = -0.34
		elif kind == "ally" and game.stage == "forest" and game.hero_low() and state == "idle":
			drop = -0.3
		if kind == "hero" and state == "surf":
			drop = 0.12
		rig.rotation.x = lerpf(rig.rotation.x, tilt, 1.0 - exp(-10.0 * dt))
		if clip_on:
			rig.position.y = lerpf(rig.position.y, clip_lift, 1.0 - exp(-30.0 * dt))
		else:
			rig.position.y = lerpf(rig.position.y, drop, 1.0 - exp(-12.0 * dt))
	# Anyone the close camera would clip through fades out of the way.
	if kind != "hero" and game.camera:
		var cd: float = game.camera.global_position.distance_to(global_position + Vector3.UP * height * 0.5)
		rig.visible = cd > 1.3
		# Far-off characters skip bone posing; nobody can see the detail.
		if cd > 38.0 and state != "dead":
			return
	if kind == "hero":
		rig.sheathed = not game.sword_out
		if state == "surf":
			rig.shield_mode = "surf"
		elif not game.sword_out:
			rig.shield_mode = "back"
		elif state == "block" or game.spin_charge > 0.0:
			rig.shield_mode = "guard"
		else:
			rig.shield_mode = "arm"
		if game.spin_charge > 0.0 and state == "idle":
			# hold the blade back, ready to spin
			var wp: Dictionary = P.spin_ready(anim_t)
			for key2: String in wp:
				pose[key2] = wp[key2]
	rig.apply(pose, dt, rate)
	rig.update_trail()
	var tint: float = flash
	var col: Color = flash_color
	if state == "windup" or state == "leap":
		tint = maxf(tint, 0.25 + 0.25 * sin(state_t * 30.0))
		col = Color(1, 0.15, 0.1)
	rig.glow = 1.0 if state in ["attack", "plunge", "strike", "slam", "dashchain", "spin"] else (0.6 if state in ["windup", "leap"] else 0.0)
	if kind == "hero" and game.spin_charge > 0.0:
		rig.glow = maxf(rig.glow, game.spin_charge * 1.8)
		if game.spin_charge >= 1.0:
			tint = maxf(tint, 0.2 + 0.15 * sin(anim_t * 24.0))
			col = rig.blade_color
	if kind == "hero" and game.charge > 0.0:
		rig.glow = maxf(rig.glow, game.charge * 1.6)
		tint = maxf(tint, game.charge * 0.25 * (0.6 + 0.4 * sin(anim_t * 20.0)))
		col = Color(1.0, 0.85, 0.4)
	rig.set_flash(tint * 0.5, col)

## Knights: chase, telegraph, strike, recover. A shared token keeps at most
## two of them swinging at once so the player can read the fight.
func knight_tick(dt: float) -> void:
	var hero: CharacterBody3D = game.target_for(self)
	if not alive():
		return
	if global_position.y < home.y - 15.0:
		# Knocked off the sky ruin: counts as defeated so the section can clear.
		hp = 0
		set_state("dead")
		game.on_death(self)
		return
	attack_cd -= dt
	var to: Vector3 = hero.global_position - global_position
	to.y = 0
	var dist: float = to.length()
	if not active:
		if stealth:
			game.patrol.tick(self, dt)
			return
		velocity.x = 0
		velocity.z = 0
		if section <= game.section and dist < 13.0 and absf(hero.global_position.y - global_position.y) < 3.5:
			active = true
			game.sound("alarm", -18)
		return
	# Forest: an alerted guard who loses sight of you heads for where you were
	# last seen instead of homing in (the MG CHASE -> last_known rule).
	if stealth and game.stage == "forest" and hero == game.hero:
		if game.patrol.can_see(self) or dist < 2.5:
			last_known = hero.global_position
		else:
			to = last_known - global_position
			to.y = 0
			dist = maxf(to.length(), reach)
	match state:
		"idle", "chase":
			face_toward(global_position + to, dt)
			var sep: Vector3 = game.separation(self)
			if dist > reach * 0.85 and hero.alive():
				var v: Vector3 = to.normalized() * move_speed + sep * 2.0
				velocity.x = v.x
				velocity.z = v.z
				state = "chase"
			else:
				velocity.x = sep.x * 2.0
				velocity.z = sep.z * 2.0
				state = "idle"
				if attack_cd <= 0 and hero.alive() and game.take_token(self):
					set_state("windup", 0.62)
					velocity.x = 0
					velocity.z = 0
		"windup":
			face_toward(hero.global_position, dt, 6.0)
			velocity.x = 0
			velocity.z = 0
			if state_t >= state_len:
				set_state("strike", 0.24)
				velocity += forward() * 4.0
				game.sound("knock", -10)
		"strike":
			velocity.x = move_toward(velocity.x, 0, 30 * dt)
			velocity.z = move_toward(velocity.z, 0, 30 * dt)
			if not hit_done and state_t > 0.08:
				hit_done = true
				game.enemy_hits(self, dmg, reach + 0.4, 0.55)
			if state_t >= state_len:
				set_state("recover", 0.55)
				game.give_token(self)
		"recover":
			velocity.x = 0
			velocity.z = 0
			if state_t >= state_len:
				state = "idle"
				attack_cd = randf_range(0.9, 1.9)
		"hurt", "stagger":
			velocity.x = move_toward(velocity.x, 0, 12 * dt)
			velocity.z = move_toward(velocity.z, 0, 12 * dt)
			game.give_token(self)
			if state_t >= state_len:
				state = "idle"
				attack_cd = maxf(attack_cd, 0.5)

## The Dark Knight: three-cut combo, and a leaping slam whose shockwave
## can only be avoided by jumping over it.
func boss_tick(dt: float) -> void:
	var hero: CharacterBody3D = game.hero
	if not alive():
		return
	if global_position.y < home.y - 6.0:
		# Leapt off the sky ruin's core: he returns in a burst, the fight goes on.
		global_position = home
		velocity = Vector3.ZERO
		game.burst(home + Vector3.UP, Color("ff3346"), 30, 5.0)
	attack_cd -= dt
	var to: Vector3 = hero.global_position - global_position
	to.y = 0
	var dist: float = to.length()
	var rage: bool = hp < max_hp * 0.5
	if not active:
		velocity.x = 0
		velocity.z = 0
		return
	match state:
		"idle", "chase":
			face_toward(hero.global_position, dt, 6.0)
			if attack_cd <= 0 and hero.alive():
				if dist > 5.5 or (randf() < 0.3 and slam_count < 2):
					set_state("leap", 0.75 if not rage else 0.55)
					slam_count += 1
				elif dist < reach + 0.6:
					combo = 0
					slam_count = 0
					set_state("windup", 0.55 if not rage else 0.4)
				else:
					velocity.x = to.normalized().x * move_speed
					velocity.z = to.normalized().z * move_speed
			elif dist > reach * 0.8:
				velocity.x = to.normalized().x * move_speed
				velocity.z = to.normalized().z * move_speed
				state = "chase"
			else:
				velocity.x = 0
				velocity.z = 0
		"windup":
			velocity.x = 0
			velocity.z = 0
			face_toward(hero.global_position, dt, 8.0)
			if state_t >= state_len:
				set_state("strike", 0.26)
				velocity += forward() * 6.0
				game.sound("knock", -6)
		"strike":
			velocity.x = move_toward(velocity.x, 0, 35 * dt)
			velocity.z = move_toward(velocity.z, 0, 35 * dt)
			if not hit_done and state_t > 0.08:
				hit_done = true
				game.enemy_hits(self, dmg, reach + 0.6, 0.45)
			if state_t >= state_len:
				combo += 1
				if combo < 3:
					set_state("windup", (0.3 if combo == 1 else 0.42) * (0.8 if rage else 1.0))
				else:
					set_state("recover", 1.1 if not rage else 0.8)
		"leap":
			velocity.x = 0
			velocity.z = 0
			face_toward(hero.global_position, dt, 8.0)
			if state_t >= state_len:
				var target: Vector3 = hero.global_position
				var flat: Vector3 = target - global_position
				flat.y = 0
				var air: float = 0.8
				velocity = flat / air
				velocity.y = GRAVITY * air * 0.5
				set_state("slam", 1.2)
				game.sound("hook", -6)
		"slam":
			if state_t > 0.15 and is_on_floor():
				velocity.x = 0
				velocity.z = 0
				game.shockwave(global_position, rage)
				set_state("recover", 1.0 if not rage else 0.7)
				attack_cd = 0.6
			elif state_t > 2.0:
				set_state("recover", 0.6)
		"recover":
			velocity.x = 0
			velocity.z = 0
			if state_t >= state_len:
				state = "idle"
				attack_cd = randf_range(0.5, 1.2) if rage else randf_range(0.9, 1.6)
		"stagger":
			velocity.x = move_toward(velocity.x, 0, 10 * dt)
			velocity.z = move_toward(velocity.z, 0, 10 * dt)
			if state_t >= state_len:
				state = "idle"
				attack_cd = 0.4

## Eliza follows the hero and heals once the hero is hurt.
func ally_tick(dt: float) -> void:
	var hero: CharacterBody3D = game.hero
	if game.ally_captive:
		# held in the crystal cage: kneel and watch the fight
		velocity.x = 0
		velocity.z = 0
		face_toward(hero.global_position, dt, 2.0)
		return
	heal_cd -= dt
	# Stay at Lance's left shoulder, out of the over-the-shoulder camera's view line.
	var spot: Vector3 = hero.global_position - game.cam_right() * 1.8 + game.cam_forward() * 0.4
	if game.stage == "forest":
		# Closer in the forest so his cover is her cover.
		spot = hero.global_position - game.cam_right() * 1.1 - game.cam_forward() * 0.6
	var to: Vector3 = spot - global_position
	to.y = 0
	if to.length() > 14.0 or global_position.y < hero.global_position.y - 4.0:
		global_position = spot + Vector3.UP * 0.5
		velocity = Vector3.ZERO
		return
	if state == "cast":
		velocity.x = 0
		velocity.z = 0
		face_toward(hero.global_position, dt)
		if state_t > 0.5 and not hit_done:
			hit_done = true
			game.ally_heal(self)
		if state_t >= state_len:
			state = "idle"
		return
	if hero.alive() and hero.hp < hero.max_hp * 0.5 and heal_cd <= 0:
		heal_cd = 16.0
		set_state("cast", 1.0)
		return
	if to.length() > 0.8:
		var sp: float = clampf(to.length() * 2.2, 0.0, 7.5)
		velocity.x = to.normalized().x * sp
		velocity.z = to.normalized().z * sp
		face_toward(global_position + to, dt)
		if is_on_floor() and to.length() > 3.0 and hero.global_position.y > global_position.y + 0.6:
			velocity.y = 9.0
	else:
		velocity.x = 0
		velocity.z = 0
		face_toward(hero.global_position + hero.forward() * 6.0, dt, 4.0)
