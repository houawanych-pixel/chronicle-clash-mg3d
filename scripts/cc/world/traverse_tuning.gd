extends Resource
## Swimming, cliff diving, shield surfing and the bow (CC defaults).

# swim
@export var swim_speed: float = 2.4
@export var swim_dash_speed: float = 4.8
@export var swim_dash_drain: float = 25.0      # stamina / s while dashing
@export var swim_float: float = 1.3             # how far below the surface Lance's feet sit
@export var deep_water_m: float = 1.4           # deeper than this you swim
@export var drown_damage: float = 20.0
# skydive / dive
@export var skydive_min_height: float = 7.0
@export var skydive_air_speed: float = 7.5
@export var terminal_speed: float = 26.0
@export var dive_min_depth: float = 2.5        # water this deep takes a high dive safely
# shield surf
@export var surf_gravity_k: float = 1.0
@export var surf_friction: Dictionary = {"snow": 0.04, "sand": 0.05, "grass": 0.16, "rock": 0.32}
@export var surf_rain_friction_mult: float = 0.6
@export var surf_sled_wear: Dictionary = {"snow": 0.0, "sand": 0.0, "grass": 0.4, "rock": 1.5}
@export var surf_impact_cost: float = 1.0
@export var surf_turn_rate: float = 2.2
@export var surf_hop_speed: float = 6.0
@export var shield_life: float = 100.0
@export var shield_break_damage_frac: float = 0.08
@export var tumble_f: int = 40
# bow
@export var bow_draw_s: float = 0.45
@export var arrow_speed_min: float = 18.0
@export var arrow_speed_max: float = 42.0
@export var arrow_gravity: float = 9.8
@export var arrow_damage: float = 14.0
@export var headshot_mult: float = 2.0
@export var aerial_time_scale: float = 0.3
@export var aerial_drain: float = 15.0
