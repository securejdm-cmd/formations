class_name SimRng
extends RefCounted

var _rng := RandomNumberGenerator.new()
var _seed: int = 0


func set_seed(value: int) -> void:
	_seed = value
	_rng.seed = value


func get_seed() -> int:
	return _seed


func capture_state() -> int:
	return _rng.state


func restore_state(state: int) -> void:
	_rng.state = state


func randf_wobble(pct: float) -> float:
	return 1.0 + _rng.randf_range(-pct, pct)


func randf_range(a: float, b: float) -> float:
	return _rng.randf_range(a, b)


func randf() -> float:
	return _rng.randf()


func randi_range(a: int, b: int) -> int:
	return _rng.randi_range(a, b)


func randn() -> float:
	var u1: float = maxf(_rng.randf(), 1e-12)
	var u2: float = _rng.randf()
	return sqrt(-2.0 * log(u1)) * cos(TAU * u2)


func roll_quality_of_day(sigma: float, enabled: bool) -> float:
	if not enabled or sigma <= 0.0:
		return 1.0
	return 1.0 + sigma * randn()
