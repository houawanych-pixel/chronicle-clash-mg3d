extends Resource
## CameraDirector modes: distance (m), height (m above feet), FOV, shoulder offset, pitch bias.

@export var modes: Dictionary = {
	"explore": {"dist": 4.2, "height": 1.6, "fov": 52.0, "shoulder": 0.45, "pitch": 0.0},
	"lock": {"dist": 3.6, "height": 1.5, "fov": 50.0, "shoulder": 0.3, "pitch": 0.0},
	"ads": {"dist": 1.6, "height": 1.65, "fov": 42.0, "shoulder": 0.55, "pitch": 0.0},
	"glide": {"dist": 6.0, "height": 1.2, "fov": 57.0, "shoulder": 0.0, "pitch": 0.12},
	"ride": {"dist": 6.5, "height": 1.9, "fov": 55.0, "shoulder": 0.0, "pitch": 0.05},
	"climb": {"dist": 3.0, "height": 1.4, "fov": 50.0, "shoulder": 0.2, "pitch": -0.25},
}
@export var blend_rate: float = 16.0          # 1 - exp(-rate t): ~98% in 0.25 s
@export var probe_radius: float = 0.25
@export var recenter_after_s: float = 1.2
