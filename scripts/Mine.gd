extends Node3D
const V = preload("res://scripts/Visuals.gd")
var game: Node
var kind: String = "remote"
var facing: Vector3 = Vector3.FORWARD
var arm_time: float = .8
var dead: bool = false
func _ready() -> void:
	V.box(self,Vector3(0,.16,0),Vector3(.55,.3,.16),V.mat(Color("73ac86") if kind=="claymore" else Color("5e8ecc")))
	V.ring(self,Vector3(0,.035,0),.55,Color("ffb750") if kind=="claymore" else Color("5bd0f4"))
	if kind=="claymore":
		V.line(self,Vector3(0,.2,0),facing*2.5+Vector3.UP*.2,Color("efa955"),.018)
func tick(delta: float) -> void:
	arm_time -= delta
	if dead or arm_time>0 or kind!="claymore": return
	for guard: CharacterBody3D in game.guards+game.drones:
		if guard.health<=0: continue
		var d: Vector3 = guard.global_position-global_position
		if d.length()<3.0 and d.normalized().dot(facing)>.65 and game.clear_sight(global_position+Vector3.UP*.3,guard.global_position+Vector3.UP*.7):
			explode(); return
func explode() -> void:
	if dead: return
	dead = true
	game.blast(global_position+Vector3.UP*.25,4.0,120,kind)
	game.mines.erase(self)
	queue_free()
