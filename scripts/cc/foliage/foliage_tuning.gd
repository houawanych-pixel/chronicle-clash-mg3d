extends Resource
## CC foliage numbers (leaves, vines, flowers). One table for all three block types.

@export var season_regrow_h: float = 72.0      ## T_season_regrow: world-clock hours from BURNED_CLEARED back to INTACT
@export var vine_spread_h: float = 6.0         ## world hours for an intact vine to hang one more cell down
@export var vine_max_hang: int = 8             ## cells: the longest a vine hangs
@export var vine_offset: float = 0.008         ## m off the host face along its normal (no z-fighting)
@export var burn_spread_chance: float = 0.75   ## a burning cell lights an intact neighbour this often
@export var burn_spread_delay: Vector2 = Vector2(0.3, 0.8)   ## s before a neighbour catches
@export var sway_amount: float = 0.09          ## m at the tips in a normal wind
@export var snap_radius: float = 2.6           ## m: the big flower notices a target this close
@export var snap_reach: float = 1.7            ## m from its head: the bite hits inside this
@export var snap_damage: float = 14.0
@export var snap_telegraph_s: float = 0.45     ## pull-back before the bite
@export var snap_shut_s: float = 0.12
@export var snap_cooldown_s: float = 1.3
@export var vine_climb_drain_k: float = 0.45   ## climbing on vines costs this share of the stamina
@export var vine_climb_speed_k: float = 1.3
