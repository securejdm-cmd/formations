extends SceneTree

## Headless acceptance harness for WO-005 Scenario 1.

const WO003_WINNERS := {
	1000: "red_1",
	1001: "red_1",
	1002: "blue_1",
	1003: "blue_1",
	1004: "red_1",
	1005: "red_1",
	1006: "red_1",
	1007: "red_1",
	1008: "red_1",
	1009: "red_1",
	12345: "blue_1",
}

const WO003_COMBAT_SEC := {
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
var _determinism_a: String = ""
var _determinism_b: String = ""
var _ten_seed_results: Array[Dictionary] = []
var _ten_seed_index: int = 0
var _test_mode: String = ""
var _sim_harness: Script


func _initialize() -> void:
	_constants = root.get_node("Constants")
	_sim_harness = load("res://scripts/sim_harness.gd")
	process_frame.connect(_on_process_frame)
	_begin_determinism_test()


func _on_process_frame() -> void:
	if _scenario == null:
		return

	if not _scenario.is_node_ready():
		return

	if _phase == "simulate":
		_sim_harness.run_to_completion(_scenario, _sim_harness.RunMode.FAST)
		_finish_current_scenario()


func _begin_determinism_test() -> void:
	_test_mode = "determinism_a"
	_start_scenario(_constants.get_int("scenario_01_battle_seed"))


func _start_scenario(seed_value: int) -> void:
	if _scenario != null:
		_scenario.free()
		_scenario = null

	_phase = "spawn"
	var rng: Node = root.get_node("RNG")
	rng.set_seed(seed_value)
	var packed: PackedScene = load("res://tests/scenario_01.tscn")
	_scenario = packed.instantiate()
	_scenario.headless_mode = true
	_scenario.fast_sim_mode = true
	_scenario.set_battle_seed(seed_value)
	root.add_child(_scenario)
	_phase = "simulate"


func _finish_current_scenario() -> void:
	if _scenario.had_overlap_failure():
		push_error("Overlap assertion failed for seed scenario")
		_exit_code = 1

	var trace_text: String = _scenario.get_trace_text()
	if not trace_text.contains(",kills,"):
		push_error("Trace CSV missing kills column")
		_exit_code = 1

	match _test_mode:
		"determinism_a":
			_determinism_a = trace_text
			_test_mode = "determinism_b"
			_start_scenario(_constants.get_int("scenario_01_battle_seed"))
		"determinism_b":
			_determinism_b = trace_text
			if _determinism_a != _determinism_b:
				push_error("Determinism check failed: trace CSVs differ for same seed")
				_exit_code = 1
			else:
				print(
					"[WO-005 Test] Determinism: PASS (seed %d)"
					% _constants.get_int("scenario_01_battle_seed")
				)
			_test_mode = "mirror_kills"
			_start_scenario(_constants.get_int("scenario_01_battle_seed"))
		"mirror_kills":
			_check_mirror_kills()
			_test_mode = "ten_seed"
			_ten_seed_index = 0
			_start_scenario(1000)
		"ten_seed":
			var seed_value := 1000 + _ten_seed_index
			var phases: Dictionary = _scenario.get_phase_durations_sec()
			var winner: String = _scenario.get_winner_id()
			_ten_seed_results.append({
				"seed": seed_value,
				"winner": winner,
				"march_sec": phases.march_sec,
				"combat_sec": phases.combat_sec,
				"flee_sec": phases.flee_sec,
			})
			if WO003_WINNERS.has(seed_value) and WO003_WINNERS[seed_value] != winner:
				push_error(
					"Winner flip on seed %d: was %s now %s"
					% [seed_value, WO003_WINNERS[seed_value], winner]
				)
				_exit_code = 1
			print(
				"[WO-005 Test] Seed %d winner: %s | combat: %.1fs (WO-003: %.1fs)"
				% [
					seed_value,
					winner,
					phases.combat_sec,
					WO003_COMBAT_SEC.get(seed_value, -1.0),
				]
			)
			_ten_seed_index += 1
			if _ten_seed_index < 10:
				_start_scenario(1000 + _ten_seed_index)
			else:
				_print_outcome_table()
				_test_mode = "primary_seed"
				_start_scenario(_constants.get_int("scenario_01_battle_seed"))
		"primary_seed":
			var winner: String = _scenario.get_winner_id()
			var phases: Dictionary = _scenario.get_phase_durations_sec()
			if winner == "none":
				push_error("Primary seed battle did not produce a winner")
				_exit_code = 1
			else:
				print(
					"[WO-005 Test] Primary seed winner: %s | combat: %.1fs"
					% [winner, phases.combat_sec]
				)
				if phases.combat_sec < 45.0 or phases.combat_sec > 120.0:
					print(
						"[WO-005 Test] NOTE: Combat %.1fs outside 45-120s band — Task 3 geometry change; traces delivered, no self-tuning"
						% phases.combat_sec
					)
			process_frame.disconnect(_on_process_frame)
			if _scenario != null:
				_scenario.free()
			quit(_exit_code)


func _check_mirror_kills() -> void:
	var kills: Dictionary = _scenario.get_unit_kill_totals()
	var red_kills: int = int(kills.get("red_1", 0))
	var blue_kills: int = int(kills.get("blue_1", 0))
	var red_unit: Unit = null
	var blue_unit: Unit = null
	for unit in _scenario._units:
		if unit.unit_id == "red_1":
			red_unit = unit
		elif unit.unit_id == "blue_1":
			blue_unit = unit

	if red_unit == null or blue_unit == null:
		push_error("Mirror kill check: missing units")
		_exit_code = 1
		return

	var men_per_strength: float = (
		_constants.get_float("men_per_full_unit") / _constants.get_float("strength_max")
	)
	var blue_men_remaining := int(round(blue_unit.strength * men_per_strength))
	var red_men_remaining := int(round(red_unit.strength * men_per_strength))
	var tolerance := 30

	if absi(red_kills + blue_men_remaining - 1000) > tolerance:
		push_error(
			"Men accounting failed (red kills + blue remaining): %d + %d != ~1000"
			% [red_kills, blue_men_remaining]
		)
		_exit_code = 1
	elif absi(blue_kills + red_men_remaining - 1000) > tolerance:
		push_error(
			"Men accounting failed (blue kills + red remaining): %d + %d != ~1000"
			% [blue_kills, red_men_remaining]
		)
		_exit_code = 1
	else:
		print(
			"[WO-005 Test] Kill accounting: PASS (red=%d, blue=%d)"
			% [red_kills, blue_kills]
		)


func _print_outcome_table() -> void:
	print("[WO-005 Test] 10-run outcome table:")
	for result in _ten_seed_results:
		var old_combat: float = WO003_COMBAT_SEC.get(result.seed, -1.0)
		print(
			"  seed %d -> %s | march %.1fs | combat %.1fs (was %.1fs) | flee %.1fs"
			% [
				result.seed,
				result.winner,
				result.march_sec,
				result.combat_sec,
				old_combat,
				result.flee_sec,
			]
		)
