extends SceneTree

## WO-007 harness: Reflection Test, post-fix 11-seed tables, rout-band sweep.

const REFLECTION_SEEDS := [1000, 1001, 1002, 1003, 1004]
const ALL_SEEDS := [1000, 1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009, 12345]

const SWEEP_DRAIN_METER := [0.8, 1.2, 1.6, 2.0]
const SWEEP_DRAIN_STRENGTH := [1.5, 2.0, 2.5]

const WO005_S1_WINNERS := {
	1000: "red_1", 1001: "red_1", 1002: "blue_1", 1003: "blue_1", 1004: "red_1",
	1005: "red_1", 1006: "red_1", 1007: "red_1", 1008: "red_1", 1009: "red_1", 12345: "blue_1",
}
const WO005_S1_COMBAT := {
	1000: 76.2, 1001: 83.4, 1002: 77.0, 1003: 84.2, 1004: 96.2,
	1005: 75.2, 1006: 73.2, 1007: 77.2, 1008: 82.0, 1009: 91.4, 12345: 78.0,
}
const WO006_S2_WINNERS := {
	1000: "red_1", 1001: "red_1", 1002: "red_1", 1003: "red_1", 1004: "red_1",
	1005: "red_1", 1006: "red_1", 1007: "red_1", 1008: "red_1", 1009: "red_1", 12345: "red_1",
}
const WO006_S2_COMBAT := {
	1000: 44.6, 1001: 44.2, 1002: 44.6, 1003: 44.2, 1004: 44.4,
	1005: 44.2, 1006: 44.2, 1007: 44.4, 1008: 44.2, 1009: 44.2, 12345: 44.4,
}
const WO006_S2_STRENGTH_AT_ROUT := {
	1000: 46.42, 1001: 46.55, 1002: 46.38, 1003: 46.54, 1004: 46.54,
	1005: 46.38, 1006: 46.54, 1007: 46.53, 1008: 46.51, 1009: 46.51, 12345: 46.47,
}

const STAT_TOL := 0.0001
const POS_TOL := 0.05

var _constants: Node
var _scenario = null
var _exit_code: int = 0
var _phase: String = "idle"
var _test_mode: String = ""
var _reflection_index: int = 0
var _reflection_normal_trace: String = ""
var _seed_index: int = 0
var _s1_results: Array[Dictionary] = []
var _s2_results: Array[Dictionary] = []
var _determinism_a: String = ""
var _determinism_b: String = ""
var _sweep_cell: int = 0
var _sweep_seed_index: int = 0
var _sweep_scene: String = "scenario_01"
var _sweep_accum_s1: Array[Dictionary] = []
var _sweep_accum_s2: Array[Dictionary] = []
var _sweep_rows: Array[Dictionary] = []
var _baseline_s1_winners: Dictionary = {}
var _baseline_s2_winners: Dictionary = {}
var _sim_harness: Script


func _initialize() -> void:
	_constants = root.get_node("Constants")
	_sim_harness = load("res://scripts/sim_harness.gd")
	process_frame.connect(_on_process_frame)
	_test_mode = "reflection_normal"
	_reflection_index = 0
	_start_scenario("scenario_01", REFLECTION_SEEDS[0])


func _on_process_frame() -> void:
	if _scenario == null:
		return
	if not _scenario.is_node_ready():
		return
	if _phase == "simulate":
		_sim_harness.run_to_completion(_scenario, _sim_harness.RunMode.FAST)
		_finish_current_scenario()


func _start_scenario(scene_key: String, seed_value: int) -> void:
	if _scenario != null:
		_scenario.free()
		_scenario = null

	_phase = "spawn"
	var rng: Node = root.get_node("RNG")
	rng.set_seed(seed_value)
	var scene_path := "res://tests/scenario_01.tscn"
	match scene_key:
		"scenario_01_mirror":
			scene_path = "res://tests/scenario_01_mirror.tscn"
		"scenario_02":
			scene_path = "res://tests/scenario_02.tscn"
	var packed: PackedScene = load(scene_path)
	_scenario = packed.instantiate()
	_scenario.headless_mode = true
	_scenario.fast_sim_mode = true
	_scenario.set_battle_seed(seed_value)
	root.add_child(_scenario)
	_phase = "simulate"


func _finish_current_scenario() -> void:
	if _scenario.had_overlap_failure():
		push_error("Overlap failure in mode %s" % _test_mode)
		_exit_code = 1

	match _test_mode:
		"reflection_normal":
			_reflection_normal_trace = _scenario.get_trace_text()
			_test_mode = "reflection_mirror"
			_start_scenario("scenario_01_mirror", REFLECTION_SEEDS[_reflection_index])
		"reflection_mirror":
			_check_reflection(REFLECTION_SEEDS[_reflection_index], _reflection_normal_trace, _scenario.get_trace_text())
			_reflection_index += 1
			if _reflection_index < REFLECTION_SEEDS.size():
				_test_mode = "reflection_normal"
				_start_scenario("scenario_01", REFLECTION_SEEDS[_reflection_index])
			else:
				print("[WO-007 Test] Reflection Test: all 5 seeds checked")
				_test_mode = "determinism_a"
				_start_scenario("scenario_01", 12345)
		"determinism_a":
			_determinism_a = _scenario.get_trace_text()
			_test_mode = "determinism_b"
			_start_scenario("scenario_01", 12345)
		"determinism_b":
			_determinism_b = _scenario.get_trace_text()
			if _determinism_a != _determinism_b:
				push_error("Determinism check failed")
				_exit_code = 1
			else:
				print("[WO-007 Test] Determinism: PASS (seed 12345)")
			_test_mode = "s1_seeds"
			_seed_index = 0
			_start_scenario("scenario_01", ALL_SEEDS[0])
		"s1_seeds":
			_record_s1()
			_seed_index += 1
			if _seed_index < ALL_SEEDS.size():
				_start_scenario("scenario_01", ALL_SEEDS[_seed_index])
			else:
				_print_s1_table()
				for r in _s1_results:
					_baseline_s1_winners[r.seed] = r.winner
				_test_mode = "s2_seeds"
				_seed_index = 0
				_start_scenario("scenario_02", ALL_SEEDS[0])
		"s2_seeds":
			_record_s2()
			_seed_index += 1
			if _seed_index < ALL_SEEDS.size():
				_start_scenario("scenario_02", ALL_SEEDS[_seed_index])
			else:
				_print_s2_table()
				for r in _s2_results:
					_baseline_s2_winners[r.seed] = r.winner
				_begin_sweep()
		"sweep":
			_record_sweep()
			_sweep_seed_index += 1
			if _sweep_seed_index < ALL_SEEDS.size():
				_start_scenario(_sweep_scene, ALL_SEEDS[_sweep_seed_index])
			elif _sweep_scene == "scenario_01":
				_sweep_scene = "scenario_02"
				_sweep_seed_index = 0
				_start_scenario("scenario_02", ALL_SEEDS[0])
			else:
				_finalize_sweep_cell()
				_sweep_cell += 1
				if _sweep_cell < SWEEP_DRAIN_METER.size() * SWEEP_DRAIN_STRENGTH.size():
					_begin_sweep_cell()
				else:
					_print_sweep_matrix()
					process_frame.disconnect(_on_process_frame)
					if _scenario != null:
						_scenario.free()
					quit(_exit_code)


func _check_reflection(seed_value: int, normal_trace: String, mirror_trace: String) -> void:
	var err := _compare_reflection_traces(normal_trace, mirror_trace)
	if err.is_empty():
		print("[WO-007 Test] Reflection seed %d: PASS" % seed_value)
	else:
		push_error("Reflection seed %d FAIL: %s" % [seed_value, err])
		_exit_code = 1


func _compare_reflection_traces(normal_trace: String, mirror_trace: String) -> String:
	var normal := _parse_trace_by_unit(normal_trace)
	var mirror := _parse_trace_by_unit(mirror_trace)
	for unit_id in ["red_1", "blue_1"]:
		if not normal.has(unit_id) or not mirror.has(unit_id):
			return "missing unit %s in trace" % unit_id
		var normal_times: Array = normal[unit_id].keys()
		normal_times.sort()
		for time_sec in normal_times:
			if not mirror[unit_id].has(time_sec):
				return "tick %.1fs missing mirror row for %s" % [time_sec, unit_id]
			var n: Dictionary = normal[unit_id][time_sec]
			var m: Dictionary = mirror[unit_id][time_sec]
			if absf(n.strength - m.strength) > STAT_TOL:
				return "tick %.1fs %s strength %.4f vs %.4f" % [time_sec, unit_id, n.strength, m.strength]
			if absf(n.cohesion - m.cohesion) > STAT_TOL:
				return "tick %.1fs %s cohesion %.4f vs %.4f" % [time_sec, unit_id, n.cohesion, m.cohesion]
			if n.kills != m.kills:
				return "tick %.1fs %s kills %d vs %d" % [time_sec, unit_id, n.kills, m.kills]
			if n.state != m.state:
				return "tick %.1fs %s state %s vs %s" % [time_sec, unit_id, n.state, m.state]
			if absf(n.pos_x + m.pos_x) > POS_TOL:
				return "tick %.1fs %s pos_x %.2f vs %.2f (not reflected)" % [time_sec, unit_id, n.pos_x, m.pos_x]
			if absf(n.pos_y - m.pos_y) > POS_TOL:
				return "tick %.1fs %s pos_y %.2f vs %.2f" % [time_sec, unit_id, n.pos_y, m.pos_y]
	return ""


func _parse_trace_by_unit(trace_text: String) -> Dictionary:
	var by_unit := {}
	for line in trace_text.split("\n", false):
		if line.is_empty() or line.begins_with("time_sec"):
			continue
		var parts := line.split(",")
		if parts.size() < 8:
			continue
		var time_sec := float(parts[0])
		var unit_id := parts[1]
		if not by_unit.has(unit_id):
			by_unit[unit_id] = {}
		by_unit[unit_id][time_sec] = {
			"strength": float(parts[2]),
			"cohesion": float(parts[3]),
			"kills": int(parts[4]),
			"pos_x": float(parts[5]),
			"pos_y": float(parts[6]),
			"state": parts[7],
		}
	return by_unit


func _record_s1() -> void:
	var phases: Dictionary = _scenario.get_phase_durations_sec()
	var seed_value: int = ALL_SEEDS[_seed_index]
	_s1_results.append({
		"seed": seed_value,
		"winner": _scenario.get_winner_id(),
		"combat_sec": phases.combat_sec,
	})


func _record_s2() -> void:
	var phases: Dictionary = _scenario.get_phase_durations_sec()
	var seed_value: int = ALL_SEEDS[_seed_index]
	_s2_results.append({
		"seed": seed_value,
		"winner": _scenario.get_winner_id(),
		"combat_sec": phases.combat_sec,
		"strength_at_rout": _scenario.get_strength_at_rout(),
	})


func _print_s1_table() -> void:
	print("[WO-007 Test] Scenario 1 post-fix (11 seeds):")
	for r in _s1_results:
		var old_w: String = WO005_S1_WINNERS.get(r.seed, "?")
		var old_c: float = WO005_S1_COMBAT.get(r.seed, -1.0)
		var w_flag := " *WINNER CHANGE*" if old_w != r.winner else ""
		print(
			"  seed %d -> %s | combat %.1fs (WO-005 %.1fs)%s"
			% [r.seed, r.winner, r.combat_sec, old_c, w_flag]
		)


func _print_s2_table() -> void:
	print("[WO-007 Test] Scenario 2 post-fix (11 seeds):")
	for r in _s2_results:
		var old_w: String = WO006_S2_WINNERS.get(r.seed, "?")
		var old_c: float = WO006_S2_COMBAT.get(r.seed, -1.0)
		var old_s: float = WO006_S2_STRENGTH_AT_ROUT.get(r.seed, -1.0)
		var w_flag := " *WINNER CHANGE*" if old_w != r.winner else ""
		print(
			"  seed %d -> %s | combat %.1fs (WO-006 %.1fs) | strength_at_rout %.2f (WO-006 %.2f)%s"
			% [r.seed, r.winner, r.combat_sec, old_c, r.strength_at_rout, old_s, w_flag]
		)


func _begin_sweep() -> void:
	_constants.reload_from_file()
	_sweep_cell = 0
	_begin_sweep_cell()


func _begin_sweep_cell() -> void:
	_constants.reload_from_file()
	var meter_idx := _sweep_cell / SWEEP_DRAIN_STRENGTH.size()
	var strength_idx := _sweep_cell % SWEEP_DRAIN_STRENGTH.size()
	_constants.set_constant("drain_per_meter_lost", SWEEP_DRAIN_METER[meter_idx])
	_constants.set_constant("drain_per_strength_pct_lost", SWEEP_DRAIN_STRENGTH[strength_idx])
	_sweep_accum_s1.clear()
	_sweep_accum_s2.clear()
	_sweep_scene = "scenario_01"
	_sweep_seed_index = 0
	_test_mode = "sweep"
	_start_scenario("scenario_01", ALL_SEEDS[0])


func _record_sweep() -> void:
	var seed_value: int = ALL_SEEDS[_sweep_seed_index]
	var phases: Dictionary = _scenario.get_phase_durations_sec()
	if _sweep_scene == "scenario_01":
		_sweep_accum_s1.append({
			"seed": seed_value,
			"winner": _scenario.get_winner_id(),
			"combat_sec": phases.combat_sec,
		})
	else:
		_sweep_accum_s2.append({
			"seed": seed_value,
			"winner": _scenario.get_winner_id(),
			"combat_sec": phases.combat_sec,
			"strength_at_rout": _scenario.get_strength_at_rout(),
		})


func _finalize_sweep_cell() -> void:
	var meter_idx := _sweep_cell / SWEEP_DRAIN_STRENGTH.size()
	var strength_idx := _sweep_cell % SWEEP_DRAIN_STRENGTH.size()
	var drain_m: float = SWEEP_DRAIN_METER[meter_idx]
	var drain_s: float = SWEEP_DRAIN_STRENGTH[strength_idx]

	var mean_s2_rout := 0.0
	var mean_s2_combat := 0.0
	var mean_s1_combat := 0.0
	var s1_winner_changes := 0
	var s2_winner_changes := 0

	for r in _sweep_accum_s2:
		mean_s2_rout += r.strength_at_rout
		mean_s2_combat += r.combat_sec
		if _baseline_s2_winners.get(r.seed, "") != r.winner:
			s2_winner_changes += 1
	for r in _sweep_accum_s1:
		mean_s1_combat += r.combat_sec
		if _baseline_s1_winners.get(r.seed, "") != r.winner:
			s1_winner_changes += 1

	mean_s2_rout /= float(_sweep_accum_s2.size())
	mean_s2_combat /= float(_sweep_accum_s2.size())
	mean_s1_combat /= float(_sweep_accum_s1.size())

	_sweep_rows.append({
		"drain_meter": drain_m,
		"drain_strength": drain_s,
		"mean_s2_rout": mean_s2_rout,
		"mean_s2_combat": mean_s2_combat,
		"mean_s1_combat": mean_s1_combat,
		"s1_winner_changes": s1_winner_changes,
		"s2_winner_changes": s2_winner_changes,
	})


func _print_sweep_matrix() -> void:
	_constants.reload_from_file()
	print("[WO-007 Test] Rout-band sweep matrix (experimental — constants file unchanged):")
	print("  drain_meter | drain_strength_pct | mean_s2_rout | mean_s2_combat | mean_s1_combat | s1_w_chg | s2_w_chg")
	for row in _sweep_rows:
		print(
			"  %.1f | %.1f | %.2f | %.1fs | %.1fs | %d | %d"
			% [
				row.drain_meter,
				row.drain_strength,
				row.mean_s2_rout,
				row.mean_s2_combat,
				row.mean_s1_combat,
				row.s1_winner_changes,
				row.s2_winner_changes,
			]
		)
