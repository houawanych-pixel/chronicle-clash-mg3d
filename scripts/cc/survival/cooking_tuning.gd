extends Resource
## Chronicle Clash cooking balance. All numbers are CC's own.

@export var max_ingredients: int = 5
@export var pot_heal_mult: float = 2.0       # a pot meal heals this much more than eating the same things raw
@export var roast_heal_mult: float = 1.5     # roasting over a fire: some extra heal, never a buff
@export var fail_heal_mult: float = 1.0      # mixed buff families: a murky meal, raw value only
@export var tier_thresholds: Array[int] = [2, 6, 10]   # total potency for buff tier 1 / 2 / 3
@export var count_crit_rates: Array[int] = [0, 4, 8, 12, 16]   # crit % added for 1..5 ingredients
@export var crit_heart_bonus: float = 2.0
@export var crit_duration_bonus: float = 240.0
@export var max_duration: float = 1800.0
@export var max_hearts: float = 30.0
