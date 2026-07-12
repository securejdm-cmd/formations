extends SceneTree

## Post-commit baseline capture for WO-007b (11 seeds, S1 + S2).

const ALL_SEEDS := [1000, 1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009, 12345]

var _scenario = null
var _phase: String = "idle"
var _mode: String = "s1"
var _seed_index: int = 0


func _initialize() -> void:
	process_frame.connect(_on_process_frame)
	_start("scenario_01", ALL_SEEDS[0])


func _on_process_frame() -> void:
	if _scenario == null or not _scenario.is_node_ready():
		return
	if _phase == "simulate":
		while not _scenario.is_battle_over():
			_scenario.advance_one_tick()
		_done()


func _start(scene_key: String, seed_value: int) -> void:
	if _scenario != null:
		_scenario.free()
		_scenario = null
	_phase = "spawn"
	root.get_node("RNG").set_seed(seed_value)
	var path := "res://tests/scenario_01.tscn" if scene_key == "scenario_01" else "res://tests/scenario_02.tscn"
	_scenario = load(path).instantiate()
	_scenario.headless_mode = true
	_scenario.set_battle_seed(seed_value)
	root.add_child(_scenario)
	_phase = "simulate"


func _done() -> void:
	var seed_value: int = ALL_SEEDS[_seed_index]
	var phases: Dictionary = _scenario.get_phase_durations_sec()
	if _mode == "s1":
		print(
			"[BASELINE S1] seed %d | %s | combat %.1fs"
			% [seed_value, _scenario.get_winner_id(), phases.combat_sec]
		)
	else:
		print(
			"[BASELINE S2] seed %d | %s | combat %.1fs | strength_at_rout %.2f"
			% [
				seed_value,
				_scenario.get_winner_id(),
				phases.combat_sec,
				_scenario.get_strength_at_rout(),
			]
		)
	_seed_index += 1
	if _seed_index < ALL_SEEDS.size():
		_start("scenario_01" if _mode == "s1" else "scenario_02", ALL_SEEDS[_seed_index])
	elif _mode == "s1":
		_mode = "s2"
		_seed_index = 0
		_start("scenario_02", ALL_SEEDS[0])
	else:
		process_frame.disconnect(_on_process_frame)
		_scenario.free()
		quit(0)
