extends CharacterBody3D
## A villager at home, inside a house interior (Frogtown). Only the residents
## of the house you walk into are made, so they can do a little more than the
## villagers outside: cook at the hearth, eat at the table, sleep in bed,
## children play on the rug, and they greet (or shoo out) the player.
## Spots are the interior's Spot_<kind>_<n> markers, one resident per spot.
## Local and deterministic: no LLM calls. One speaker at a time (village bark lock).
const RigScript = preload("res://scripts/citadel/Rig.gd")
const P = preload("res://scripts/citadel/Poses.gd")
const GRAVITY: float = 26.0
const HOME_LINES: Array = ["Mind the hearth, it's hot.", "Stew tonight. Again.", "Did you wipe your feet?", "The roof leaks when it rains.", "Have you met the Chief yet?"]
const PAIR_LINES: Array = ["Pass the lily bread.", "The water's up again.", "Who left reeds on the bed?", "Bogg says he saw the giant catfish.", "Shh, someone's here."]
const NIGHT_LINES: Array = ["It's late, knight... let us sleep.", "Mmm... shoo... sleeping..."]

var game: Node
var town: RefCounted
var vid: String = ""
var vname: String = ""
var job: String = ""
var height: float = 1.75
var walk_speed: float = 1.3
var child: bool = false
var rig: Node3D
var bubble: Label3D
var head_node: MeshInstance3D
var head_bone: int = -1
var head_scale: float = 1.0
var yaw: float = 0.0
var anim_t: float = 0.0
var run_phase: float = 0.0
var activity: String = ""
var spot_id: String = ""
var state: String = "idle"     # idle, walk, do
var path: PackedVector3Array = PackedVector3Array()
var path_i: int = 0
var linger: float = 0.0
var talk_t: float = 0.0
var bark_cd: float = 0.0
var greet_cd: float = 0.0

func setup(g: Node, t: RefCounted, def: Dictionary) -> void:
	game = g
	town = t
	vid = def.id
	vname = def.name
	job = def.job
	height = def.get("height", 1.75)
	child = height < 1.45
	walk_speed = def.get("speed", 1.3)
	collision_layer = 4
	collision_mask = 1
	var shape: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = height
	shape.shape = cap
	shape.position.y = height * 0.5
	add_child(shape)
	rig = Node3D.new()
	rig.set_script(RigScript)
	add_child(rig)
	rig.setup(def.model, height, Color("c8b48a"), 0.9, 0.0)
	rig.set_tool("none")
	if def.has("tint"):
		rig.set_flash(def.get("tint_amount", 0.14), def.tint)
	if def.get("head_mesh") != null:
		head_node = MeshInstance3D.new()
		head_node.mesh = def.head_mesh
		head_node.top_level = true
		add_child(head_node)
		head_bone = rig.idx.get("Head", -1)
		head_scale = def.get("head_scale", 1.0)
		if def.get("hat_mesh") != null:
			var hat: MeshInstance3D = MeshInstance3D.new()
			hat.mesh = def.hat_mesh
			hat.position = Vector3(0, 0.27, 0)
			head_node.add_child(hat)
	bubble = Label3D.new()
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.no_depth_test = true
	bubble.font_size = 34
	bubble.pixel_size = 0.0026
	bubble.outline_size = 10
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.width = 520.0
	bubble.modulate = Color("fff6dd")
	bubble.outline_modulate = Color(0.05, 0.08, 0.15, 0.9)
	bubble.position = Vector3(0, height + 0.5, 0)
	bubble.visible = false
	add_child(bubble)
	bark_cd = randf_range(2.0, 6.0)

## What the routine asks for, translated to rooms in the house.
func kinds_for(act: String) -> Array:
	match act:
		"sleep":
			return ["bed"]
		"wake":
			return ["hearth", "window", "shelf"]
		"eat":
			return ["seat", "table", "hearth"]
		"social":
			return ["seat", "window", "table"]
		_:
			if child:
				return ["play", "window", "seat"]
			if job == "homekeeper":
				return ["hearth", "shelf", "window", "table"]
			return ["seat", "window", "shelf"]

func place_for_schedule() -> void:
	activity = town.activity_for(self)
	spot_id = town.claim_interior(self, kinds_for(activity))
	if spot_id != "":
		global_position = town.interior_spots[spot_id].pos
		state = "do"
		linger = randf_range(6.0, 14.0)
	else:
		state = "idle"

func plan() -> void:
	activity = town.activity_for(self)
	var id: String = town.claim_interior(self, kinds_for(activity))
	if id == "" or id == spot_id:
		state = "do" if spot_id != "" else "idle"
		linger = randf_range(5.0, 10.0)
		return
	spot_id = id
	var map: RID = get_world_3d().navigation_map
	path = NavigationServer3D.map_get_path(map, global_position, town.interior_spots[id].pos, true)
	path_i = 0
	state = "walk" if path.size() > 0 else "do"

func say(text: String, seconds: float = 3.0) -> bool:
	if not town.request_bark(self, seconds):
		return false
	bubble.text = vname + "\n" + text
	bubble.visible = true
	talk_t = seconds
	return true

func _physics_process(dt: float) -> void:
	if game == null or not town.active or game.paused():
		return
	anim_t += dt
	talk_t = maxf(0.0, talk_t - dt)
	bark_cd -= dt
	greet_cd -= dt
	if talk_t <= 0.0:
		bubble.visible = false
	if not is_on_floor():
		velocity.y -= GRAVITY * dt
	else:
		velocity.y = 0.0
	var want: String = town.activity_for(self)
	var hero: Node3D = game.hero
	# greet the player (or shoo them out at night)
	if hero and greet_cd <= 0.0 and hero.global_position.distance_to(global_position) < 2.4:
		var lines: Array = NIGHT_LINES if want == "sleep" else town.lines_for(job)
		if lines.is_empty():
			lines = HOME_LINES
		if say(lines[randi() % lines.size()]):
			greet_cd = 14.0
	elif bark_cd <= 0.0 and want != "sleep":
		bark_cd = randf_range(7.0, 13.0)
		say((PAIR_LINES if town.residents.size() > 1 else HOME_LINES)[randi() % 5])
	match state:
		"walk":
			if path_i >= path.size():
				state = "do"
				linger = randf_range(6.0, 14.0)
				velocity.x = 0
				velocity.z = 0
			else:
				var to: Vector3 = path[path_i] - global_position
				to.y = 0
				if to.length() < 0.25:
					path_i += 1
				else:
					var d: Vector3 = to.normalized()
					velocity.x = d.x * walk_speed
					velocity.z = d.z * walk_speed
					yaw = lerp_angle(yaw, atan2(-d.x, -d.z), 1.0 - exp(-10.0 * dt))
		"do", "idle":
			velocity.x = 0
			velocity.z = 0
			linger -= dt
			if want != activity or (linger <= 0.0 and want != "sleep"):
				plan()
			elif spot_id != "" and talk_t > 0.0 and hero:
				var th: Vector3 = hero.global_position - global_position
				yaw = lerp_angle(yaw, atan2(-th.x, -th.z), 1.0 - exp(-6.0 * dt))
	move_and_slide()
	animate(dt)

func spot_kind() -> String:
	return str(town.interior_spots.get(spot_id, {}).get("kind", ""))

func animate(dt: float) -> void:
	var pose: Dictionary
	var drop: float = 0.0
	var lie: bool = false
	if state == "walk":
		run_phase += dt * (5.0 + 6.5 * 0.25)
		pose = P.run_free(run_phase, 0.25)
	else:
		match spot_kind():
			"bed":
				pose = P.idle_free(anim_t)
				lie = activity == "sleep"
				if not lie:
					pose = P.sit(anim_t)
					drop = -0.42
			"seat", "table":
				pose = P.sit(anim_t)
				drop = -0.42
			"hearth":
				pose = P.cast(anim_t) if fmod(anim_t, 6.0) < 3.0 else P.hoe(fmod(anim_t, 1.8) / 1.8)
			"shelf":
				pose = P.talk(anim_t)
			"play":
				pose = P.run_free(anim_t * 8.0, 0.6) if fmod(anim_t, 4.0) < 2.0 else P.idle_free(anim_t)
			_:
				pose = P.talk(anim_t) if talk_t > 0.0 else P.idle_free(anim_t)
	rig.rotation.y = yaw
	rig.rotation.x = lerpf(rig.rotation.x, PI / 2.0 * 0.92 if lie else 0.0, 1.0 - exp(-6.0 * dt))
	rig.position.y = lerpf(rig.position.y, 0.3 if lie else drop, 1.0 - exp(-10.0 * dt))
	rig.apply(pose, dt, 12.0)
	if head_node and head_bone >= 0:
		var hp: Vector3 = rig.sk.global_transform * rig.sk.get_bone_global_pose(head_bone).origin
		var b: Basis = Basis(Vector3.UP, yaw + PI)
		if lie:
			b = Basis(Vector3.UP, yaw + PI) * Basis(Vector3.RIGHT, -PI / 2.0 * 0.92)
		head_node.global_transform = Transform3D(b.scaled(Vector3.ONE * head_scale), hp)
