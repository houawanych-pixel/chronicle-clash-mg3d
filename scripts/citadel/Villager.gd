extends CharacterBody3D
## A village resident. Separate from Fighter.gd: villagers never fight.
## Each one belongs to a single village block and never leaves it.
##
## States: idle, walk, work, sit, inside, talk.
## Every few game minutes the villager asks the village what its schedule
## says (wake, work, eat, social, sleep) and walks to a matching spot using
## Godot's NavigationAgent3D on the block's baked navigation mesh.
const RigScript = preload("res://scripts/citadel/Rig.gd")
const P = preload("res://scripts/citadel/Poses.gd")
const GRAVITY: float = 26.0

var game: Node
var village: RefCounted
var vid: String = ""
var vname: String = ""
var job: String = "wanderer"
var home_door: RefCounted
var height: float = 1.75
var walk_speed: float = 1.6
var rig: Node3D
var agent: NavigationAgent3D
var bubble: Label3D
var load_box: MeshInstance3D

var state: String = "idle"
var activity: String = ""      # what the schedule asked for last
var goal_kind: String = ""     # work, drop, seat, door, point
var spot: RefCounted           # claimed WorkSpot
var target: Vector3
var linger: float = 0.0        # game minutes left idling at a point
var work_min: float = 0.0      # game minutes into the current work cycle
var work_count: int = 0        # finished work cycles (logs, ore, fish, sacks...)
var carrying: bool = false
var inside_min: float = 0.0
var yaw: float = 0.0
var anim_t: float = 0.0
var run_phase: float = 0.0
var speed_now: float = 0.0
var think_min: float = 0.0
var stuck_t: float = 0.0
var stuck_from: Vector3
var repaths: int = 0
var recoveries: int = 0
var talk_t: float = 0.0
var talk_cd: float = 0.0
var resume_state: String = ""
var desired_vel: Vector3 = Vector3.ZERO

const LINES: Dictionary = {
	"woodcutter": ["Good timber in these woods.", "Mind the axe, traveller.", "One more log and I'll rest."],
	"miner": ["This rock's got iron in it.", "My back aches, but the ore pays.", "Hear that ring? Good stone."],
	"fisher": ["They're biting today.", "Quiet now, you'll scare the fish.", "Caught a big one this morning!"],
	"merchant": ["Fresh goods! Have a look.", "Bread, rope, lamp oil. Best prices.", "Come back when you've got coin."],
	"elder": ["I remember when the citadel was built.", "Sit a while, young one.", "The knights are restless lately."],
	"wanderer": ["Lovely day, isn't it?", "Have you seen the windmill?", "I'm off to see a friend."],
	"farmer": ["The wheat's coming in well.", "Rain soon, I can feel it.", "Mind the furrows!"],
	"miller": ["Flour for the whole village.", "The sails never rest.", "Another sack done."],
}

func setup(g: Node, v: RefCounted, def: Dictionary) -> void:
	game = g
	village = v
	vid = def.id
	vname = def.name
	job = def.job
	height = def.get("height", 1.75)
	walk_speed = def.get("speed", 1.6)
	collision_layer = 4
	collision_mask = 1
	var shape: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = height
	shape.shape = cap
	shape.position.y = height * 0.5
	add_child(shape)
	floor_snap_length = 0.4
	rig = Node3D.new()
	rig.set_script(RigScript)
	add_child(rig)
	rig.setup(def.model, height, Color("c8b48a"), 0.9, 0.0)
	rig.set_tool("none")
	if def.has("tint"):
		rig.set_flash(0.14, def.tint)
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.6
	agent.target_desired_distance = 0.5
	agent.radius = 0.45
	agent.height = height
	agent.max_speed = walk_speed + 0.4
	agent.avoidance_enabled = true
	agent.neighbor_distance = 4.0
	agent.time_horizon_agents = 1.0
	agent.path_max_distance = 3.0
	add_child(agent)
	agent.velocity_computed.connect(_on_velocity)
	bubble = Label3D.new()
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.no_depth_test = true
	bubble.font_size = 34
	bubble.pixel_size = 0.0028
	bubble.outline_size = 10
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.width = 520.0
	bubble.modulate = Color("fff6dd")
	bubble.outline_modulate = Color(0.05, 0.08, 0.15, 0.9)
	bubble.position = Vector3(0, height + 0.55, 0)
	bubble.visible = false
	add_child(bubble)
	load_box = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.5, 0.3, 0.3)
	load_box.mesh = bm
	var lm: StandardMaterial3D = StandardMaterial3D.new()
	lm.albedo_color = Color("8a6a44")
	load_box.material_override = lm
	load_box.visible = false
	add_child(load_box)

# ---------------------------------------------------------------- helpers

func forward() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))

func face(p: Vector3, dt: float, rate: float = 8.0) -> void:
	var to: Vector3 = p - global_position
	to.y = 0
	if to.length() < 0.01:
		return
	yaw = lerp_angle(yaw, atan2(-to.x, -to.z), 1.0 - exp(-rate * dt))

func release_spot() -> void:
	if spot:
		spot.release(self)
	spot = null

func go_to(p: Vector3, kind: String) -> void:
	goal_kind = kind
	target = p
	agent.target_position = p
	state = "walk"
	stuck_t = 0.0
	stuck_from = global_position
	repaths = 0

func say(text: String) -> void:
	bubble.text = vname + "\n" + text
	bubble.visible = true
	talk_t = 3.0

# ---------------------------------------------------------------- planning

## Pick what to do for the schedule's current activity.
func plan(act: String) -> void:
	activity = act
	release_spot()
	match act:
		"sleep":
			go_to(home_door.pos, "door")
		"work":
			plan_work()
		"eat":
			if not claim_and_go(["seat"], "seat"):
				plan_point(true)
		"social":
			plan_point(false)
		_:
			plan_point(true)

func plan_work() -> void:
	if carrying:
		var drop: RefCounted = village.drop_for(job)
		if drop:
			go_to(drop.pos, "drop")
			return
	var kinds: Array = village.JOB_SPOTS.get(job, [])
	if job == "elder":
		if not claim_and_go(["seat"], "seat"):
			plan_point(false)
		return
	if job == "miller":
		var mill: RefCounted = village.spot_of_kind("mill_door")
		if mill:
			go_to(mill.pos, "mill")
			return
	if kinds.is_empty() or not claim_and_go(kinds, "work"):
		plan_point(false)

func claim_and_go(kinds: Array, kind: String) -> bool:
	var s: RefCounted = village.claim_nearest(self, kinds)
	if s == null:
		return false
	spot = s
	go_to(s.pos, kind)
	return true

func plan_point(near_home: bool) -> void:
	var p: Vector3 = village.random_point(home_door.pos if near_home else Vector3.ZERO, 5.0 if near_home else 9.0)
	linger = randf_range(10.0, 30.0)
	go_to(p, "point")

func arrive() -> void:
	velocity = Vector3.ZERO
	match goal_kind:
		"work":
			state = "work"
			work_min = 0.0 if work_min <= 0.0 else work_min
		"seat":
			state = "sit"
			global_position = Vector3(spot.pos.x, global_position.y, spot.pos.z)
		"door":
			go_inside()
		"mill":
			go_inside()
			inside_min = 0.0
		"drop":
			carrying = false
			work_count += 0
			village.on_delivery(self)
			state = "idle"
			linger = 3.0
			goal_kind = "after_drop"
		"point":
			state = "idle"
		_:
			state = "idle"

func go_inside() -> void:
	release_spot()
	state = "inside"
	visible = false
	collision_layer = 0
	agent.avoidance_enabled = false

func come_out(at: Vector3) -> void:
	visible = true
	collision_layer = 4
	agent.avoidance_enabled = true
	global_position = at + Vector3.UP * 0.1
	velocity = Vector3.ZERO
	state = "idle"

# ---------------------------------------------------------------- per frame

func _physics_process(dt: float) -> void:
	if game == null or not village.active or game.paused():
		return
	var gdt: float = dt * village.minutes_per_second()
	anim_t += dt
	talk_t = maxf(0.0, talk_t - dt)
	talk_cd = maxf(0.0, talk_cd - dt)
	if talk_t <= 0.0:
		bubble.visible = false
	if not is_on_floor():
		velocity.y -= GRAVITY * dt
	else:
		velocity.y = 0.0
	# The hero walking up starts a short chat; the routine resumes after.
	if state != "inside" and state != "talk" and talk_cd <= 0.0 and game.hero and game.hero.alive():
		if game.hero.global_position.distance_to(global_position) < 2.1:
			resume_state = state
			state = "talk"
			talk_cd = 14.0
			var lines: Array = LINES.get(job, LINES.wanderer)
			say(lines[randi() % lines.size()])
	think_min -= gdt
	var want: String = village.activity_for(self)
	match state:
		"talk":
			velocity.x = 0
			velocity.z = 0
			face(game.hero.global_position, dt)
			if talk_t <= 0.0:
				state = resume_state if resume_state in ["work", "sit", "idle"] else "idle"
				if resume_state == "walk":
					go_to(target, goal_kind)
		"inside":
			inside_min += gdt
			if goal_kind == "mill":
				if inside_min > village.WORK_CYCLE or want != "work":
					come_out(village.spot_of_kind("mill_door").pos)
					if want == "work":
						carrying = true
						work_count += 1
					plan(want)
			elif want != "sleep":
				come_out(home_door.pos)
				plan(want)
		"walk":
			walk(dt)
		"work":
			velocity.x = 0
			velocity.z = 0
			if spot:
				face(spot.look, dt)
			work_min += gdt
			if want != "work":
				plan(want)
			elif work_min >= village.WORK_CYCLE:
				work_min = 0.0
				work_count += 1
				if job in ["woodcutter", "miner", "fisher", "farmer"]:
					carrying = true
					release_spot()
					plan_work()
		"sit":
			velocity.x = 0
			velocity.z = 0
			if spot:
				face(spot.look, dt)
			if want != activity:
				plan(want)
		"idle":
			velocity.x = 0
			velocity.z = 0
			linger -= gdt
			if want != activity or linger <= 0.0 or think_min <= 0.0:
				think_min = 20.0
				plan(want)
	if state == "inside":
		return
	move_and_slide()
	animate(dt)

func walk(dt: float) -> void:
	if global_position.y < -0.5:
		recoveries += 1
		snap_to_nav()
	if agent.is_navigation_finished() or global_position.distance_to(target) < 0.55:
		arrive()
		return
	var next: Vector3 = agent.get_next_path_position()
	var dir: Vector3 = next - global_position
	dir.y = 0
	if dir.length() > 0.01:
		dir = dir.normalized()
	desired_vel = dir * (walk_speed * (0.8 if carrying else 1.0))
	agent.velocity = desired_vel
	face(global_position + dir, dt, 10.0)
	# Blocked-path recovery: re-path, then nudge back onto the mesh, then give up.
	stuck_t += dt
	if stuck_t > 1.5:
		var moved: float = global_position.distance_to(stuck_from)
		stuck_t = 0.0
		stuck_from = global_position
		if moved < 0.25:
			repaths += 1
			recoveries += 1
			if repaths == 1 or repaths == 2:
				agent.target_position = target
			elif repaths == 3:
				snap_to_nav()
			else:
				release_spot()
				plan_point(false)
		else:
			repaths = 0

## Put the villager back on the walkable area (after being pushed into a
## wall, a building or under the ground).
func snap_to_nav() -> void:
	# Route from home to here: the path ends at the nearest reachable point.
	# (Godot 4.3's map_get_closest_point can land inside large obstacles.)
	var map: RID = get_world_3d().navigation_map
	var probe: Vector3 = Vector3(global_position.x, 0.0, global_position.z)
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, home_door.pos, probe, true)
	var p: Vector3 = path[path.size() - 1] if path.size() > 0 else home_door.pos
	global_position = Vector3(p.x, 0.05, p.z)
	velocity = Vector3.ZERO
	agent.target_position = target

func _on_velocity(safe: Vector3) -> void:
	if state != "walk":
		return
	velocity.x = safe.x
	velocity.z = safe.z

func animate(dt: float) -> void:
	var pose: Dictionary
	var drop: float = 0.0
	var tool: String = "none"
	var cycle: float = fmod(anim_t, 1.4) / 1.4
	match state:
		"work":
			var k: String = spot.kind if spot else ""
			tool = spot.tool if spot else "none"
			match k:
				"tree":
					pose = P.chop(cycle)
				"rock":
					pose = P.mine(cycle)
				"field":
					pose = P.hoe(fmod(anim_t, 1.8) / 1.8)
				"fish":
					pose = P.fish(fmod(anim_t, 3.0) / 3.0)
				_:
					pose = P.talk(anim_t)
		"sit":
			pose = P.sit(anim_t)
			drop = -0.42
		"talk":
			pose = P.talk(anim_t)
		"walk":
			var hs: float = Vector2(velocity.x, velocity.z).length()
			speed_now = lerpf(speed_now, clampf(hs / 6.0, 0.0, 1.0), 1.0 - exp(-10.0 * dt))
			run_phase += dt * (5.0 + 6.5 * speed_now)
			pose = P.carry(run_phase, speed_now) if carrying else P.run(run_phase, speed_now)
		_:
			pose = P.idle(anim_t, false)
	rig.set_tool(tool)
	load_box.visible = carrying and state != "work"
	load_box.position = forward() * 0.38 + Vector3.UP * (height * 0.6)
	load_box.rotation.y = yaw
	rig.rotation.y = yaw
	rig.position.y = lerpf(rig.position.y, drop, 1.0 - exp(-10.0 * dt))
	if game.camera and game.camera.global_position.distance_to(global_position) > 38.0:
		return
	rig.apply(pose, dt, 12.0)
	rig.update_line()

# ---------------------------------------------------------------- save / restore

func to_dict() -> Dictionary:
	return {
		"pos": [snappedf(global_position.x, 0.01), snappedf(global_position.y, 0.01), snappedf(global_position.z, 0.01)],
		"yaw": snappedf(yaw, 0.01),
		"state": state if state != "talk" else resume_state,
		"activity": activity,
		"goal": goal_kind,
		"spot": spot.id if spot else "",
		"target": [snappedf(target.x, 0.01), snappedf(target.y, 0.01), snappedf(target.z, 0.01)],
		"work_min": snappedf(work_min, 0.1),
		"work_count": work_count,
		"carrying": carrying,
		"inside_min": snappedf(inside_min, 0.1),
	}

## Put the villager back exactly where the save says.
func restore(d: Dictionary) -> void:
	var p: Array = d.get("pos", [])
	if p.size() == 3:
		global_position = Vector3(p[0], p[1], p[2])
	yaw = float(d.get("yaw", 0.0))
	work_count = int(d.get("work_count", 0))
	work_min = float(d.get("work_min", 0.0))
	carrying = bool(d.get("carrying", false))
	inside_min = float(d.get("inside_min", 0.0))
	activity = str(d.get("activity", ""))
	goal_kind = str(d.get("goal", ""))
	var t: Array = d.get("target", [])
	if t.size() == 3:
		target = Vector3(t[0], t[1], t[2])
	var sid: String = str(d.get("spot", ""))
	if sid != "":
		var s: RefCounted = village.spots.get(sid)
		if s and s.claim(self):
			spot = s
	var st: String = str(d.get("state", "idle"))
	match st:
		"inside":
			go_inside()
		"walk":
			go_to(target, goal_kind)
		"work", "sit":
			state = st if spot else "idle"
		_:
			state = "idle"
			linger = 5.0

## Place the villager where its routine says it should be right now
## (used when its block was unloaded while game time moved on).
func place_for_schedule() -> void:
	var act: String = village.activity_for(self)
	activity = act
	match act:
		"sleep":
			global_position = home_door.pos
			goal_kind = "door"
			go_inside()
		"work", "eat":
			plan(act)
			if goal_kind in ["work", "seat"] and spot:
				global_position = spot.pos
				arrive()
			elif goal_kind == "mill":
				global_position = target
				arrive()
			else:
				global_position = target
				state = "idle"
		_:
			plan(act)
			global_position = target
			state = "idle"
