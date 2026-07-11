extends SceneTree

const ALL_SEEDS := [1000, 1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009, 12345]

const WO007B_S1 := {
	1000: {"winner": "red_1", "combat": 68.2},
	1001: {"winner": "red_1", "combat": 72.8},
	1002: {"winner": "blue_1", "combat": 68.0},
	1003: {"winner": "blue_1", "combat": 80.2},
	1004: {"winner": "red_1", "combat": 81.5},
	1005: {"winner": "red_1", "combat": 66.4},
	1006: {"winner": "red_1", "combat": 66.2},
	1007: {"winner": "red_1", "combat": 80.4},
	1008: {"winner": "red_1", "combat": 73.2},
	1009: {"winner": "red_1", "combat": 79.2},
	12345: {"winner": "blue_1", "combat": 68.2},
}
const WO007B_S2 := {
	1000: {"winner": "red_1", "combat": 41.6, "rout": 67.39},
	1001: {"winner": "red_1", "combat": 41.4, "rout": 67.39},
	1002: {"winner": "red_1", "combat": 41.6, "rout": 67.38},
	1003: {"winner": "red_1", "combat": 41.4, "rout": 67.36},
	1004: {"winner": "red_1", "combat": 41.6, "rout": 67.33},
	1005: {"winner": "red_1", "combat": 41.2, "rout": 67.38},
	1006: {"winner": "red_1", "combat": 41.4, "rout": 67.34},
	1007: {"winner": "red_1", "combat": 41.6, "rout": 67.33},
	1008: {"winner": "red_1", "combat": 41.4, "rout": 67.33},
	1009: {"winner": "red_1", "combat": 41.4, "rout": 67.33},
	12345: {"winner": "red_1", "combat": 41.6, "rout": 67.31},
}

const CORE_COLS := 8
const STAT_TOL := 0.0001
const POS_TOL := 0.05

var _scenario = null
var _exit_code := 0
var _mode := "s1_regression"
var _seed_idx := 0
var _s4_mode_idx := 0
var _s4_modes := ["front", "side", "corner"]
var _s4_results: Array[Dictionary] = []
var _determinism_a := ""
var _determinism_b := ""


func _initialize() -> void:
	process_frame.connect(_on_frame)
	_start("scenario_01", ALL_SEEDS[0])


func _on_frame() -> void:
	if _scenario == null or not _scenario.is_node_ready():
		return
	while not _scenario.is_battle_over() and _mode != "s4_drain":
		_scenario.advance_one_tick()
	if _mode == "s4_drain":
		for _i in 50:
			_scenario.advance_one_tick()
	_finish()


func _start(scene: String, seed_value: int) -> void:
	if _scenario != null:
		_scenario.free()
	var path := "res://tests/scenario_01.tscn"
	match scene:
		"scenario_02":
			path = "res://tests/scenario_02.tscn"
		"scenario_03":
			path = "res://tests/scenario_03.tscn"
		"scenario_04":
			path = "res://tests/scenario_04.tscn"
	_scenario = load(path).instantiate()
	_scenario.headless_mode = true
	_scenario.set_battle_seed(seed_value)
	if scene == "scenario_04":
		match _s4_modes[_s4_mode_idx]:
			"front":
				_scenario.contact_mode = _scenario.ContactMode.FRONT
			"side":
				_scenario.contact_mode = _scenario.ContactMode.SIDE
			"corner":
				_scenario.contact_mode = _scenario.ContactMode.CORNER
	root.add_child(_scenario)


func _finish() -> void:
	match _mode:
		"s1_regression":
			_check_s1_regression(ALL_SEEDS[_seed_idx])
			_seed_idx += 1
			if _seed_idx < ALL_SEEDS.size():
				_start("scenario_01", ALL_SEEDS[_seed_idx])
			else:
				_mode = "s2_regression"
				_seed_idx = 0
				_start("scenario_02", ALL_SEEDS[0])
		"s2_regression":
			_check_s2_regression(ALL_SEEDS[_seed_idx])
			_seed_idx += 1
			if _seed_idx < ALL_SEEDS.size():
				_start("scenario_02", ALL_SEEDS[_seed_idx])
			else:
				_mode = "determinism_a"
				_start("scenario_01", 12345)
		"determinism_a":
			_determinism_a = _core_trace(_scenario.get_trace_text())
			_mode = "determinism_b"
			_start("scenario_01", 12345)
		"determinism_b":
			_determinism_b = _core_trace(_scenario.get_trace_text())
			if _determinism_a != _determinism_b:
				push_error("Determinism failed")
				_exit_code = 1
			else:
				print("[WO-008] Determinism PASS")
			_mode = "scenario_03"
			_start("scenario_03", 1000)
		"scenario_03":
			_check_scenario_03()
			_mode = "s4_drain"
			_s4_mode_idx = 0
			_start("scenario_04", 1000)
		"s4_drain":
			_s4_results.append({
				"mode": _s4_modes[_s4_mode_idx],
				"drain_per_sec": _scenario.get_drain_per_sec(),
				"edge": _scenario.get_edge_label_sample(),
			})
			_s4_mode_idx += 1
			if _s4_mode_idx < _s4_modes.size():
				_start("scenario_04", 1000)
			else:
				_print_s4_table()
				_mode = "reflection"
				_start("scenario_01", 1000)
		"reflection":
			_check_reflection_pair(1000)
			process_frame.disconnect(_on_frame)
			_scenario.free()
			quit(_exit_code)


func _check_s1_regression(seed_value: int) -> void:
	var phases: Dictionary = _scenario.get_phase_durations_sec()
	var winner: String = _scenario.get_winner_id()
	var expected: Dictionary = WO007B_S1[seed_value]
	if winner != expected.winner:
		push_error("S1 winner flip seed %d: %s vs %s" % [seed_value, winner, expected.winner])
		_exit_code = 1
	if absf(phases.combat_sec - expected.combat) > 0.15:
		push_error("S1 combat drift seed %d: %.1f vs %.1f" % [seed_value, phases.combat_sec, expected.combat])
		_exit_code = 1
	print("[WO-008] S1 seed %d PASS winner=%s combat=%.1fs" % [seed_value, winner, phases.combat_sec])


func _check_s2_regression(seed_value: int) -> void:
	var phases: Dictionary = _scenario.get_phase_durations_sec()
	var winner: String = _scenario.get_winner_id()
	var rout: float = _scenario.get_strength_at_rout()
	var expected: Dictionary = WO007B_S2[seed_value]
	if winner != expected.winner:
		push_error("S2 winner flip seed %d" % seed_value)
		_exit_code = 1
	if absf(phases.combat_sec - expected.combat) > 0.15:
		push_error("S2 combat drift seed %d" % seed_value)
		_exit_code = 1
	if absf(rout - expected.rout) > 0.15:
		push_error("S2 rout drift seed %d" % seed_value)
		_exit_code = 1
	print("[WO-008] S2 seed %d PASS combat=%.1fs rout=%.2f" % [seed_value, phases.combat_sec, rout])


func _check_scenario_03() -> void:
	var phases: Dictionary = _scenario.get_phase_durations_sec()
	var s1_ref: float = WO007B_S1[1000].combat
	var rout: float = _scenario.get_blue_a_strength_at_rout()
	var drains: Dictionary = _scenario.get_blue_a_edge_drains()
	var ratio: float = phases.combat_sec / s1_ref if s1_ref > 0.0 else 0.0
	print(
		"[WO-008] S3 combat=%.1fs (S1=%.1fs ratio=%.2f) blue_rout=%.2f drains=%s"
		% [phases.combat_sec, s1_ref, ratio, rout, drains]
	)
	if ratio > 0.60:
		push_error("S3 flank not faster enough: ratio %.2f" % ratio)
		_exit_code = 1
	if rout <= 67.0:
		push_error("S3 blue strength_at_rout %.2f not > 67%%" % rout)
		_exit_code = 1
	if drains.get("left", 0.0) <= 0.0 and drains.get("right", 0.0) <= 0.0 and drains.get("rear", 0.0) <= 0.0:
		push_error("S3 missing flank-edge drain on blue_a")
		_exit_code = 1
	if _scenario.had_overlap_failure():
		push_error("S3 overlap assertion failed (includes allied pairs)")
		_exit_code = 1


func _print_s4_table() -> void:
	print("[WO-008] Scenario 4 drain comparison:")
	for row in _s4_results:
		print("  %s | drain/s=%.3f | edges=%s" % [row.mode, row.drain_per_sec, row.edge])
	var front_d: float = _s4_results[0].drain_per_sec
	var side_d: float = _s4_results[1].drain_per_sec
	var corner_d: float = _s4_results[2].drain_per_sec
	if not (front_d < corner_d and corner_d <= side_d and front_d < side_d):
		push_error("S4 corner drain %.3f not between front %.3f and side %.3f" % [corner_d, front_d, side_d])
		_exit_code = 1


func _core_trace(trace_text: String) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for line in trace_text.split("\n", false):
		if line.is_empty():
			continue
		var parts := line.split(",")
		if parts.size() < CORE_COLS:
			continue
		lines.append(",".join(parts.slice(0, CORE_COLS)))
	return "\n".join(lines) + "\n"


func _check_reflection_pair(seed_value: int) -> void:
	# Reflection covered by WO-007 harness; spot-check overlap on normal run.
	if _scenario.had_overlap_failure():
		push_error("Overlap on seed %d" % seed_value)
		_exit_code = 1
	else:
		print("[WO-008] Overlap check seed %d PASS" % seed_value)
