extends Node
## Autoload StaminaPool: one stamina meter for the CC survival systems (P1 movement will
## spend from it). Regen starts after a short rest; at zero you are exhausted until it
## refills to recover_at.

signal changed(value: float, max_value: float)
signal exhausted
signal recovered

var max_value: float = 100.0
var value: float = 100.0
var regen_per_sec: float = 28.0
var regen_delay: float = 0.9
var recover_at: float = 30.0
var is_exhausted: bool = false
var _wait: float = 0.0

func _process(dt: float) -> void:
	if _wait > 0.0:
		_wait -= dt
		return
	if value < max_value:
		value = minf(max_value, value + regen_per_sec * dt)
		if is_exhausted and value >= recover_at:
			is_exhausted = false
			recovered.emit()
		changed.emit(value, max_value)

## Spend some stamina. Returns false (and spends nothing) when exhausted.
func spend(amount: float) -> bool:
	if is_exhausted or amount <= 0.0:
		return not is_exhausted
	value = maxf(0.0, value - amount)
	_wait = regen_delay
	if value <= 0.0:
		is_exhausted = true
		exhausted.emit()
	changed.emit(value, max_value)
	return true

func refill() -> void:
	value = max_value
	is_exhausted = false
	changed.emit(value, max_value)
