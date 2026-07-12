extends SceneTree

## Headless acceptance harness for WO-006: Scenario 2 + mirror bias audit.

const SEEDS := [1000, 1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009, 12345]
const MIRROR_SEEDS := [1000, 1001, 1002, 1003, 1004]

const SCENARIO_01_WINNERS := {
	1000: "red_1",
	1001: "red_1",
	1002: "blue_1",
	1003: "blue_1",
	1004: "red_1",
}

const SCENARIO_01_COMBAT_SEC := {
	1000: 76.2,
	1001: 83.4,
	1002: 77.0,
	1003: 84.2,
	1004: 96.2,
	1005: 75.2,
	1006: 73.2,
	1007: 77.2,
	1008: 82.0,
	1009: 91.4,
	12345: 78.0,
}

var _constants: Node
var _scenario = null
var _exit_code: int = 0
var _phase: String = "idle"
var _test_mode: String = ""
var _determinism_a: String = ""
var _determinism_b: String = ""
var _seed_index: int = 0
var _scenario2_results: Array[Dictionary] = []
var _mirror_index: int = 0
var _mirror_results: Array[Dictionary] = []
var _normal_trace_by_seed: Dictionary = {}
var _mirror_trace_by_seed: Dictionary = {}
var _sim_harness: Script


func _initialize() -> void:
	_constants = root.get_node("Constants")
	_sim_harness = load("res://scripts/sim_harness.gd")
	process_frame.connect(_on_process_frame)
	_test_mode = "s2_determinism_a"
	_start_scenario("scenario_02", 12345)


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
	var scene_path := "res://tests/scenario_02.tscn"
	match scene_key:
		"scenario_01":
			scene_path = "res://tests/scenario_01.tscn"
		"scenario_01_mirror":
			scene_path = "res://tests/scenario_01_mirror.tscn"
	var packed: PackedScene = load(scene_path)
	_scenario = packed.instantiate()
	_scenario.headless_mode = true
	_scenario.fast_sim_mode = true
	_scenario.set_battle_seed(seed_value)
	root.add_child(_scenario)
	_phase = "simulate"


func _finish_current_scenario() -> void:
	if _scenario.had_overlap_failure():
		push_error("Overlap assertion failed in mode %s" % _test_mode)
		_exit_code = 1

	match _test_mode:
		"s2_determinism_a":
			_determinism_a = _scenario.get_trace_text()
			_test_mode = "s2_determinism_b"
			_start_scenario("scenario_02", 12345)
		"s2_determinism_b":
			_determinism_b = _scenario.get_trace_text()
			if _determinism_a != _determinism_b:
				push_error("Scenario 2 determinism check failed")
				_exit_code = 1
			else:
				print("[WO-006 Test] Scenario 2 determinism: PASS (seed 12345)")
			_test_mode = "s2_seeds"
			_seed_index = 0
			_start_scenario("scenario_02", SEEDS[0])
		"s2_seeds":
			_record_scenario2_result()
			_seed_index += 1
			if _seed_index < SEEDS.size():
				_start_scenario("scenario_02", SEEDS[_seed_index])
			else:
				_print_scenario2_table()
				_test_mode = "mirror_normal"
				_mirror_index = 0
				_start_scenario("scenario_01", MIRROR_SEEDS[0])
		"mirror_normal":
			var seed_value: int = MIRROR_SEEDS[_mirror_index]
			_normal_trace_by_seed[seed_value] = _scenario.get_trace_text()
			_mirror_results.append({
				"seed": seed_value,
				"normal_winner": _scenario.get_winner_id(),
			})
			_test_mode = "mirror_swapped"
			_start_scenario("scenario_01_mirror", seed_value)
		"mirror_swapped":
			var seed_value: int = MIRROR_SEEDS[_mirror_index]
			var mirror_winner: String = _scenario.get_winner_id()
			_mirror_trace_by_seed[seed_value] = _scenario.get_trace_text()
			var row: Dictionary = _mirror_results[_mirror_index]
			row["mirrored_winner"] = mirror_winner
			row["symmetric"] = _is_symmetric(row.normal_winner, mirror_winner)
			if not row.symmetric:
				var divergence := _find_trace_divergence(
					int(row.seed),
					_normal_trace_by_seed[seed_value],
					_mirror_trace_by_seed[seed_value]
				)
				row["divergence"] = divergence
				push_error(
					"Mirror asymmetry seed %d: normal=%s mirrored=%s | first divergence: %s"
					% [seed_value, row.normal_winner, mirror_winner, divergence]
				)
			_mirror_index += 1
			if _mirror_index < MIRROR_SEEDS.size():
				_test_mode = "mirror_normal"
				_start_scenario("scenario_01", MIRROR_SEEDS[_mirror_index])
			else:
				_print_mirror_table()
				process_frame.disconnect(_on_process_frame)
				if _scenario != null:
					_scenario.free()
				quit(_exit_code)


func _record_scenario2_result() -> void:
	var phases: Dictionary = _scenario.get_phase_durations_sec()
	var winner: String = _scenario.get_winner_id()
	var strength_at_rout: float = _scenario.get_strength_at_rout()
	var routed_id: String = _scenario.get_routed_unit_id()
	var displacement_m: float = _scenario.get_ground_displacement_m()
	var seed_value: int = SEEDS[_seed_index]
	var s1_combat: float = SCENARIO_01_COMBAT_SEC.get(seed_value, -1.0)
	_scenario2_results.append({
		"seed": seed_value,
		"winner": winner,
		"strength_at_rout": strength_at_rout,
		"routed_unit": routed_id,
		"ground_displacement_m": displacement_m,
		"combat_sec": phases.combat_sec,
		"s1_combat_sec": s1_combat,
	})
	print(
		"[WO-006 Test] S2 seed %d | winner=%s | strength_at_rout=%.2f (%s) | displacement=%.2fm | combat=%.1fs (S1=%.1fs)"
		% [
			seed_value,
			winner,
			strength_at_rout,
			routed_id,
			displacement_m,
			phases.combat_sec,
			s1_combat,
		]
	)


func _print_scenario2_table() -> void:
	print("[WO-006 Test] Scenario 2 outcome table:")
	var push60_wins := 0
	for result in _scenario2_results:
		if result.winner == "red_1":
			push60_wins += 1
		print(
			"  seed %d -> %s | strength_at_rout=%.2f | displacement=%.2fm | combat %.1fs (S1 %.1fs)"
			% [
				result.seed,
				result.winner,
				result.strength_at_rout,
				result.ground_displacement_m,
				result.combat_sec,
				result.s1_combat_sec,
			]
		)
	print("[WO-006 Test] push60 (red_1) wins: %d / %d" % [push60_wins, _scenario2_results.size()])


func _is_symmetric(normal_winner: String, mirror_winner: String) -> bool:
	if normal_winner == "red_1" and mirror_winner == "blue_1":
		return true
	if normal_winner == "blue_1" and mirror_winner == "red_1":
		return true
	return false


func _print_mirror_table() -> void:
	print("[WO-006 Test] Mirror bias audit (seeds 1000-1004):")
	print("  seed | normal_winner | mirrored_winner | SYMMETRIC")
	for row in _mirror_results:
		var sym := "yes" if row.symmetric else "NO"
		var extra := "" if row.symmetric else " | divergence: %s" % row.get("divergence", "")
		print(
			"  %d | %s | %s | %s%s"
			% [
				row.seed,
				row.normal_winner,
				row.mirrored_winner,
				sym,
				extra,
			]
		)


func _find_trace_divergence(
	seed_value: int,
	normal_trace: String,
	mirror_trace: String
) -> String:
	var normal_rows := _parse_trace_rows(normal_trace)
	var mirror_rows := _parse_trace_rows(mirror_trace)
	var left_slot_map := {"red_1": "blue_1", "blue_1": "red_1"}
	var all_times := {}
	for time_sec in normal_rows.keys():
		all_times[time_sec] = true
	for time_sec in mirror_rows.keys():
		all_times[time_sec] = true
	var sorted_times: Array = all_times.keys()
	sorted_times.sort()

	for time_sec in sorted_times:
		if not normal_rows.has(time_sec) or not mirror_rows.has(time_sec):
			return "tick %.1fs — row count mismatch" % time_sec
		var normal_at_time: Dictionary = normal_rows[time_sec]
		var mirror_at_time: Dictionary = mirror_rows[time_sec]
		for unit_id in ["red_1", "blue_1"]:
			if not normal_at_time.has(unit_id) or not mirror_at_time.has(left_slot_map[unit_id]):
				return "tick %.1fs — missing unit row for %s" % [time_sec, unit_id]
			var n: Dictionary = normal_at_time[unit_id]
			var m: Dictionary = mirror_at_time[left_slot_map[unit_id]]
			if absf(n.strength - m.strength) > 0.0001:
				return (
					"tick %.1fs — %s strength normal=%.4f mirror_slot=%.4f"
					% [time_sec, unit_id, n.strength, m.strength]
				)
			if absf(n.cohesion - m.cohesion) > 0.0001:
				return (
					"tick %.1fs — %s cohesion normal=%.4f mirror_slot=%.4f"
					% [time_sec, unit_id, n.cohesion, m.cohesion]
				)
			if n.kills != m.kills:
				return (
					"tick %.1fs — %s kills normal=%d mirror_slot=%d"
					% [time_sec, unit_id, n.kills, m.kills]
				)
			if absf(n.pos_x - m.pos_x) > 0.05:
				return (
					"tick %.1fs — %s pos_x normal=%.2f mirror_slot=%.2f"
					% [time_sec, unit_id, n.pos_x, m.pos_x]
				)
			if n.state != m.state:
				return (
					"tick %.1fs — %s state normal=%s mirror_slot=%s"
					% [time_sec, unit_id, n.state, m.state]
				)

	return "no slot-mapped divergence found — winner-only asymmetry seed %d" % seed_value


func _parse_trace_rows(trace_text: String) -> Dictionary:
	var by_time := {}
	for line in trace_text.split("\n", false):
		if line.is_empty() or line.begins_with("time_sec"):
			continue
		var parts := line.split(",")
		if parts.size() < 8:
			continue
		var time_sec := float(parts[0])
		var unit_id := parts[1]
		if not by_time.has(time_sec):
			by_time[time_sec] = {}
		by_time[time_sec][unit_id] = {
			"strength": float(parts[2]),
			"cohesion": float(parts[3]),
			"kills": int(parts[4]),
			"pos_x": float(parts[5]),
			"pos_y": float(parts[6]),
			"state": parts[7],
		}
	return by_time
