class_name ScenarioPerfScale
extends Scenario01

const TRACE_PREFIX := "scenario_perf_scale"

@export var unit_pairs: int = 20

var _tick_times_ms: Array[float] = []


func _spawn_units() -> void:
	var profile := UnitProfileLoader.load_profile("test_infantry")
	var px_per_meter := Constants.get_float("px_per_meter")
	var row_spacing_m := 45.0
	var col_spacing_m := 55.0
	var row_spacing_px := row_spacing_m * px_per_meter
	var col_spacing_px := col_spacing_m * px_per_meter
	var start_distance_m := Constants.get_float("scenario_01_start_distance_m")
	var half_distance_px := start_distance_m * 0.5 * px_per_meter
	var rows := 1 if unit_pairs <= 10 else 2
	var cols := int(ceil(float(unit_pairs) / float(rows)))

	for row in rows:
		for col in cols:
			if row * cols + col >= unit_pairs:
				break
			var lane_y := (float(row) - float(rows - 1) * 0.5) * row_spacing_px
			var offset_x := float(col) * col_spacing_px * 0.15

			var red: Unit = UNIT_SCENE.instantiate()
			add_child(red)
			var red_id := "red_%d_%d" % [row, col]
			red.configure(
				red_id,
				"red",
				profile,
				Vector2(-half_distance_px - offset_x, lane_y),
				Vector2.RIGHT,
			)
			red.set_march_to(Vector2(half_distance_px, lane_y))
			_units.append(red)

			var blue: Unit = UNIT_SCENE.instantiate()
			add_child(blue)
			var blue_id := "blue_%d_%d" % [row, col]
			blue.configure(
				blue_id,
				"blue",
				profile,
				Vector2(half_distance_px + offset_x, lane_y),
				Vector2.LEFT,
			)
			blue.set_march_to(Vector2(-half_distance_px, lane_y))
			_units.append(blue)

	for unit in _units:
		unit.set_render_camera(_camera)


func advance_one_tick() -> void:
	var start_usec := Time.get_ticks_usec()
	super.advance_one_tick()
	_tick_times_ms.append(float(Time.get_ticks_usec() - start_usec) / 1000.0)


func get_tick_perf_stats() -> Dictionary:
	var tick_times := _tick_times_ms.duplicate()
	tick_times.sort()
	if tick_times.is_empty():
		return {
			"unit_count": _units.size(),
			"min_tick_ms": 0.0,
			"avg_tick_ms": 0.0,
			"max_tick_ms": 0.0,
			"p95_tick_ms": 0.0,
			"tick_count": 0,
		}
	var tick_sum := 0.0
	for t in tick_times:
		tick_sum += t
	var p95_idx := int(floor(float(tick_times.size() - 1) * 0.95))
	return {
		"unit_count": _units.size(),
		"min_tick_ms": tick_times[0],
		"avg_tick_ms": tick_sum / float(tick_times.size()),
		"max_tick_ms": tick_times[-1],
		"p95_tick_ms": tick_times[p95_idx],
		"tick_count": tick_times.size(),
	}
