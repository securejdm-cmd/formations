class_name SimRngBridge
extends RefCounted

## Thread-local RNG override for worker sim (WO-011). Falls back to autoload RNG on main/fast path.

const SimRng := preload("res://scripts/sim/sim_rng.gd")

static var _worker_rng: SimRng = null


static func set_worker_rng(rng: SimRng) -> void:
	_worker_rng = rng


static func clear_worker_rng() -> void:
	_worker_rng = null


static func randf_wobble(pct: float) -> float:
	if _worker_rng != null:
		return _worker_rng.randf_wobble(pct)
	return RNG.randf_wobble(pct)
