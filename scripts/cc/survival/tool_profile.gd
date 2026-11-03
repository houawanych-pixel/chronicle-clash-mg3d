extends Resource
## A tool or weapon as the survival systems see it. kind decides how it works on trees and
## ore: "axe" chops, "blade" cuts (weaker on wood), "blunt" bounces off trees.

@export var id: String = ""
@export var display_name: String = ""
@export_enum("axe", "blade", "blunt") var kind: String = "blade"
@export var power: float = 8.0
