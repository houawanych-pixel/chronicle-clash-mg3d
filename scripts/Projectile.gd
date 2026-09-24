extends Node3D
const V = preload("res://scripts/Visuals.gd")
var game: Node
var kind: String = "grenade"
var velocity: Vector3
var life: float = 2.5
var dead: bool = false
func _ready() -> void:
	V.box(self,Vector3.ZERO,Vector3(.15,.15,.45) if kind=="rocket" else Vector3(.22,.22,.22),V.mat(Color("ffbd66") if kind=="rocket" else Color("658d74"),.2))
	if kind=="rocket": life = 5
func tick(delta: float) -> void:
	if dead: return
	life -= delta
	if kind=="grenade": velocity.y -= 16*delta
	var end: Vector3 = global_position+velocity*delta
	var hit: Dictionary = game.ray(global_position,end,29)
	if not hit.is_empty():
		global_position = hit.position+hit.normal*.15
		if kind=="rocket": explode(); return
		velocity = velocity.bounce(hit.normal)*.45
	else: global_position = end
	rotate_y(delta*4)
	if life<=0: explode()
func explode() -> void:
	if dead: return
	dead = true
	game.blast(global_position,4.5 if kind=="rocket" else 4.0,150 if kind=="rocket" else 110,kind)
	game.projectiles.erase(self)
	queue_free()
