extends Resource
## A CC weapon: its class, light string, how its charge works, and how it looks.

@export var id: String = "ironwood_blade"
@export var display_name: String = "Ironwood Blade"
@export_enum("one_hand", "two_hand", "spear") var weapon_class: String = "one_hand"
@export var string_moves: Array[String] = ["light1", "light2", "light3"]
## one_hand: hold = charge, release = spin (costs release_cost; drains while held; empty = auto-fire)
## two_hand: hold = keep spinning (charge_loop_move, drains), release / empty = slam (finisher_move)
## spear:    hold = rapid thrusts (charge_loop_move, drains), release / empty = stop
@export_enum("spin_release", "spin_hold_slam", "rapid_thrust") var charge_kind: String = "spin_release"
@export var charge_loop_move: String = ""
@export var finisher_move: String = "heavy"
@export var charge_drain_per_sec: float = 6.0
@export var release_cost: float = 25.0
@export var can_guard: bool = true
@export var flurry_hits: int = 7
@export var blade_len: float = 1.2
@export var blade_width: float = 0.095
@export var color: Color = Color("b48cff")
@export var walk_mult: float = 1.0
@export var life: float = 100.0
@export var damage_mult: float = 1.0
@export_enum("metal", "wood", "flesh") var material: String = "metal"
@export var survives_throw: bool = false
@export var breakable: bool = true
