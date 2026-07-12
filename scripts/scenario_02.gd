class_name Scenario02
extends Scenario01

const TRACE_PREFIX := "scenario_02"

var _contact_line_x_at_contact_m: float = 0.0
var _contact_line_x_at_rout_m: float = 0.0
var _strength_at_rout: float = -1.0
var _routed_unit_id: String = ""


func _ready() -> void:
	_setup_ground()
	_battle_seed = _seed_override if _seed_override >= 0 else Constants.get_int("scenario_01_battle_seed")
	RNG.set_seed(_battle_seed)
	print("[Scenario 02] Battle seed: %d" % _battle_seed)

	_spawn_units()
	_debug_overlay.setup_for_scenario(_units, _camera, _stat_card)
	_stat_card.setup(_camera)
	if not headless_mode:
		_results_overlay.skip_pressed.connect(_on_skip_epilogue)
		_results_overlay.watch_pressed.connect(_on_watch_epilogue)
	else:
		_results_overlay.hide_all()

	if auto_run:
		_battle_start_time_msec = Time.get_ticks_msec()
		_write_trace_header()
		_log_trace_row()


func _spawn_units() -> void:
	var red_profile := UnitProfileLoader.load_profile("test_infantry_push60")
	var blue_profile := UnitProfileLoader.load_profile("test_infantry_push40")
	var start_distance_m := Constants.get_float("scenario_01_start_distance_m")
	var half_distance_px := start_distance_m * 0.5 * Constants.get_float("px_per_meter")

	var red: Unit = UNIT_SCENE.instantiate()
	add_child(red)
	red.configure("red_1", "red", red_profile, Vector2(-half_distance_px, 0.0), Vector2.RIGHT)
	red.set_march_to(Vector2(half_distance_px, 0.0))
	_units.append(red)

	var blue: Unit = UNIT_SCENE.instantiate()
	add_child(blue)
	blue.configure("blue_1", "blue", blue_profile, Vector2(half_distance_px, 0.0), Vector2.LEFT)
	blue.set_march_to(Vector2(-half_distance_px, 0.0))
	_units.append(blue)


func _contact_line_x_m() -> float:
	var px_per_meter := Constants.get_float("px_per_meter")
	var front_sum_px := 0.0
	var count := 0
	for unit in _units:
		if unit.get_state() == Unit.State.REMOVED:
			continue
		var half_depth_px := unit.effective_depth_m() * 0.5 * px_per_meter
		front_sum_px += unit.position.x + unit.facing.x * half_depth_px
		count += 1
	if count == 0:
		return 0.0
	return front_sum_px / float(count) / px_per_meter


func _on_first_contact() -> void:
	if _first_contact_tick >= 0:
		return
	_first_contact_tick = _sim_tick_count
	_contact_line_x_at_contact_m = _contact_line_x_m()


func _on_first_rout() -> void:
	if _first_rout_tick >= 0:
		return
	for unit in _units:
		if unit.get_state() == Unit.State.ROUTING:
			_strength_at_rout = unit.strength
			_routed_unit_id = unit.unit_id
			_contact_line_x_at_rout_m = _contact_line_x_m()
			break
	_first_rout_tick = _sim_tick_count


func _write_trace_file() -> void:
	var dir := DirAccess.open("res://tests")
	if dir == null:
		push_error("Scenario 02: cannot access tests directory")
		return

	if not dir.dir_exists("traces"):
		dir.make_dir("traces")

	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("Scenario 02: cannot write trace file %s" % file_path)
		return

	for line in _trace_lines:
		file.store_line(line)

	print("[Scenario 02] Trace written: %s" % file_path)


func _print_summary() -> void:
	var phases := _phase_durations_sec()
	var displacement_m := get_ground_displacement_m()
	if _winner == null:
		print(
			"[Scenario 02] SUMMARY | winner=none | march=%.1fs | combat=%.1fs | flee=%.1fs"
			% [phases.march_sec, phases.combat_sec, phases.flee_sec]
		)
		return

	print(
		"[Scenario 02] SUMMARY | winner=%s | march=%.1fs | combat=%.1fs | flee=%.1fs | routed=%s | strength_at_rout=%.2f | ground_displacement_m=%.2f"
		% [
			_winner.unit_id,
			phases.march_sec,
			phases.combat_sec,
			phases.flee_sec,
			_routed_unit_id,
			_strength_at_rout,
			displacement_m,
		]
	)


func get_strength_at_rout() -> float:
	return _strength_at_rout


func get_routed_unit_id() -> String:
	return _routed_unit_id


func get_ground_displacement_m() -> float:
	return absf(_contact_line_x_at_rout_m - _contact_line_x_at_contact_m)


func get_ground_displacement_signed_m() -> float:
	return _contact_line_x_at_rout_m - _contact_line_x_at_contact_m
