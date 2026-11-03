extends Node
## Autoload CombatFx: hit sparks, sounds and camera shake requests (the arena's camera listens).

signal shake_requested(trauma: float)

var sounds: Dictionary = {}
var muted: bool = false
var shakes: Array[float] = []     # tests read the last requests

func spark(tree: SceneTree, at: Vector3, color: Color, count: int = 20) -> void:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.one_shot = true
	p.amount = count
	p.lifetime = 0.3
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 10.0
	p.gravity = Vector3(0, -12, 0)
	p.particle_flag_align_y = true
	p.damping_min = 8.0
	p.damping_max = 12.0
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(color.r, color.g, color.b, 0))
	p.color_ramp = g
	var m: BoxMesh = BoxMesh.new()
	m.size = Vector3(0.03, 0.32, 0.03)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	m.material = mat
	p.mesh = m
	tree.current_scene.add_child(p)
	p.global_position = at
	p.emitting = true
	var flash: OmniLight3D = OmniLight3D.new()
	flash.light_color = color
	flash.light_energy = 3.0
	flash.omni_range = 3.0
	tree.current_scene.add_child(flash)
	flash.global_position = at
	var tw: Tween = flash.create_tween()
	tw.tween_property(flash, "light_energy", 0.0, 0.12)
	tw.tween_callback(flash.queue_free)
	tree.create_timer(0.8).timeout.connect(p.queue_free)

func sound(tree: SceneTree, cue: String, db: float = -6.0) -> void:
	if muted:
		return
	if not sounds.has(cue):
		var path: String = "res://audio/%s.wav" % cue
		sounds[cue] = load(path) if ResourceLoader.exists(path) else null
	if sounds[cue] == null:
		return
	var n: AudioStreamPlayer = AudioStreamPlayer.new()
	n.stream = sounds[cue]
	n.volume_db = db
	tree.current_scene.add_child(n)
	n.finished.connect(n.queue_free)
	n.play()

func shake(tree: SceneTree, trauma: float) -> void:
	shakes.append(trauma)
	if shakes.size() > 20:
		shakes.pop_front()
	shake_requested.emit(trauma)
