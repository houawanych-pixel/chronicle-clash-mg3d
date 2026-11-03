extends Resource
## What a thing is made of, for chemistry.

@export var id: String = "grass"
@export_flags("wood", "grass", "metal", "stone", "flesh", "ice") var tags: int = 2
@export var ignition_point: float = 0.3
@export var burn_speed: float = 1.0
@export var conductive: bool = false
@export var flammable: bool = true
@export var fuel: float = 1.0
