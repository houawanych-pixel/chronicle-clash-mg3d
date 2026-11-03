extends Resource
## Combat feel numbers (CC's own, 60 fps frames).

@export var input_buffer_f: int = 8
@export var lock_assist_deg: float = 12.0
@export var lock_range_m: float = 14.0
@export var lock_cone_deg: float = 70.0
@export var hold_to_charge_f: int = 12       # ATTACK still held this long after a swing = charge
@export var charge_full_f: int = 40
@export var guard_damage_mult: float = 0.25
@export var parry_window_f: int = 8          # guard pressed this many frames before impact = parry
@export var parry_stun_f: int = 40
@export var dodge_f: int = 22
@export var dodge_iframes_f: int = 12
@export var dodge_speed: float = 7.5
@export var dodge_cancel_after_active_f: int = 2
@export var dodge_stamina: float = 12.0
@export var flurry_hits: Dictionary = {"one_hand": 7, "two_hand": 4, "spear": 7}
@export var flurry_time_scale: float = 0.3
@export var flurry_window_s: float = 1.2     # real seconds to press ATTACK after a perfect dodge
@export var flurry_hit_damage: float = 6.0
@export var sneak_mult: float = 6.0
@export var stagger_light_f: int = 12
@export var stagger_heavy_f: int = 30
@export var shake_max_offset: float = 0.22
@export var shake_max_roll_deg: float = 2.5
@export var shake_decay: float = 1.8         # trauma lost per second
@export var walk_speed: float = 2.4
@export var run_speed: float = 5.2
@export var sprint_speed: float = 7.6
@export var crouch_speed: float = 1.6
