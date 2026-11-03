extends Resource
## Jump, air control, glide and fall-damage numbers (CC, 60 fps frames).

@export var gravity: float = 20.0
@export var peak_height: float = 2.0          # standing jump
@export var run_height_add: float = 0.45      # added at full run speed
@export var coyote_f: int = 8
@export var buffer_f: int = 8
@export var air_accel: float = 9.0
@export var air_max_speed: float = 5.4
@export var glide_min_height: float = 2.2
@export var glide_fall_speed: float = 1.6
@export var glide_speed: float = 6.0
@export var glide_drain: float = 8.0          # stamina / s
@export var fall_safe_m: float = 5.0          # no damage below
@export var fall_heavy_m: float = 20.0        # max curve damage here
@export var fall_heavy_frac: float = 0.6      # of max hp at fall_heavy_m
@export var dead_height_m: float = 30.0       # KO at or above
@export var hard_land_stun_f: int = 30
@export var mantle_min_m: float = 0.5
@export var mantle_max_m: float = 1.3
@export var mantle_f: int = 16
@export var roll_iframes_f: int = 8

## Fall damage as a fraction of max hp for a drop of h metres.
func fall_damage_frac(h: float) -> float:
	if h < fall_safe_m:
		return 0.0
	if h >= dead_height_m:
		return 1.0
	if h >= fall_heavy_m:
		return lerpf(fall_heavy_frac, 1.0, (h - fall_heavy_m) / (dead_height_m - fall_heavy_m))
	return lerpf(0.05, fall_heavy_frac, (h - fall_safe_m) / (fall_heavy_m - fall_safe_m))
