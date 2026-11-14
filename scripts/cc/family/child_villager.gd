extends "res://scripts/citadel/Villager.gd"
## A village-born child (or a village-born grown-up) walking the same
## navigation mesh and using the same rig as the cast. Never fights and never
## takes a work spot: its day comes from family_activities.child_activity().
## Newborns have no body here; a parent carries them as a bundle.
const Anim = preload("res://scripts/cc/family/child_anim.gd")
const Acts = preload("res://scripts/cc/family/family_activities.gd")

var npc_id: String = ""
var stage: String = "child"
var parent_ids: Array = []
var anim_state: String = "stand"

func setup(g: Node, v: RefCounted, def: Dictionary) -> void:
	npc_id = def.id
	stage = def.get("stage", "child")
	parent_ids = def.get("parent_ids", [])
	super.setup(g, v, def)
	bubble.position = Vector3(0, height + 0.45, 0)

func is_child() -> bool:
	return stage != "adult"

func can_chat() -> bool:
	var cfg: Resource = village.family.svc.cfg
	return cfg.stage_index(stage) >= cfg.stage_index(cfg.chat_min_stage)

func stays_inside_for(want: String) -> bool:
	if stage == "adult":
		return super.stays_inside_for(want)
	return Acts.stays_inside(want)

## A parent's body in this block, if one is out and about.
func parent_body() -> Node:
	for v: Node in village.villagers:
		if is_instance_valid(v) and v.vid in parent_ids and v.visible:
			return v
	return null

func plan(act: String) -> void:
	if stage == "adult":
		super.plan(act if act != "" else "social")
		return
	activity = act
	release_spot()
	match act:
		"home", "nap", "sleep", "family_meal":
			go_to(home_door.pos, "door")
		"play_near_home":
			var p: Vector3 = village.random_point(home_door.pos, 3.0)
			linger = randf_range(6.0, 14.0)
			go_to(p, "point")
		"lessons":
			var elder: RefCounted = village.spot_of_kind("seat")
			var c: Vector3 = elder.pos if elder else Vector3.ZERO
			linger = randf_range(15.0, 30.0)
			go_to(village.random_point(c, 2.5), "point")
		"apprentice":
			var par: Node = parent_body()
			var at: Vector3 = par.global_position if par else home_door.pos
			linger = randf_range(8.0, 16.0)
			go_to(village.random_point(at, 2.0), "point")
		"eat":
			if not claim_and_go(["seat"], "seat"):
				plan_point(true)
		_:
			plan_point(false)

func doing_text() -> String:
	match activity:
		"play", "play_near_home": return "playing"
		"lessons": return "listening to the elder's lessons"
		"apprentice": return "learning a parent's trade"
		"eat", "family_meal": return "eating"
		"nap", "sleep": return "sleeping"
	return super.doing_text()

func animate(dt: float) -> void:
	var hs: float = Vector2(velocity.x, velocity.z).length()
	var moving: bool = state == "walk" and hs > 0.05
	speed_now = lerpf(speed_now, clampf(hs / 3.0, 0.0, 1.0), 1.0 - exp(-10.0 * dt))
	run_phase += dt * (4.0 + 6.0 * speed_now)
	var playing: bool = state == "idle" and activity in ["play", "play_near_home"]
	if state == "talk":
		anim_state = "stand"
	else:
		anim_state = Anim.state_for(stage, moving, playing)
	var pose: Dictionary = Anim.pose(anim_state, anim_t, run_phase, speed_now)
	if state == "talk" and stage in ["child", "adolescent", "adult"]:
		pose = P.talk(anim_t)
	var drop: float = 0.0
	if state == "sit":
		pose = P.sit(anim_t)
		drop = -0.42 * height / 1.75
	var tilt: Vector2 = Anim.tilt_for(anim_state)
	rig.set_tool("none")
	load_box.visible = false
	rig.rotation.y = yaw
	rig.rotation.x = lerpf(rig.rotation.x, tilt.x, 1.0 - exp(-10.0 * dt))
	rig.position.y = lerpf(rig.position.y, drop + tilt.y * height, 1.0 - exp(-10.0 * dt))
	if game.camera and game.camera.global_position.distance_to(global_position) > 38.0:
		return
	if not pose.is_empty():
		rig.apply(pose, dt, 12.0)
		rig.update_line()

func to_dict() -> Dictionary:
	var d: Dictionary = super.to_dict()
	d["stage"] = stage
	return d

func place_for_schedule() -> void:
	if stage == "adult":
		super.place_for_schedule()
		return
	var act: String = village.activity_for(self)
	if Acts.stays_inside(act):
		activity = act
		global_position = home_door.pos
		goal_kind = "door"
		go_inside()
		return
	plan(act)
	global_position = target
	state = "idle"
