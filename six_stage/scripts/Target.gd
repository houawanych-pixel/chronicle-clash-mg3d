extends StaticBody3D
const V=preload("res://scripts/Visuals.gd")
var game: Node
var weapon: String="pistol"
var health: float=100
var marker: MeshInstance3D
func _ready() -> void:
	collision_layer=8
	var col: CollisionShape3D=CollisionShape3D.new()
	var shape: BoxShape3D=BoxShape3D.new(); shape.size=Vector3(1.6,2.5,.4)
	col.shape=shape; col.position.y=1.25; add_child(col)
	marker=V.box(self,Vector3(0,1.25,0),shape.size,V.mat(Color("394b5d")))
	V.box(self,Vector3(0,1.35,.23),Vector3(.65,.9,.045),V.mat(Color("ffcd79"),.3))
	V.label(self,Vector3(0,3,0),weapon.to_upper(),Color("ffce7e"),36)
func receive_hit(amount: float, used: String, _at: Vector3) -> void:
	if health<=0: return
	if used!=weapon:
		game.toast("Use "+weapon.to_upper()+" at this target."); return
	health-=amount
	game.sound("hit",-10)
	if health<=0:
		marker.material_override=V.mat(Color("39b388"),.3)
		game.mark_goal("target_"+weapon)
		game.toast(weapon.to_upper()+" station cleared.")
