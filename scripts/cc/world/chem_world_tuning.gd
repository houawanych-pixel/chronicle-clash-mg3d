extends Resource
## World chemistry numbers (CC-tuned).

@export var cell_size: float = 1.0
@export var fire_heat_transfer: float = 0.3      # chance scale a burning cell lights a neighbour per tick
@export var burn_speed_rate: float = 0.4         # fuel burnt per second (grass has 1.0 fuel)
@export var fire_extra_radius: float = 0.3       # a fire source reaches this far past its own radius
@export var wind_bias: float = 2.2               # downwind neighbours are this much more likely
@export var tick_s: float = 0.15
@export var rain_quench_per_s: float = 1.5       # burning fuel lost per second in rain
@export var updraft_height: float = 14.0         # how high a fire column lifts
@export var wind_lift_rate: float = 0.7          # m/s of lift per burning cell nearby (capped)
@export var updraft_max: float = 6.0
@export var lightning_distance: float = 35.0
@export var lightning_interval_s: float = 6.0
@export var lightning_warn_s: float = 2.0
@export var lightning_damage: float = 40.0
@export var electric_water_radius_mult: float = 8.0
@export var ice_melt_fire: float = 1.0           # ice lost per second next to fire
@export var character_ignite_ticks: int = 90
@export var bomb_fire_chance: float = 0.6
