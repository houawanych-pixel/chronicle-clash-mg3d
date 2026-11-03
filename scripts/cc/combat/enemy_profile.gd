extends Resource
## A CC enemy type: senses, pacing and its attack (frames at 60 fps).

@export var id: String = "briar_knight"
@export var display_name: String = "Briar Knight"
@export var model: String = "res://assets/characters/knight_lite.glb"
@export var height: float = 1.82
@export var hp: float = 60.0
@export var walk_speed: float = 1.6
@export var run_speed: float = 4.2
@export var sight_m: float = 12.0
@export var sight_half_deg: float = 55.0
@export var hearing_m: float = 10.0
@export var proximity_m: float = 1.2
@export var notice_time_s: float = 0.9       # seeing you this long (up close faster) = battle
@export var forget_time_s: float = 5.0       # no sight or sound this long = give up, back to roam
@export var alert_range_m: float = 14.0      # allies this close join the fight
@export var keep_dist_m: float = 3.0         # ring radius while waiting a turn
@export var attack_range_m: float = 2.0
@export var attack_cooldown_s: float = 1.6
@export var windup_f: int = 24               # telegraph: readable wind-up
@export var active_f: int = 5
@export var recover_f: int = 30
@export var damage: float = 14.0
@export var just_avoid_f: int = 12           # a dodge this many frames before impact (or during) is perfect
@export var planes: Array[String] = ["horizontal", "vertical"]   # alternates
@export var is_archer: bool = false
@export var arrow_speed: float = 16.0
@export var archer_min_m: float = 8.0
@export var archer_max_m: float = 13.0
