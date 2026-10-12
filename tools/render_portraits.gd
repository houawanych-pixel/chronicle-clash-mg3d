extends SceneTree
## Renders 320x256 face portraits of the character GLBs for the dialogue cards.
const RigScript = preload("res://scripts/citadel/Rig.gd")
const P = preload("res://scripts/citadel/Poses.gd")
func _init() -> void:
	var jobs: Array = [["blonde_lance", "blonde_lance", Color("1b2c5a")], ["lance", "lance", Color("1d2a2a")], ["ally", "eliza", Color("1d3a5c")], ["boss", "knight", Color("3a0d14")]]
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(320, 256)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	get_root().add_child(vp)
	var root3d: Node3D = Node3D.new()
	vp.add_child(root3d)
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.85, 1.0)
	e.ambient_light_energy = 0.55
	env.environment = e
	root3d.add_child(env)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-20, -35, 0)
	key.light_energy = 1.4
	root3d.add_child(key)
	var rim: DirectionalLight3D = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, 150, 0)
	rim.light_energy = 1.2
	rim.light_color = Color("8fe9ff")
	root3d.add_child(rim)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 26
	root3d.add_child(cam)
	for job: Array in jobs:
		e.background_color = job[2]
		var r: Node3D = Node3D.new()
		r.set_script(RigScript)
		root3d.add_child(r)
		r.setup("res://assets/characters/%s.glb" % job[1], 1.8, Color("8fe9ff"), 1.0, 0.0)
		r.sword.visible = false
		r.rotation.y = PI - 0.35
		for i in 4:
			r.apply(P.idle(0.0, false), 0.1, 60.0)
			await process_frame
		var head: Vector3 = r.sk.global_transform * r.sk.get_bone_global_pose(r.idx["Head"]).origin
		var fwd: Vector3 = Vector3(-sin(r.rotation.y), 0, -cos(r.rotation.y))
		cam.look_at_from_position(head + Vector3(0, 0.06, 0) + fwd * 1.15 + Vector3(0, 0.02, 0), head + Vector3(0, 0.04, 0))
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("res://assets/citadel/portrait_%s.png" % job[0])
		r.queue_free()
		await process_frame
	quit()
