extends Node
## Autoload TimeDilation: combat slow-motion (perfect dodge -> flurry). Combat actors scale
## their own time by scale(); the player can ask for a lighter slow-down on himself.

signal changed(scale: float)

var world_scale: float = 1.0
var _left: float = 0.0       # real seconds left

func _process(dt: float) -> void:
	if _left > 0.0:
		_left -= dt
		if _left <= 0.0:
			release()

## Slow the world to s for real_seconds.
func slow(s: float, real_seconds: float) -> void:
	world_scale = s
	_left = real_seconds
	changed.emit(world_scale)

func release() -> void:
	_left = 0.0
	world_scale = 1.0
	changed.emit(world_scale)

func scale(is_player: bool = false) -> float:
	if is_player and world_scale < 1.0:
		return lerpf(world_scale, 1.0, 0.75)    # the player is slowed far less
	return world_scale

func active() -> bool:
	return world_scale < 1.0
