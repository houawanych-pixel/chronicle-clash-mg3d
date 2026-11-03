extends Resource
## One attack, authored in frames at 60 fps (the clip built from it uses these exact times).
## The hitbox is live only between startup and startup + active (hit_start / hit_end tracks).

@export var id: String = "light1"
@export var startup_f: int = 10
@export var active_f: int = 4
@export var recovery_f: int = 16
@export var hitstop_f: int = 5
@export var damage: float = 10.0
@export var stamina_cost: float = 0.0
@export var lunge_m: float = 0.6            # root motion forward over startup + active
@export var reach_m: float = 1.8            # hitbox centre distance in front of the chest
@export var radius_m: float = 0.9           # hitbox size
@export_enum("horizontal", "vertical", "thrust") var plane: String = "horizontal"
@export var shake: float = 0.3              # camera trauma added on hit
@export var stagger_f: int = 12             # how long a normal foe is staggered
@export var knockback: float = 2.0          # m/s push on the victim
@export var chain_to: String = ""           # next move in the string ("" = string ends)
@export var pose: String = "slash0"         # which procedural pose family draws it

func total_f() -> int:
	return startup_f + active_f + recovery_f

func seconds(frames: int) -> float:
	return frames / 60.0
