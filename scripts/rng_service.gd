extends Node

## Single seeded RNG wrapper. All randomness in FORMATIONS routes through this service.

var _rng := RandomNumberGenerator.new()
var _current_seed: int = 0


func set_seed(value: int) -> void:
	_current_seed = value
	_rng.seed = value
	print("[RNG] Battle seed set: %d" % value)


func get_seed() -> int:
	return _current_seed


func randf_wobble(pct: float) -> float:
	return 1.0 + _rng.randf_range(-pct, pct)


func randf_range(a: float, b: float) -> float:
	return _rng.randf_range(a, b)


func randf() -> float:
	return _rng.randf()


func randi_range(a: int, b: int) -> int:
	return _rng.randi_range(a, b)
