extends "res://scripts/citadel/Ruin.gd"
## Sky Citadel v2: the rebuilt castle (Blender, art/castle2 in the work folder),
## same size and structure as the sky ruin but built clean: three ring decks
## with spiral stairs, galleries through the drums, ladders between rings, the
## summit, the crown, and the eye dropping into the Core arena.
## The castle model carries its own walkways; its collision is a separate,
## simple mesh. assets/ruin2/route2.json holds gates, checkpoints, knights,
## ladders and the test bot's moves (all made by the build script).

const MODEL2: String = "res://assets/ruin2/skycitadel.glb"
const COLLIDER2: String = "res://assets/ruin2/skycitadel_col.glb"
const ROUTE2: String = "res://assets/ruin2/route2.json"

var eye_c: Vector2 = Vector2.ZERO
var eye_r: float = 5.5
var core_c: Vector3 = Vector3.ZERO
var core_r: float = 13.0

func load_route() -> void:
	var f: FileAccess = FileAccess.open(ROUTE2, FileAccess.READ)
	route = JSON.parse_string(f.get_as_text())
	core_y = route.core_y
	crown_y = route.crown_y
	dock = v3(route.dock)
	eye_c = Vector2(route.eye[0], route.eye[1])
	eye_r = route.eye[2]
	core_c = v3(route.core_c)
	core_r = route.core_r
	sections.clear()
	for i in route.spawns.size():
		sections.append({"goal": route.goals[i], "spawn": v3(route.spawns[i])})
	last = sections.size() - 1

func configure() -> void:
	game.sections = sections
	game.map_zones = [Rect2(-48, -45, 96, 100)]
	game.boss_name = "DARK KNIGHT"
	game.win_text = "CITADEL CLEARED"

func build() -> void:
	configure()
	root = Node3D.new()
	root.name = "SkyRuin"
	game.world.add_child(root)
	game.ladders.clear()
	look()
	for l: Dictionary in route.ladders:
		ladder(v3(l.bottom), v3(l.top), v3(l.face))
	for b: Dictionary in route.barriers:
		barrier(v3(b.pos), v3(b.size), v3(b.face))
	add_castle()
	add_sky()

func look() -> void:
	game.citadel_look()
	game.env_res.fog_density = 0.0009
	game.env_res.tonemap_exposure = 0.75
	game.env_res.ambient_light_energy = 0.5
	game.sun.light_energy = 0.75
	game.sun.rotation_degrees = Vector3(-40, 38, 0)
	if game.sun.shadow_enabled:
		game.sun.directional_shadow_max_distance = 60.0

func add_castle() -> void:
	var castle: Node3D = (load(MODEL2) as PackedScene).instantiate()
	root.add_child(castle)
	for mi: MeshInstance3D in castle.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if game.phone else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var col_scene: Node3D = (load(COLLIDER2) as PackedScene).instantiate()
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "RuinCollision"
	for mi: MeshInstance3D in col_scene.find_children("*", "MeshInstance3D", true, false):
		var cps: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
		cps.set_faces(mi.mesh.get_faces())
		cps.backface_collision = true
		var shape: CollisionShape3D = CollisionShape3D.new()
		shape.shape = cps
		body.add_child(shape)
	col_scene.free()
	root.add_child(body)

func guard_routes(guards: Array) -> Array:
	var out: Array = []
	for g: CharacterBody3D in guards:
		var p: Vector2 = Vector2(g.global_position.x, g.global_position.z)
		out.append([p + Vector2(-5, 0), p + Vector2(5, 0)])
	return out

func boss_pos() -> Vector3:
	return core_c + Vector3(0, 0.2, -4.0)

func start() -> void:
	game.say_once("ruin_start", "ally", "The citadel... the Dark Knight waits in the Core, under the crown.")
	game.say_once("ruin_tip", "tip", "Climb the rings: stairs, galleries through the walls, ladders up. Then drop through the eye.")

func progress() -> void:
	if game.section < last and game.section_clear(game.section):
		game.open_barrier(game.section)
		game.section += 1
		match game.section:
			1:
				game.say("ally", "The stair is open. Up and round, through the gallery!")
			2:
				game.say("ally", "Up the ladder to the second ring!")
			3:
				game.say("ally", "One more ladder. Then the summit.")
			4:
				game.say("ally", "The summit stair is clear. Take the crown!")
			5:
				game.say("ally", "The eye is open. Jump down. He's in the Core!")
	var p: Vector3 = game.hero.global_position
	var reached: int = game.checkpoint
	for i in range(sections.size() - 1, 0, -1):
		var s: Vector3 = sections[i].spawn
		if p.y > s.y - 1.2 and p.y < s.y + 3.0 and Vector2(p.x - s.x, p.z - s.z).length() < 6.0:
			reached = maxi(reached, i)
			break
	if in_core():
		reached = last
	if reached > game.checkpoint and reached <= game.section:
		game.checkpoint = reached
	if not game.boss_seen and in_core() and game.hero.is_on_floor():
		game.boss_seen = true
		game.boss.active = true
		game.sound("alarm", -8)
		game.say("boss", "You fell all this way to die in my core?")
		game.say("ally", "We can break through! Keep pressing!")

func in_eye(p: Vector3) -> bool:
	return Vector2(p.x, p.z).distance_to(eye_c) < eye_r + 1.0 and p.y > core_y - 1.0

func in_core() -> bool:
	if game.hero == null:
		return false
	var p: Vector3 = game.hero.global_position
	return p.y > core_y - 1.0 and p.y < core_y + 8.0 and Vector2(p.x - core_c.x, (p.z - core_c.z) / 0.8).length() < core_r + 1.0
