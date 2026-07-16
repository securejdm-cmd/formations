extends Node

## Single seeded RNG wrapper. All randomness in FORMATIONS routes through this service.

var _rng := RandomNumberGenerator.new()
var _current_seed: int = 0


func set_seed(value: int) -> void:
	_current_seed = value
	_rng.seed = value
	if not bool(get_meta("suppress_seed_print", false)):
		print("[RNG] Battle seed set: %d" % value)


func set_suppress_seed_print(quiet: bool) -> void:
	set_meta("suppress_seed_print", quiet)


func get_seed() -> int:
	return _current_seed


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


## Standard normal via Box-Muller (two draws from the battle stream).
func randn() -> float:
	var u1: float = maxf(_rng.randf(), 1e-12)
	var u2: float = _rng.randf()
	return sqrt(-2.0 * log(u1)) * cos(TAU * u2)


## Persistent "quality of the day" multiplier ~ N(1, sigma). Disabled → 1.0, no draws.
func roll_quality_of_day(sigma: float, enabled: bool) -> float:
	if not enabled or sigma <= 0.0:
		return 1.0
	return 1.0 + sigma * randn()
