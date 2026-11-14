extends Resource
## Tuning for the Living Village family module. Every boundary, chance,
## duration and budget lives here so designers can change it without code.
## Real time (unix seconds) drives aging and pregnancy. The village day/night
## clock (1 real hour = 1 game day) only drives daily routines.

## Life stages in order, and the real day (age in whole days since birth)
## each one starts on. Default: 0-7 newborn, 8-14 crawling infant,
## 15-21 early walker, 22-30 toddler, 31-45 child, 46-59 adolescent, 60+ adult.
@export var stage_names: PackedStringArray = PackedStringArray(["newborn", "crawling_infant", "early_walker", "toddler", "child", "adolescent", "adult"])
@export var stage_start_days: PackedInt32Array = PackedInt32Array([0, 8, 15, 22, 31, 46, 60])
## Placeholder body height per stage (metres) until real child models exist.
@export var stage_heights: PackedFloat32Array = PackedFloat32Array([0.5, 0.7, 0.8, 0.92, 1.2, 1.55, 1.75])
@export var stage_speeds: PackedFloat32Array = PackedFloat32Array([0.0, 0.35, 0.55, 0.9, 1.5, 1.6, 1.6])
## Length of one "real day" in seconds. Only change this for a debug build.
@export var seconds_per_day: float = 86400.0

## Romance and birth.
@export var allow_pregnancy: bool = true
@export var pregnancy_chance: float = 0.35          # per completed home visit
@export var pregnancy_days: float = 3.0             # real days from conception to birth
@export var birth_cooldown_days: float = 7.0        # real days before a parent can conceive again
@export var visit_cooldown_seconds: float = 3600.0  # one village day between home visits
@export var visit_game_minutes: float = 40.0        # how long the couple stays home (game minutes)
@export var privacy_fade_seconds: float = 0.8
@export var max_population: int = 40                # living NPCs + active pregnancies, per world
@export var max_children_per_family: int = 4

## Home audio while the couple is inside: soft, muffled, fades with distance.
## Empty until a licensed/original clip exists (see docs/FAMILY.md, missing assets).
@export var home_audio_path: String = ""
@export var home_audio_db: float = -16.0
@export var home_audio_max_distance: float = 12.0
@export var home_audio_cutoff_hz: float = 700.0

## Jobs nobody under adult may ever hold.
@export var combat_jobs: PackedStringArray = PackedStringArray(["guard", "soldier", "knight", "hunter", "mercenary", "recruit"])

## Echo Vision context limits.
@export var memory_max_entries: int = 8
@export var memory_entry_chars: int = 120
@export var memory_summary_chars: int = 480
@export var chat_min_stage: String = "toddler"      # younger children don't open a chat

## Simulation levels and budgets.
@export var active_radius: float = 30.0             # metres from the hero: full simulation
@export var background_tick_seconds: float = 30.0   # how often off-screen records are advanced
@export var max_spawned_children: int = 12          # child bodies alive in one block at once
@export var ai_calls_per_minute: int = 6            # chat requests allowed per real minute
@export var applied_event_keep: int = 5000          # idempotency ids remembered

func stage_index(stage: String) -> int:
	return Array(stage_names).find(stage)

func is_adult(stage: String) -> bool:
	return stage == "adult"
