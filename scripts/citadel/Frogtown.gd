extends "res://scripts/citadel/Village.gd"
## Frogtown (Crownfen Keep, Mistfen, Elindor): the frog-folk marsh village as a
## 1x1 village tile. Built on the Village stage (clock, routines, work spots,
## save) with these differences:
##  - The village is the owner's Tripo model, as game-ready copies only
##    (frogtown.glb ~110k tris desktop, frogtown_lite.glb ~48k tris phone,
##    frogtown_col.glb ~22k tris collision). Never the raw high-poly.
##  - Houses are exterior shells only (they're part of the model). Each door is
##    a trigger (walk in, or press ENTER) that swaps the tile for a separate
##    interior scene; leaving puts you back at that house's door.
##  - assets/frogtown/frogtown.json is the house registry: house_id -> shell,
##    interior model, dressing, residents, spawn marker, door, access. Interiors
##    are reusable: INT_HUT serves eight families, INT_LODGE two.
##  - Inside, only that house's residents are made (Resident.gd).
##  - Villagers are ordinary frog-folk (Villager.gd with a frog head), never the
##    CC_ boss characters. Only one villager speaks at a time.
##  - A road leaves the tile at the south gate: the hook for the next tile.
const ResidentScript = preload("res://scripts/citadel/Resident.gd")
const DATA_PATH: String = "res://assets/frogtown/frogtown.json"
## v2: the village rebuilt as clean game geometry on the Tripo layout
## (tools/frogtown/rebuild): plank boardwalks, stilt huts, lodges, marsh trees.
const MODEL: String = "res://assets/frogtown/frogtown_v2.glb"
const MODEL_LITE: String = "res://assets/frogtown/frogtown_v2_lite.glb"
const COLLIDER: String = "res://assets/frogtown/frogtown_v2_col.glb"   # 'walk' floors + 'walls'
const WALK: String = COLLIDER
const WALLS: String = COLLIDER
const PROPS: String = "res://assets/frogtown/frog_props.glb"
const NAV_RES: String = "res://assets/frogtown/frogtown_nav.res"
const INTERIORS: Dictionary = {
	"INT_HUT": "res://assets/frogtown/int_hut.glb",
	"INT_LODGE": "res://assets/frogtown/int_lodge.glb",
}
const FROG_SAVE: String = "user://frogtown_save.json"
const HALF_TILE: float = 50.0
const MARSH_LAYER: int = 16
const WALL_LAYER: int = 32
const FROG_LINES: Dictionary = {
	"chief": ["Crownfen welcomes you, knight. Mind your manners.", "The Ancestor Shell hears every word.", "Sit, sit. The council drum calls soon."],
	"captain": ["New bounties on the board. Can you read?", "Marsh wolves near the south road again.", "You hunt? Show me."],
	"drummer": ["BOOM! Ha, did I scare you?", "The drum calls the council at dusk.", "Feel that? That's the heart of Crownfen."],
	"lotus": ["Hush. The old ones are listening.", "The totem fire must never go out.", "Leave a shell, take a blessing."],
	"fisher": ["Ribbit... sorry. They're biting today.", "Quiet, you'll scare the catfish.", "Biggest catch in Mistfen, this morning!"],
	"reeds": ["Good reeds make good walls.", "Water's rising. Watch the gauge.", "Mind your feet, the planks are slick."],
	"merchant": ["Lily bread! Lantern oil! Shell charms!", "For you, knight, a special price.", "Come back when you've got coin."],
	"herbalist": ["Not that mushroom. Never that one.", "A poultice for those bruises?", "Mint, mud and marsh-lily. Cures most things."],
	"homekeeper": ["Shoes off, please.", "Stew's nearly ready.", "Who let a knight in here?"],
}

var data: Dictionary = {}
var houses: Dictionary = {}       # house_id -> def
var vdefs: Dictionary = {}        # villager id -> def
var prop_meshes: Dictionary = {}
var inside: String = ""           # house_id while the player is inside
var residents: Array = []
var interior_spots: Dictionary = {}
var interior_exit: Vector3 = Vector3.ZERO
var interior_spawn: Transform3D
var door_cd: float = 0.0
var speaker: Node = null
var speaker_t: float = 0.0
var wheel: Node3D
var safe_pos: Vector3 = Vector3.ZERO
var road_msg_t: float = 0.0
var tile_root: Node3D
var nav_baked_ms: int = 0
var lift: float = 3.5
var dais_seat: Vector3 = Vector3.ZERO
var water_y: float = -2.4

func _init(g: Node) -> void:
	super(g)
	block = "frogtown"
	load_data()

func load_data() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	data = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	houses.clear()
	for h: Dictionary in data.get("houses", []):
		houses[h.house_id] = h
	vdefs.clear()
	for v: Dictionary in data.get("villagers", []):
		vdefs[v.id] = v
	lift = float(data.get("model_lift", 3.5))
	water_y = float(data.get("water_y", -2.4))

# ---------------------------------------------------------------- hooks

func block_def() -> Dictionary:
	var vs: Array = []
	for v: Dictionary in data.get("villagers", []):
		vs.append(v)
	return {"title": data.get("title", "Frogtown"), "spawn": v3(data.get("spawn", [0, 0, 0])), "villagers": vs, "exits": {}}

func save_path() -> String:
	return FROG_SAVE

func job_spots(job: String) -> Array:
	return data.get("jobs", {}).get(job, [])

func stays_home(v: Node) -> bool:
	return v.job in data.get("home_jobs", [])

func lines_for(job: String) -> Array:
	return FROG_LINES.get(job, [])

func fall_y() -> float:
	return water_y - 3.0

## One speaker at a time across the tile and the interiors.
func request_bark(v: Node, seconds: float) -> bool:
	if chat.is_open() and chat.get("target") != v:
		return false
	if speaker != null and is_instance_valid(speaker) and speaker != v and speaker_t > 0.0:
		return false
	speaker = v
	speaker_t = seconds
	return true

func v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]) if a.size() > 2 else 0.0, float(a[2]) if a.size() > 2 else float(a[1]))

func xz(a: Array) -> Vector3:
	return Vector3(float(a[0]), 0.0, float(a[1]))

# ---------------------------------------------------------------- stage

func configure_stage() -> void:
	var title: String = data.get("title", "Frogtown")
	if inside != "":
		title = houses[inside].name
	game.sections = [{"goal": "%s  ·  explore" % title, "spawn": v3(data.get("spawn", [0, 0, 0]))}]
	game.map_zones = [Rect2(-HALF_TILE, -HALF_TILE, HALF_TILE * 2, HALF_TILE * 2)]
	game.win_text = "FROGTOWN"
	game.boss_name = ""

func look() -> void:
	game.env_res.fog_density = 0.0035
	game.env_res.tonemap_exposure = 0.9
	game.sun.rotation_degrees = Vector3(-48, 35, 0)
	apply_daylight()
	# marsh haze: a little greener than the square
	game.env_res.fog_light_color = game.env_res.fog_light_color.lerp(Color("9fc7b0"), 0.35)

func build() -> void:
	look()
	spots.clear()
	doors.clear()
	interior_spots.clear()
	wheel = null
	load_props()
	if inside != "":
		build_interior(houses[inside])
	else:
		build_tile()

func load_props() -> void:
	if not prop_meshes.is_empty():
		return
	var inst: Node = (load(PROPS) as PackedScene).instantiate()
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		prop_meshes[str(mi.name)] = mi.mesh
	inst.free()

## Ground height under a point (walkways are near y = 0), or 'fallback' if none.
## Roofs and tree crowns hang over the boardwalks, so look at every upward-facing
## surface under the point and take the one nearest boardwalk height.
func ground_at(p: Vector3, fallback: float = 0.0) -> float:
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var top: float = 12.0
	var best: float = fallback
	var best_d: float = INF
	for i in 8:
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(p.x, top, p.z), Vector3(p.x, water_y - 2.0, p.z), 1 | MARSH_LAYER)
		q.hit_back_faces = false
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			break
		var y: float = (hit.position as Vector3).y
		if (hit.normal as Vector3).y > 0.5 and absf(y - p.y) < best_d:
			best_d = absf(y - p.y)
			best = y
		top = y - 0.05
	return best

func on_ground(p: Vector3) -> Vector3:
	return Vector3(p.x, ground_at(p), p.z)

func prop(name: String, at: Vector3, yaw: float, parent: Node3D = null, scale: float = 1.0) -> MeshInstance3D:
	var mesh: Mesh = prop_meshes.get(name)
	if mesh == null:
		push_warning("frogtown prop missing " + name)
		return null
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = name
	mi.set_meta("prop", name)
	mi.mesh = mesh
	mi.position = at
	mi.rotation.y = yaw
	mi.scale = Vector3.ONE * scale
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if game.phone else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	(parent if parent else game.world).add_child(mi)
	return mi

func cylinder_body(at: Vector3, r: float, h: float, layer: int = 1) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = layer
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: CylinderShape3D = CylinderShape3D.new()
	sh.radius = r
	sh.height = h
	cs.shape = sh
	body.add_child(cs)
	body.position = at + Vector3.UP * h * 0.5
	game.world.add_child(body)

func trimesh_body(mesh: Mesh, layer: int, xform: Transform3D, parent: Node3D) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var cps: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	cps.set_faces(mesh.get_faces())
	cps.backface_collision = true
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.shape = cps
	body.add_child(cs)
	body.transform = xform
	parent.add_child(body)
	return body

func build_tile() -> void:
	var w: Node3D = game.world
	tile_root = Node3D.new()
	tile_root.name = "FrogtownTile"
	w.add_child(tile_root)
	# the village (game-ready copy; lighter one on phones)
	var model: Node3D = (load(MODEL_LITE if game.phone else MODEL) as PackedScene).instantiate()
	model.position.y = lift
	tile_root.add_child(model)
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if game.phone else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# collision: 'walk' (decks, boardwalks, island tops) and 'walls' (huts, rails, trunks)
	var col: Node3D = (load(COLLIDER) as PackedScene).instantiate()
	tile_root.add_child(col)
	for mi: MeshInstance3D in col.find_children("*", "MeshInstance3D", true, false):
		trimesh_body(mi.mesh, WALL_LAYER if str(mi.name).begins_with("walls") else 1, mi.global_transform, tile_root)
	tile_root.remove_child(col)
	col.free()
	# marsh water under the boardwalks: a flat surface, wading floor below it
	var water: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(HALF_TILE * 2 + 60, HALF_TILE * 2 + 60)
	water.mesh = pm
	var wm: StandardMaterial3D = StandardMaterial3D.new()
	wm.albedo_color = Color(0.2, 0.42, 0.38, 0.86)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.12
	wm.metallic_specular = 0.7
	water.material_override = wm
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.position.y = water_y
	tile_root.add_child(water)
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.collision_layer = MARSH_LAYER
	var fcs: CollisionShape3D = CollisionShape3D.new()
	var fb: BoxShape3D = BoxShape3D.new()
	fb.size = Vector3(HALF_TILE * 2 + 60, 1.0, HALF_TILE * 2 + 60)
	fcs.shape = fb
	floor_body.add_child(fcs)
	floor_body.position.y = water_y - 1.2
	tile_root.add_child(floor_body)
	build_features()
	bake_tile_nav()
	build_doors()
	build_spots()

func build_features() -> void:
	var f: Dictionary = data.get("features", {})
	var d: Dictionary = f.get("chief_dais", {})
	if not d.is_empty():
		var p: Vector3 = on_ground(xz(d.at))
		var k: float = float(d.get("scale", 1.0))
		prop("chief_dais", p, float(d.yaw), null, k)
		cylinder_body(p, 2.1 * k, 0.8 * k)
		dais_seat = p + Vector3(0, 0.82 * k, -1.0 * k).rotated(Vector3.UP, float(d.yaw))
	for key: String in ["council_drum", "request_board", "shell_totem", "flood_gauge"]:
		var e: Dictionary = f.get(key, {})
		if e.is_empty():
			continue
		var p2: Vector3 = on_ground(xz(e.at))
		var k2: float = float(e.get("scale", 1.0))
		prop(key, p2, float(e.yaw), null, k2)
		cylinder_body(p2, {"council_drum": 0.8, "request_board": 0.5, "shell_totem": 1.0, "flood_gauge": 0.35}[key] * k2, 2.0)
	var sl: Dictionary = f.get("sluice", {})
	if not sl.is_empty():
		var p3: Vector3 = Vector3(float(sl.at[0]), water_y + 1.4, float(sl.at[1]))
		prop("sluice_frame", p3, float(sl.yaw))
		wheel = prop("sluice_paddles", p3 + Vector3(0, 0.2, 0), float(sl.yaw))
	for st: Dictionary in f.get("market_stall", []):
		var p4: Vector3 = on_ground(xz(st.at))
		prop("market_stall", p4, float(st.yaw))
		cylinder_body(p4, 1.0, 1.2)
	# lantern-lit market path: hooked posts on alternate sides, lantern strings between
	var lp: Array = f.get("lantern_path", [])
	if lp.size() >= 2:
		var a: Vector3 = xz(lp[0])
		var b: Vector3 = xz(lp[1])
		var dir: Vector3 = (b - a).normalized()
		var side: Vector3 = dir.cross(Vector3.UP)
		var n: int = int(a.distance_to(b) / 3.4)
		var prev: Array = [null, null]
		for i in n + 1:
			var c: Vector3 = a.lerp(b, float(i) / n)
			for s: int in [0, 1]:
				if (i + s) % 2 != 0:
					continue
				var sgn: float = 1.0 if s == 0 else -1.0
				var at: Vector3 = on_ground(c + side * sgn * 1.45)
				prop("lantern_post", at, atan2(-side.x * sgn, -side.z * sgn) + PI / 2.0)
				var hook: Vector3 = at + Vector3(0, 2.4, 0) - side * sgn * 0.85
				if prev[s] != null:
					string_lanterns(prev[s], hook)
				prev[s] = hook
	# Ancestor fire and the dais get the only dynamic lights (desktop only).
	if not game.phone:
		for key2: String in ["shell_totem", "chief_dais"]:
			var e2: Dictionary = f.get(key2, {})
			if e2.is_empty():
				continue
			var l: OmniLight3D = OmniLight3D.new()
			l.light_color = Color("ffb35c")
			l.light_energy = 1.4
			l.omni_range = 7.0
			l.position = on_ground(xz(e2.at)) + Vector3(0, 1.4, 0)
			game.world.add_child(l)
	# the road out (next tile hook)
	for ex: Dictionary in data.get("exits", []):
		var gp: Vector3 = on_ground(xz([ex.at[0], ex.at[2]]))
		prop("exit_gate", gp, float(ex.get("gate_yaw", 0.0)))
		var right: Vector3 = Vector3(cos(float(ex.get("gate_yaw", 0.0))), 0, -sin(float(ex.get("gate_yaw", 0.0))))
		cylinder_body(gp + right * 2.3, 0.35, 3.0)
		cylinder_body(gp - right * 2.3, 0.35, 3.0)

func string_lanterns(a: Vector3, b: Vector3) -> void:
	var mesh: Mesh = prop_meshes.get("string_lantern")
	if mesh == null:
		return
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = 5
	for i in 5:
		var t: float = (i + 0.5) / 5.0
		var p: Vector3 = a.lerp(b, t) - Vector3.UP * (0.6 * 4.0 * t * (1.0 - t) + 0.3)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game.world.add_child(mmi)

## A carved arch and lantern marks each door; the door spot is where villagers
## go in and where the player comes back out.
func build_doors() -> void:
	for hid: String in houses:
		var h: Dictionary = houses[hid]
		var p0: Vector3 = on_ground(xz(h.door))
		var into: Vector3 = door_dir(h)
		prop("door_arch", p0 + into * 0.2, atan2(into.x, into.z))
		var p: Vector3 = on_nav(p0)
		var s: RefCounted = add_spot("door_" + hid, "door", p, p + into * 3.0)
		doors[hid] = s

## Direction from the door into the house (toward the hut it belongs to).
func door_dir(h: Dictionary) -> Vector3:
	if h.has("into"):
		return xz(h.into).normalized()
	# default: away from the plaza
	var p: Vector3 = xz(h.door)
	var c: Vector3 = Vector3(-4.5, 0, -3.5)
	var d: Vector3 = p - c
	return d.normalized() if d.length() > 0.1 else Vector3.FORWARD

## Spots and doors sit on the walkable area: snap each onto the nav mesh.
func on_nav(p: Vector3) -> Vector3:
	if region == null or region.navigation_mesh == null:
		return p
	var map: RID = game.get_world_3d().navigation_map
	var q0: Vector3 = NavigationServer3D.map_get_closest_point(map, p)
	if Vector2(q0.x - p.x, q0.z - p.z).length() < 1.0 and absf(q0.y - p.y) < 0.8:
		return q0
	# look from boardwalk height too: spots given over water or under a roof still land on the walk
	var best: Vector3 = p
	var best_d: float = INF
	for probe: Vector3 in [p, Vector3(p.x, 0.4, p.z), Vector3(p.x, 1.4, p.z)]:
		var q: Vector3 = NavigationServer3D.map_get_closest_point(map, probe)
		var d: float = Vector2(q.x - p.x, q.z - p.z).length() + absf(q.y - probe.y) * 0.5
		if d < best_d:
			best_d = d
			best = q
	return best if Vector2(best.x - p.x, best.z - p.z).length() < 4.0 else p

func build_spots() -> void:
	for sd: Dictionary in data.get("spots", []):
		var p: Vector3 = on_nav(on_ground(xz(sd.at)))
		add_spot(sd.id, sd.kind, p, on_ground(xz(sd.look)), sd.get("tool", "none"))
	var seats: Array = data.get("features", {}).get("seats", [])
	for i in seats.size():
		var p2: Vector3 = on_nav(on_ground(xz(seats[i])))
		add_spot("seat_%d" % i, "seat", p2, Vector3(-4.5, p2.y, -3.5))

func drop_for(job: String) -> RefCounted:
	return spots.get("drop_" + job)

# ---------------------------------------------------------------- navigation

## Prebaked (tools: --bake-frog-nav) so phones don't bake at load time.
func bake_tile_nav(force: bool = false) -> void:
	region = NavigationRegion3D.new()
	game.world.add_child(region)
	var nm: NavigationMesh
	if not force and ResourceLoader.exists(NAV_RES):
		nm = load(NAV_RES)
	else:
		var t0: int = Time.get_ticks_msec()
		nm = NavigationMesh.new()
		nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
		nm.geometry_collision_mask = 1 | 8 | WALL_LAYER
		nm.cell_size = 0.25
		nm.cell_height = 0.25
		nm.agent_radius = 0.3
		nm.agent_height = 1.5
		nm.agent_max_climb = 0.3
		nm.agent_max_slope = 40.0
		nm.filter_baking_aabb = AABB(Vector3(-HALF_TILE, water_y + 0.5, -HALF_TILE), Vector3(HALF_TILE * 2, 14.0, HALF_TILE * 2))
		var src: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(nm, src, game.world)
		NavigationServer3D.bake_from_source_geometry_data(nm, src)
		keep_main_island(nm)
		nav_baked_ms = Time.get_ticks_msec() - t0
	region.navigation_mesh = nm
	NavigationServer3D.region_set_navigation_mesh(region.get_rid(), nm)
	NavigationServer3D.map_force_update(game.get_world_3d().navigation_map)

# Drop nav patches nobody can walk to (hut floors behind their walls, the dais
# top, stall roofs): only the largest connected piece of the village stays, so
# villagers never snap or wander onto an island they can't leave.
func keep_main_island(nm: NavigationMesh) -> void:
	var vs: PackedVector3Array = nm.get_vertices()
	var n: int = nm.get_polygon_count()
	var parent: PackedInt32Array = PackedInt32Array()
	parent.resize(n)
	for i in n:
		parent[i] = i
	var owner: Dictionary = {}
	for i in n:
		var poly: PackedInt32Array = nm.get_polygon(i)
		for k in poly.size():
			var a: Vector3 = vs[poly[k]].snapped(Vector3.ONE * 0.01)
			var b: Vector3 = vs[poly[(k + 1) % poly.size()]].snapped(Vector3.ONE * 0.01)
			var key: String = str(a) + str(b) if str(a) < str(b) else str(b) + str(a)
			if owner.has(key):
				var ra: int = root_of(parent, i)
				var rb: int = root_of(parent, int(owner[key]))
				parent[ra] = rb
			else:
				owner[key] = i
	var size: Dictionary = {}
	for i in n:
		var r: int = root_of(parent, i)
		size[r] = int(size.get(r, 0)) + 1
	var best: int = -1
	for r: int in size:
		if best < 0 or size[r] > size[best]:
			best = r
	var polys: Array = []
	for i in n:
		if root_of(parent, i) == best:
			polys.append(nm.get_polygon(i))
	nm.clear_polygons()
	for poly: PackedInt32Array in polys:
		nm.add_polygon(poly)

func root_of(parent: PackedInt32Array, x: int) -> int:
	var r: int = x
	while parent[r] != r:
		r = parent[r]
	return r

func save_nav() -> int:
	return ResourceSaver.save(region.navigation_mesh, NAV_RES)

func random_point(center: Vector3, radius: float) -> Vector3:
	var map: RID = game.get_world_3d().navigation_map
	var c: Vector3 = center
	if center == Vector3.ZERO:
		c = on_ground(Vector3(-7.0, 0, -7.0))
	for i in 8:
		var a: float = randf() * TAU
		var p: Vector3 = c + Vector3(cos(a), 0, sin(a)) * randf_range(1.0, radius)
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, c, p, true)
		if path.size() > 0:
			var q: Vector3 = path[path.size() - 1]
			if Vector2(q.x - p.x, q.z - p.z).length() < 1.2:
				return q
	return c

# ---------------------------------------------------------------- cast

func spawn_cast() -> void:
	active = true
	var hero_def: Dictionary = game.HEROES[game.hero_key]
	var at: Vector3
	var yaw: float = float(data.get("spawn_yaw", 0.0))
	if inside != "":
		at = interior_spawn.origin
		yaw = 0.0
	else:
		at = on_ground(v3(data.get("spawn", [0, 0, 0]))) + Vector3.UP * 0.2
	game.hero = game.make_fighter("hero", hero_def.model, 1.8, hero_def.blade, 1.25, at)
	game.hero.collision_mask |= MARSH_LAYER | WALL_LAYER
	game.hero.max_hp = 100
	game.hero.hp = 100
	game.hero.yaw = yaw
	game.cam_yaw = yaw
	game.ally = game.make_fighter("ally", "res://assets/characters/eliza.glb", 1.7, Color("bfe9ff"), 0.5, at + Vector3(0.8, 0, 1.0).rotated(Vector3.UP, yaw))
	game.ally.collision_mask |= MARSH_LAYER | WALL_LAYER
	game.ally.rig.sword.visible = false
	safe_pos = at
	if inside != "":
		spawn_residents()
	else:
		spawn_villagers()

func villager_def(d: Dictionary) -> Dictionary:
	var vd: Dictionary = d.duplicate()
	var models: Array = VILLAGER_MODELS
	vd.model = models[absi(hash(d.id)) % models.size()] if not d.get("female", false) else "res://assets/characters/eliza_lite.glb"
	# frog-folk placeholder look: a strong marsh-green wash over the shared body
	var tint: Color = Color(d.tint[0], d.tint[1], d.tint[2]) if d.has("tint") else Color(0.3, 0.5, 0.2)
	vd.tint = tint.lerp(Color(0.25, 0.6, 0.2), 0.5)
	vd.tint_amount = 0.42
	vd.head_mesh = prop_meshes.get("frog_head")
	if d.get("hat", false):
		vd.hat_mesh = prop_meshes.get("reed_hat")
	vd.head_scale = clampf(float(d.get("height", 1.75)) / 1.75, 0.8, 1.1)
	return vd

func spawn_villagers() -> void:
	clear_villagers()
	var saved: Dictionary = save.get("blocks", {}).get(block, {})
	var saved_v: Dictionary = saved.get("villagers", {})
	var same_time: bool = saved.has("saved_clock") and absf(float(saved.saved_clock) - clock) < 5.0
	for d: Dictionary in data.get("villagers", []):
		if d.job in data.get("home_jobs", []):
			continue   # homekeepers are only ever inside their house
		var v: CharacterBody3D = CharacterBody3D.new()
		v.set_script(VillagerScript)
		game.add_child(v)
		v.setup(game, self, villager_def(d))
		v.home_door = doors.get(d.home, spots.values()[0])
		v.global_position = v.home_door.pos + Vector3.UP * 0.1
		if game.phone:
			game.add_blob(v, v.height)
		villagers.append(v)
	for v: Node in villagers:
		if saved_v.has(v.vid) and same_time:
			v.restore(saved_v[v.vid])
		else:
			if saved_v.has(v.vid):
				v.work_count = int((saved_v[v.vid] as Dictionary).get("work_count", 0))
			v.place_for_schedule()

## Is this villager at home right now (by the village's saved state, or the schedule)?
func at_home(vid: String) -> bool:
	var d: Dictionary = vdefs.get(vid, {})
	if d.is_empty():
		return false
	if d.job in data.get("home_jobs", []):
		return true
	var sv: Dictionary = save.get("blocks", {}).get(block, {}).get("villagers", {}).get(vid, {})
	if not sv.is_empty():
		return str(sv.get("state", "")) == "inside" and str(sv.get("goal", "")) == "door"
	var h: float = hour()
	return h < 6.0 or h >= 21.5

func clear_villagers() -> void:
	super.clear_villagers()
	for r: Node in residents:
		if is_instance_valid(r):
			r.queue_free()
	residents.clear()

func block_state() -> Dictionary:
	var st: Dictionary = super.block_state()
	if inside != "" and save.has("blocks") and save.blocks.has(block):
		# inside a house: the tile's villagers are frozen as they were left
		st.villagers = save.blocks[block].get("villagers", {})
		st.saved_clock = save.blocks[block].get("saved_clock", st.saved_clock)
	return st

func save_now() -> void:
	if not active:
		return
	save["inside"] = inside
	super.save_now()

func load_save() -> void:
	super.load_save()
	block = "frogtown"
	var ins: String = str(save.get("inside", ""))
	inside = ins if houses.has(ins) else ""

func start() -> void:
	game.say("ally", "Frogtown... the marsh folk of Crownfen. Be polite.")
	game.say_once("frog_tip", "tip", "Walk into a door (or press ENTER) to go inside. The south gate road leads on.")

# ---------------------------------------------------------------- interiors

func build_interior(h: Dictionary) -> void:
	var path: String = INTERIORS.get(h.interior_model, INTERIORS.INT_HUT)
	var scene: Node3D = (load(path) as PackedScene).instantiate()
	scene.name = "Interior_" + str(h.interior_model)
	game.world.add_child(scene)
	interior_spots.clear()
	for n: Node in scene.find_children("*", "", true, false):
		var nm: String = str(n.name)
		if n is MeshInstance3D and nm.begins_with("col"):
			trimesh_body((n as MeshInstance3D).mesh, 1, (n as MeshInstance3D).global_transform, scene)
			(n as MeshInstance3D).visible = false
		elif n is MeshInstance3D:
			dress(n as MeshInstance3D, h.get("interior_dressing", {}))
		elif nm == str(h.get("interior_spawn", "Spawn_Door")):
			interior_spawn = (n as Node3D).global_transform
		elif nm == "Exit_Door":
			interior_exit = (n as Node3D).global_position
		elif nm.begins_with("Spot_"):
			var parts: PackedStringArray = nm.split("_")
			interior_spots[nm] = {"kind": parts[1], "pos": (n as Node3D).global_position, "by": null}
	var extra: String = str(h.get("interior_dressing", {}).get("extra", ""))
	var work: Dictionary = interior_spots.get("Spot_work_1", interior_spots.get("Spot_window_1", {}))
	if extra != "" and not work.is_empty():
		var pmap: Dictionary = {"drum": ["council_drum", 0.7], "goods": ["market_stall", 0.55], "spears": ["request_board", 0.6], "herbs": ["string_lantern", 2.0]}
		if pmap.has(extra):
			prop(pmap[extra][0], (work.pos as Vector3) + Vector3(0.0, 0, -0.9), 0.0, scene, pmap[extra][1])
	# a ceiling the camera can't rise through (the roofs are visual only)
	var lid: StaticBody3D = StaticBody3D.new()
	lid.collision_layer = 64
	var lcs: CollisionShape3D = CollisionShape3D.new()
	var lb: BoxShape3D = BoxShape3D.new()
	lb.size = Vector3(16, 0.3, 16)
	lcs.shape = lb
	lid.add_child(lcs)
	lid.position.y = 2.75
	scene.add_child(lid)
	# warm hearth light (one dynamic light inside)
	var l: OmniLight3D = OmniLight3D.new()
	l.light_color = Color("ffb35c")
	l.light_energy = 1.6
	l.omni_range = 9.0
	var hp: Dictionary = interior_spots.get("Spot_hearth_1", {})
	l.position = ((hp.pos as Vector3) if not hp.is_empty() else Vector3.ZERO) + Vector3(0, 1.5, -0.8)
	scene.add_child(l)
	# small nav mesh for the residents (rooms are tiny: bakes in a few ms)
	region = NavigationRegion3D.new()
	var nm2: NavigationMesh = NavigationMesh.new()
	nm2.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm2.geometry_collision_mask = 1
	nm2.cell_size = 0.25
	nm2.cell_height = 0.25
	nm2.agent_radius = 0.3
	nm2.agent_height = 1.5
	nm2.agent_max_climb = 0.2
	game.world.add_child(region)
	var src: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm2, src, game.world)
	NavigationServer3D.bake_from_source_geometry_data(nm2, src)
	region.navigation_mesh = nm2
	NavigationServer3D.region_set_navigation_mesh(region.get_rid(), nm2)
	NavigationServer3D.map_force_update(game.get_world_3d().navigation_map)

## Dressing: the same room looks different per family (cloth colour + one extra prop).
func dress(mi: MeshInstance3D, dressing: Dictionary) -> void:
	var cloth: String = str(dressing.get("cloth", ""))
	if cloth == "" or mi.mesh == null:
		return
	var colors: Dictionary = {"cloth_blue": Color(0.14, 0.25, 0.48), "cloth_teal": Color(0.18, 0.5, 0.53), "red": Color(0.62, 0.22, 0.16)}
	for i in mi.mesh.get_surface_count():
		var m: Material = mi.mesh.surface_get_material(i)
		if m and m.resource_name.contains("cloth"):
			var nm: StandardMaterial3D = (m as BaseMaterial3D).duplicate() if m is BaseMaterial3D else StandardMaterial3D.new()
			nm.albedo_color = colors.get(cloth, Color(0.5, 0.5, 0.5))
			mi.set_surface_override_material(i, nm)

func spawn_residents() -> void:
	var h: Dictionary = houses[inside]
	for vid: String in h.residents:
		if not at_home(vid):
			continue
		var r: CharacterBody3D = CharacterBody3D.new()
		r.set_script(ResidentScript)
		game.add_child(r)
		r.setup(game, self, villager_def(vdefs[vid]))
		residents.append(r)
		r.place_for_schedule()

func claim_interior(r: Node, kinds: Array) -> String:
	var best: String = ""
	var best_d: float = INF
	for id: String in interior_spots:
		var s: Dictionary = interior_spots[id]
		if not (s.kind in kinds):
			continue
		if s.by != null and s.by != r and is_instance_valid(s.by):
			continue
		var d: float = (s.pos as Vector3).distance_to(r.global_position) + randf() * 0.5
		if d < best_d:
			best_d = d
			best = id
	if best != "":
		release_interior(r)
		interior_spots[best].by = r
	return best

func release_interior(r: Node) -> void:
	for id: String in interior_spots:
		if interior_spots[id].by == r:
			interior_spots[id].by = null

## Walking into a door (or pressing ENTER next to it).
func near_door() -> String:
	if not active or game.hero == null:
		return ""
	var p: Vector3 = game.hero.global_position
	if inside != "":
		return inside if Vector2(p.x - interior_exit.x, p.z - interior_exit.z).length() < 1.4 else ""
	for hid: String in doors:
		var s: RefCounted = doors[hid]
		if Vector2(p.x - s.pos.x, p.z - s.pos.z).length() < 1.5 and absf(p.y - s.pos.y) < 1.6:
			return hid
	return ""

func can_enter(hid: String) -> String:
	var h: Dictionary = houses[hid]
	var hr: float = hour()
	var night: bool = hr < 6.0 or hr >= 21.5
	match str(h.get("access", "open")):
		"locked_night":
			if night:
				return "Locked for the night."
		"knock":
			var home: bool = false
			for vid: String in h.residents:
				if at_home(vid):
					home = true
			if not home:
				return "You knock... nobody's home."
		"locked_story":
			return "The door is barred."
	return ""

func enter_house(hid: String) -> bool:
	var why: String = can_enter(hid)
	if why != "":
		game.hud.popup(why.to_upper(), Color("ffd27a"))
		door_cd = 2.0
		return false
	save_now()
	inside = hid
	clear_villagers()
	game.build_stage()
	var at: Vector3 = interior_spawn.origin + Vector3(0, 0.1, -1.0)
	var yaw: float = 0.0   # interiors have their door on +z: face into the room
	game.hero.global_position = at
	game.hero.velocity = Vector3.ZERO
	game.hero.yaw = yaw
	game.cam_yaw = yaw
	game.cam_pos = at
	game.ally.global_position = at + Vector3(0.8, 0, 0.6).rotated(Vector3.UP, yaw)
	game.ally.velocity = Vector3.ZERO
	spawn_residents()
	save_now()
	door_cd = 1.2
	game.hud.fade = 1.0
	game.hud.popup(str(houses[hid].name).to_upper(), Color("ffe08a"))
	game.sound("cover", -10)
	return true

func exit_house() -> void:
	var hid: String = inside
	if hid == "":
		return
	for r: Node in residents:
		if is_instance_valid(r):
			r.queue_free()
	residents.clear()
	inside = ""
	game.build_stage()
	var door: RefCounted = doors.get(hid)
	var out: Vector3 = -door_dir(houses[hid])
	var at: Vector3 = on_ground(door.pos + out * 1.8) + Vector3.UP * 0.15
	game.hero.global_position = at
	game.hero.velocity = Vector3.ZERO
	game.hero.yaw = atan2(-out.x, -out.z)
	game.cam_yaw = game.hero.yaw
	game.cam_pos = at
	game.ally.global_position = at + out * 1.2 + out.cross(Vector3.UP) * 0.8
	game.ally.velocity = Vector3.ZERO
	spawn_villagers()
	save_now()
	safe_pos = at
	door_cd = 1.5
	game.hud.fade = 1.0
	game.hud.popup(str(data.get("title", "Frogtown")).to_upper(), Color("ffe08a"))

func use_door() -> void:
	var hid: String = near_door()
	if hid == "":
		return
	if inside != "":
		exit_house()
	else:
		enter_house(hid)

# ---------------------------------------------------------------- per frame

func progress(dt: float) -> void:
	clock += dt * minutes_per_second()
	apply_daylight()
	chat.tick(dt)
	speaker_t = maxf(0.0, speaker_t - dt)
	door_cd = maxf(0.0, door_cd - dt)
	road_msg_t = maxf(0.0, road_msg_t - dt)
	autosave_t += dt
	if autosave_t > 20.0:
		autosave_t = 0.0
		save_now()
	if wheel:
		wheel.rotate_object_local(Vector3.RIGHT, dt * 0.8)
	var h: CharacterBody3D = game.hero
	if h == null:
		return
	var p: Vector3 = h.global_position
	# doors are triggers: walking into one goes through it
	if door_cd <= 0.0 and game.mode == "play":
		var hid: String = near_door()
		if hid != "":
			var moving: Vector3 = Vector3(h.velocity.x, 0, h.velocity.z)
			var into: Vector3 = (interior_exit - p) if inside != "" else door_dir(houses[hid])
			into.y = 0
			if moving.length() > 1.0 and moving.normalized().dot(into.normalized()) > 0.4:
				use_door()
				return
	if inside != "":
		return
	if h.is_on_floor() and p.y > water_y + 0.8:
		safe_pos = p
	# fell into the marsh: splash, then back onto the boardwalk
	if p.y < water_y - 0.2:
		game.hud.popup("SPLASH!", Color("8fe9ff"))
		game.burst(Vector3(p.x, water_y + 0.1, p.z), Color("bfeee8"), 18, 4.0)
		h.global_position = safe_pos + Vector3.UP * 0.3
		h.velocity = Vector3.ZERO
		game.cam_pos = h.global_position
	# road exit at the tile edge: the hook for the next tile
	for ex: Dictionary in data.get("exits", []):
		var gp: Vector3 = xz([ex.at[0], ex.at[2]])
		var dv: Vector3 = xz(ex.dir)
		var rel: Vector3 = Vector3(p.x - gp.x, 0, p.z - gp.z)
		if rel.length() < 2.4 and rel.dot(dv) > -0.4:
			leave_by_road(ex)

## Next-tile hook: 2x2 / 3x3 villages load the neighbour here. Today there is
## only this tile, so the road says where it goes and turns you back.
func leave_by_road(ex: Dictionary) -> void:
	var to: String = str(ex.get("to_tile", ""))
	if to != "" and has_tile(to):
		load_tile(to, str(ex.id))
		return
	var dv: Vector3 = xz(ex.dir)
	game.hero.global_position -= dv * 1.2
	game.hero.velocity = Vector3.ZERO
	if road_msg_t <= 0.0:
		road_msg_t = 3.0
		game.hud.popup("ROAD TO %s" % str(ex.get("title", "?")).to_upper(), Color("ffe08a"))
		game.say("tip", "The road to %s isn't open yet. (Next village tile.)" % ex.get("title", "the next tile"))

func has_tile(_tile_id: String) -> bool:
	return false

func load_tile(_tile_id: String, _from_exit: String) -> void:
	pass

func leave() -> void:
	super.leave()
	for r: Node in residents:
		if is_instance_valid(r):
			r.queue_free()
	residents.clear()
