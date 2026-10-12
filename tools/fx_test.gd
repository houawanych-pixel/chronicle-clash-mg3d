extends SceneTree
## Freeze-frame of the hit effects on a white floor and a dark floor.
const FxScript = preload("res://scripts/citadel/Fx.gd")
func _init() -> void:
	var holder: Node3D = Node3D.new()
	var dummy: GDScript = GDScript.new()
	dummy.source_code = "extends Node3D\nvar autotest = null\nvar height = 1.8\n"
	dummy.reload()
	holder.set_script(dummy)
	get_root().add_child(holder)
	await process_frame
	var fx: RefCounted = FxScript.new(holder)
	for side in 2:
		var floor_mi: MeshInstance3D = MeshInstance3D.new()
		var pm: PlaneMesh = PlaneMesh.new()
		pm.size = Vector2(6, 8)
		floor_mi.mesh = pm
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = Color("e8e6e1") if side == 0 else Color("1c1a26")
		floor_mi.material_override = m
		floor_mi.position = Vector3(-3 + side * 6, 0, 0)
		holder.add_child(floor_mi)
	var cam: Camera3D = Camera3D.new()
	holder.add_child(cam)
	cam.look_at_from_position(Vector3(0, 2.2, 5.5), Vector3(0, 1.0, 0))
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 20, 0)
	holder.add_child(sun)
	# Warm up shaders so the capture lands mid-effect.
	fx.slash(Vector3(0, -5, 0), Vector3(0, 0, -1), Color.WHITE)
	fx.impact(Vector3(0, -5, 0), Color.WHITE)
	fx.sparks(Vector3(0, -5, 0), Color.WHITE)
	for i in 30:
		await process_frame
	Engine.time_scale = 0.05
	for side in 2:
		var x: float = -3 + side * 6
		var at: Vector3 = Vector3(x, 1.05, 0)
		fx.slash(at, Vector3(0, 0, -1), Color("8fe9ff"), 1.8, 0.85 if side == 0 else 1.4, false)
		fx.impact(at + Vector3(0, 0, 0.3), Color("8fe9ff"), 1.5)
		fx.sparks(at, Color("ffd27a"), 26, 9.0, Vector3(0, 0.4, -1))
	for i in 4:
		await process_frame
	get_root().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	quit()
