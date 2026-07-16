class_name TickProfiler
extends RefCounted

## Optional tick instrumentation for WO-010b / WO-026 performance work.

static var enabled: bool = false
static var _section_usec: Dictionary = {}
static var _tick_count: int = 0
static var classifier_calls: int = 0
static var adhesion_classifier_calls: int = 0
static var binary_search_iterations: int = 0
static var adhesion_pairs_processed: int = 0
static var _classification_usec: int = 0
static var adhesion_context: bool = false

## WO-026: ephemeral probe — omit charge_commit_range from march enemy radius.
static var debug_disable_charge_commit_radius: bool = false

## WO-026 movement micro-profile counters (accumulate while enabled).
static var move_enemy_query_calls: int = 0
static var move_enemy_query_usec: int = 0
static var move_enemy_query_cells_scanned: int = 0
static var move_enemy_query_candidates: int = 0
static var move_radius_calc_calls: int = 0
static var move_radius_calc_usec: int = 0
static var move_max_scan_calls: int = 0
static var move_max_scan_usec: int = 0
static var move_substep_iterations: int = 0
static var move_substep_unit_ticks: int = 0
static var move_charge_commit_calls: int = 0
static var move_charge_commit_usec: int = 0
static var move_gravity_calls: int = 0
static var move_gravity_usec: int = 0
static var move_auto_rotation_calls: int = 0
static var move_auto_rotation_usec: int = 0
static var move_position_integrate_calls: int = 0
static var move_position_integrate_usec: int = 0
static var move_contact_check_calls: int = 0
static var move_contact_check_usec: int = 0
static var move_alloc_arrays: int = 0
static var move_alloc_dicts: int = 0


static func reset() -> void:
	_section_usec.clear()
	_tick_count = 0
	classifier_calls = 0
	adhesion_classifier_calls = 0
	binary_search_iterations = 0
	adhesion_pairs_processed = 0
	_classification_usec = 0
	move_enemy_query_calls = 0
	move_enemy_query_usec = 0
	move_enemy_query_cells_scanned = 0
	move_enemy_query_candidates = 0
	move_radius_calc_calls = 0
	move_radius_calc_usec = 0
	move_max_scan_calls = 0
	move_max_scan_usec = 0
	move_substep_iterations = 0
	move_substep_unit_ticks = 0
	move_charge_commit_calls = 0
	move_charge_commit_usec = 0
	move_gravity_calls = 0
	move_gravity_usec = 0
	move_auto_rotation_calls = 0
	move_auto_rotation_usec = 0
	move_position_integrate_calls = 0
	move_position_integrate_usec = 0
	move_contact_check_calls = 0
	move_contact_check_usec = 0
	move_alloc_arrays = 0
	move_alloc_dicts = 0


static func begin_section(name: String) -> int:
	if not enabled:
		return -1
	return Time.get_ticks_usec()


static func end_section(name: String, start_usec: int) -> void:
	if not enabled or start_usec < 0:
		return
	var elapsed := Time.get_ticks_usec() - start_usec
	_section_usec[name] = int(_section_usec.get(name, 0)) + elapsed


static func on_tick_complete() -> void:
	if not enabled:
		return
	_tick_count += 1


static func record_classifier(from_adhesion: bool = false) -> void:
	if not enabled:
		return
	classifier_calls += 1
	if from_adhesion or adhesion_context:
		adhesion_classifier_calls += 1


static func record_binary_search_step() -> void:
	if not enabled:
		return
	binary_search_iterations += 1


static func record_adhesion_pair() -> void:
	if not enabled:
		return
	adhesion_pairs_processed += 1


static func begin_classification() -> int:
	if not enabled:
		return 0
	return Time.get_ticks_usec()


static func end_classification(start_usec: int) -> void:
	if not enabled:
		return
	_classification_usec += Time.get_ticks_usec() - start_usec


static func _per_tick(n: int, ticks: int) -> float:
	return float(n) / float(ticks)


static func _ms_per_tick(usec: int, ticks: int) -> float:
	return float(usec) / float(ticks) / 1000.0


static func _mean_usec(usec: int, calls: int) -> float:
	if calls <= 0:
		return 0.0
	return float(usec) / float(calls)


static func get_report(unit_count: int) -> Dictionary:
	var ticks := maxi(_tick_count, 1)
	var sections_ms: Dictionary = {}
	var total_usec := 0
	for key in _section_usec.keys():
		var usec: int = int(_section_usec[key])
		total_usec += usec
		sections_ms[key] = float(usec) / float(ticks) / 1000.0
	sections_ms["total"] = float(total_usec) / float(ticks) / 1000.0
	sections_ms["contact_classification"] = float(_classification_usec) / float(ticks) / 1000.0
	var movement_ms := float(sections_ms.get("movement", 0.0))
	var enemy_q_ms := _ms_per_tick(move_enemy_query_usec, ticks)
	return {
		"unit_count": unit_count,
		"tick_samples": ticks,
		"sections_ms": sections_ms,
		"classifier_calls_per_tick": float(classifier_calls) / float(ticks),
		"adhesion_classifier_calls_per_tick": float(adhesion_classifier_calls) / float(ticks),
		"binary_search_iterations_per_tick": float(binary_search_iterations) / float(ticks),
		"adhesion_pairs_per_tick": float(adhesion_pairs_processed) / float(ticks),
		"movement_micro": {
			"enemy_query_calls_per_tick": _per_tick(move_enemy_query_calls, ticks),
			"enemy_query_ms_per_tick": enemy_q_ms,
			"enemy_query_mean_usec": _mean_usec(move_enemy_query_usec, move_enemy_query_calls),
			"enemy_query_cells_scanned_per_tick": _per_tick(move_enemy_query_cells_scanned, ticks),
			"enemy_query_cells_per_call": (
				float(move_enemy_query_cells_scanned) / float(maxi(move_enemy_query_calls, 1))
			),
			"enemy_query_candidates_per_tick": _per_tick(move_enemy_query_candidates, ticks),
			"enemy_query_frac_of_movement": (
				enemy_q_ms / movement_ms if movement_ms > 0.0 else 0.0
			),
			"radius_calc_calls_per_tick": _per_tick(move_radius_calc_calls, ticks),
			"radius_calc_ms_per_tick": _ms_per_tick(move_radius_calc_usec, ticks),
			"max_scan_calls_per_tick": _per_tick(move_max_scan_calls, ticks),
			"max_scan_ms_per_tick": _ms_per_tick(move_max_scan_usec, ticks),
			"substep_iterations_per_tick": _per_tick(move_substep_iterations, ticks),
			"substep_unit_ticks_per_tick": _per_tick(move_substep_unit_ticks, ticks),
			"charge_commit_calls_per_tick": _per_tick(move_charge_commit_calls, ticks),
			"charge_commit_ms_per_tick": _ms_per_tick(move_charge_commit_usec, ticks),
			"charge_commit_mean_usec": _mean_usec(move_charge_commit_usec, move_charge_commit_calls),
			"gravity_calls_per_tick": _per_tick(move_gravity_calls, ticks),
			"gravity_ms_per_tick": _ms_per_tick(move_gravity_usec, ticks),
			"gravity_mean_usec": _mean_usec(move_gravity_usec, move_gravity_calls),
			"auto_rotation_calls_per_tick": _per_tick(move_auto_rotation_calls, ticks),
			"auto_rotation_ms_per_tick": _ms_per_tick(move_auto_rotation_usec, ticks),
			"position_integrate_calls_per_tick": _per_tick(move_position_integrate_calls, ticks),
			"position_integrate_ms_per_tick": _ms_per_tick(move_position_integrate_usec, ticks),
			"contact_from_movement_calls_per_tick": _per_tick(move_contact_check_calls, ticks),
			"contact_from_movement_ms_per_tick": _ms_per_tick(move_contact_check_usec, ticks),
			"contact_from_movement_mean_usec": _mean_usec(
				move_contact_check_usec, move_contact_check_calls
			),
			"alloc_arrays_per_tick": _per_tick(move_alloc_arrays, ticks),
			"alloc_dicts_per_tick": _per_tick(move_alloc_dicts, ticks),
		},
	}
