class_name SpatialGrid
extends RefCounted

## Uniform spatial grid for deterministic neighbor-limited pair queries.
## Logic is mirrored in Scenario01 for runtime; this class supports direct unit tests.

var _cell_size_px: float = 1.0
var _cells: Dictionary = {}


func rebuild(units: Array, cell_size_m: float, px_per_meter: float) -> void:
	_cell_size_px = maxf(cell_size_m * px_per_meter, 1.0)
	_cells.clear()
	for unit in units:
		if unit == null or _is_inactive_unit(unit):
			continue
		var cell: Vector2i = _cell_key(unit.position)
		if not _cells.has(cell):
			_cells[cell] = []
		(_cells[cell] as Array).append(unit)


func get_neighbor_units(unit) -> Array:
	var origin: Vector2i = _cell_key(unit.position)
	var found: Array = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var key := Vector2i(origin.x + dx, origin.y + dy)
			if not _cells.has(key):
				continue
			for other in _cells[key]:
				if other != unit:
					found.append(other)
	return found


func sorted_pair_candidates(units: Array, cell_size_m: float, px_per_meter: float) -> Array:
	rebuild(units, cell_size_m, px_per_meter)
	var seen: Dictionary = {}
	var pairs: Array = []
	for unit in units:
		if unit == null or _is_inactive_unit(unit):
			continue
		for other in get_neighbor_units(unit):
			if other == null or _is_inactive_unit(other):
				continue
			var key := _pair_key(unit, other)
			if seen.has(key):
				continue
			seen[key] = true
			pairs.append([unit, other])
	pairs.sort_custom(func(a, b) -> bool:
		return _pair_key(a[0], a[1]) < _pair_key(b[0], b[1])
	)
	return pairs


func _is_inactive_unit(unit) -> bool:
	var state_name: String = unit.get_state_name()
	return state_name == "removed" or state_name == "routing"


func _pair_key(unit_a, unit_b) -> String:
	if unit_a.unit_id < unit_b.unit_id:
		return unit_a.unit_id + ":" + unit_b.unit_id
	return unit_b.unit_id + ":" + unit_a.unit_id


func _cell_key(pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(pos.x / _cell_size_px)),
		int(floor(pos.y / _cell_size_px)),
	)
