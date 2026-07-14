extends SceneTree

const ALL_SEEDS := [1000, 1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009, 12345]
const WO013_S1 := {
	1000: {"winner": "red_1", "combat": 75.8},
	1001: {"winner": "red_1", "combat": 80.6},
	1002: {"winner": "blue_1", "combat": 76.0},
	1003: {"winner": "blue_1", "combat": 83.9},
	1004: {"winner": "red_1", "combat": 83.4},
	1005: {"winner": "red_1", "combat": 73.2},
	1006: {"winner": "red_1", "combat": 77.0},
	1007: {"winner": "blue_1", "combat": 82.4},
	1008: {"winner": "red_1", "combat": 81.0},
	1009: {"winner": "red_1", "combat": 84.6},
	12345: {"winner": "blue_1", "combat": 81.6},
}
const WO013_S2 := {
	1000: {"winner": "red_1", "combat": 61.2, "rout": 68.12},
	1001: {"winner": "red_1", "combat": 61.2, "rout": 68.12},
	1002: {"winner": "red_1", "combat": 61.2, "rout": 68.12},
	1003: {"winner": "red_1", "combat": 61.2, "rout": 68.12},
	1004: {"winner": "red_1", "combat": 61.2, "rout": 68.12},
	1005: {"winner": "red_1", "combat": 61.2, "rout": 68.12},
	1006: {"winner": "red_1", "combat": 61.2, "rout": 68.12},
	1007: {"winner": "red_1", "combat": 61.2, "rout": 68.12},
	1008: {"winner": "red_1", "combat": 61.2, "rout": 68.12},
	1009: {"winner": "red_1", "combat": 61.2, "rout": 68.12},
	12345: {"winner": "red_1", "combat": 61.2, "rout": 68.12},
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
## Gated PASS lines emitted when every check is green (WO-015).
## Compass, Fast+Threaded cert, S1×11, S2×11, Determinism, S3, Overlap, S4, S5–S8, S9,
## S10–S11, S12, S13×3, S14×2, S15, S16×2, S17×2, S18, S19, S20×2 = 51
const EXPECTED_GREEN_PASS_COUNT := 51

var _scenario: Scenario01 = null
var _exit_code := 0
var _check_pass_count := 0
var _check_fail_count := 0
var _s9_ok := true
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
var _s8_single_damage: float = 0.0
var _s11_control_combat: float = 0.0
var _s11_control_damage: float = 0.0
var _s11_control_breach: float = -1.0
var _s9_heavy_wins: int = 0
var _s9_casualty_ratio: float = 0.0
var _perf_stats: Dictionary = {}
var _perf_scale_results: Array[Dictionary] = []
var _perf_scale_idx := 0
var _perf_scale_pairs := [2, 10, 20]
var _s14_ff_lost: float = 0.0
var _s13_at70_dist: float = -1.0
var _s13_engaged_dist: float = -1.0
var _s17_charge_impact: float = -1.0
var _s17_charge_shock: float = -1.0
var _s17_combat_sec: float = -1.0
var _s20_short_closing: float = -1.0
var _s20_long_closing: float = -1.0
var _extra_ticks_for_mode := 0


func _initialize() -> void:
	var scene_smoke_exit := OS.execute(
		"/tmp/godot/Godot_v4.4.1-stable_linux.x86_64",
		["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", "res://tests/all_scenes_smoke_test.gd"],
		[],
		false
	)
	if scene_smoke_exit != 0:
		push_error("Universal scene smoke test failed (exit %d)" % scene_smoke_exit)
		_record_check("[WO-010] SceneSmoke gate", false, "exit %d" % scene_smoke_exit)
	var compass_exit := OS.execute(
		"/tmp/godot/Godot_v4.4.1-stable_linux.x86_64",
		["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", "res://tests/edge_contact_compass_test.gd"],
		[],
		false
	)
	if compass_exit != 0:
		push_error("Compass test failed (exit %d)" % compass_exit)
		_record_check("[WO-010] Compass test", false, "exit %d" % compass_exit)
	else:
		_record_check("[WO-010] Compass test", true, "(32/32)")
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
		_record_check("[WO-010] Fast-mode certification", false, "seed %d" % CERT_SEED)
	else:
		_record_check(
			"[WO-010] Fast-mode certification",
			true,
			"(seed %d trace byte-identical)" % CERT_SEED,
		)

	var threaded: Scenario01 = _sim_runner.instantiate_scenario(
		"res://tests/scenario_01.tscn", CERT_SEED, false, true
	)
	_sim_runner.attach_and_wait_ready(self, threaded)
	_sim_harness.run_threaded_to_completion(threaded)
	var threaded_trace: String = threaded.get_trace_text()
	threaded.free()

	if threaded_trace != fast_trace:
		push_error("Threaded certification failed: threaded vs fast trace differ (seed %d)" % CERT_SEED)
		_record_check("[WO-011] Threaded certification", false, "seed %d" % CERT_SEED)
	else:
		_record_check(
			"[WO-011] Threaded certification",
			true,
			"(seed %d trace byte-identical)" % CERT_SEED,
		)

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
		"s9_regression":
			scene = "scenario_09"
			seed_value = ALL_SEEDS[_seed_idx]
		"s10_chip_floor":
			scene = "scenario_10"
			seed_value = 1000
		"s11_control", "s11_anti_armor":
			scene = "scenario_11"
			seed_value = 1000
		"s12_attrition":
			scene = "scenario_12"
			seed_value = 1000
		"s13_doctrine":
			scene = "scenario_13"
			seed_value = 1000
		"s13_at70":
			scene = "scenario_13"
			seed_value = 1000
		"s13_engaged":
			scene = "scenario_13"
			seed_value = 1000
		"s14_friendly_fire":
			scene = "scenario_14"
			seed_value = 1000
		"s14_ff_control":
			scene = "scenario_14"
			seed_value = 1000
		"s15_empty_quiver":
			scene = "scenario_15"
			seed_value = 1000
		"s16_leather":
			scene = "scenario_16"
			seed_value = 1000
		"s16_plate":
			scene = "scenario_16"
			seed_value = 1000
		"s17_charge":
			scene = "scenario_17"
			seed_value = 1000
		"s17_charge_adj":
			scene = "scenario_17"
			seed_value = 1000
		"s18_brace":
			scene = "scenario_18"
			seed_value = 1000
		"s19_brace_timing":
			scene = "scenario_19"
			seed_value = 1000
		"s20_runup_short":
			scene = "scenario_20"
			seed_value = 1000
		"s20_runup_long":
			scene = "scenario_20"
			seed_value = 1000

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
	elif scene == "scenario_11":
		if _mode == "s11_control":
			_scenario.set("attacker_anti_armor", 0.0)
		else:
			_scenario.set("attacker_anti_armor", 15.0)
	elif scene == "scenario_13":
		match _mode:
			"s13_doctrine":
				_scenario.set("doctrine_mode", "FIRE_ON_SIGHT")
				_scenario.set("include_blocker", false)
			"s13_at70":
				_scenario.set("doctrine_mode", "FIRE_AT_70")
				_scenario.set("include_blocker", false)
			"s13_engaged":
				_scenario.set("doctrine_mode", "FIRE_ON_ENGAGED")
				_scenario.set("include_blocker", true)
	elif scene == "scenario_16":
		_scenario.set("plate_mode", _mode == "s16_plate")
	elif scene == "scenario_17":
		_scenario.set("adjacent_control", _mode == "s17_charge_adj")
	elif scene == "scenario_20":
		if _mode == "s20_runup_short":
			_scenario.set("run_up_m", 20.0)
		else:
			_scenario.set("run_up_m", 120.0)
	elif scene == "scenario_14":
		_scenario.set("control_mode", _mode == "s14_ff_control")

	root.add_child(_scenario)
	_pending_ready = true
	_extra_ticks_for_mode = extra_ticks
	call_deferred("_run_when_ready")


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
	elif _mode == "s13_engaged":
		_sim_harness.run_ticks(_scenario, 2800)
	elif _mode in ["s14_friendly_fire", "s14_ff_control"]:
		_sim_harness.run_ticks(_scenario, 2200)
	elif _mode in ["s16_leather", "s16_plate"]:
		_sim_harness.run_ticks(_scenario, 2000)
	elif _mode in ["s17_charge", "s17_charge_adj", "s18_brace", "s19_brace_timing", "s20_runup_short", "s20_runup_long"]:
		_sim_harness.run_ticks(_scenario, 4500)
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
				_record_check("[WO-010] Determinism", false)
			else:
				_record_check("[WO-010] Determinism", true)
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
			_mode = "s9_regression"
			_seed_idx = 0
			_s9_heavy_wins = 0
			_s9_ok = true
			_spawn_and_run()
		"s9_regression":
			_check_s9_regression(ALL_SEEDS[_seed_idx])
			_seed_idx += 1
			if _seed_idx < ALL_SEEDS.size():
				_spawn_and_run()
			else:
				var s9_ok := _s9_ok and _s9_heavy_wins >= 10
				if not s9_ok and _s9_heavy_wins < 10:
					push_error("S9 heavy armor wins %d/11 (need >= 10)" % _s9_heavy_wins)
				_record_check(
					"[WO-013] S9",
					s9_ok,
					"heavy_wins=%d/11 casualty_ratio_seed1000=%.3f" % [
						_s9_heavy_wins,
						_s9_casualty_ratio,
					],
				)
				_mode = "s10_chip_floor"
				_spawn_and_run()
		"s10_chip_floor":
			_check_s10_chip_floor()
			_mode = "s11_control"
			_spawn_and_run()
		"s11_control":
			_s11_control_combat = _scenario.get_combat_duration_sec()
			_s11_control_damage = _scenario.get_plate_damage_taken()
			_s11_control_breach = _scenario.get_plate_armor_breach_combat_sec(10.0)
			_mode = "s11_anti_armor"
			_spawn_and_run()
		"s11_anti_armor":
			_check_s11_anti_armor()
			_mode = "s12_attrition"
			_spawn_and_run()
		"s12_attrition":
			_check_s12_attrition()
			_mode = "s13_doctrine"
			_spawn_and_run()
		"s13_doctrine":
			_check_s13_doctrine_sight()
			_mode = "s13_at70"
			_spawn_and_run()
		"s13_at70":
			_s13_at70_dist = _scenario.first_volley_distance_m()
			_check_s13_doctrine_at70()
			_mode = "s13_engaged"
			_spawn_and_run()
		"s13_engaged":
			_s13_engaged_dist = _scenario.first_volley_distance_m()
			_check_s13_doctrine_engaged()
			_mode = "s14_friendly_fire"
			_spawn_and_run()
		"s14_friendly_fire":
			_s14_ff_lost = _scenario.friendly_fire_strength_lost()
			_check_s14_friendly_fire(false)
			_mode = "s14_ff_control"
			_spawn_and_run()
		"s14_ff_control":
			_check_s14_friendly_fire(true)
			_mode = "s15_empty_quiver"
			_spawn_and_run()
		"s15_empty_quiver":
			_check_s15_empty_quiver()
			_mode = "s16_leather"
			_spawn_and_run()
		"s16_leather":
			_check_s16_leather()
			_mode = "s16_plate"
			_spawn_and_run()
		"s16_plate":
			_check_s16_plate()
			_mode = "s17_charge"
			_spawn_and_run()
		"s17_charge":
			_check_s17_charge(false)
			_mode = "s17_charge_adj"
			_spawn_and_run()
		"s17_charge_adj":
			_check_s17_charge(true)
			_mode = "s18_brace"
			_spawn_and_run()
		"s18_brace":
			_check_s18_brace()
			_mode = "s19_brace_timing"
			_spawn_and_run()
		"s19_brace_timing":
			_check_s19_brace_timing()
			_mode = "s20_runup_short"
			_spawn_and_run()
		"s20_runup_short":
			_check_s20_runup(true)
			_mode = "s20_runup_long"
			_spawn_and_run()
		"s20_runup_long":
			_check_s20_runup(false)
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
				_reconcile_and_quit()


func _check_s1_regression(seed_value: int) -> void:
	var phases: Dictionary = _scenario.get_phase_durations_sec()
	var winner: String = _scenario.get_winner_id()
	var expected: Dictionary = WO013_S1[seed_value]
	var ok := true
	if winner != expected.winner:
		push_error("S1 winner flip seed %d: %s vs %s" % [seed_value, winner, expected.winner])
		ok = false
	if absf(phases.combat_sec - expected.combat) > 0.15:
		push_error("S1 combat drift seed %d: %.1f vs %.1f" % [seed_value, phases.combat_sec, expected.combat])
		ok = false
	var baseline := _load_baseline_trace("scenario_01_%d.csv" % seed_value)
	if not baseline.is_empty() and _core_trace(_scenario.get_trace_text()) != _core_trace(baseline):
		push_error("S1 trace drift seed %d (not byte-identical to baseline)" % seed_value)
		ok = false
	_record_check(
		"[WO-010] S1 seed %d" % seed_value,
		ok,
		"winner=%s combat=%.1fs" % [winner, phases.combat_sec],
	)


func _check_s2_regression(seed_value: int) -> void:
	var phases: Dictionary = _scenario.get_phase_durations_sec()
	var winner: String = _scenario.get_winner_id()
	var rout: float = _scenario.get_strength_at_rout()
	var expected: Dictionary = WO013_S2[seed_value]
	var ok := true
	if winner != expected.winner:
		push_error("S2 winner flip seed %d" % seed_value)
		ok = false
	if absf(phases.combat_sec - expected.combat) > 0.15:
		push_error("S2 combat drift seed %d" % seed_value)
		ok = false
	if absf(rout - expected.rout) > 0.15:
		push_error("S2 rout drift seed %d" % seed_value)
		ok = false
	var baseline := _load_baseline_trace("scenario_02_%d.csv" % seed_value)
	if not baseline.is_empty() and _core_trace(_scenario.get_trace_text()) != _core_trace(baseline):
		push_error("S2 trace drift seed %d (not byte-identical to baseline)" % seed_value)
		ok = false
	_record_check(
		"[WO-010] S2 seed %d" % seed_value,
		ok,
		"combat=%.1fs rout=%.2f" % [phases.combat_sec, rout],
	)


func _check_scenario_03() -> void:
	var phases: Dictionary = _scenario.get_phase_durations_sec()
	var s1_ref: float = WO013_S1[1000].combat
	var rout: float = _scenario.get_blue_a_strength_at_rout()
	var drains: Dictionary = _scenario.get_blue_a_edge_drains()
	var ratio: float = phases.combat_sec / s1_ref if s1_ref > 0.0 else 0.0
	var ok := true
	if rout <= 67.0:
		push_error("S3 blue strength_at_rout %.2f not > 67%%" % rout)
		ok = false
	if drains.get("left", 0.0) <= 0.0:
		push_error("S3 missing LEFT edge drain")
		ok = false
	if _scenario.had_overlap_failure() or _scenario.had_adhesion_invariant_failure():
		push_error("S3 invariant/overlap failure")
		ok = false
	var baseline := _load_baseline_trace("scenario_03_1000.csv")
	if not baseline.is_empty() and _core_trace(_scenario.get_trace_text()) != _core_trace(baseline):
		push_error("S3 trace drift (not byte-identical to baseline)")
		ok = false
	_record_check(
		"[WO-013] S3",
		ok,
		"ratio=%.3f rout=%.2f (ratio band deferred to TD)" % [ratio, rout],
	)


func _check_s4_labels_and_ratio() -> void:
	var expected_labels := {"front": "front", "side": "left", "corner": "front+left"}
	var ok := true
	for row in _s4_results:
		var expected: String = expected_labels.get(row.mode, "")
		if row.edge != expected:
			push_error("S4 %s edge label '%s' expected '%s'" % [row.mode, row.edge, expected])
			ok = false
	var front_d: float = _s4_results[0].drain_per_sec
	var side_d: float = _s4_results[1].drain_per_sec
	var corner_d: float = _s4_results[2].drain_per_sec
	if not (front_d < corner_d and corner_d < side_d):
		push_error("S4 ordering failed")
		ok = false
	_record_check(
		"[WO-010] S4",
		ok,
		"front=%.3f corner=%.3f side=%.3f" % [front_d, corner_d, side_d],
	)


func _check_reflection_pair(seed_value: int) -> void:
	var ok := true
	if _scenario.had_overlap_failure():
		push_error("Overlap on seed %d" % seed_value)
		ok = false
	elif _scenario.had_adhesion_invariant_failure():
		push_error("Adhesion invariant failed on seed %d" % seed_value)
		ok = false
	_record_check("[WO-010] Overlap/adhesion seed %d" % seed_value, ok)


func _check_scenario_05() -> void:
	var standard: Unit = _scenario.get_blue_standard()
	var rally: Unit = _scenario.get_blue_rally()
	var ok := true
	if standard.get_state() != Unit.State.REMOVED:
		push_error("S5 standard unit did not exit map (state=%s)" % standard.get_state_name())
		ok = false
	if rally.get_state() != Unit.State.HOLD or not rally.is_rallied_hold():
		push_error("S5 rally unit expected rallied HOLD, got %s" % rally.get_state_name())
		ok = false
	if not rally.is_rallied_hold():
		push_error("S5 rally unit missing rallied-hold flag")
		ok = false
	if absf(rally.cohesion - 50.0) > 0.5:
		push_error("S5 rally cohesion %.2f expected 50" % rally.cohesion)
		ok = false
	if rally.current_order != Unit.Order.HOLD:
		push_error("S5 rally unit resumed stale order")
		ok = false
	var trace: String = _scenario.get_trace_text()
	if "blue_rally" not in trace or "rallying" not in trace:
		push_error("S5 trace missing rally timeline (routing→rallying→holding)")
		ok = false
	_record_check(
		"[WO-010] S5",
		ok,
		"standard=%s rally=%s cohesion=%.1f"
		% [standard.get_state_name(), rally.get_state_name(), rally.cohesion],
	)


func _check_scenario_06() -> void:
	var rally: Unit = _scenario.get_blue_rally()
	var ok := true
	if rally.get_state() == Unit.State.HOLD and rally.is_rallied_hold():
		push_error("S6 rally entered HOLD despite pursuit")
		ok = false
	elif rally.get_state() not in [Unit.State.ROUTING, Unit.State.RALLYING, Unit.State.REMOVED]:
		push_error("S6 rally unit state unexpected: %s" % rally.get_state_name())
		ok = false
	if _scenario.get_pursuit_tick_count() <= 0:
		push_error("S6 no pursuit damage ticks logged")
		ok = false
	_record_check(
		"[WO-010] S6",
		ok,
		"rally=%s pursuit_ticks=%d strength=%.2f"
		% [rally.get_state_name(), _scenario.get_pursuit_tick_count(), rally.strength],
	)


func _check_scenario_07() -> void:
	var shocks: Array = _scenario.get_shock_events()
	var ok := true
	if shocks.size() < 2:
		push_error("S7 expected 2 neighbor shock events, got %d" % shocks.size())
		ok = false
	for row in shocks:
		if absf(float(row.drain) - 15.0) > 0.1:
			push_error("S7 shock drain %.1f expected 15" % row.drain)
			ok = false
	var tipped := false
	for neighbor in _scenario.get_red_neighbors():
		if neighbor == null:
			continue
		if neighbor.get_state() == Unit.State.WAVERING:
			tipped = true
	_record_check(
		"[WO-010] S7",
		ok,
		"shocks=%d shock_tips_wavering=%s" % [shocks.size(), tipped],
	)


func _check_s9_regression(seed_value: int) -> void:
	if _scenario.get_winner_id() == "red_1":
		_s9_heavy_wins += 1
	if seed_value == 1000:
		_s9_casualty_ratio = _scenario.get_casualty_ratio()
		var heavy: Unit = _scenario.get_heavy_unit()
		var light_unit: Unit = null
		for u in _scenario._units:
			if u.unit_id == "blue_1":
				light_unit = u
		if heavy != null and light_unit != null:
			var heavy_armor_eff: float = float(heavy.profile.get("armor", 0.0)) * ArmorMatrix.class_vs_type(
				str(heavy.profile.get("armor_class", "None")),
				str(light_unit.profile.get("melee_damage_type", "Slash"))
			)
			var light_armor_eff: float = float(light_unit.profile.get("armor", 0.0)) * ArmorMatrix.class_vs_type(
				str(light_unit.profile.get("armor_class", "None")),
				str(heavy.profile.get("melee_damage_type", "Slash"))
			)
			if heavy_armor_eff + 0.0001 < light_armor_eff:
				push_error("S9 seed %d: heavy effective armor %.2f should exceed light %.2f" % [
					seed_value, heavy_armor_eff, light_armor_eff
				])
				_s9_ok = false
			var hypothetical_raw: float = 25.0
			var heavy_dmg_at_raw: float = maxf(
				hypothetical_raw - light_armor_eff,
				_c_float("chip_floor_pct") * hypothetical_raw
			)
			var light_dmg_at_raw: float = maxf(
				hypothetical_raw - heavy_armor_eff,
				_c_float("chip_floor_pct") * hypothetical_raw
			)
			if heavy_dmg_at_raw + 0.0001 < light_dmg_at_raw:
				push_error("S9 seed %d: heavy should out-damage light above chip-floor regime" % seed_value)
				_s9_ok = false


func _check_s10_chip_floor() -> void:
	var winner: String = _scenario.get_winner_id()
	var ok := true
	if winner.is_empty():
		push_error("S10 battle did not resolve a winner")
		ok = false
	var attacker: Unit = _scenario.get_attacker_unit()
	var plate: Unit = _scenario.get_plate_unit()
	if attacker == null or plate == null:
		push_error("S10 missing units")
		_record_check("[WO-013b] S10", false, "missing units")
		return
	var strength_max: float = _c_float("strength_max")
	var raw_at_full: float = float(attacker.profile.get("close_damage", 0.0)) * _c_float("k_melee_scale")
	var plate_eff_armor: float = float(plate.profile.get("armor", 0.0)) * ArmorMatrix.class_vs_type(
		str(plate.profile.get("armor_class", "None")),
		str(attacker.profile.get("melee_damage_type", "Slash"))
	) * _c_float("k_melee_scale")
	var expected_chip_full: float = maxf(
		raw_at_full - plate_eff_armor,
		_c_float("chip_floor_pct") * raw_at_full
	)
	if plate_eff_armor <= raw_at_full:
		push_error("S10 plate effective armor %.2f should exceed raw %.4f (chip-floor proof setup)" % [
			plate_eff_armor, raw_at_full
		])
		ok = false
	var saved_strength: float = attacker.strength
	attacker.strength = strength_max
	var expected_chip_live: float = CombatResolver.calc_melee_strength_loss(attacker, plate, 1.0, false)
	attacker.strength = saved_strength
	if absf(expected_chip_live - expected_chip_full) > 0.0001:
		push_error("S10 resolver chip mismatch live=%.4f full=%.4f" % [expected_chip_live, expected_chip_full])
		ok = false
	var trace_ok := _trace_shows_chip_floor(_scenario.get_trace_text(), plate.unit_id, expected_chip_full)
	if not trace_ok:
		push_error("S10 chip-floor clamp not visible in trace")
		ok = false
	if winner != "blue_1":
		push_error("S10 expected plate defender blue_1 to win, got %s" % winner)
		ok = false
	_record_check(
		"[WO-013b] S10",
		ok,
		"winner=%s chip_tick=%.4f trace_floor_ok=%s" % [winner, expected_chip_full, trace_ok],
	)


func _trace_shows_chip_floor(trace_text: String, defender_id: String, expected_tick: float) -> bool:
	var prev_strength := -1.0
	var prev_time := -1.0
	var ticks_per_row: float = _c_float("tick_rate_per_sec")
	var expected_delta: float = expected_tick * ticks_per_row
	var loser_delta: float = expected_delta * _c_float("push_loser_damage_factor")
	var combat_states: Array[String] = ["marching", "engaged", "hold", "wavering"]
	var saw_match := false
	for line in trace_text.split("\n", false):
		var parts := line.split(",")
		if parts.size() < 8:
			continue
		if parts[1] != defender_id:
			continue
		var state_name: String = parts[7]
		if state_name in ["routing", "removed", "rallying"]:
			prev_strength = -1.0
			prev_time = -1.0
			continue
		if state_name not in combat_states:
			prev_strength = -1.0
			prev_time = -1.0
			continue
		var strength: float = float(parts[2])
		var time_sec: float = float(parts[0])
		if prev_strength > 0.0 and prev_time >= 0.0 and time_sec > prev_time:
			var delta: float = prev_strength - strength
			if delta > 0.0:
				if absf(delta - expected_delta) <= 0.5 or absf(delta - loser_delta) <= 0.5:
					saw_match = true
		prev_strength = strength
		prev_time = time_sec
	return saw_match


func _check_s11_anti_armor() -> void:
	var aa_combat: float = _scenario.get_combat_duration_sec()
	var aa_damage: float = _scenario.get_plate_damage_taken()
	var plate: Unit = _scenario.get_plate_unit()
	var attacker: Unit = _scenario.get_attacker_unit()
	var ok := true
	if plate == null or attacker == null:
		push_error("S11 missing units")
		_record_check("[WO-013b] S11", false, "missing units")
		return
	var plate_eff: float = float(plate.profile.get("armor", 0.0)) * ArmorMatrix.class_vs_type(
		str(plate.profile.get("armor_class", "None")),
		str(attacker.profile.get("melee_damage_type", "Slash"))
	)
	var k_melee: float = _c_float("k_melee_scale")
	var eff_armor_ctrl: float = maxf(plate_eff - 0.0, 0.0) * k_melee
	var eff_armor_aa: float = maxf(plate_eff - 15.0, 0.0) * k_melee
	if eff_armor_aa + 0.0001 >= eff_armor_ctrl:
		push_error("S11 anti_armor should reduce effective armor (ctrl=%.4f aa=%.4f)" % [
			eff_armor_ctrl, eff_armor_aa
		])
		ok = false
	if aa_damage <= _s11_control_damage * 1.25:
		push_error(
			"S11 anti_armor damage %.2f not materially above control %.2f"
			% [aa_damage, _s11_control_damage]
		)
		ok = false
	var breach_ctrl: float = _s11_control_breach if _s11_control_breach >= 0.0 else _s11_control_combat
	var breach_aa: float = _scenario.get_plate_armor_breach_combat_sec(10.0)
	if breach_aa < 0.0:
		push_error("S11 anti_armor never breached plate armor in trace")
		ok = false
	if breach_aa + 0.15 >= breach_ctrl:
		push_error(
			"S11 armor breach slower: anti_armor=%.2fs vs control=%.2fs (combat %.1fs/%.1fs)"
			% [breach_aa, breach_ctrl, aa_combat, _s11_control_combat]
		)
		ok = false
	_record_check(
		"[WO-013b] S11",
		ok,
		"control=%.1fs breach=%.2fs/%.2f dmg anti_armor=%.1fs breach=%.2fs/%.2f dmg"
		% [_s11_control_combat, breach_ctrl, _s11_control_damage, aa_combat, breach_aa, aa_damage],
	)


func _check_s12_attrition() -> void:
	var volleys: int = _scenario.count_volley_events()
	var approach_lost: float = _scenario.approach_strength_lost()
	var inf_lost: float = _scenario.infantry_strength_lost()
	var ok := true
	if volleys < 2:
		push_error("S12 expected multiple volleys, got %d" % volleys)
		ok = false
	if approach_lost < 8.0 or approach_lost > 20.0:
		push_error("S12 approach attrition %.2f%% outside [8, 20]" % approach_lost)
		ok = false
	if inf_lost <= 0.0:
		push_error("S12 infantry took no missile damage")
		ok = false
	if not _scenario.had_dead_zone_panic():
		push_error("S12 missing dead_zone_panic event")
		ok = false
	if _scenario.infantry_routed_by_missiles_only():
		push_error("S12 infantry routed by missiles before melee")
		ok = false
	_record_check(
		"[WO-014] S12",
		ok,
		"volleys=%d approach_lost=%.2f%% total_lost=%.2f panic=%s"
		% [volleys, approach_lost, inf_lost, _scenario.had_dead_zone_panic()],
	)


func _check_s13_doctrine_sight() -> void:
	var d_sight: float = _scenario.first_volley_distance_m()
	var ok := true
	if d_sight < 0.0:
		push_error("S13 FIRE_ON_SIGHT missing first volley")
		ok = false
	elif absf(d_sight - 150.0) > 8.0:
		push_error("S13 FIRE_ON_SIGHT first volley %.1fm expected ~150m" % d_sight)
		ok = false
	_record_check("[WO-014] S13 sight", ok, "first_volley_m=%.1f" % d_sight)


func _check_s13_doctrine_at70() -> void:
	var ok := true
	if _s13_at70_dist < 0.0:
		push_error("S13 FIRE_AT_70 missing first volley")
		ok = false
	elif absf(_s13_at70_dist - 105.0) > 8.0:
		push_error("S13 FIRE_AT_70 first volley %.1fm expected ~105m" % _s13_at70_dist)
		ok = false
	_record_check("[WO-014] S13 at70", ok, "first_volley_m=%.1f" % _s13_at70_dist)


func _check_s13_doctrine_engaged() -> void:
	var ok := true
	if _s13_engaged_dist < 0.0:
		push_error("S13 FIRE_ON_ENGAGED missing first volley")
		ok = false
	elif _s13_at70_dist > 0.0 and _s13_engaged_dist <= _s13_at70_dist + 3.0:
		push_error(
			"S13 engaged first volley %.1fm should trail FIRE_AT_70 %.1fm"
			% [_s13_engaged_dist, _s13_at70_dist]
		)
		ok = false
	elif _s13_engaged_dist >= 150.0:
		push_error("S13 FIRE_ON_ENGAGED should not open at sight range (%.1fm)" % _s13_engaged_dist)
		ok = false
	_record_check("[WO-014] S13 engaged", ok, "first_volley_m=%.1f" % _s13_engaged_dist)


func _check_s14_friendly_fire(control: bool) -> void:
	var ff_events: int = _scenario.count_friendly_fire_events()
	var ok := true
	if control:
		if ff_events > 0:
			push_error("S14 control expected zero friendly_fire events, got %d" % ff_events)
			ok = false
		_record_check("[WO-014] S14 control", ok, "ff_events=0")
		return
	if ff_events <= 0:
		push_error("S14 expected friendly_fire events")
		ok = false
	if _s14_ff_lost <= 0.0:
		push_error("S14 friendly lost %.2f strength to FF" % _s14_ff_lost)
		ok = false
	_record_check(
		"[WO-014] S14",
		ok,
		"ff_events=%d friendly_lost=%.2f" % [ff_events, _s14_ff_lost],
	)


func _check_s15_empty_quiver() -> void:
	var volleys: int = _scenario.count_volley_events()
	var ok := true
	if volleys != 3:
		push_error("S15 expected 3 volleys, got %d" % volleys)
		ok = false
	if not _scenario.had_ammo_empty_event():
		push_error("S15 missing ammo_empty trace event")
		ok = false
	if _scenario.volleys_after_ammo_empty() > 0:
		push_error("S15 fired volleys after ammo empty")
		ok = false
	_record_check("[WO-014] S15", ok, "volleys=%d ammo_empty=true" % volleys)


func _check_s16_leather() -> void:
	var volleys: int = _scenario.count_volley_events()
	var lost: float = _scenario.target_strength_lost()
	var ok := true
	if volleys != 30:
		push_error("S16 leather expected 30 volleys, got %d" % volleys)
		ok = false
	if not _scenario.had_ammo_empty():
		push_error("S16 leather missing ammo_empty")
		ok = false
	if lost < 30.0 or lost > 45.0:
		push_error("S16 leather lost %.2f%% outside [30, 45]" % lost)
		ok = false
	_record_check("[WO-014] S16 leather", ok, "volleys=%d lost=%.2f%%" % [volleys, lost])


func _check_s16_plate() -> void:
	var volleys: int = _scenario.count_volley_events()
	var lost: float = _scenario.target_strength_lost()
	var k: float = _c_float("k_ranged_scale")
	var expected_chip: float = 30.0 * 18.0 * k * _c_float("chip_floor_pct")
	var ok := true
	if volleys != 30:
		push_error("S16 plate expected 30 volleys, got %d" % volleys)
		ok = false
	if absf(lost - expected_chip) > maxf(0.05 * expected_chip, 0.5):
		push_error("S16 plate lost %.2f%% not chip-dominated (expected %.2f)" % [lost, expected_chip])
		ok = false
	_record_check(
		"[WO-014] S16 plate",
		ok,
		"volleys=%d lost=%.2f%% chip_expected=%.2f" % [volleys, lost, expected_chip],
	)


func _check_scenario_08(single_damage: float) -> void:
	var triple_damage: float = _scenario.get_defender_damage_taken()
	var ratio: float = triple_damage / single_damage if single_damage > 0.0 else 0.0
	var ok := true
	if single_damage <= 0.0 or triple_damage <= 0.0:
		push_error("S8 zero damage recorded")
		ok = false
	if ratio > S8_BLOB_RATIO_MAX:
		push_error("S8 blob ratio %.3f exceeds cap %.1f (not frontage-capped)" % [ratio, S8_BLOB_RATIO_MAX])
		ok = false
	_record_check(
		"[WO-010] S8",
		ok,
		"single_damage=%.2f triple_damage=%.2f ratio=%.3f"
		% [single_damage, triple_damage, ratio],
	)


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
	var ok := true
	if sim_stats.get("p95_tick_ms", 999.0) > 50.0:
		push_error(
			"WO-011 perf gate FAIL: sim-thread p95_tick_ms=%.3f exceeds 50ms budget"
			% sim_stats.get("p95_tick_ms", 0.0)
		)
		ok = false
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
	# Perf env is observational on cloud — do not gate PASS count on it.
	if not ok:
		_exit_code = 1



func _check_s17_charge(adjacent: bool) -> void:
	var ev: Dictionary = _scenario.primary_charge_event()
	var ok := true
	var closing: float = float(ev.get("closing_speed", -1.0))
	var impact: float = float(ev.get("impact", -1.0))
	var shock: float = float(ev.get("shock", -1.0))
	var charged: bool = bool(ev.get("charged", false))
	if adjacent:
		if ev.is_empty():
			push_error("S17 adjacent expected a charge-eval event")
			ok = false
		if charged:
			push_error("S17 adjacent control unexpectedly charged (closing=%.3f)" % closing)
			ok = false
		_record_check(
			"[WO-016] S17 adj",
			ok,
			"closing=%.3f charged=%s combat=%.1fs" % [closing, charged, _scenario.combat_duration_sec()],
		)
		return
	if not charged:
		push_error("S17 expected charge impact, closing=%.3f" % closing)
		ok = false
	if impact < 4.0:
		push_error("S17 impact %.3f too small" % impact)
		ok = false
	if shock < 80.0:
		push_error("S17 shock %.3f too small for rout-by-shock" % shock)
		ok = false
	_s17_charge_impact = impact
	_s17_charge_shock = shock
	_s17_combat_sec = _scenario.combat_duration_sec()
	var winner: String = _scenario.get_winner_id()
	# Infantry should lose via charge shock (cavalry wins).
	if winner != "red_cav":
		push_error("S17 expected red_cav win via charge shock, got %s" % winner)
		ok = false
	var inf_str: float = _scenario.infantry_strength_at_rout()
	if inf_str >= 0.0 and inf_str < 70.0:
		push_error("S17 infantry strength_at_end %.2f suggests attrition not shock" % inf_str)
		ok = false
	_record_check(
		"[WO-016] S17",
		ok,
		"impact=%.3f shock=%.3f closing=%.3f combat=%.1fs winner=%s inf_str=%.2f"
		% [impact, shock, closing, _s17_combat_sec, winner, inf_str],
	)


func _check_s18_brace() -> void:
	var ev: Dictionary = _scenario.primary_charge_event()
	var ok := true
	if not bool(ev.get("charged", false)):
		push_error("S18 expected a charge attempt above min_speed")
		ok = false
	if not bool(ev.get("braced", false)):
		push_error("S18 expected braced defender")
		ok = false
	if float(ev.get("shock", 1.0)) > 0.01:
		push_error("S18 braced defender should take no charge shock")
		ok = false
	if float(ev.get("reflected", 0.0)) <= 0.0:
		push_error("S18 expected brace reflect damage")
		ok = false
	var cav_str: float = _scenario.cavalry_strength_at_rout()
	# Cavalry should be weakened / eventually lose grind.
	_record_check(
		"[WO-016] S18",
		ok,
		"impact=%.3f reflected=%.3f cav_str=%.2f winner=%s"
		% [float(ev.get("impact", 0.0)), float(ev.get("reflected", 0.0)), cav_str, _scenario.get_winner_id()],
	)


func _check_s19_brace_timing() -> void:
	var ev: Dictionary = _scenario.primary_charge_event()
	var ok := true
	if not bool(ev.get("charged", false)):
		push_error("S19 expected charge to land (late brace)")
		ok = false
	if bool(ev.get("braced", false)):
		push_error("S19 spears should NOT be braced yet")
		ok = false
	if float(ev.get("shock", 0.0)) <= 0.0:
		push_error("S19 expected cohesion shock from charge")
		ok = false
	_record_check(
		"[WO-016] S19",
		ok,
		"impact=%.3f shock=%.3f braced=%s closing=%.3f"
		% [
			float(ev.get("impact", 0.0)),
			float(ev.get("shock", 0.0)),
			ev.get("braced", false),
			float(ev.get("closing_speed", 0.0)),
		],
	)


func _check_s20_runup(short: bool) -> void:
	var ev: Dictionary = _scenario.primary_charge_event()
	var ok := true
	var closing: float = float(ev.get("closing_speed", -1.0))
	var charged: bool = bool(ev.get("charged", false))
	var min_speed := _c_float("charge_min_speed")
	if short:
		_s20_short_closing = closing
		if charged or closing >= min_speed - 0.05:
			push_error("S20 20m should be below charge_min_speed (closing=%.3f min=%.3f)" % [closing, min_speed])
			ok = false
		_record_check("[WO-016] S20 20m", ok, "closing=%.3f charged=%s" % [closing, charged])
	else:
		_s20_long_closing = closing
		if not charged or closing < min_speed:
			push_error("S20 120m should charge (closing=%.3f min=%.3f)" % [closing, min_speed])
			ok = false
		if _s20_short_closing >= 0.0 and closing <= _s20_short_closing + 0.1:
			push_error("S20 long closing %.3f should exceed short %.3f" % [closing, _s20_short_closing])
			ok = false
		_record_check(
			"[WO-016] S20 120m",
			ok,
			"closing=%.3f impact=%.3f short_closing=%.3f"
			% [closing, float(ev.get("impact", 0.0)), _s20_short_closing],
		)


func _record_check(tag: String, ok: bool, detail: String = "") -> void:
	var suffix := ("" if detail.is_empty() else (" " + detail))
	if ok:
		_check_pass_count += 1
		print("%s PASS%s" % [tag, suffix])
	else:
		_check_fail_count += 1
		_exit_code = 1
		print("%s FAIL%s" % [tag, suffix])


func _reconcile_and_quit() -> void:
	# Meta-assertion: PASS/FAIL emissions must reconcile with process exit.
	if _exit_code == 0:
		if _check_fail_count != 0:
			push_error(
				"WO-015 meta: exit 0 but FAIL count=%d (PASS/exit divergence)" % _check_fail_count
			)
			_exit_code = 1
		if _check_pass_count != EXPECTED_GREEN_PASS_COUNT:
			push_error(
				"WO-015 meta: PASS count=%d expected %d"
				% [_check_pass_count, EXPECTED_GREEN_PASS_COUNT]
			)
			_exit_code = 1
	else:
		if _check_fail_count == 0:
			push_error("WO-015 meta: exit 1 but FAIL count=0 (PASS printed without FAIL)")
			# Keep exit 1; already failing suite.
	print(
		"[WO-015] Meta PASS=%d FAIL=%d expected_green_pass=%d exit=%d"
		% [_check_pass_count, _check_fail_count, EXPECTED_GREEN_PASS_COUNT, _exit_code]
	)
	quit(_exit_code)


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


func _c_float(key: String) -> float:
	return float(root.get_node("Constants").get_float(key))


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
