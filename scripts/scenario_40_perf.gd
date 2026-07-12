class_name Scenario40Perf
extends Scenario01

const TRACE_PREFIX := "scenario_40_perf"
const GRID_COLS := 10
const GRID_ROWS := 2
const ROW_SPACING_M := 45.0
const COL_SPACING_M := 55.0

var _tick_times_ms: Array[float] = []
var _fps_samples: Array[float] = []
var _sample_accum: float = 0.0


func _spawn_units() -> void:
	var profile := UnitProfileLoader.load_profile("test_infantry")
	var px_per_meter := Constants.get_float("px_per_meter")
	var row_spacing_px := ROW_SPACING_M * px_per_meter
	var col_spacing_px := COL_SPACING_M * px_per_meter
	var start_distance_m := Constants.get_float("scenario_01_start_distance_m")
	var half_distance_px := start_distance_m * 0.5 * px_per_meter

	for row in GRID_ROWS:
		for col in GRID_COLS:
			var lane_y := (float(row) - 0.5) * row_spacing_px
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
	var elapsed_ms := float(Time.get_ticks_usec() - start_usec) / 1000.0
	_tick_times_ms.append(elapsed_ms)


func simulate_realtime_step(delta: float = -1.0) -> void:
	var step := delta if delta > 0.0 else CombatResolver.tick_interval()
	var frame_start := Time.get_ticks_usec()
	super.simulate_realtime_step(step)
	var frame_ms := float(Time.get_ticks_usec() - frame_start) / 1000.0
	_sample_accum += step
	if _sample_accum >= 1.0:
		_fps_samples.append(1000.0 / maxf(frame_ms, 0.001))
		_sample_accum = 0.0


func get_perf_stats() -> Dictionary:
	var tick_times := _tick_times_ms.duplicate()
	tick_times.sort()
	var fps_samples := _fps_samples.duplicate()
	var min_fps := 0.0
	var avg_fps := 0.0
	if not fps_samples.is_empty():
		min_fps = fps_samples.min()
		var fps_sum := 0.0
		for sample in fps_samples:
			fps_sum += sample
		avg_fps = fps_sum / float(fps_samples.size())

	var min_tick: float = tick_times[0] if not tick_times.is_empty() else 0.0
	var max_tick: float = tick_times[-1] if not tick_times.is_empty() else 0.0
	var tick_sum := 0.0
	for t in tick_times:
		tick_sum += t
	var avg_tick := tick_sum / float(tick_times.size()) if not tick_times.is_empty() else 0.0
	var p95_idx := int(floor(float(tick_times.size() - 1) * 0.95)) if not tick_times.is_empty() else 0
	var p95_tick: float = tick_times[p95_idx] if not tick_times.is_empty() else 0.0

	return {
		"min_fps": min_fps,
		"avg_fps": avg_fps,
		"fps_samples": fps_samples.size(),
		"min_tick_ms": min_tick,
		"avg_tick_ms": avg_tick,
		"max_tick_ms": max_tick,
		"p95_tick_ms": p95_tick,
		"tick_count": tick_times.size(),
	}
