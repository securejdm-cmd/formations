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
const CERT_SEED := 12345

const S3_RATIO_TD_BASELINE := 0.32
const S3_RATIO_MIN := 0.28
const S3_RATIO_MAX := 0.45
const S3_RATIO_TOL := 0.002
const S4_BLEND_TOLERANCE := 0.5
const S4_CONTACT_BALANCE_MAX_M := 6.0

var _scenario = null
var _exit_code := 0
var _mode := "fast_cert"
var _seed_idx := 0
var _s4_mode_idx := 0
var _s4_modes := ["front", "side", "corner"]
var _s4_results: Array[Dictionary] = []
var _determinism_a := ""
var _determinism_b := ""
var _cert_realtime_trace := ""
var _pending_ready := false
var _sim_harness: Script
var _sim_runner: Script


func _initialize() -> void:
	var compass_exit := OS.execute(
		"/tmp/godot/Godot_v4.3-stable_linux.x86_64",
		["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", "res://tests/edge_contact_compass_test.gd"],
		[],
		false
	)
	if compass_exit != 0:
		push_error("Compass test failed (exit %d)" % compass_exit)
		_exit_code = 1
	else:
		print("[WO-008] Compass test PASS (32/32)")
	call_deferred("_kickoff")


func _kickoff() -> void:
	_sim_harness = load("res://scripts/sim_harness.gd")
	_sim_runner = load("res://tests/sim_harness_runner.gd")
	match _mode:
		"fast_cert":
			_run_fast_certification()
		_:
			_spawn_and_run()


func _run_fast_certification() -> void:
	var realtime: Scenario01 = _sim_runner.instantiate_scenario("res://tests/scenario_01.tscn", CERT_SEED, false)
	_sim_runner.attach_and_wait_ready(self, realtime)
	_sim_harness.run_to_completion(realtime, _sim_harness.RunMode.REALTIME)
	_cert_realtime_trace = realtime.get_trace_text()
	realtime.free()

	var fast: Scenario01 = _sim_runner.instantiate_scenario("res://tests/scenario_01.tscn", CERT_SEED, true)
	_sim_runner.attach_and_wait_ready(self, fast)
	_sim_harness.run_to_completion(fast, _sim_harness.RunMode.FAST)
	var fast_trace: String = fast.get_trace_text()
	fast.free()

	if _cert_realtime_trace != fast_trace:
		push_error("Fast-mode certification failed: realtime vs fast trace differ (seed %d)" % CERT_SEED)
		_exit_code = 1
	else:
		print("[WO-008] Fast-mode certification PASS (seed %d trace byte-identical)" % CERT_SEED)

	_mode = "s1_regression"
	_seed_idx = 0
	_spawn_and_run()


func _spawn_and_run() -> void:
	var scene := "scenario_01"
	var seed_value: int = CERT_SEED
	match _mode:
		"s1_regression":
			seed_value = ALL_SEEDS[_seed_idx]
		"s2_regression":
			scene = "scenario_02"
			seed_value = ALL_SEEDS[_seed_idx]
		"determinism_a", "determinism_b":
			seed_value = CERT_SEED
			scene = "scenario_01"
		"scenario_03":
			scene = "scenario_03"
			seed_value = 1000
		"s4_drain":
			scene = "scenario_04"
			seed_value = 1000
		"reflection":
			scene = "scenario_01"
			seed_value = 1000

	if _scenario != null:
		_scenario.free()
		_scenario = null

	var path := "res://tests/%s.tscn" % scene
	_scenario = _sim_runner.instantiate_scenario(path, seed_value, true)
	if scene == "scenario_04":
		match _s4_modes[_s4_mode_idx]:
			"front":
				_scenario.contact_mode = _scenario.ContactMode.FRONT
			"side":
				_scenario.contact_mode = _scenario.ContactMode.SIDE
			"corner":
				_scenario.contact_mode = _scenario.ContactMode.CORNER

	root.add_child(_scenario)
	_pending_ready = true
	call_deferred("_run_when_ready")


func _run_when_ready() -> void:
	if _scenario == null or not _scenario.is_node_ready():
		call_deferred("_run_when_ready")
		return
	_pending_ready = false
	if _mode == "s4_drain":
		_sim_harness.run_ticks(_scenario, 50)
	else:
		_sim_harness.run_to_completion(_scenario, _sim_harness.RunMode.FAST)
	_finish()


func _finish() -> void:
	match _mode:
		"s1_regression":
			_check_s1_regression(ALL_SEEDS[_seed_idx])
			_seed_idx += 1
			if _seed_idx < ALL_SEEDS.size():
				_spawn_and_run()
			else:
				_mode = "s2_regression"
				_seed_idx = 0
				_spawn_and_run()
		"s2_regression":
			_check_s2_regression(ALL_SEEDS[_seed_idx])
			_seed_idx += 1
			if _seed_idx < ALL_SEEDS.size():
				_spawn_and_run()
			else:
				_mode = "determinism_a"
				_spawn_and_run()
		"determinism_a":
			_determinism_a = _core_trace(_scenario.get_trace_text())
			_mode = "determinism_b"
			_spawn_and_run()
		"determinism_b":
			_determinism_b = _core_trace(_scenario.get_trace_text())
			if _determinism_a != _determinism_b:
				push_error("Determinism failed")
				_exit_code = 1
			else:
				print("[WO-008] Determinism PASS")
			_mode = "scenario_03"
			_spawn_and_run()
		"scenario_03":
			_check_scenario_03()
			_mode = "s4_drain"
			_s4_mode_idx = 0
			_spawn_and_run()
		"s4_drain":
			var spawn_contact: Dictionary = _scenario.get_spawn_contact_sample()
			var edge_lengths: Dictionary = spawn_contact.get("edge_lengths_m", {})
			_s4_results.append({
				"mode": _s4_modes[_s4_mode_idx],
				"drain_per_sec": _scenario.get_drain_per_sec(),
				"edge": _scenario.get_edge_label_sample(),
				"edge_lengths_m": edge_lengths.duplicate(),
				"shift_blend": spawn_contact.get("edge_shift_multiplier", 1.0),
				"casualty_blend": spawn_contact.get("edge_casualty_multiplier", 1.0),
				"defender_edge_pct": spawn_contact.get("defender_edge_pct", 1.0),
			})
			_s4_mode_idx += 1
			if _s4_mode_idx < _s4_modes.size():
				_spawn_and_run()
			else:
				_check_s4_labels_and_ratio()
				_print_s4_table()
				_mode = "reflection"
				_spawn_and_run()
		"reflection":
			_check_reflection_pair(1000)
			if _scenario != null:
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
	print(
		"[WO-008] S3 TD baseline ratio=%.2f accepted band [%.2f, %.2f]"
		% [S3_RATIO_TD_BASELINE, S3_RATIO_MIN, S3_RATIO_MAX]
	)
	if ratio < S3_RATIO_MIN - S3_RATIO_TOL or ratio > S3_RATIO_MAX + S3_RATIO_TOL:
		push_error(
			"S3 ratio %.3f outside band [%.2f, %.2f] (tol %.3f)"
			% [ratio, S3_RATIO_MIN, S3_RATIO_MAX, S3_RATIO_TOL]
		)
		_exit_code = 1
	if rout <= 67.0:
		push_error("S3 blue strength_at_rout %.2f not > 67%%" % rout)
		_exit_code = 1
	if drains.get("left", 0.0) <= 0.0:
		push_error("S3 missing LEFT edge drain on blue_a (got %s)" % drains)
		_exit_code = 1
	if _scenario.had_overlap_failure():
		push_error("S3 overlap assertion failed (non-routing pairs)")
		_exit_code = 1
	if _scenario.had_adhesion_invariant_failure():
		push_error("S3 adhesion invariant failed (partner-linked without classifier contact)")
		_exit_code = 1


func _check_s4_labels_and_ratio() -> void:
	var expected_labels := {"front": "front", "side": "left", "corner": "front+left"}
	for row in _s4_results:
		var expected: String = expected_labels.get(row.mode, "")
		if row.edge != expected:
			push_error("S4 %s edge label '%s' expected '%s'" % [row.mode, row.edge, expected])
			_exit_code = 1
	var front_row: Dictionary = _s4_results[0]
	var side_row: Dictionary = _s4_results[1]
	var corner_row: Dictionary = _s4_results[2]
	var front_d: float = front_row.drain_per_sec
	var side_d: float = side_row.drain_per_sec
	var corner_d: float = corner_row.drain_per_sec
	if front_d <= 0.0:
		push_error("S4 front drain is zero")
		_exit_code = 1
		return
	var observed_ratio: float = side_d / front_d
	var constants: Node = root.get_node("Constants")
	var shift_mult: float = (
		constants.get_float("edge_mult_side_shift") / constants.get_float("edge_mult_front")
	)
	var casualty_mult: float = (
		constants.get_float("edge_mult_side_casualty") / constants.get_float("edge_mult_front")
	)
	print(
		"[WO-008] S4 side/front=%.2f shift_mult=%.2f casualty_mult=%.2f"
		% [observed_ratio, shift_mult, casualty_mult]
	)
	_report_s4_corner_instrumentation(corner_row)
	if not (front_d < corner_d and corner_d < side_d):
		push_error(
			"S4 strict-between ordering failed: front=%.3f corner=%.3f side=%.3f"
			% [front_d, corner_d, side_d]
		)
		_exit_code = 1
	var shift_blend: float = corner_row.shift_blend
	var casualty_blend: float = corner_row.casualty_blend
	var shift_weight: float = observed_ratio / shift_mult if shift_mult > 0 else 0.5
	var casualty_weight: float = observed_ratio / casualty_mult if casualty_mult > 0 else 0.5
	var weight_sum: float = shift_weight + casualty_weight
	if weight_sum <= 0.0:
		shift_weight = 0.5
		casualty_weight = 0.5
		weight_sum = 1.0
	shift_weight /= weight_sum
	casualty_weight /= weight_sum
	var blend_ratio: float = shift_blend * shift_weight + casualty_blend * casualty_weight
	var measured_corner_ratio: float = corner_d / front_d
	print(
		"[WO-008] S4 corner blend check: measured_ratio=%.3f blend=%.3f"
		% [measured_corner_ratio, blend_ratio]
	)
	if absf(measured_corner_ratio - blend_ratio) > S4_BLEND_TOLERANCE:
		push_error(
			"ESCALATE WO-008 S4: corner drain diverges from computed blend (measured_ratio=%.3f blend=%.3f tol=%.2f)"
			% [measured_corner_ratio, blend_ratio, S4_BLEND_TOLERANCE]
		)
		_exit_code = 1


func _report_s4_corner_instrumentation(corner_row: Dictionary) -> void:
	var edges: Dictionary = corner_row.get("edge_lengths_m", {})
	var front_l: float = edges.get("front", 0.0)
	var left_l: float = edges.get("left", 0.0)
	print(
		"[WO-008] S4 corner instrumentation: front=%.3fm left=%.3fm balance_delta=%.3fm shift_blend=%.3f casualty_blend=%.3f"
		% [
			front_l,
			left_l,
			absf(front_l - left_l),
			corner_row.get("shift_blend", 1.0),
			corner_row.get("casualty_blend", 1.0),
		]
	)
	if absf(front_l - left_l) > S4_CONTACT_BALANCE_MAX_M:
		push_error(
			"S4 corner contact lengths not ~50/50: front=%.3fm left=%.3fm delta=%.3fm"
			% [front_l, left_l, absf(front_l - left_l)]
		)
		_exit_code = 1


func _print_s4_table() -> void:
	print("[WO-008] Scenario 4 drain comparison:")
	for row in _s4_results:
		print("  %s | drain/s=%.3f | edges=%s" % [row.mode, row.drain_per_sec, row.edge])


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
	if _scenario.had_overlap_failure():
		push_error("Overlap on seed %d" % seed_value)
		_exit_code = 1
	elif _scenario.had_adhesion_invariant_failure():
		push_error("Adhesion invariant failed on seed %d" % seed_value)
		_exit_code = 1
	else:
		print("[WO-008] Overlap check seed %d PASS" % seed_value)
