extends Resource
## Stormrunner (CC motorcycle) tuning. Speeds in m/s, angles in degrees, times in seconds.

@export var max_speed: float = 22.0
@export var accel: float = 9.0
@export var brake: float = 20.0
@export var coast_drag: float = 2.5
@export var steer_rate: float = 1.9           # rad/s at low speed
@export var steer_high_speed: float = 0.9     # rad/s at max speed
@export var drift_enter_speed: float = 13.0   # must be at least this fast to start a drift
@export var drift_exit_speed: float = 9.0     # a drift ends below this
@export var drift_steer_mult: float = 1.8
@export var drift_slip: float = 0.55          # how far the travel lags the heading in a drift (0..1)
@export var wheelie_min_speed: float = 4.0
@export var wheelie_angle: float = 28.0
@export var wheelie_time: float = 2.2
@export var jump_speed: float = 6.5
@export var jump_interval: float = 1.2
@export var tank_seconds: float = 300.0       # full tank at full throttle on the ground
@export var refuel_max_items: int = 5
@export var summon_deny_tags: Array[String] = ["interior", "sanctum", "deep_water"]
