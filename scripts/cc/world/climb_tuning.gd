extends Resource
## Climbing (CC defaults). Distances in metres, drains in stamina.

@export var climb_speed: float = 1.6
@export var stamina_drain_move: float = 12.0   # per second while moving on the wall
@export var stamina_drain_hold: float = 2.0    # per second hanging still
@export var drain_jump: float = 40.0           # a climbing leap
@export var leap_height: float = 1.6
@export var rain_drain_mult: float = 1.2
@export var slip_after_meters: float = 8.0
@export var slip_random_extra_meters: float = 8.0
@export var slip_distance: float = 2.0
@export var slip_stamina_penalty: float = 20.0
@export var no_climb_time_after_fall: float = 0.6
@export var no_climb_time_tired: float = 1.2
