class_name Scenario03
extends Scenario01

const TRACE_PREFIX := "scenario_03"
const FLANK_DELAY_SEC := 10.0

var _red_b: Unit = null
var _blue_a: Unit = null
var _flank_released: bool = false
var _blue_a_strength_at_rout: float = -1.0


func _ready() -> void:
	_setup_ground()
	_battle_seed = _seed_override if _seed_override >= 0 else Constants.get_int("scenario_01_battle_seed")
	RNG.set_seed(_battle_seed)
	print("[Scenario 03] Battle seed: %d" % _battle_seed)

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
	var profile := UnitProfileLoader.load_profile("test_infantry")
	var start_distance_m := Constants.get_float("scenario_01_start_distance_m")
	var half_distance_px := start_distance_m * 0.5 * Constants.get_float("px_per_meter")
	var px_per_meter := Constants.get_float("px_per_meter")
	var flank_standoff_m := 8.0
	var flank_standoff_px := flank_standoff_m * px_per_meter

	var red_a: Unit = UNIT_SCENE.instantiate()
	add_child(red_a)
	red_a.configure("red_a", "red", profile, Vector2(-half_distance_px, 0.0), Vector2.RIGHT)
	red_a.set_march_to(Vector2(half_distance_px, 0.0))
	_units.append(red_a)

	_blue_a = UNIT_SCENE.instantiate()
	add_child(_blue_a)
	_blue_a.configure("blue_a", "blue", profile, Vector2(half_distance_px, 0.0), Vector2.LEFT)
	_blue_a.set_march_to(Vector2(-half_distance_px, 0.0))
	_units.append(_blue_a)

	var right := FormationGeometry.right_vector(_blue_a.facing)
	var half_frontage_px := _blue_a.effective_frontage_m() * 0.5 * px_per_meter
	var left_edge_center := _blue_a.position + right * (-half_frontage_px)
	var spawn_pos := left_edge_center + (-right) * flank_standoff_px

	_red_b = UNIT_SCENE.instantiate()
	add_child(_red_b)
	_red_b.configure("red_b", "red", profile, spawn_pos, right.normalized())
	_red_b.current_order = Unit.Order.HOLD
	_units.append(_red_b)


func _update_movement(delta: float) -> void:
	_maybe_release_flank()
	super._update_movement(delta)


func _maybe_release_flank() -> void:
	if _flank_released or _red_b == null or _blue_a == null:
		return
	if _first_contact_tick < 0:
		return
	var release_tick := _first_contact_tick + int(FLANK_DELAY_SEC / CombatResolver.tick_interval())
	if _sim_tick_count < release_tick:
		return

	var px_per_meter := Constants.get_float("px_per_meter")
	var half_frontage_px := _blue_a.effective_frontage_m() * 0.5 * px_per_meter
	_red_b.position = _blue_a.position + Vector2(0.0, half_frontage_px * 0.5)
	_red_b.facing = Vector2.UP
	_red_b.rotation = _red_b.facing.angle()
	_red_b.add_contact_partner(_blue_a)
	_blue_a.add_contact_partner(_red_b)
	_flank_released = true


func _on_first_rout() -> void:
	if _first_rout_tick >= 0:
		return
	for unit in _units:
		if unit.get_state() == Unit.State.ROUTING:
			if unit.unit_id == "blue_a":
				_blue_a_strength_at_rout = unit.strength
			_first_rout_tick = _sim_tick_count
			break


func _write_trace_file() -> void:
	var dir := DirAccess.open("res://tests")
	if dir == null:
		return
	if not dir.dir_exists("traces"):
		dir.make_dir("traces")
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
	print("[Scenario 03] Trace written: %s" % file_path)


func _print_summary() -> void:
	var phases := _phase_durations_sec()
	var drains: Dictionary = {}
	if _blue_a != null:
		drains = _blue_a.get_edge_cohesion_drain_totals()
	print(
		"[Scenario 03] SUMMARY | winner=%s | combat=%.1fs | blue_a_strength_at_rout=%.2f | edge_drains front=%.2f left=%.2f right=%.2f rear=%.2f"
		% [
			_winner.unit_id if _winner else "none",
			phases.combat_sec,
			_blue_a_strength_at_rout,
			drains.get("front", 0.0),
			drains.get("left", 0.0),
			drains.get("right", 0.0),
			drains.get("rear", 0.0),
		]
	)


func get_blue_a_strength_at_rout() -> float:
	return _blue_a_strength_at_rout


func get_blue_a_edge_drains() -> Dictionary:
	if _blue_a == null:
		return {}
	return _blue_a.get_edge_cohesion_drain_totals()
