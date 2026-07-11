extends SceneTree

## Headless acceptance harness for WO-002 Scenario 1.

var _constants: Node
var _scenario = null
var _exit_code: int = 0
var _phase: String = "idle"
var _determinism_a: String = ""
var _determinism_b: String = ""
var _ten_seed_outcomes: Array[String] = []
var _ten_seed_index: int = 0
var _pending_seed: int = 0
var _test_mode: String = ""


func _initialize() -> void:
	_constants = root.get_node("Constants")
	process_frame.connect(_on_process_frame)
	_begin_determinism_test()


func _on_process_frame() -> void:
	if _scenario == null:
		return

	if not _scenario.is_node_ready():
		return

	if _phase == "simulate":
		if _scenario.is_battle_over():
			_finish_current_scenario()
			return
		_scenario.advance_one_tick()


func _begin_determinism_test() -> void:
	_test_mode = "determinism_a"
	_pending_seed = _constants.get_int("scenario_01_battle_seed")
	_start_scenario(_pending_seed)


func _start_scenario(seed_value: int) -> void:
	if _scenario != null:
		_scenario.free()
		_scenario = null

	_phase = "spawn"
	var rng: Node = root.get_node("RNG")
	rng.set_seed(seed_value)
	var packed: PackedScene = load("res://tests/scenario_01.tscn")
	_scenario = packed.instantiate()
	_scenario.set_battle_seed(seed_value)
	root.add_child(_scenario)
	_phase = "simulate"


func _finish_current_scenario() -> void:
	match _test_mode:
		"determinism_a":
			_determinism_a = _scenario.get_trace_text()
			_test_mode = "determinism_b"
			_start_scenario(_constants.get_int("scenario_01_battle_seed"))
		"determinism_b":
			_determinism_b = _scenario.get_trace_text()
			if _determinism_a != _determinism_b:
				push_error("Determinism check failed: trace CSVs differ for same seed")
				_exit_code = 1
			else:
				print(
					"[WO-002 Test] Determinism: PASS (seed %d)"
					% _constants.get_int("scenario_01_battle_seed")
				)
			_test_mode = "ten_seed"
			_ten_seed_index = 0
			_start_scenario(1000)
		"ten_seed":
			_ten_seed_outcomes.append(_scenario.get_winner_id())
			print(
				"[WO-002 Test] Seed %d winner: %s"
				% [1000 + _ten_seed_index, _scenario.get_winner_id()]
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
			if winner == "none":
				push_error("Primary seed battle did not produce a winner")
				_exit_code = 1
			else:
				print("[WO-002 Test] Primary seed winner: %s" % winner)
			process_frame.disconnect(_on_process_frame)
			if _scenario != null:
				_scenario.free()
			quit(_exit_code)


func _print_outcome_table() -> void:
	print("[WO-002 Test] 10-run outcome table:")
	for i in _ten_seed_outcomes.size():
		print("  seed %d -> %s" % [1000 + i, _ten_seed_outcomes[i]])
