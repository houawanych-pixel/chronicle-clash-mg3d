extends Resource
## Movement tuning for the hero (Sky Citadel traversal). Edit
## res://data/movement.tres in the Godot inspector to change these without
## touching code. Speeds are metres per second, drains are stamina per second.

@export_group("Stamina")
@export var stamina_max: float = 100.0
@export var regen_rate: float = 28.0          ## refill per second on the ground
@export var regen_delay: float = 0.6          ## pause after exertion before refilling
@export var exhausted_until: float = 0.3      ## exhausted until stamina is back above this share of max
@export var low_warning: float = 0.25         ## bar flashes red below this share of max

@export_group("Ground")
@export var run_speed: float = 6.6
@export var sprint_speed: float = 9.6
@export var exhausted_speed: float = 4.6
@export var ground_accel: float = 48.0        ## how fast you reach full speed
@export var ground_decel: float = 60.0        ## how fast you stop when you let go
@export var air_accel: float = 20.0           ## steering while in the air
@export var sprint_drain: float = 12.0
@export var jump_speed: float = 9.6

@export_group("Climbing")
@export var climb_speed: float = 2.3
@export var climb_drain: float = 11.0         ## moving on a wall
@export var hang_drain: float = 3.0           ## holding still on a wall
@export var climb_leap_cost: float = 18.0
@export var ledge_drain: float = 2.0          ## hanging from a ledge
@export var shimmy_speed: float = 1.7
@export var ledge_reach: float = 2.25         ## highest ledge you can catch, above your feet
@export var pullup_time: float = 0.55

@export_group("Glider")
@export var glide_speed: float = 7.5
@export var glide_min_speed: float = 4.0      ## forward drift with no input
@export var glide_accel: float = 7.0
@export var glide_fall: float = 3.0           ## sink rate
@export var glide_drain: float = 7.0
@export var glide_min_height: float = 2.2     ## must be this high above the ground to open

@export_group("Slopes")
@export var slide_angle: float = 37.0         ## degrees; steeper floors make you slide
@export var slide_accel: float = 16.0
@export var slide_max: float = 12.0
