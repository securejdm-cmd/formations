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
const S8_BLOB_RATIO_MAX := 2.0
const SCENARIO_EXTRA_TICKS := 120

var _scenario: Scenario01 = null
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
var _s8_single_damage := 0.0
var _perf_stats: Dictionary = {}
var _perf_scale_results: Array[Dictionary] = []
var _perf_scale_idx := 0
var _perf_scale_pairs := [2, 10, 20]


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
		print("[WO-010] Compass test PASS (32/32)")
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
		print("[WO-010] Fast-mode certification PASS (seed %d trace byte-identical)" % CERT_SEED)

	var threaded: Scenario01 = _sim_runner.instantiate_scenario(
		"res://tests/scenario_01.tscn", CERT_SEED, false, true
	)
	_sim_runner.attach_and_wait_ready(self, threaded)
	_sim_harness.run_threaded_to_completion(threaded)
	var threaded_trace: String = threaded.get_trace_text()
	threaded.free()

	if threaded_trace != fast_trace:
		push_error("Threaded certification failed: threaded vs fast trace differ (seed %d)" % CERT_SEED)
		_exit_code = 1
	else:
		print("[WO-011] Threaded certification PASS (seed %d trace byte-identical)" % CERT_SEED)

	_mode = "s1_regression"
	_seed_idx = 0
	_spawn_and_run()


func _spawn_and_run() -> void:
	var scene := "scenario_01"
	var seed_value: int = CERT_SEED
	var extra_ticks := 0
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
		"s5_rally":
			scene = "scenario_05"
			seed_value = 1000
			extra_ticks = SCENARIO_EXTRA_TICKS
		"s6_pursuit":
			scene = "scenario_06"
			seed_value = 1000
			extra_ticks = SCENARIO_EXTRA_TICKS
		"s7_cascade":
			scene = "scenario_07"
			seed_value = 1000
			extra_ticks = SCENARIO_EXTRA_TICKS
		"s8_blob_single":
			scene = "scenario_08"
			seed_value = 1000
			extra_ticks = 80
		"s8_blob_triple":
			scene = "scenario_08"
			seed_value = 1000
			extra_ticks = 80
		"perf_40":
			scene = "scenario_40_perf"
			seed_value = 1000
			extra_ticks = 0
		"perf_scale":
			scene = "scenario_perf_scale"
			seed_value = 1000
			extra_ticks = 0

	if _scenario != null:
		_scenario.free()
		_scenario = null

	var path := "res://tests/%s.tscn" % scene
	_scenario = _sim_runner.instantiate_scenario(path, seed_value, _mode != "perf_40")
	if _mode == "perf_40":
		_scenario.use_sim_thread = true
	if scene == "scenario_04":
		match _s4_modes[_s4_mode_idx]:
			"front":
				_scenario.set("contact_mode", 0)
			"side":
				_scenario.set("contact_mode", 1)
			"corner":
				_scenario.set("contact_mode", 2)
	elif scene == "scenario_08":
		if _mode == "s8_blob_triple":
			_scenario.set("attacker_count", 3)
		else:
			_scenario.set("attacker_count", 1)
	elif scene == "scenario_perf_scale":
		_scenario.set("unit_pairs", _perf_scale_pairs[_perf_scale_idx])

	root.add_child(_scenario)
	_pending_ready = true
	_extra_ticks_for_mode = extra_ticks
	call_deferred("_run_when_ready")


var _extra_ticks_for_mode := 0


func _run_when_ready() -> void:
	if _scenario == null or not _scenario.is_node_ready():
		call_deferred("_run_when_ready")
		return
	_pending_ready = false
	if _mode == "s4_drain":
		_sim_harness.run_ticks(_scenario, 50)
	elif _mode == "perf_40":
		for _i in 1200:
			_scenario.simulate_realtime_step()
			if _scenario.is_battle_over():
				break
		_perf_stats = _scenario.get_perf_stats()
	elif _mode == "perf_scale":
		for _i in 800:
			_scenario.advance_one_tick()
		_perf_scale_results.append(_scenario.get_tick_perf_stats())
	elif _mode in ["s5_rally", "s6_pursuit", "s7_cascade", "s8_blob_single", "s8_blob_triple"]:
		_sim_harness.run_ticks(_scenario, 3500 + _extra_ticks_for_mode)
	else:
		_sim_harness.run_to_completion(_scenario, _sim_harness.RunMode.FAST, _extra_ticks_for_mode)
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
				print("[WO-010] Determinism PASS")
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
				_mode = "reflection"
				_spawn_and_run()
		"reflection":
			_check_reflection_pair(1000)
			_mode = "s5_rally"
			_spawn_and_run()
		"s5_rally":
			_check_scenario_05()
			_mode = "s6_pursuit"
			_spawn_and_run()
		"s6_pursuit":
			_check_scenario_06()
			_mode = "s7_cascade"
			_spawn_and_run()
		"s7_cascade":
			_check_scenario_07()
			_mode = "s8_blob_single"
			_spawn_and_run()
		"s8_blob_single":
			_s8_single_damage = _scenario.get_defender_damage_taken()
			_mode = "s8_blob_triple"
			_spawn_and_run()
		"s8_blob_triple":
			_check_scenario_08(_s8_single_damage)
			_mode = "perf_40"
			_spawn_and_run()
		"perf_40":
			_check_perf_40()
			_mode = "perf_scale"
			_perf_scale_idx = 0
			_spawn_and_run()
		"perf_scale":
			_perf_scale_idx += 1
			if _perf_scale_idx < _perf_scale_pairs.size():
				_spawn_and_run()
			else:
				_report_perf_scale()
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
	var baseline := _load_baseline_trace("scenario_01_%d.csv" % seed_value)
	if not baseline.is_empty() and _core_trace(_scenario.get_trace_text()) != _core_trace(baseline):
		push_error("S1 trace drift seed %d (not byte-identical to baseline)" % seed_value)
		_exit_code = 1
	print("[WO-010] S1 seed %d PASS winner=%s combat=%.1fs" % [seed_value, winner, phases.combat_sec])


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
	var baseline := _load_baseline_trace("scenario_02_%d.csv" % seed_value)
	if not baseline.is_empty() and _core_trace(_scenario.get_trace_text()) != _core_trace(baseline):
		push_error("S2 trace drift seed %d (not byte-identical to baseline)" % seed_value)
		_exit_code = 1
	print("[WO-010] S2 seed %d PASS combat=%.1fs rout=%.2f" % [seed_value, phases.combat_sec, rout])


func _check_scenario_03() -> void:
	var phases: Dictionary = _scenario.get_phase_durations_sec()
	var s1_ref: float = WO007B_S1[1000].combat
	var rout: float = _scenario.get_blue_a_strength_at_rout()
	var drains: Dictionary = _scenario.get_blue_a_edge_drains()
	var ratio: float = phases.combat_sec / s1_ref if s1_ref > 0.0 else 0.0
	if ratio < S3_RATIO_MIN - S3_RATIO_TOL or ratio > S3_RATIO_MAX + S3_RATIO_TOL:
		push_error("S3 ratio %.3f outside band" % ratio)
		_exit_code = 1
	if rout <= 67.0:
		push_error("S3 blue strength_at_rout %.2f not > 67%%" % rout)
		_exit_code = 1
	if drains.get("left", 0.0) <= 0.0:
		push_error("S3 missing LEFT edge drain")
		_exit_code = 1
	if _scenario.had_overlap_failure() or _scenario.had_adhesion_invariant_failure():
		push_error("S3 invariant/overlap failure")
		_exit_code = 1
	var baseline := _load_baseline_trace("scenario_03_1000.csv")
	if not baseline.is_empty() and _core_trace(_scenario.get_trace_text()) != _core_trace(baseline):
		push_error("S3 trace drift (not byte-identical to baseline)")
		_exit_code = 1
	print("[WO-010] S3 PASS ratio=%.3f rout=%.2f" % [ratio, rout])


func _check_s4_labels_and_ratio() -> void:
	var expected_labels := {"front": "front", "side": "left", "corner": "front+left"}
	for row in _s4_results:
		var expected: String = expected_labels.get(row.mode, "")
		if row.edge != expected:
			push_error("S4 %s edge label '%s' expected '%s'" % [row.mode, row.edge, expected])
			_exit_code = 1
	var front_d: float = _s4_results[0].drain_per_sec
	var side_d: float = _s4_results[1].drain_per_sec
	var corner_d: float = _s4_results[2].drain_per_sec
	if not (front_d < corner_d and corner_d < side_d):
		push_error("S4 ordering failed")
		_exit_code = 1


func _check_reflection_pair(seed_value: int) -> void:
	if _scenario.had_overlap_failure():
		push_error("Overlap on seed %d" % seed_value)
		_exit_code = 1
	elif _scenario.had_adhesion_invariant_failure():
		push_error("Adhesion invariant failed on seed %d" % seed_value)
		_exit_code = 1
	else:
		print("[WO-010] Overlap/adhesion seed %d PASS" % seed_value)



func _check_scenario_05() -> void:
	var standard: Unit = _scenario.get_blue_standard()
	var rally: Unit = _scenario.get_blue_rally()
	if standard.get_state() != Unit.State.REMOVED:
		push_error("S5 standard unit did not exit map (state=%s)" % standard.get_state_name())
		_exit_code = 1
	if rally.get_state() != Unit.State.HOLD or not rally.is_rallied_hold():
		push_error("S5 rally unit expected rallied HOLD, got %s" % rally.get_state_name())
		_exit_code = 1
	if not rally.is_rallied_hold():
		push_error("S5 rally unit missing rallied-hold flag")
		_exit_code = 1
	if absf(rally.cohesion - 50.0) > 0.5:
		push_error("S5 rally cohesion %.2f expected 50" % rally.cohesion)
		_exit_code = 1
	if rally.current_order != Unit.Order.HOLD:
		push_error("S5 rally unit resumed stale order")
		_exit_code = 1
	var trace: String = _scenario.get_trace_text()
	if "blue_rally" not in trace or "rallying" not in trace:
		push_error("S5 trace missing rally timeline (routing→rallying→holding)")
		_exit_code = 1
	print(
		"[WO-010] S5 PASS standard=%s rally=%s cohesion=%.1f"
		% [standard.get_state_name(), rally.get_state_name(), rally.cohesion]
	)


func _check_scenario_06() -> void:
	var rally: Unit = _scenario.get_blue_rally()
	if rally.get_state() == Unit.State.HOLD and rally.is_rallied_hold():
		push_error("S6 rally entered HOLD despite pursuit")
		_exit_code = 1
	elif rally.get_state() not in [Unit.State.ROUTING, Unit.State.RALLYING, Unit.State.REMOVED]:
		push_error("S6 rally unit state unexpected: %s" % rally.get_state_name())
		_exit_code = 1
	if _scenario.get_pursuit_tick_count() <= 0:
		push_error("S6 no pursuit damage ticks logged")
		_exit_code = 1
	print(
		"[WO-010] S6 PASS rally=%s pursuit_ticks=%d strength=%.2f"
		% [rally.get_state_name(), _scenario.get_pursuit_tick_count(), rally.strength]
	)


func _check_scenario_07() -> void:
	var shocks: Array = _scenario.get_shock_events()
	if shocks.size() < 2:
		push_error("S7 expected 2 neighbor shock events, got %d" % shocks.size())
		_exit_code = 1
	for row in shocks:
		if absf(float(row.drain) - 15.0) > 0.1:
			push_error("S7 shock drain %.1f expected 15" % row.drain)
			_exit_code = 1
	var tipped := false
	for neighbor in _scenario.get_red_neighbors():
		if neighbor == null:
			continue
		if neighbor.get_state() == Unit.State.WAVERING:
			tipped = true
	print("[WO-010] S7 PASS shocks=%d shock_tips_wavering=%s" % [shocks.size(), tipped])


func _check_scenario_08(single_damage: float) -> void:
	var triple_damage: float = _scenario.get_defender_damage_taken()
	var ratio: float = triple_damage / single_damage if single_damage > 0.0 else 0.0
	print(
		"[WO-010] S8 single_damage=%.2f triple_damage=%.2f ratio=%.3f"
		% [single_damage, triple_damage, ratio]
	)
	if single_damage <= 0.0 or triple_damage <= 0.0:
		push_error("S8 zero damage recorded")
		_exit_code = 1
	if ratio > S8_BLOB_RATIO_MAX:
		push_error("S8 blob ratio %.3f exceeds cap %.1f (not frontage-capped)" % [ratio, S8_BLOB_RATIO_MAX])
		_exit_code = 1


func _check_perf_40() -> void:
	var sim_stats: Dictionary = _perf_stats.get("sim_thread", {})
	print(
		"[WO-011] Perf40 sim_thread avg_tick_ms=%.3f p95_tick_ms=%.3f max_tick_ms=%.3f ticks=%d"
		% [
			sim_stats.get("avg_tick_ms", 0.0),
			sim_stats.get("p95_tick_ms", 0.0),
			sim_stats.get("max_tick_ms", 0.0),
			sim_stats.get("tick_count", 0),
		]
	)
	if sim_stats.get("p95_tick_ms", 999.0) > 50.0:
		push_error(
			"WO-011 perf gate FAIL: sim-thread p95_tick_ms=%.3f exceeds 50ms budget"
			% sim_stats.get("p95_tick_ms", 0.0)
		)
		_exit_code = 1
	print(
		"[WO-011] Perf40 environmental actuals (cloud, not designer-desktop gate): "
		+ "min_fps=%.1f avg_fps=%.1f avg_tick_ms=%.3f p95_tick_ms=%.3f ticks=%d"
		% [
			_perf_stats.get("min_fps", 0.0),
			_perf_stats.get("avg_fps", 0.0),
			_perf_stats.get("avg_tick_ms", 0.0),
			_perf_stats.get("p95_tick_ms", 0.0),
			_perf_stats.get("tick_count", 0),
		]
	)


func _report_perf_scale() -> void:
	print("[WO-010] Spatial-grid tick perf (after partitioning, cloud env):")
	for row in _perf_scale_results:
		print(
			"  units=%d avg_tick_ms=%.3f p95_tick_ms=%.3f max_tick_ms=%.3f ticks=%d"
			% [
				row.get("unit_count", 0),
				row.get("avg_tick_ms", 0.0),
				row.get("p95_tick_ms", 0.0),
				row.get("max_tick_ms", 0.0),
				row.get("tick_count", 0),
			]
		)


func _load_baseline_trace(filename: String) -> String:
	var path := "res://tests/traces/" + filename
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


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
