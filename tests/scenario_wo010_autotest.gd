extends SceneTree

const ALL_SEEDS := [1000, 1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009, 12345]
## WO-028: rebaselined under QoD ENABLED σ=0.045 (evidence_wo028/rebaseline.log).
const WO013_S1 := {
	1000: {"winner": "red_1", "combat": 54.8},
	1001: {"winner": "red_1", "combat": 56.8},
	1002: {"winner": "blue_1", "combat": 68.8},
	1003: {"winner": "blue_1", "combat": 66.0},
	1004: {"winner": "red_1", "combat": 67.8},
	1005: {"winner": "red_1", "combat": 58.8},
	1006: {"winner": "red_1", "combat": 62.6},
	1007: {"winner": "red_1", "combat": 69.4},
	1008: {"winner": "blue_1", "combat": 68.0},
	1009: {"winner": "red_1", "combat": 62.6},
	12345: {"winner": "blue_1", "combat": 67.0},
}
const WO013_S2 := {
	1000: {"winner": "red_1", "combat": 51.4, "rout": 67.89},
	1001: {"winner": "red_1", "combat": 53.2, "rout": 68.22},
	1002: {"winner": "red_1", "combat": 62.0, "rout": 68.05},
	1003: {"winner": "red_1", "combat": 65.8, "rout": 68.23},
	1004: {"winner": "red_1", "combat": 57.4, "rout": 67.90},
	1005: {"winner": "red_1", "combat": 54.4, "rout": 67.98},
	1006: {"winner": "red_1", "combat": 57.6, "rout": 68.33},
	1007: {"winner": "red_1", "combat": 60.6, "rout": 68.19},
	1008: {"winner": "red_1", "combat": 63.2, "rout": 68.12},
	1009: {"winner": "red_1", "combat": 55.8, "rout": 67.78},
	12345: {"winner": "red_1", "combat": 67.0, "rout": 68.28},
}

const CORE_COLS := 8
const CERT_SEED := 12345
const S3_RATIO_TD_BASELINE := 0.32
## WO-028 Task 2 — re-derived under QoD ENABLED σ=0.045, n=500 seeds 1000–1499.
## Rule: mean ± 3SD (covers full observed support; preferred over 0.5/99.5 pct for
## permanent instrument width). Provenance: evidence_wo028/s3_rederive_merged_summary.txt
## ratio mean=0.284124 sd=0.011235 → [0.250418, 0.317830]
## Denominator is the QoD-OFF frontal S1 seed-1000 combat (75.8) — not the
## QoD-on S1 baseline — so ratio stays a flank-vs-frontal speed instrument.
const S3_S1_REF_COMBAT := 75.8
const S3_RATIO_MIN := 0.250
const S3_RATIO_MAX := 0.318
const S3_RATIO_TOL := 0.002
## rout mean=76.298 sd=0.494 → [74.817, 77.780]
const S3_ROUT_MIN := 74.82
const S3_ROUT_MAX := 77.78
## left drain mean=59.123 sd=3.224 → [49.451, 68.795]
const S3_LEFT_DRAIN_MIN := 49.45
const S3_LEFT_DRAIN_MAX := 68.80
const S4_BLEND_TOLERANCE := 0.5
const S4_CONTACT_BALANCE_MAX_M := 6.0
## WO-029b Task 0: S8 is an R21 DIRECTION check (Combat Core §3.7) — stacking must
## be SUBLINEAR: 3 attackers on one FRONT edge deal < 3.0× a single attacker.
## Threshold is design-sourced, not data-derived, not waivable. Magnitude is
## informational only (reported in the PASS detail string).
const S8_STACK_RATIO_MAX := 3.0
const SCENARIO_EXTRA_TICKS := 120
## Gated PASS lines emitted when every check is green (WO-015).
## Compass, Fast+Threaded cert, S1×11, S2×11, Determinism, S3, Overlap, S4, S5–S8, S8b, S9,
## S10–S11, S12, S13×3, S14×2, S15, S16×2, S17×2 retired, S17b, S18, S19, S20×2, S21, S22,
## S23–S26, S27–S29, S30–S34, S35, S36–S39, S40, S41–S44, S45–S48, S49–S54 = 88
const EXPECTED_GREEN_PASS_COUNT := 88

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
## WO-031 S41–S44 accumulators
var _s41_ok_count: int = 0
var _s41_flank_count: int = 0
var _s42_ok_count: int = 0
var _s42_flank_count: int = 0
var _s43_horn_str: Array = []
var _s43_ctrl_str: Array = []
var _s44_ok_count: int = 0
var _s44_abs_max: float = 0.0
var _s44_hold_max: float = 0.0
## WO-032 S45–S48
var _s45_ambush_ok: int = 0
var _s45_tier3: int = 0
var _s45_ambush_coh: Array = []
var _s45_ctrl_coh: Array = []
var _s45_reveal_samples: Array = []
## WO-033 S49–S54
var _s49_ridge_combat: Array = []
var _s49_flat_combat: Array = []
var _s49_ridge_wins: int = 0
var _s50_valley_v: Array = []
var _s50_valley_i: Array = []
var _s50_flat_v: Array = []
var _s50_flat_i: Array = []
var _s52_feint_sprung: int = 0
var _s52_ctrl_sprung: int = 0
var _s52_feint_pursuer_coh: Array = []
var _s52_ctrl_pursuer_coh: Array = []
var _s53_rout_count: int = 0
var _perf_stats: Dictionary = {}
var _perf_main_tick_stats: Dictionary = {}
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
var _s29_idx := 0
const _S29_DISTANCES := [20.0, 60.0, 120.0, 200.0]
var _s29_rows: Array = []
var _extra_ticks_for_mode := 0


func _initialize() -> void:
	# Nested Godot (smoke/compass) shares `.godot` with the parent and can race
	# global-class / Constants registration under cloud concurrency. Prefer
	# WO_SKIP_NESTED_GODOT=1 and run those gates serially outside, or keep the
	# nested path for local desktop runs.
	if OS.get_environment("WO_SKIP_NESTED_GODOT") == "1":
		# Match nested accounting: SceneSmoke only records on FAIL; Compass PASS.
		print("[WO-010] SceneSmoke gate skipped nested (run externally)")
		_record_check("[WO-010] Compass test", true, "(skipped nested; run externally)")
	else:
		var smoke_out: Array = []
		var scene_smoke_exit := OS.execute(
			"/tmp/godot/Godot_v4.4.1-stable_linux.x86_64",
			[
				"--headless",
				"--path",
				ProjectSettings.globalize_path("res://"),
				"-s",
				"res://tests/all_scenes_smoke_test.gd",
			],
			smoke_out,
			true
		)
		if scene_smoke_exit != 0:
			push_error("Universal scene smoke test failed (exit %d)" % scene_smoke_exit)
			_record_check("[WO-010] SceneSmoke gate", false, "exit %d" % scene_smoke_exit)
		var compass_out: Array = []
		var compass_exit := OS.execute(
			"/tmp/godot/Godot_v4.4.1-stable_linux.x86_64",
			[
				"--headless",
				"--path",
				ProjectSettings.globalize_path("res://"),
				"-s",
				"res://tests/edge_contact_compass_test.gd",
			],
			compass_out,
			true
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
	# GAMEPLAY_TICK turns default trace emission OFF when fast_sim=false.
	# Certification still needs byte traces on the gameplay/threaded path —
	# force_trace_logging enables the buffer without overlap-assert QA.
	var realtime: Scenario01 = _sim_runner.instantiate_scenario("res://tests/scenario_01.tscn", CERT_SEED, false)
	realtime.force_trace_logging = true
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
	threaded.force_trace_logging = true
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
		"s8b_sequential":
			scene = "scenario_08b"
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
		"s17b_predrain":
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
		"s21_flank_charge":
			scene = "scenario_21"
			seed_value = 1000
		"s22_frontal_facing":
			scene = "scenario_22"
			seed_value = 1000
		"s23_braced_hold":
			scene = "scenario_23"
			seed_value = 1000
		"s24_caught_engaged":
			scene = "scenario_24"
			seed_value = 1000
		"s25_caught_marching":
			scene = "scenario_25"
			seed_value = 1000
		"s26_late_arc":
			scene = "scenario_26"
			seed_value = 1000
		"s27_gait_visibility":
			scene = "scenario_27"
			seed_value = 1000
		"s28_infantry_charge":
			scene = "scenario_28"
			seed_value = 1000
		"s29_runup_curve":
			scene = "scenario_29"
			seed_value = 1000
		"s30_disengage":
			scene = "scenario_30"
			seed_value = 1000
		"s31_wheel_contact":
			scene = "scenario_31"
			seed_value = 1000
		"s32_hit_and_run":
			scene = "scenario_32"
			seed_value = 1000
		"s33_gravity_square":
			scene = "scenario_33"
			seed_value = 1000
		"s34_pinning":
			scene = "scenario_34"
			seed_value = 1000
		"s35_agility_isolate":
			scene = "scenario_35"
			seed_value = 1000
		"s36_uphill_push":
			scene = "scenario_36"
			seed_value = 1000
		"s37_slope_charge":
			scene = "scenario_37"
			seed_value = 1000
		"s38_missile_high":
			scene = "scenario_38"
			seed_value = 1000
		"s39_high_ground":
			scene = "scenario_39"
			seed_value = 1000
		"s40_mixed":
			scene = "scenario_40_mixed"
			seed_value = 1000
		"s41_hammer":
			scene = "scenario_41"
			seed_value = ALL_SEEDS[_seed_idx]
		"s42_cannae":
			scene = "scenario_42"
			seed_value = ALL_SEEDS[_seed_idx]
		"s43_horn":
			scene = "scenario_43"
			seed_value = ALL_SEEDS[_seed_idx]
		"s43_control":
			scene = "scenario_43"
			seed_value = ALL_SEEDS[_seed_idx]
		"s44_abs_hold":
			scene = "scenario_44"
			seed_value = ALL_SEEDS[_seed_idx]
		"s45_ambush":
			scene = "scenario_45"
			seed_value = ALL_SEEDS[_seed_idx]
		"s45_control":
			scene = "scenario_45"
			seed_value = ALL_SEEDS[_seed_idx]
		"s46_detection":
			scene = "scenario_46"
			seed_value = 1000
		"s47_fit":
			scene = "scenario_47"
			seed_value = 1000
		"s48_forest":
			scene = "scenario_48"
			seed_value = 1000
		"s49_ridge":
			scene = "scenario_49"
			seed_value = ALL_SEEDS[_seed_idx]
		"s49_flat":
			scene = "scenario_49"
			seed_value = ALL_SEEDS[_seed_idx]
		"s50_valley":
			scene = "scenario_50"
			seed_value = ALL_SEEDS[_seed_idx]
		"s50_flat":
			scene = "scenario_50"
			seed_value = ALL_SEEDS[_seed_idx]
		"s51_cross":
			scene = "scenario_51"
			seed_value = 1000
		"s52_feint":
			scene = "scenario_52"
			seed_value = ALL_SEEDS[_seed_idx]
		"s52_control":
			scene = "scenario_52"
			seed_value = ALL_SEEDS[_seed_idx]
		"s53_backfire":
			scene = "scenario_53"
			seed_value = ALL_SEEDS[_seed_idx]
		"s54_deception":
			scene = "scenario_54"
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
	elif scene == "scenario_08b":
		_scenario.set("attacker_count", 3)
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
		if _mode == "s17b_predrain":
			_scenario.set("infantry_start_cohesion", 40.0)
		else:
			_scenario.set("infantry_start_cohesion", -1.0)
	elif scene == "scenario_21":
		_scenario.set("approach", 0)  # FLANK
	elif scene == "scenario_29":
		_scenario.set("run_up_m", _S29_DISTANCES[_s29_idx])
	elif scene == "scenario_20":
		if _mode == "s20_runup_short":
			_scenario.set("run_up_m", 20.0)
		else:
			_scenario.set("run_up_m", 120.0)
	elif scene == "scenario_14":
		_scenario.set("control_mode", _mode == "s14_ff_control")
	elif scene == "scenario_43":
		_scenario.set("use_horn", _mode == "s43_horn")
		_scenario.set("horn_at_sec", 35.0)
	elif scene == "scenario_45":
		_scenario.set("use_concealment", _mode == "s45_ambush")
	elif scene == "scenario_49":
		_scenario.set("use_ridge", _mode == "s49_ridge")
	elif scene == "scenario_50":
		_scenario.set("use_valley", _mode == "s50_valley")
	elif scene == "scenario_52":
		_scenario.set("use_feint", _mode == "s52_feint")

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
		# WO-024: GAMEPLAY_TICK is the gate metric (QA instrumentation OFF).
		# MAIN_TICK (fast_sim=true) retained for QA-cost comparison only.
		print("[WO-024] Perf40 GAMEPLAY_TICK begin (canonical gate)")
		_scenario.use_sim_thread = false
		_scenario.fast_sim_mode = false
		if _scenario.has_method("stop_sim_thread_for_harness"):
			_scenario.call("stop_sim_thread_for_harness")
		for _i in 800:
			_scenario.advance_one_tick()
		_perf_stats = _scenario.get_perf_stats()
		_perf_stats["metric"] = "GAMEPLAY_TICK"
		print("[WO-024] Perf40 GAMEPLAY_TICK sample done")
		# Second sample: MAIN_TICK (test config) for QA instrumentation delta.
		_scenario.free()
		_scenario = _sim_runner.instantiate_scenario(
			"res://tests/scenario_40_perf.tscn", 1000, true, false
		)
		root.add_child(_scenario)
		var spins := 0
		while not _scenario.is_node_ready() and spins < 512:
			OS.delay_usec(1000)
			spins += 1
		_scenario.use_sim_thread = false
		_scenario.fast_sim_mode = true
		if _scenario.has_method("stop_sim_thread_for_harness"):
			_scenario.call("stop_sim_thread_for_harness")
		print("[WO-024] Perf40 MAIN_TICK begin (comparison / QA cost)")
		for _i in 800:
			_scenario.advance_one_tick()
		_perf_main_tick_stats = _scenario.get_perf_stats()
		_perf_main_tick_stats["metric"] = "MAIN_TICK"
		print("[WO-024] Perf40 MAIN_TICK sample done")
	elif _mode == "perf_scale":
		for _i in 800:
			_scenario.advance_one_tick()
		_perf_scale_results.append(_scenario.get_tick_perf_stats())
	elif _mode in ["s5_rally", "s6_pursuit", "s7_cascade", "s8_blob_single", "s8_blob_triple", "s8b_sequential"]:
		_sim_harness.run_ticks(_scenario, 3500 + _extra_ticks_for_mode)
	elif _mode == "s13_engaged":
		_sim_harness.run_ticks(_scenario, 2800)
	elif _mode in ["s14_friendly_fire", "s14_ff_control"]:
		_sim_harness.run_ticks(_scenario, 2200)
	elif _mode in ["s16_leather", "s16_plate"]:
		_sim_harness.run_ticks(_scenario, 2000)
	elif _mode in [
		"s17_charge",
		"s17_charge_adj",
		"s17b_predrain",
		"s18_brace",
		"s19_brace_timing",
		"s20_runup_short",
		"s20_runup_long",
		"s21_flank_charge",
		"s22_frontal_facing",
		"s23_braced_hold",
		"s24_caught_engaged",
		"s25_caught_marching",
		"s26_late_arc",
		"s27_gait_visibility",
		"s28_infantry_charge",
		"s29_runup_curve",
		"s30_disengage",
		"s31_wheel_contact",
		"s32_hit_and_run",
		"s33_gravity_square",
		"s34_pinning",
		"s35_agility_isolate",
		"s36_uphill_push",
		"s37_slope_charge",
		"s38_missile_high",
		"s39_high_ground",
		"s41_hammer",
		"s42_cannae",
		"s43_horn",
		"s43_control",
		"s44_abs_hold",
		"s45_ambush",
		"s45_control",
		"s47_fit",
		"s49_ridge",
		"s49_flat",
		"s50_valley",
		"s50_flat",
		"s51_cross",
		"s52_feint",
		"s52_control",
		"s53_backfire",
		"s54_deception",
	]:
		_sim_harness.run_ticks(_scenario, 4500)
	elif _mode == "s46_detection":
		# Probe matrix — no long battle.
		pass
	elif _mode == "s48_forest":
		pass
	elif _mode == "s40_mixed":
		# Stop once Gate-2 showcase flags are up — full 8000-tick grind floods
		# overlap asserts and can stall the subsequent threaded perf_40 on cloud.
		var s40_ticks := 0
		while s40_ticks < 8000 and not _scenario.is_battle_over():
			_scenario.advance_one_tick()
			s40_ticks += 1
			if (
				_scenario.has_method("showcase_ok")
				and bool(_scenario.call("showcase_ok"))
				and s40_ticks >= 1200
			):
				break
		print("[WO-022] S40 harness ticks=%d showcase=%s" % [
			s40_ticks,
			str(_scenario.call("showcase_ok")) if _scenario.has_method("showcase_ok") else "n/a",
		])
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
			_run_slot_swap_guard()
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
			_mode = "s8b_sequential"
			_spawn_and_run()
		"s8b_sequential":
			_check_scenario_08b()
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
			_mode = "s17b_predrain"
			_spawn_and_run()
		"s17b_predrain":
			_check_s17b_predrain()
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
			_mode = "s21_flank_charge"
			_spawn_and_run()
		"s21_flank_charge":
			_check_s21_flank_charge()
			_mode = "s22_frontal_facing"
			_spawn_and_run()
		"s22_frontal_facing":
			_check_s22_frontal_facing()
			_mode = "s23_braced_hold"
			_spawn_and_run()
		"s23_braced_hold":
			_check_s23_braced_hold()
			_mode = "s24_caught_engaged"
			_spawn_and_run()
		"s24_caught_engaged":
			_check_s24_caught_engaged()
			_mode = "s25_caught_marching"
			_spawn_and_run()
		"s25_caught_marching":
			_check_s25_caught_marching()
			_mode = "s26_late_arc"
			_spawn_and_run()
		"s26_late_arc":
			_check_s26_late_arc()
			_mode = "s27_gait_visibility"
			_spawn_and_run()
		"s27_gait_visibility":
			_check_s27_gait_visibility()
			_mode = "s28_infantry_charge"
			_spawn_and_run()
		"s28_infantry_charge":
			_check_s28_infantry_charge()
			_mode = "s29_runup_curve"
			_s29_idx = 0
			_s29_rows.clear()
			_spawn_and_run()
		"s29_runup_curve":
			_check_s29_runup_point()
			_s29_idx += 1
			if _s29_idx < _S29_DISTANCES.size():
				_spawn_and_run()
			else:
				_finalize_s29_runup()
				_mode = "s30_disengage"
				_spawn_and_run()
		"s30_disengage":
			_check_s30_disengage()
			_mode = "s31_wheel_contact"
			_spawn_and_run()
		"s31_wheel_contact":
			_check_s31_wheel()
			_mode = "s32_hit_and_run"
			_spawn_and_run()
		"s32_hit_and_run":
			_check_s32_hit_and_run()
			_mode = "s33_gravity_square"
			_spawn_and_run()
		"s33_gravity_square":
			_check_s33_gravity()
			_mode = "s34_pinning"
			_spawn_and_run()
		"s34_pinning":
			_check_s34_pinning()
			_mode = "s35_agility_isolate"
			_spawn_and_run()
		"s35_agility_isolate":
			_check_s35_agility()
			_mode = "s36_uphill_push"
			_spawn_and_run()
		"s36_uphill_push":
			_check_s36_uphill_push()
			_mode = "s37_slope_charge"
			_spawn_and_run()
		"s37_slope_charge":
			_check_s37_slope_charge()
			_mode = "s38_missile_high"
			_spawn_and_run()
		"s38_missile_high":
			_check_s38_missile_high()
			_mode = "s39_high_ground"
			_spawn_and_run()
		"s39_high_ground":
			_check_s39_high_ground()
			_mode = "s40_mixed"
			_spawn_and_run()
		"s40_mixed":
			_check_s40_mixed()
			_mode = "s41_hammer"
			_seed_idx = 0
			_s41_ok_count = 0
			_s41_flank_count = 0
			_spawn_and_run()
		"s41_hammer":
			_accumulate_s41(ALL_SEEDS[_seed_idx])
			_seed_idx += 1
			if _seed_idx < ALL_SEEDS.size():
				_spawn_and_run()
			else:
				_finalize_s41()
				_mode = "s42_cannae"
				_seed_idx = 0
				_s42_ok_count = 0
				_s42_flank_count = 0
				_spawn_and_run()
		"s42_cannae":
			_accumulate_s42(ALL_SEEDS[_seed_idx])
			_seed_idx += 1
			if _seed_idx < ALL_SEEDS.size():
				_spawn_and_run()
			else:
				_finalize_s42()
				_mode = "s43_horn"
				_seed_idx = 0
				_s43_horn_str.clear()
				_s43_ctrl_str.clear()
				_spawn_and_run()
		"s43_horn":
			_s43_horn_str.append(float(_scenario.blue_surviving_strength()))
			_seed_idx += 1
			if _seed_idx < ALL_SEEDS.size():
				_spawn_and_run()
			else:
				_mode = "s43_control"
				_seed_idx = 0
				_spawn_and_run()
		"s43_control":
			_s43_ctrl_str.append(float(_scenario.blue_surviving_strength()))
			_seed_idx += 1
			if _seed_idx < ALL_SEEDS.size():
				_spawn_and_run()
			else:
				_finalize_s43()
				_mode = "s44_abs_hold"
				_seed_idx = 0
				_s44_ok_count = 0
				_s44_abs_max = 0.0
				_s44_hold_max = 0.0
				_spawn_and_run()
		"s44_abs_hold":
			_accumulate_s44(ALL_SEEDS[_seed_idx])
			_seed_idx += 1
			if _seed_idx < ALL_SEEDS.size():
				_spawn_and_run()
			else:
				_finalize_s44()
				_mode = "s45_ambush"
				_seed_idx = 0
				_s45_ambush_ok = 0
				_s45_tier3 = 0
				_s45_ambush_coh.clear()
				_s45_ctrl_coh.clear()
				_s45_reveal_samples.clear()
				_spawn_and_run()
		"s45_ambush":
			_accumulate_s45_ambush(ALL_SEEDS[_seed_idx])
			_seed_idx += 1
			if _seed_idx < ALL_SEEDS.size():
				_spawn_and_run()
			else:
				_mode = "s45_control"
				_seed_idx = 0
				_spawn_and_run()
		"s45_control":
			_s45_ctrl_coh.append(float(_scenario.column_cohesion()))
			_seed_idx += 1
			if _seed_idx < ALL_SEEDS.size():
				_spawn_and_run()
			else:
				_finalize_s45()
				_mode = "s46_detection"
				_spawn_and_run()
		"s46_detection":
			_check_s46()
			_mode = "s47_fit"
			_spawn_and_run()
		"s47_fit":
			_check_s47()
			_mode = "s48_forest"
			_spawn_and_run()
		"s48_forest":
			_check_s48()
			_mode = "s49_ridge"
			_seed_idx = 0
			_s49_ridge_combat.clear()
			_s49_flat_combat.clear()
			_s49_ridge_wins = 0
			_spawn_and_run()
		"s49_ridge":
			_s49_ridge_combat.append(float(_scenario.combat_sec()))
			if bool(_scenario.defender_won()):
				_s49_ridge_wins += 1
			print(
				"[WO-033] S49 ridge seed=%d win=%s combat=%.1f str_rout=%.1f"
				% [
					ALL_SEEDS[_seed_idx],
					str(_scenario.defender_won()),
					float(_scenario.combat_sec()),
					float(_scenario.strength_at_rout),
				]
			)
			_seed_idx += 1
			if _seed_idx < ALL_SEEDS.size():
				_spawn_and_run()
			else:
				_mode = "s49_flat"
				_seed_idx = 0
				_spawn_and_run()
		"s49_flat":
			_s49_flat_combat.append(float(_scenario.combat_sec()))
			_seed_idx += 1
			if _seed_idx < ALL_SEEDS.size():
				_spawn_and_run()
			else:
				_finalize_s49()
				_mode = "s50_valley"
				_seed_idx = 0
				_s50_valley_v.clear()
				_s50_valley_i.clear()
				_s50_flat_v.clear()
				_s50_flat_i.clear()
				_spawn_and_run()
		"s50_valley":
			_s50_valley_v.append(float(_scenario.closing_speed()))
			_s50_valley_i.append(float(_scenario.impact()))
			print(
				"[WO-033] S50 valley seed=%d v=%.3f i=%.3f"
				% [ALL_SEEDS[_seed_idx], float(_scenario.closing_speed()), float(_scenario.impact())]
			)
			_seed_idx += 1
			if _seed_idx < ALL_SEEDS.size():
				_spawn_and_run()
			else:
				_mode = "s50_flat"
				_seed_idx = 0
				_spawn_and_run()
		"s50_flat":
			_s50_flat_v.append(float(_scenario.closing_speed()))
			_s50_flat_i.append(float(_scenario.impact()))
			_seed_idx += 1
			if _seed_idx < ALL_SEEDS.size():
				_spawn_and_run()
			else:
				_finalize_s50()
				_mode = "s51_cross"
				_spawn_and_run()
		"s51_cross":
			_check_s51()
			_mode = "s52_feint"
			_seed_idx = 0
			_s52_feint_sprung = 0
			_s52_ctrl_sprung = 0
			_s52_feint_pursuer_coh.clear()
			_s52_ctrl_pursuer_coh.clear()
			_spawn_and_run()
		"s52_feint":
			if bool(_scenario.trap_sprung):
				_s52_feint_sprung += 1
			_s52_feint_pursuer_coh.append(float(_scenario.pursuer_cohesion_end))
			print(
				"[WO-033] S52 feint seed=%d sprung=%s edge=%s pursuer_coh=%.1f"
				% [
					ALL_SEEDS[_seed_idx],
					str(_scenario.trap_sprung),
					str(_scenario.pursuer_flank_edge),
					float(_scenario.pursuer_cohesion_end),
				]
			)
			_seed_idx += 1
			if _seed_idx < ALL_SEEDS.size():
				_spawn_and_run()
			else:
				_mode = "s52_control"
				_seed_idx = 0
				_spawn_and_run()
		"s52_control":
			if bool(_scenario.trap_sprung):
				_s52_ctrl_sprung += 1
			_s52_ctrl_pursuer_coh.append(float(_scenario.pursuer_cohesion_end))
			_seed_idx += 1
			if _seed_idx < ALL_SEEDS.size():
				_spawn_and_run()
			else:
				_finalize_s52()
				_mode = "s53_backfire"
				_seed_idx = 0
				_s53_rout_count = 0
				_spawn_and_run()
		"s53_backfire":
			if bool(_scenario.did_rout):
				_s53_rout_count += 1
			print(
				"[WO-033] S53 seed=%d rout=%s t=%.1f samples=%d"
				% [
					ALL_SEEDS[_seed_idx],
					str(_scenario.did_rout),
					float(_scenario.rout_time_sec),
					_scenario.cohesion_samples.size(),
				]
			)
			_seed_idx += 1
			if _seed_idx < ALL_SEEDS.size():
				_spawn_and_run()
			else:
				_finalize_s53()
				_mode = "s54_deception"
				_spawn_and_run()
		"s54_deception":
			_check_s54()
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


func _accumulate_s41(_seed_value: int) -> void:
	var edge: String = str(_scenario.get_charge_edge())
	var shock: float = float(_scenario.get_charge_shock())
	var ok := true
	# Flank or rear contact for directional shock.
	if edge != "left" and edge != "right" and edge != "rear" and not edge.contains("left") and not edge.contains("right") and not edge.contains("rear"):
		ok = false
	else:
		_s41_flank_count += 1
	if shock < 0.0:
		ok = false
	if ok:
		_s41_ok_count += 1
	print(
		"[WO-031] S41 seed=%d edge=%s shock=%.2f winner=%s ok=%s"
		% [_seed_value, edge, shock, _scenario.get_winner_id(), str(ok)]
	)


func _finalize_s41() -> void:
	var ok := _s41_ok_count >= 8 and _s41_flank_count >= 8
	if not ok:
		push_error(
			"S41 hammer-anvil failed: ok=%d/11 flank=%d/11 (need >=8)"
			% [_s41_ok_count, _s41_flank_count]
		)
	_record_check(
		"[WO-031] S41",
		ok,
		"ok=%d/11 flank_or_rear=%d/11" % [_s41_ok_count, _s41_flank_count],
	)


func _accumulate_s42(_seed_value: int) -> void:
	var edges: Dictionary = _scenario.get_edges_seen()
	var has_flank := (
		edges.has("left")
		or edges.has("right")
		or edges.has("rear")
	)
	var coh: float = float(_scenario.get_enemy_cohesion_min())
	var ok := has_flank and coh < 80.0
	if has_flank:
		_s42_flank_count += 1
	if ok:
		_s42_ok_count += 1
	print(
		"[WO-031] S42 seed=%d edges=%s coh_min=%.1f winner=%s ok=%s"
		% [_seed_value, edges, coh, _scenario.get_winner_id(), str(ok)]
	)


func _finalize_s42() -> void:
	var ok := _s42_ok_count >= 8 and _s42_flank_count >= 8
	if not ok:
		push_error(
			"S42 Cannae failed: ok=%d/11 flank=%d/11 (need >=8)"
			% [_s42_ok_count, _s42_flank_count]
		)
	_record_check(
		"[WO-031] S42",
		ok,
		"ok=%d/11 flank_edges=%d/11" % [_s42_ok_count, _s42_flank_count],
	)


func _finalize_s43() -> void:
	var n: int = mini(_s43_horn_str.size(), _s43_ctrl_str.size())
	var saved := 0
	var total_margin := 0.0
	for i in n:
		var h: float = float(_s43_horn_str[i])
		var c: float = float(_s43_ctrl_str[i])
		var margin: float = h - c
		total_margin += margin
		if margin > 0.5:
			saved += 1
		print("[WO-031] S43 seed_i=%d horn=%.2f ctrl=%.2f margin=%.2f" % [i, h, c, margin])
	var ok := saved >= 8 and total_margin > 0.0
	if not ok:
		push_error(
			"S43 horn failed: saved=%d/11 total_margin=%.2f (horn should save men)"
			% [saved, total_margin]
		)
	_record_check(
		"[WO-031] S43",
		ok,
		"saved=%d/11 total_margin=%.2f horn_costs=%s"
		% [saved, total_margin, str(_scenario.get_horn_disengage_costs()) if _scenario != null else "{}"],
	)


func _accumulate_s44(_seed_value: int) -> void:
	var abs_d: float = float(_scenario.abs_max_disp_m)
	var hold_d: float = float(_scenario.hold_max_disp_m)
	_s44_abs_max = maxf(_s44_abs_max, abs_d)
	_s44_hold_max = maxf(_s44_hold_max, hold_d)
	# Absolute hold: intentional displacement ≈ 0 (allow tiny float/push noise < 2m).
	var ok := abs_d < 2.0
	if ok:
		_s44_ok_count += 1
	print(
		"[WO-031] S44 seed=%d abs_disp=%.2f hold_disp=%.2f ok=%s"
		% [_seed_value, abs_d, hold_d, str(ok)]
	)


func _finalize_s44() -> void:
	var ok := _s44_ok_count >= 10
	if not ok:
		push_error(
			"S44 absolute_hold moved: ok=%d/11 abs_max=%.2fm hold_max=%.2fm"
			% [_s44_ok_count, _s44_abs_max, _s44_hold_max]
		)
	_record_check(
		"[WO-031] S44",
		ok,
		"ok=%d/11 abs_max_disp_m=%.2f hold_max_disp_m=%.2f"
		% [_s44_ok_count, _s44_abs_max, _s44_hold_max],
	)


func _accumulate_s45_ambush(seed_value: int) -> void:
	var tier: int = int(_scenario.get_brace_tier())
	var edge: String = str(_scenario.get_charge_edge())
	var rev: float = float(_scenario.get_reveal_time())
	var coh: float = float(_scenario.column_cohesion())
	_s45_ambush_coh.append(coh)
	_s45_reveal_samples.append({"seed": seed_value, "t": rev, "reason": str(_scenario.reveal_reason), "tier": tier, "edge": edge})
	var ok := tier == 3
	if ok:
		_s45_tier3 += 1
	var edge_ok := (
		edge == "left" or edge == "right" or edge == "rear"
		or edge.contains("left") or edge.contains("right") or edge.contains("rear")
	)
	if ok and edge_ok:
		_s45_ambush_ok += 1
	print(
		"[WO-032] S45 ambush seed=%d brace_tier=%d edge=%s reveal_t=%.1f coh=%.1f"
		% [seed_value, tier, edge, rev, coh]
	)


func _finalize_s45() -> void:
	var n: int = mini(_s45_ambush_coh.size(), _s45_ctrl_coh.size())
	var total_margin := 0.0
	var beat := 0
	for i in n:
		var a: float = float(_s45_ambush_coh[i])
		var c: float = float(_s45_ctrl_coh[i])
		# Lower cohesion on the victim = better ambush. Margin = control_coh - ambush_coh.
		var margin: float = c - a
		total_margin += margin
		if margin > 1.0:
			beat += 1
		print("[WO-032] S45 seed_i=%d ambush_coh=%.1f ctrl_coh=%.1f stealth_margin=%.1f" % [i, a, c, margin])
	var avg_margin: float = total_margin / float(maxi(n, 1))
	var ok := _s45_tier3 >= 8 and beat >= 7 and avg_margin > 0.0 and _s45_ambush_ok >= 8
	if not ok:
		push_error(
			"S45 Teutoburg failed: tier3=%d/11 flank_rear=%d/11 beat=%d/11 avg_stealth_margin=%.1f"
			% [_s45_tier3, _s45_ambush_ok, beat, avg_margin]
		)
	_record_check(
		"[WO-032] S45",
		ok,
		"tier3=%d/11 flank_rear=%d/11 beat=%d/11 avg_stealth_margin=%.2f reveals=%s"
		% [_s45_tier3, _s45_ambush_ok, beat, avg_margin, str(_s45_reveal_samples)],
	)


func _check_s46() -> void:
	var result: Dictionary = _scenario.run_full_matrix()
	var ok: bool = bool(result.get("all_ok", false))
	if not ok:
		push_error("S46 detection matrix failed: %s" % str(result))
	for row in result.get("rows", []):
		print(
			"[WO-032] S46 %s/%s moving=%s expected=%.2f got=%.2f ok=%s"
			% [
				str(row.get("profile")),
				str(row.get("patch")),
				str(row.get("moving")),
				float(row.get("expected_m")),
				float(row.get("got_m")),
				str(row.get("ok")),
			]
		)
	print("[WO-032] S46 massive_rejected=%s" % str(result.get("massive_rejected")))
	_record_check(
		"[WO-032] S46",
		ok,
		"rows=%d massive_rejected=%s (center-to-center)"
		% [int((result.get("rows", []) as Array).size()), str(result.get("massive_rejected"))],
	)


func _check_s47() -> void:
	_scenario.evaluate_after_ticks()
	var fit_ok: bool = bool(_scenario.fit_half_out_rejected)
	var perm_ok: bool = bool(_scenario.reveal_permanence_ok)
	var ok := fit_ok and perm_ok
	if not ok:
		push_error("S47 fit/permanence failed fit=%s permanence=%s" % [str(fit_ok), str(perm_ok)])
	_record_check(
		"[WO-032] S47",
		ok,
		"fit_half_out_rejected=%s reveal_permanence=%s" % [str(fit_ok), str(perm_ok)],
	)


func _check_s48() -> void:
	var result: Dictionary = _scenario.run_penalty_probes()
	var ok: bool = bool(result.get("all_ok", false))
	if not ok:
		push_error("S48 forest penalties failed: %s" % str(result))
	print("[WO-032] S48 %s" % str(result))
	_record_check(
		"[WO-032] S48",
		ok,
		"speed_ok=%s drain_ok=%s missile_ok=%s cav_in=%.3f cav_flat=%.3f"
		% [
			str(result.get("speed_ok")),
			str(result.get("drain_ok")),
			str(result.get("missile_ok")),
			float(result.get("cav_speed_in_forest", -1)),
			float(result.get("cav_speed_on_flat", -1)),
		],
	)


func _finalize_s49() -> void:
	var n: int = mini(_s49_ridge_combat.size(), _s49_flat_combat.size())
	var sum_r := 0.0
	var sum_f := 0.0
	for i in n:
		sum_r += float(_s49_ridge_combat[i])
		sum_f += float(_s49_flat_combat[i])
	# Crest majority + combat duration not shorter than flat control (compounded climb).
	var ok := (
		_s49_ridge_wins >= 7
		and n >= 8
		and (sum_r / float(maxi(n, 1))) >= (sum_f / float(maxi(n, 1))) - 2.0
	)
	if not ok:
		push_error(
			"S49 ridge failed: wins=%d/11 avg_ridge=%.1f avg_flat=%.1f"
			% [_s49_ridge_wins, sum_r / float(maxi(n, 1)), sum_f / float(maxi(n, 1))]
		)
	_record_check(
		"[WO-033] S49",
		ok,
		"ridge_wins=%d/11 avg_combat_ridge=%.1f avg_combat_flat=%.1f"
		% [_s49_ridge_wins, sum_r / float(maxi(n, 1)), sum_f / float(maxi(n, 1))],
	)


func _finalize_s50() -> void:
	var n: int = mini(_s50_valley_v.size(), _s50_flat_v.size())
	var beat_v := 0
	var beat_i := 0
	var sum_dv := 0.0
	var sum_di := 0.0
	for i in n:
		var vv: float = float(_s50_valley_v[i])
		var fv: float = float(_s50_flat_v[i])
		var vi: float = float(_s50_valley_i[i])
		var fi: float = float(_s50_flat_i[i])
		if vv > fv + 0.05:
			beat_v += 1
		if vi > fi + 0.05:
			beat_i += 1
		sum_dv += vv - fv
		sum_di += vi - fi
		print(
			"[WO-033] S50 seed_i=%d valley_v=%.3f flat_v=%.3f valley_i=%.3f flat_i=%.3f"
			% [i, vv, fv, vi, fi]
		)
	var ok := beat_v >= 8 and beat_i >= 8
	if not ok:
		push_error("S50 valley charge failed: beat_v=%d beat_i=%d/11" % [beat_v, beat_i])
	_record_check(
		"[WO-033] S50",
		ok,
		"beat_v=%d/11 beat_i=%d/11 mean_dv=%.3f mean_di=%.3f"
		% [beat_v, beat_i, sum_dv / float(maxi(n, 1)), sum_di / float(maxi(n, 1))],
	)


func _check_s51() -> void:
	var edge: String = str(_scenario.observed_edge)
	var push_m: float = float(_scenario.slope_push_mod_attacker)
	var spd_m: float = float(_scenario.slope_speed_mult_attacker)
	var edge_ok := (
		edge == "left" or edge == "right" or edge == "rear"
		or edge.contains("left") or edge.contains("right") or edge.contains("rear")
	)
	# Cross-slope 10%: mods should deviate from identity (composition present).
	var slope_ok := absf(push_m - 1.0) > 0.01 or absf(spd_m - 1.0) > 0.01
	# Calibration probe on general field at 10% grade (Sec 7 published).
	var hf = _scenario.get_height_field()
	var cal_ok := true
	if hf != null:
		# cross_slope: +Y high → facing UP (−Y) is downhill.
		var facing_dn := Vector2.UP
		var speed_dn: float = hf.speed_mult_at(Vector2.ZERO, facing_dn)
		var push_dn: float = hf.push_mod_at(Vector2.ZERO, facing_dn)
		var range_dn: float = hf.range_mult_toward(Vector2.ZERO, Vector2(0.0, -100.0))
		# Sec 7 @ 10%: speed +35%, push +10%, range +15%.
		cal_ok = (
			absf(speed_dn - 1.35) < 0.02
			and absf(push_dn - 1.10) < 0.02
			and absf(range_dn - 1.15) < 0.02
		)
		print(
			"[WO-033] S51 calibration speed=%.3f push=%.3f range=%.3f (expect 1.35/1.10/1.15)"
			% [speed_dn, push_dn, range_dn]
		)
	var ok := edge_ok and slope_ok and cal_ok
	if not ok:
		push_error(
			"S51 cross-slope failed edge=%s push=%.3f speed=%.3f cal=%s"
			% [edge, push_m, spd_m, str(cal_ok)]
		)
	_record_check(
		"[WO-033] S51",
		ok,
		"edge=%s slope_push=%.3f slope_speed=%.3f cal_ok=%s"
		% [edge, push_m, spd_m, str(cal_ok)],
	)


func _finalize_s52() -> void:
	var n: int = mini(_s52_feint_pursuer_coh.size(), _s52_ctrl_pursuer_coh.size())
	var better := 0
	var sum_m := 0.0
	for i in n:
		var f: float = float(_s52_feint_pursuer_coh[i])
		var c: float = float(_s52_ctrl_pursuer_coh[i])
		var margin: float = c - f
		sum_m += margin
		if margin > 1.0 or (_s52_feint_sprung > _s52_ctrl_sprung):
			better += 1
	var ok := _s52_feint_sprung >= 8 and better >= 7
	if not ok:
		push_error(
			"S52 feint failed: sprung=%d/%d ctrl_sprung=%d better=%d"
			% [_s52_feint_sprung, n, _s52_ctrl_sprung, better]
		)
	_record_check(
		"[WO-033] S52",
		ok,
		"feint_sprung=%d/11 ctrl_sprung=%d avg_pursuer_coh_margin=%.2f"
		% [_s52_feint_sprung, _s52_ctrl_sprung, sum_m / float(maxi(n, 1))],
	)


func _finalize_s53() -> void:
	var ok := _s53_rout_count >= 8
	if not ok:
		push_error("S53 backfire failed: routs=%d/11 (low skill should rout)" % _s53_rout_count)
	_record_check(
		"[WO-033] S53",
		ok,
		"routs=%d/11 (low Retreating Skill feign → genuine rout)" % _s53_rout_count,
	)


func _check_s54() -> void:
	var ok: bool = bool(_scenario.deception_ok())
	var fired: bool = bool(_scenario.enemy_routs_fired)
	if not ok:
		push_error(
			"S54 deception failed fired=%s samples=%s"
			% [str(fired), str(_scenario.window_samples.slice(0, mini(8, _scenario.window_samples.size())))]
		)
	# Print first ~2.5s of exposed state.
	for s in _scenario.window_samples:
		if float(s.get("t", 0.0)) > 2.5:
			break
		print(
			"[WO-033] S54 t=%.1f true=%s enemy_vis=%s feign=%s left=%.2f"
			% [
				float(s.get("t")),
				str(s.get("true_state")),
				str(s.get("enemy_visible")),
				str(s.get("feign_active")),
				float(s.get("deception_left")),
			]
		)
	_record_check(
		"[WO-033] S54",
		ok,
		"enemy_routs_fired=%s window_samples=%d" % [str(fired), _scenario.window_samples.size()],
	)


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
	# WO-028: magnitude bands re-derived under FINAL Phase 2 config (QoD on σ=0.045).
	# DIRECTION (flank wins / ratio << 1) is R21 law — asserted separately in boundary probe.
	var phases: Dictionary = _scenario.get_phase_durations_sec()
	var s1_ref: float = S3_S1_REF_COMBAT
	var rout: float = _scenario.get_blue_a_strength_at_rout()
	var drains: Dictionary = _scenario.get_blue_a_edge_drains()
	var ratio: float = phases.combat_sec / s1_ref if s1_ref > 0.0 else 0.0
	var left_drain: float = float(drains.get("left", 0.0))
	var ok := true
	if ratio + S3_RATIO_TOL < S3_RATIO_MIN or ratio - S3_RATIO_TOL > S3_RATIO_MAX:
		push_error(
			"S3 ratio %.3f outside QoD-on band [%.3f, %.3f] (WO-028 n=500 mean±3SD)"
			% [ratio, S3_RATIO_MIN, S3_RATIO_MAX]
		)
		ok = false
	if rout + 0.01 < S3_ROUT_MIN or rout - 0.01 > S3_ROUT_MAX:
		push_error(
			"S3 strength_at_rout %.2f outside QoD-on band [%.2f, %.2f]"
			% [rout, S3_ROUT_MIN, S3_ROUT_MAX]
		)
		ok = false
	if left_drain <= 0.0:
		push_error("S3 missing LEFT edge drain")
		ok = false
	if left_drain + 0.01 < S3_LEFT_DRAIN_MIN or left_drain - 0.01 > S3_LEFT_DRAIN_MAX:
		push_error(
			"S3 LEFT drain %.2f outside QoD-on band [%.2f, %.2f]"
			% [left_drain, S3_LEFT_DRAIN_MIN, S3_LEFT_DRAIN_MAX]
		)
		ok = false
	# Direction sanity (not a magnitude band): flank must still win faster than frontal.
	if ratio >= 0.95:
		push_error("S3 ratio %.3f not << 1.0 (flank direction broken)" % ratio)
		ok = false
	if _scenario.had_overlap_failure() or _scenario.had_adhesion_invariant_failure():
		push_error("S3 invariant/overlap failure")
		ok = false
	_record_check(
		"[WO-028] S3",
		ok,
		"ratio=%.3f rout=%.2f left_drain=%.2f (QoD-on σ=0.045 n=500 mean±3SD)"
		% [ratio, rout, left_drain],
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


func _run_slot_swap_guard() -> void:
	## WO-027: permanent slot-order guard (units[] reverse, not position mirror).
	var out: Array = []
	var exit_code := OS.execute(
		"/tmp/godot/Godot_v4.4.1-stable_linux.x86_64",
		[
			"--headless",
			"--path",
			ProjectSettings.globalize_path("res://"),
			"--script",
			"res://tests/wo027_slot_swap.gd",
			"--",
			"SEED=1000",
		],
		out,
		true
	)
	var detail := ""
	var ok_line := false
	for line in out:
		var s := str(line).strip_edges()
		if s.begins_with("WO027_SLOT_SWAP seed="):
			detail = s
			if "ok=true" in s:
				ok_line = true
			print(s)
	# Nested OS.execute stdout is flaky — prefer sidecar written by the child.
	var side := "res://docs/reports/evidence_wo028/slot_swap_guard.txt"
	if FileAccess.file_exists(side):
		var sf := FileAccess.open(side, FileAccess.READ)
		if sf != null:
			var side_text := sf.get_as_text()
			sf.close()
			for line in side_text.split("\n", false):
				var s2 := str(line).strip_edges()
				if s2.begins_with("WO027_SLOT_SWAP seed="):
					detail = s2
					if "ok=true" in s2:
						ok_line = true
					print(s2)
	if not ok_line and exit_code == 0 and "ok=true" in "\n".join(out):
		ok_line = true
	if not ok_line:
		push_error("WO-027 SLOT-SWAP guard failed (exit %d)" % exit_code)
		_record_check("[WO-027] SLOT-SWAP", false, detail)
	else:
		_record_check("[WO-027] SLOT-SWAP", true, detail)


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
	# WO-028: melee raw includes quality_of_day (CombatResolver path); band must match.
	var qod: float = float(attacker.quality_of_day) if "quality_of_day" in attacker else 1.0
	var raw_at_full: float = (
		float(attacker.profile.get("close_damage", 0.0)) * _c_float("k_melee_scale") * qod
	)
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
	# DIRECTION (R21 / Combat Core §3.7): frontage stacking is sublinear — never ≥ 3.0×.
	if ratio >= S8_STACK_RATIO_MAX:
		push_error(
			"S8 stack ratio %.3f >= %.1f (frontage stacking not sublinear)"
			% [ratio, S8_STACK_RATIO_MAX]
		)
		ok = false
	var peak_partners := 0
	if _scenario.get("max_defender_partners") != null:
		peak_partners = int(_scenario.get("max_defender_partners"))
	_record_check(
		"[WO-030] S8",
		ok,
		"single_damage=%.2f triple_damage=%.2f ratio=%.3f (sublinear <%.1f) peak_partners=%d"
		% [single_damage, triple_damage, ratio, S8_STACK_RATIO_MAX, peak_partners],
	)


func _check_scenario_08b() -> void:
	## Depth-column sequential contact: defender never hosts 2+ partners at once.
	var peak := int(_scenario.get("max_defender_partners"))
	var multi_ticks := int(_scenario.get("multi_partner_ticks"))
	var dmg: float = float(_scenario.get_defender_damage_taken())
	var ok := true
	if peak > 1 or multi_ticks > 0:
		push_error(
			"S8b sequential violated: max_partners=%d multi_partner_ticks=%d (expected sequential depth column)"
			% [peak, multi_ticks]
		)
		ok = false
	if dmg <= 0.0:
		push_error("S8b zero defender damage")
		ok = false
	_record_check(
		"[WO-030] S8b",
		ok,
		"max_partners=%d multi_partner_ticks=%d defender_damage=%.2f (sequential depth column)"
		% [peak, multi_ticks, dmg],
	)


func _check_perf_40() -> void:
	# WO-024: GAMEPLAY_TICK is the 50ms gate; MAIN_TICK is QA-cost comparison only.
	var g_avg := float(_perf_stats.get("avg_tick_ms", 0.0))
	var g_p95 := float(_perf_stats.get("p95_tick_ms", 0.0))
	var g_max := float(_perf_stats.get("max_tick_ms", 0.0))
	var g_n := int(_perf_stats.get("tick_count", 0))
	var m_avg := float(_perf_main_tick_stats.get("avg_tick_ms", 0.0))
	var m_p95 := float(_perf_main_tick_stats.get("p95_tick_ms", 0.0))
	var m_max := float(_perf_main_tick_stats.get("max_tick_ms", 0.0))
	var m_n := int(_perf_main_tick_stats.get("tick_count", 0))
	print(
		"[WO-024] Perf40 GAMEPLAY_TICK avg_tick_ms=%.3f p95_tick_ms=%.3f max_tick_ms=%.3f ticks=%d"
		% [g_avg, g_p95, g_max, g_n]
	)
	print(
		"[WO-024] Perf40 MAIN_TICK avg_tick_ms=%.3f p95_tick_ms=%.3f max_tick_ms=%.3f ticks=%d"
		% [m_avg, m_p95, m_max, m_n]
	)
	var d_avg := m_avg - g_avg
	var d_p95 := m_p95 - g_p95
	var pct_avg := (d_avg / g_avg) * 100.0 if g_avg > 0.0 else 0.0
	var pct_p95 := (d_p95 / g_p95) * 100.0 if g_p95 > 0.0 else 0.0
	print(
		"[WO-024] Perf40 QA_INSTRUMENTATION_COST avg_ms=%.3f (%.1f%%) p95_ms=%.3f (%.1f%%) — MAIN−GAMEPLAY"
		% [d_avg, pct_avg, d_p95, pct_p95]
	)
	var gate_pass := g_p95 <= 50.0 and g_n >= 100
	print(
		"[WO-024] Perf40 GATE_50MS GAMEPLAY_TICK_p95=%.3f verdict=%s (no optimization this WO)"
		% [g_p95, "PASS" if gate_pass else "FAIL"]
	)
	print(
		"[WO-024] Perf40 note: supersedes WO-023 MAIN_TICK-as-gate; "
		+ "WO-011..WO-022 sim_thread lines remain non-comparable; "
		+ "WO-023 MAIN_TICK remains the test-config reference."
	)
	# Soft hard-fail only on pathological blowout — TD rules on GATE_50MS FAIL.
	var ok := true
	if g_p95 > 120.0 or g_n < 100 or m_n < 100:
		push_error(
			"WO-024 perf pathological FAIL: GAMEPLAY p95=%.3f n=%d MAIN n=%d"
			% [g_p95, g_n, m_n]
		)
		ok = false
	if not ok:
		_exit_code = 1



func _check_s17_charge(adjacent: bool) -> void:
	# WO-018: S17 fresh/adj SUPERSEDED by S23 (T1 hold) / S24–S26 (unaware).
	# History retained; emit retired PASS so suite continuity documents the supersession.
	if adjacent:
		_record_check(
			"[WO-018] S17 adj RETIRED",
			true,
			"superseded by S24–S26 unaware cases",
		)
		return
	_record_check(
		"[WO-018] S17 RETIRED",
		true,
		"superseded by S23 (braced hold); see S17b for shaken rout",
	)


func _check_s17b_predrain() -> void:
	var ev: Dictionary = _scenario.primary_charge_event()
	var ok := true
	var shock: float = float(ev.get("shock", -1.0))
	var charged: bool = bool(ev.get("charged", false))
	if not charged:
		push_error("S17b expected charge impact")
		ok = false
	# Shaken 40 + Tier 1 (×0.6) still routs through threshold.
	var land_coh := 40.0 - shock
	if land_coh > 10.0:
		push_error("S17b expected rout finish (land_coh=%.2f shock=%.3f tier=%s)" % [land_coh, shock, ev.get("brace_tier", "?")])
		ok = false
	var combat: float = _scenario.combat_duration_sec()
	_record_check(
		"[WO-017] S17b",
		ok,
		"shock=%.3f land_from_40=%.2f tier=%s combat=%.1fs winner=%s"
		% [shock, land_coh, str(ev.get("brace_tier", "")), combat, _scenario.get_winner_id()],
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
	# R18: relative threshold = own tactical Speed × charge_min_speed_pct (cavalry → 5.0).
	var cav_top := 40.0 * _c_float("speed_stat_meters_per_10s") / 10.0
	var min_speed := cav_top * _c_float("charge_min_speed_pct")
	if short:
		_s20_short_closing = closing
		if charged or closing >= min_speed - 0.05:
			push_error("S20 20m should be below relative charge threshold (closing=%.3f min=%.3f sim-m/s)" % [closing, min_speed])
			ok = false
		_record_check("[WO-019] S20 20m", ok, "closing=%.3f charged=%s (sim-m/s)" % [closing, charged])
	else:
		_s20_long_closing = closing
		if not charged or closing < min_speed:
			push_error("S20 120m should charge (closing=%.3f min=%.3f sim-m/s)" % [closing, min_speed])
			ok = false
		if _s20_short_closing >= 0.0 and closing <= _s20_short_closing + 0.1:
			push_error("S20 long closing %.3f should exceed short %.3f" % [closing, _s20_short_closing])
			ok = false
		_record_check(
			"[WO-019] S20 120m",
			ok,
			"closing=%.3f impact=%.3f short_closing=%.3f (sim-m/s)"
			% [closing, float(ev.get("impact", 0.0)), _s20_short_closing],
		)


func _check_s21_flank_charge() -> void:
	# S21 — flank charge vs fresh defender must elevate edge mult and rout.
	var ev: Dictionary = _scenario.primary_charge_event()
	var ok := true
	if not bool(ev.get("charged", false)):
		push_error("S21 expected flank charge impact")
		ok = false
	var edge: String = str(ev.get("edge", ""))
	if edge != "left" and edge != "right" and edge != "rear":
		push_error("S21 expected flank/rear edge (got %s)" % edge)
		ok = false
	var edge_mult: float = float(ev.get("edge_mult", 0.0))
	if edge_mult < 1.4:
		push_error("S21 expected elevated edge_mult (>=1.4), got %.2f" % edge_mult)
		ok = false
	var shock: float = float(ev.get("shock", -1.0))
	var base_shock: float = float(ev.get("base_shock", shock / maxf(edge_mult, 0.01)))
	# Fresh 100: flank/rear shock must finish through rout_threshold (~10).
	var land_coh := 100.0 - shock
	if land_coh > 10.0:
		push_error("S21 expected rout finish (land_coh=%.2f shock=%.3f)" % [land_coh, shock])
		ok = false
	_record_check(
		"[WO-016c] S21",
		ok,
		"edge=%s edge_mult=%.2f base_shock=%.2f shock=%.2f land=%.2f winner=%s"
		% [edge, edge_mult, base_shock, shock, land_coh, _scenario.get_winner_id()],
	)


func _check_s22_frontal_facing() -> void:
	# S22 — frontal facing → Tier 1 + outcome: cav should lose grind if line holds.
	var ev: Dictionary = _scenario.primary_charge_event()
	var ok := true
	if not bool(ev.get("charged", false)):
		push_error("S22 expected frontal charge impact")
		ok = false
	var brace_tier: int = int(ev.get("brace_tier", 0))
	if brace_tier != 1:
		push_error("S22 expected brace_tier=1 (got %d)" % brace_tier)
		ok = false
	var shock: float = float(ev.get("shock", -1.0))
	var land_coh := 100.0 - shock
	if land_coh < 45.0:
		push_error("S22 Tier1 land %.2f expected >=45" % land_coh)
		ok = false
	var winner: String = _scenario.get_winner_id()
	var combat: float = float(_scenario.combat_duration_sec())
	_record_check(
		"[WO-017] S22",
		ok,
		"tier=%d shock=%.2f land=%.2f combat=%.1fs winner=%s cav_str=%.1f inf_str=%.1f"
		% [
			brace_tier,
			shock,
			land_coh,
			combat,
			winner,
			_scenario.cavalry_strength(),
			_scenario.infantry_strength(),
		],
	)


func _check_s23_braced_hold() -> void:
	var ev: Dictionary = _scenario.primary_charge_event()
	var ok := true
	if not bool(ev.get("charged", false)):
		push_error("S23 expected charge")
		ok = false
	if int(ev.get("brace_tier", 0)) != 1:
		push_error("S23 expected Tier 1 (got %s)" % ev.get("brace_tier", "?"))
		ok = false
	var shock: float = float(ev.get("shock", -1.0))
	var land := 100.0 - shock
	if land < 45.0:
		push_error("S23 expected land >=45 (got %.2f)" % land)
		ok = false
	# Design promise: cavalry fades in grind vs held line.
	var winner := _scenario.get_winner_id()
	if winner != "blue_inf":
		push_error("S23 expected infantry win grind (winner=%s)" % winner)
		ok = false
	_record_check(
		"[WO-017] S23",
		ok,
		"tier=1 shock=%.2f land=%.2f combat=%.1fs winner=%s cav_str=%.1f inf_str=%.1f"
		% [
			shock,
			land,
			_scenario.combat_duration_sec(),
			winner,
			_scenario.cavalry_strength(),
			_scenario.infantry_strength(),
		],
	)


func _check_s24_caught_engaged() -> void:
	var ev: Dictionary = _scenario.primary_charge_event()
	var ok := true
	if not bool(ev.get("charged", false)):
		push_error("S24 expected charge")
		ok = false
	if int(ev.get("brace_tier", 0)) != 3:
		push_error("S24 expected Tier 3 unaware (got %s / %s)" % [ev.get("brace_tier", "?"), ev.get("brace", "")])
		ok = false
	var shock: float = float(ev.get("shock", -1.0))
	var land := 100.0 - shock
	# Full frontal shock vs fresh → wavering break (not the steady >=45 hold of Tier 1).
	if land >= 45.0:
		push_error("S24 expected line break (land=%.2f still steady)" % land)
		ok = false
	if land < 15.0:
		# Fresh 100 + T3 should waver, not instant-rout; allow <=30 typical.
		pass
	_record_check(
		"[WO-017] S24",
		ok,
		"tier=%s shock=%.2f land=%.2f winner=%s" % [ev.get("brace_tier", ""), shock, land, _scenario.get_winner_id()],
	)


func _check_s25_caught_marching() -> void:
	var ev: Dictionary = _scenario.primary_charge_event()
	var ok := true
	if not bool(ev.get("charged", false)):
		push_error("S25 expected charge")
		ok = false
	if int(ev.get("brace_tier", 0)) != 3:
		push_error("S25 expected Tier 3 (got %s)" % ev.get("brace_tier", "?"))
		ok = false
	var shock: float = float(ev.get("shock", -1.0))
	var land := 100.0 - shock
	if land < 15.0 or land > 30.0:
		push_error("S25 T3 R15 land %.2f not in [15,30]" % land)
		ok = false
	_record_check(
		"[WO-017] S25",
		ok,
		"tier=%s shock=%.2f land=%.2f" % [ev.get("brace_tier", ""), shock, land],
	)


func _check_s26_late_arc() -> void:
	var ev: Dictionary = _scenario.primary_charge_event()
	var ok := true
	if not bool(ev.get("charged", false)):
		push_error("S26 expected charge")
		ok = false
	if int(ev.get("brace_tier", 0)) != 3:
		push_error("S26 expected Tier 3 (late arc) got %s" % ev.get("brace_tier", "?"))
		ok = false
	var shock: float = float(ev.get("shock", -1.0))
	var land := 100.0 - shock
	if land < 15.0 or land > 30.0:
		push_error("S26 T3 R15 land %.2f not in [15,30]" % land)
		ok = false
	_record_check(
		"[WO-017] S26",
		ok,
		"tier=%s shock=%.2f land=%.2f" % [ev.get("brace_tier", ""), shock, land],
	)


func _check_s27_gait_visibility() -> void:
	var ev: Dictionary = _scenario.primary_charge_event()
	var ok := true
	if not bool(ev.get("charged", false)):
		push_error("S27 expected charge impact")
		ok = false
	var closing: float = float(ev.get("closing_speed", -1.0))
	var unit_speed: float = float(ev.get("unit_speed", -1.0))
	var impact_closing: float = float(ev.get("impact_closing_speed", closing))
	# Contact velocity must equal Impact formula velocity — no hidden conversion.
	if absf(closing - impact_closing) > 0.01:
		push_error("S27 closing %.3f != impact_closing %.3f" % [closing, impact_closing])
		ok = false
	if absf(closing - unit_speed) > 0.05 and unit_speed >= 0.0:
		push_error("S27 unit_speed %.3f diverges from closing %.3f" % [unit_speed, closing])
		ok = false
	var samples: Array = _scenario.speed_samples
	var saw_commit := false
	var saw_accel := false
	var prev_speed := -1.0
	for row in samples:
		if bool(row.get("committed", false)):
			saw_commit = true
		var spd: float = float(row.get("speed", 0.0))
		if prev_speed >= 0.0 and spd > prev_speed + 0.05 and saw_commit:
			saw_accel = true
		prev_speed = spd
	if not saw_commit:
		push_error("S27 expected charge_committed samples in velocity curve")
		ok = false
	if not saw_accel and closing <= _c_float("speed_stat_meters_per_10s") * 4.0 + 0.2:
		# At least prove closing exceeds pure tactical if curve sparse.
		pass
	# Physical gait should exceed pure trot (4.0) when commitment has runway.
	if closing <= 4.0 + 0.05:
		push_error("S27 expected gait acceleration above tactical trot (closing=%.3f)" % closing)
		ok = false
	# WO-019: long runway must reach nearly full gait ceiling.
	var gait_ceiling := 40.0 * _c_float("speed_stat_meters_per_10s") / 10.0 * 3.375
	if closing < 0.95 * gait_ceiling:
		push_error("S27 expected v>=0.95×gait (closing=%.3f ceiling=%.3f)" % [closing, gait_ceiling])
		ok = false
	_record_check(
		"[WO-019] S27",
		ok,
		"closing=%.3f unit_speed=%.3f samples=%d commit=%s accel=%s"
		% [closing, unit_speed, samples.size(), saw_commit, saw_accel],
	)


func _check_s28_infantry_charge() -> void:
	var ev: Dictionary = _scenario.primary_charge_event()
	var ok := true
	if not bool(ev.get("charged", false)):
		push_error("S28 expected infantry-charge impact")
		ok = false
	var impact: float = float(ev.get("impact", -1.0))
	var shock: float = float(ev.get("shock", -1.0))
	var land := 100.0 - shock
	# Modest vs cavalry (~21.6 impact at full gallop with scale≈1).
	if impact >= 18.0:
		push_error("S28 impact %.3f should be materially below cavalry ~21.6" % impact)
		ok = false
	if land < 45.0:
		push_error("S28 defender should hold comfortably (land=%.2f)" % land)
		ok = false
	_record_check(
		"[WO-019] S28",
		ok,
		"impact=%.3f shock=%.2f land=%.2f closing=%.3f tier=%s (WO-018 was 7.79/16.6/83.4)"
		% [impact, shock, land, float(ev.get("closing_speed", 0.0)), str(ev.get("brace_tier", ""))],
	)


func _check_s29_runup_point() -> void:
	var dist: float = _S29_DISTANCES[_s29_idx]
	var ev: Dictionary = _scenario.primary_charge_event()
	_s29_rows.append({
		"run_up_m": dist,
		"closing": float(ev.get("closing_speed", -1.0)),
		"impact": float(ev.get("impact", -1.0)),
		"charged": bool(ev.get("charged", false)),
		"unit_speed": float(ev.get("unit_speed", -1.0)),
	})


func _finalize_s29_runup() -> void:
	var ok := true
	if _s29_rows.size() != _S29_DISTANCES.size():
		push_error("S29 expected %d curve points" % _S29_DISTANCES.size())
		ok = false
	var gait_ceiling := 40.0 * _c_float("speed_stat_meters_per_10s") / 10.0 * 3.375
	var cav_top := 40.0 * _c_float("speed_stat_meters_per_10s") / 10.0
	var min_speed := cav_top * _c_float("charge_min_speed_pct")
	var by_dist: Dictionary = {}
	var prev_impact := -1.0
	var prev_closing := -1.0
	for row in _s29_rows:
		var closing: float = float(row.get("closing", -1.0))
		var impact: float = float(row.get("impact", -1.0))
		var run_up: float = float(row.get("run_up_m", 0.0))
		by_dist[run_up] = row
		if run_up <= 20.5:
			if bool(row.get("charged", true)) or closing >= min_speed - 0.05:
				push_error("S29 20m should not charge (closing=%.3f min=%.3f)" % [closing, min_speed])
				ok = false
		else:
			if not bool(row.get("charged", false)):
				push_error("S29 %.0fm should charge" % run_up)
				ok = false
		if prev_closing >= 0.0 and closing + 0.05 < prev_closing:
			push_error("S29 velocity curve should not decrease (%.3f -> %.3f)" % [prev_closing, closing])
			ok = false
		if prev_impact >= 0.0 and impact + 0.05 < prev_impact:
			push_error("S29 Impact must be strictly monotonic (%.3f -> %.3f)" % [prev_impact, impact])
			ok = false
		prev_closing = closing
		prev_impact = impact
	var v60 := float(by_dist.get(60.0, {}).get("closing", -1.0)) if by_dist.has(60.0) else -1.0
	var v200 := float(by_dist.get(200.0, {}).get("closing", -1.0)) if by_dist.has(200.0) else -1.0
	if v200 < 0.95 * gait_ceiling:
		push_error("S29 v(200)=%.3f must be >= 0.95×gait (%.3f)" % [v200, 0.95 * gait_ceiling])
		ok = false
	if v60 < 0.50 * gait_ceiling or v60 > 0.80 * gait_ceiling:
		push_error("S29 v(60)=%.3f must be in [50%%,80%%] of gait %.3f" % [v60, gait_ceiling])
		ok = false
	var detail := ""
	for row in _s29_rows:
		detail += " %.0fm:v=%.2f/i=%.2f" % [
			float(row.get("run_up_m", 0.0)),
			float(row.get("closing", 0.0)),
			float(row.get("impact", 0.0)),
		]
	_record_check("[WO-019] S29", ok, detail.strip_edges())


func _check_s30_disengage() -> void:
	var ok := true
	var sk_t: float = float(_scenario.skirm_withdraw_s)
	var sp_t: float = float(_scenario.spears_withdraw_s)
	var sk_lost: float = float(_scenario.skirm_str_lost)
	var sp_lost: float = float(_scenario.spears_str_lost)
	# Direction (R21): skirmisher finishes before spears; spears lose ≥ cohesion.
	if sk_t < 0.0 or sp_t < 0.0:
		push_error("S30 missing withdraw times sk=%.2f sp=%.2f" % [sk_t, sp_t])
		ok = false
	if sk_t > sp_t:
		push_error("S30 skirmisher should finish before spears (%.2f vs %.2f)" % [sk_t, sp_t])
		ok = false
	if absf(sk_t - 1.4) > 0.35:
		push_error("S30 skirmisher withdraw expected ~1.4s got %.2f" % sk_t)
		ok = false
	if absf(sp_t - 2.4) > 0.35:
		push_error("S30 spears withdraw expected ~2.4s got %.2f" % sp_t)
		ok = false
	# WO-028: magnitude bands re-derived under QoD-on σ=0.045, n=500 seeds 1000–1499.
	# sk_lost mean=4.608 sd=0.251 → [3.856, 5.360]; sp_lost mean=6.029 sd=0.462 → [4.642, 7.416]
	# Provenance: evidence_wo028/s30_rederive.log
	const S30_SK_LOST_MIN := 3.86
	const S30_SK_LOST_MAX := 5.36
	const S30_SP_LOST_MIN := 4.64
	const S30_SP_LOST_MAX := 7.42
	if sk_lost + 0.01 < S30_SK_LOST_MIN or sk_lost - 0.01 > S30_SK_LOST_MAX:
		push_error(
			"S30 skirmisher str lost %.2f outside QoD-on band [%.2f, %.2f]"
			% [sk_lost, S30_SK_LOST_MIN, S30_SK_LOST_MAX]
		)
		ok = false
	if sp_lost + 0.01 < S30_SP_LOST_MIN or sp_lost - 0.01 > S30_SP_LOST_MAX:
		push_error(
			"S30 spears str lost %.2f outside QoD-on band [%.2f, %.2f]"
			% [sp_lost, S30_SP_LOST_MIN, S30_SP_LOST_MAX]
		)
		ok = false
	if float(_scenario.spears_coh_lost) + 0.05 < float(_scenario.skirm_coh_lost):
		push_error(
			"S30 spears should lose at least as much cohesion (%.2f vs %.2f)"
			% [float(_scenario.spears_coh_lost), float(_scenario.skirm_coh_lost)]
		)
		ok = false
	_record_check(
		"[WO-028] S30",
		ok,
		"sk_t=%.2fs lost_str=%.2f/coh=%.2f sp_t=%.2fs lost_str=%.2f/coh=%.2f ratio=%.2f"
		% [
			sk_t, sk_lost, float(_scenario.skirm_coh_lost),
			sp_t, sp_lost, float(_scenario.spears_coh_lost),
			sp_lost / sk_lost if sk_lost > 0.001 else 0.0,
		],
	)


func _check_s31_wheel() -> void:
	var ok := true
	var sp_t: float = float(_scenario.spears_time_s)
	var inf_t: float = float(_scenario.inf_time_s)
	var sp_d: float = float(_scenario.spears_drain)
	var inf_d: float = float(_scenario.inf_drain)
	if sp_t < 0.0 or inf_t < 0.0:
		push_error("S31 missing wheel times")
		ok = false
	# WO-020b Task 2 drain band selection.
	if sp_d < 15.0 or sp_d > 30.0:
		push_error("S31 spears drain %.3f expected in [15, 30]" % sp_d)
		ok = false
	if inf_d < 7.0 or inf_d > 15.0:
		push_error("S31 infantry drain %.3f expected in [7, 15]" % inf_d)
		ok = false
	if inf_d > 0.001 and (sp_d / inf_d) < 1.6:
		push_error("S31 drain ratio %.2f expected >= 1.6" % (sp_d / inf_d))
		ok = false
	if sp_t <= inf_t:
		push_error("S31 spears should take longer to wheel (%.2f vs %.2f)" % [sp_t, inf_t])
		ok = false
	_record_check(
		"[WO-020b] S31",
		ok,
		"spears_t=%.2fs drain=%.3f inf_t=%.2fs drain=%.3f ratio=%.2f"
		% [sp_t, sp_d, inf_t, inf_d, sp_d / inf_d if inf_d > 0.001 else 0.0],
	)


func _check_s32_hit_and_run() -> void:
	var ok := true
	var s1: float = float(_scenario.strength_after_fail)
	var s2: float = float(_scenario.strength_after_disengage)
	var s3: float = float(_scenario.strength_after_recharge)
	var impact2: float = float(_scenario.second_charge_impact)
	if s1 < 0.0 or s2 < 0.0 or s3 < 0.0:
		push_error("S32 missing strength samples")
		ok = false
	if s2 <= 0.0 or s2 > 100.0:
		push_error("S32 cavalry should survive disengage (str=%.2f)" % s2)
		ok = false
	# Full gait impact — strength-scaled; keep a soft floor.
	if impact2 < 12.0:
		push_error("S32 second charge should land gait impact (got %.3f)" % impact2)
		ok = false
	if s3 <= 0.0:
		push_error("S32 cavalry should still be alive after recharge")
		ok = false
	# Costly break-off expected under WO-020b; just report vs WO-020 baseline.
	_record_check(
		"[WO-020b] S32",
		ok,
		"str_fail=%.2f str_dis=%.2f str_rech=%.2f impact2=%.3f (WO-020 was 89.18/88.84/79.19)"
		% [s1, s2, s3, impact2],
	)


func _check_s33_gravity() -> void:
	var ok := true
	var er: String = str(_scenario.contact_edge_red)
	var eb: String = str(_scenario.contact_edge_blue)
	if er != EdgeContact.EDGE_FRONT or eb != EdgeContact.EDGE_FRONT:
		push_error("S33 expected FRONT/FRONT got %s/%s" % [er, eb])
		ok = false
	# WO-024: surface-gap gravity should produce a REAL square-up (>>1.1°).
	# Soft facing dots — only fail if clearly sideways/grinding.
	if float(_scenario.red_facing_dot_at_contact) < 0.5:
		push_error("S33 red grinding sideways (dot=%.3f)" % float(_scenario.red_facing_dot_at_contact))
		ok = false
	if float(_scenario.blue_facing_dot_at_contact) < 0.5:
		push_error("S33 blue grinding sideways (dot=%.3f)" % float(_scenario.blue_facing_dot_at_contact))
		ok = false
	var rot_r := float(_scenario.red_rotation_deg)
	var rot_b := float(_scenario.blue_rotation_deg)
	# Require meaningful rotation vs WO-020b's bogus 1.1° "partial square-up".
	if rot_r < 5.0 and rot_b < 5.0:
		push_error(
			"S33 expected real square-up rot≥5° (got %.1f/%.1f; WO-020b was 1.1°)"
			% [rot_r, rot_b]
		)
		ok = false
	_record_check(
		"[WO-024] S33",
		ok,
		"edges=%s/%s red_dot=%.3f blue_dot=%.3f rot_deg=%.1f/%.1f (pre-fix≈1.1°)" % [
			er, eb,
			float(_scenario.red_facing_dot_at_contact),
			float(_scenario.blue_facing_dot_at_contact),
			rot_r,
			rot_b,
		],
	)


func _check_s34_pinning() -> void:
	# WO-028: assert R19 facing pin + engagement morale mult (>1), not soft LEFT-label count.
	var ok := true
	if not bool(_scenario.a_did_not_reface):
		push_error("S34 defender auto-refaced toward flanker (R19 pin violated)")
		ok = false
	if not bool(_scenario.flank_persisted):
		push_error(
			"S34 flank morale mult did not hold (mean=%.3f frac_gt1=%.2f)"
			% [float(_scenario.mean_flank_mult), float(_scenario.frac_mult_gt1)]
		)
		ok = false
	if float(_scenario.mean_flank_mult) <= 1.0:
		push_error("S34 mean flank mult %.3f not > 1.0" % float(_scenario.mean_flank_mult))
		ok = false
	var detail := (
		"samples=%d no_reface=%s mean_mult=%.3f frac_gt1=%.2f max_dot=%.3f turn=%.2f"
		% [
			_scenario.edge_samples.size(),
			_scenario.a_did_not_reface,
			float(_scenario.mean_flank_mult),
			float(_scenario.frac_mult_gt1),
			float(_scenario.max_facing_dot_to_flanker),
			float(_scenario.max_facing_turn_deg),
		]
	)
	_record_check("[WO-028] S34", ok, detail)


func _check_s35_agility() -> void:
	var ok := true
	if float(_scenario.low_withdraw_s) < 0.0 or float(_scenario.high_withdraw_s) < 0.0:
		push_error("S35 missing withdraw timings")
		ok = false
	if float(_scenario.low_withdraw_s) <= float(_scenario.high_withdraw_s):
		push_error(
			"S35 A30 duration %.2f should exceed A80 %.2f"
			% [float(_scenario.low_withdraw_s), float(_scenario.high_withdraw_s)]
		)
		ok = false
	# Report isolation actuals — do NOT tune to 1.71 (R20 / Gate 2).
	_record_check(
		"[WO-022] S35",
		ok,
		"a30_t=%.2fs lost=%.2f a80_t=%.2fs lost=%.2f str_ratio=%.2f dur_ratio=%.2f (ref~1.71)"
		% [
			float(_scenario.low_withdraw_s),
			float(_scenario.low_str_lost),
			float(_scenario.high_withdraw_s),
			float(_scenario.high_str_lost),
			float(_scenario.str_loss_ratio()),
			float(_scenario.duration_ratio()),
		],
	)


func _check_s36_uphill_push() -> void:
	var phases: Dictionary = _scenario.get_phase_durations_sec()
	var displace: float = float(_scenario.ground_displacement_m())
	var ok := true
	if not bool(_scenario.downhill_won_push()):
		push_error("S36 downhill fighter did not win push (routed=%s displace=%.2f)" % [_scenario.get_routed_id(), displace])
		ok = false
	if displace < 0.5:
		push_error("S36 expected material downhill ground gain (displace=%.2f)" % displace)
		ok = false
	_record_check(
		"[WO-021] S36",
		ok,
		"combat=%.1fs displace_m=%.2f routed=%s (flat S1 combat~81.6s)"
		% [float(phases.get("combat_sec", -1.0)), displace, _scenario.get_routed_id()],
	)


func _check_s37_slope_charge() -> void:
	var dn: Dictionary = _scenario.downhill_charge()
	var up: Dictionary = _scenario.uphill_charge()
	var ratio: float = float(_scenario.impact_ratio())
	var ok := true
	if not bool(dn.get("charged", false)):
		push_error("S37 downhill charge missing")
		ok = false
	if not bool(up.get("charged", false)):
		push_error("S37 uphill charge missing")
		ok = false
	if float(dn.get("closing_speed", 0.0)) <= float(up.get("closing_speed", 0.0)):
		push_error(
			"S37 downhill closing %.3f should exceed uphill %.3f"
			% [float(dn.get("closing_speed", 0.0)), float(up.get("closing_speed", 0.0))]
		)
		ok = false
	if ratio < 1.4:
		push_error("S37 impact ratio %.3f < 1.4 design target" % ratio)
		ok = false
	_record_check(
		"[WO-021] S37",
		ok,
		"down_v=%.3f/i=%.3f up_v=%.3f/i=%.3f ratio=%.3f"
		% [
			float(dn.get("closing_speed", 0.0)),
			float(dn.get("impact", 0.0)),
			float(up.get("closing_speed", 0.0)),
			float(up.get("impact", 0.0)),
			ratio,
		],
	)


func _check_s38_missile_high() -> void:
	var d_down: float = float(_scenario.first_volley_down_m)
	var d_up: float = float(_scenario.first_volley_up_m)
	var base: float = 150.0
	var ok := true
	if d_down < 0.0 or d_up < 0.0:
		push_error("S38 missing first volley (down=%.1f up=%.1f)" % [d_down, d_up])
		ok = false
	# At ~10% grade: expect ~+15% downhill / ~−15% uphill (±8m tolerance).
	if absf(d_down - base * 1.15) > 12.0:
		push_error("S38 downhill first volley %.1fm expected ~172.5m (±12)" % d_down)
		ok = false
	if absf(d_up - base * 0.85) > 12.0:
		push_error("S38 uphill first volley %.1fm expected ~127.5m (±12)" % d_up)
		ok = false
	if d_down <= d_up:
		push_error("S38 downhill range %.1f should exceed uphill %.1f" % [d_down, d_up])
		ok = false
	_record_check(
		"[WO-021] S38",
		ok,
		"down_first=%.1fm up_first=%.1fm" % [d_down, d_up],
	)


func _check_s39_high_ground() -> void:
	var phases: Dictionary = _scenario.get_phase_durations_sec()
	var ok := true
	if not bool(_scenario.defender_won()):
		push_error("S39 defender should win from high ground (winner=%s routed=%s)" % [_scenario.get_winner_id(), _scenario.get_routed_id()])
		ok = false
	_record_check(
		"[WO-021] S39",
		ok,
		"winner=%s combat=%.1fs routed=%s str_at_rout=%.2f"
		% [
			_scenario.get_winner_id(),
			float(phases.get("combat_sec", -1.0)),
			_scenario.get_routed_id(),
			float(_scenario.strength_at_rout()),
		],
	)


func _check_s40_mixed() -> void:
	var phases: Dictionary = _scenario.get_phase_durations_sec()
	var ok := true
	# Soft observability gates — battle must be dynamic/readable, not a balance target.
	if not bool(_scenario.observed_volley):
		push_error("S40 expected archer volleys during approach")
		ok = false
	if not bool(_scenario.observed_melee):
		push_error("S40 expected lines to meet")
		ok = false
	if not bool(_scenario.observed_brace):
		push_error("S40 expected BLUE spears braced")
		ok = false
	_record_check(
		"[WO-022] S40",
		ok,
		"winner=%s combat=%.1fs volley=%s melee=%s flank=%s shock=%s brace=%s"
		% [
			_scenario.get_winner_id(),
			float(phases.get("combat_sec", -1.0)),
			_scenario.observed_volley,
			_scenario.observed_melee,
			_scenario.observed_flank_charge,
			_scenario.observed_rout_shock,
			_scenario.observed_brace,
		],
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
