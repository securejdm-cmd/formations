class_name Scenario03
extends Scenario01

const TRACE_PREFIX := "scenario_03"
const FLANK_DELAY_SEC := 10.0
const FLANK_CORRECTION_EAST_DEPTH_SCALE := 0.55

var _red_a: Unit = null
var _red_b: Unit = null
var _blue_a: Unit = null
var _flank_released: bool = false
var _flank_release_aborted: bool = false
var _flank_overlap_corrected: bool = false
var _blue_a_strength_at_rout: float = -1.0
var _flank_candidate_scales: Array[Vector2] = []


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
	var half_frontage_px := float(profile.get("formation_frontage_m", 40.0)) * 0.5 * px_per_meter

	var red_a: Unit = UNIT_SCENE.instantiate()
	add_child(red_a)
	red_a.configure("red_a", "red", profile, Vector2(-half_distance_px, 0.0), Vector2.RIGHT)
	red_a.set_march_to(Vector2(half_distance_px, 0.0))
	_units.append(red_a)
	_red_a = red_a

	_blue_a = UNIT_SCENE.instantiate()
	add_child(_blue_a)
	_blue_a.configure("blue_a", "blue", profile, Vector2(half_distance_px, 0.0), Vector2.LEFT)
	_blue_a.set_march_to(Vector2(-half_distance_px, 0.0))
	_units.append(_blue_a)

	# Hold red_b west/south of the march lane until scripted flank release.
	var reserve_pos := Vector2(
		-half_distance_px * 1.5,
		float(profile.get("formation_frontage_m", 40.0)) * px_per_meter * 1.5,
	)

	_red_b = UNIT_SCENE.instantiate()
	add_child(_red_b)
	_red_b.configure("red_b", "red", profile, reserve_pos, Vector2.LEFT)
	_red_b.current_order = Unit.Order.HOLD
	_units.append(_red_b)


func _update_movement(delta: float) -> void:
	super._update_movement(delta)


func advance_one_tick() -> void:
	if _battle_over:
		return

	var tick_interval := CombatResolver.tick_interval()
	_sim_tick_count += 1
	_update_movement(tick_interval)
	_combat_tick()
	_maybe_release_flank()
	_maybe_correct_flank_overlap()
	_assert_no_overlaps()
	_track_rout_state()
	_update_victory_state(tick_interval)
	var ticks_per_sec := int(Constants.get_float("tick_rate_per_sec"))
	if _sim_tick_count % ticks_per_sec == 0:
		_log_trace_row()
	_check_epilogue_end()


func _assert_no_overlaps() -> void:
	# S3 addendum: explicitly assert allied pairs after combat shifts.
	if _red_a != null and _red_b != null:
		if (
			_red_a.get_state() != Unit.State.REMOVED
			and _red_b.get_state() != Unit.State.REMOVED
			and CombatResolver.units_overlap(_red_a, _red_b)
		):
			_overlap_assertion_failed = true
			push_error(
				"Overlap detected at tick %d between %s and %s (allied)"
				% [_sim_tick_count, _red_a.unit_id, _red_b.unit_id]
			)


func _maybe_release_flank() -> void:
	if _flank_released or _flank_release_aborted or _red_b == null or _blue_a == null or _red_a == null:
		return
	if _first_contact_tick < 0:
		return
	var release_tick := _first_contact_tick + int(FLANK_DELAY_SEC / CombatResolver.tick_interval())
	if _sim_tick_count < release_tick:
		return

	var px_per_meter := Constants.get_float("px_per_meter")
	var half_depth_px := _blue_a.effective_depth_m() * 0.5 * px_per_meter
	var half_frontage_px := _blue_a.effective_frontage_m() * 0.5 * px_per_meter
	var reserve_pos := _red_b.position
	var reserve_facing := _red_b.facing

	var default_scales: Array[Vector2] = [
		Vector2(2.10, 0.58), Vector2(2.35, 0.54), Vector2(2.60, 0.62),
		Vector2(2.80, 0.66), Vector2(3.00, 0.70), Vector2(3.20, 0.80),
		Vector2(3.50, 0.58),
	]
	var scales: Array[Vector2] = _flank_candidate_scales if not _flank_candidate_scales.is_empty() else default_scales
	var candidate_offsets: Array[Vector2] = []
	for scale in scales:
		candidate_offsets.append(Vector2(half_depth_px * scale.x, half_frontage_px * scale.y))
	var chosen_offset := Vector2.ZERO
	for offset in candidate_offsets:
		_red_b.position = _blue_a.position + offset
		_red_b.facing = (_blue_a.position - _red_b.position).normalized()
		if _red_b.facing.length_squared() <= 0.0001:
			_red_b.facing = Vector2.UP
		_red_b.rotation = _red_b.facing.angle()
		if CombatResolver.units_overlap(_red_b, _red_a):
			continue
		if not EdgeContact.units_have_contact(_red_b, _blue_a):
			continue
		chosen_offset = offset
		break

	if chosen_offset == Vector2.ZERO:
		_red_b.position = reserve_pos
		_red_b.facing = reserve_facing
		_red_b.rotation = _red_b.facing.angle()
		_flank_release_aborted = true
		push_error(
			"ESCALATE WO-008 S3: no scripted flank position avoids allied overlap with red_a"
		)
		return

	_red_b.position = _blue_a.position + chosen_offset
	_red_b.facing = (_blue_a.position - _red_b.position).normalized()
	_red_b.rotation = _red_b.facing.angle()
	_red_b.add_contact_partner(_blue_a)
	_blue_a.add_contact_partner(_red_b)
	_flank_released = true


func _maybe_correct_flank_overlap() -> void:
	if (
		not _flank_released
		or _flank_overlap_corrected
		or _flank_release_aborted
		or _red_b == null
		or _red_a == null
		or _blue_a == null
	):
		return
	if not CombatResolver.units_overlap(_red_b, _red_a):
		return

	var px_per_meter := Constants.get_float("px_per_meter")
	var correction := Vector2(
		_red_a.effective_depth_m() * px_per_meter * FLANK_CORRECTION_EAST_DEPTH_SCALE,
		0.0,
	)
	_red_b.position += correction
	_red_b.facing = (_blue_a.position - _red_b.position).normalized()
	if _red_b.facing.length_squared() <= 0.0001:
		_red_b.facing = Vector2.UP
	_red_b.rotation = _red_b.facing.angle()
	_flank_overlap_corrected = true

	if CombatResolver.units_overlap(_red_b, _red_a):
		push_error(
			"ESCALATE WO-008 S3: scripted flank correction still overlaps red_a"
		)
		return
	if not EdgeContact.units_have_contact(_red_b, _blue_a):
		push_error(
			"ESCALATE WO-008 S3: scripted flank correction broke blue_a contact"
		)


func _track_rout_state() -> void:
	if _blue_a != null and _red_b != null:
		if _blue_a.get_state() == Unit.State.ROUTING:
			if _red_b.has_contact_with(_blue_a):
				_red_b.remove_contact_partner(_blue_a)
				_blue_a.remove_contact_partner(_red_b)
				_red_b.clear_bump_state()
			_return_red_b_to_reserve()
	super._track_rout_state()


func _return_red_b_to_reserve() -> void:
	if _red_b == null or not _flank_released:
		return
	var profile := UnitProfileLoader.load_profile("test_infantry")
	var start_distance_m := Constants.get_float("scenario_01_start_distance_m")
	var half_distance_px := start_distance_m * 0.5 * Constants.get_float("px_per_meter")
	var px_per_meter := Constants.get_float("px_per_meter")
	var reserve_pos := Vector2(
		-half_distance_px * 1.5,
		float(profile.get("formation_frontage_m", 40.0)) * px_per_meter * 1.5,
	)
	_red_b.position = reserve_pos
	_red_b.facing = Vector2.LEFT
	_red_b.rotation = _red_b.facing.angle()
	_red_b.current_order = Unit.Order.HOLD
	if _red_a != null and CombatResolver.units_overlap(_red_b, _red_a):
		push_error(
			"ESCALATE WO-008 S3: red_b reserve reposition overlaps red_a after blue rout"
		)


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


func set_flank_candidate_scales(scales: Array[Vector2]) -> void:
	_flank_candidate_scales = scales


func get_blue_a_strength_at_rout() -> float:
	return _blue_a_strength_at_rout


func get_blue_a_edge_drains() -> Dictionary:
	if _blue_a == null:
		return {}
	return _blue_a.get_edge_cohesion_drain_totals()
