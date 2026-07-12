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
