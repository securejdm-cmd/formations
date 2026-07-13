extends SceneTree

## Capture S1/S2/S3 trace baselines and print re-baseline tables after WO-013 constants commit.

const ALL_SEEDS := [1000, 1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009, 12345]

var _sim_harness: Script
var _scenario = null
var _phase := "s1"
var _seed_idx := 0
var _s1_rows: Array[Dictionary] = []
var _s2_rows: Array[Dictionary] = []


func _initialize() -> void:
	_sim_harness = load("res://scripts/sim_harness.gd")
	call_deferred("_run_s1", ALL_SEEDS[0])


func _run_s1(seed_value: int) -> void:
	_run_scene("res://tests/scenario_01.tscn", seed_value, func(scenario):
		var phases: Dictionary = scenario.get_phase_durations_sec()
		_s1_rows.append({
			"seed": seed_value,
			"winner": scenario.get_winner_id(),
			"combat": phases.combat_sec,
			"winner_strength": scenario.get_winner_strength(),
		})
	)


func _run_s2(seed_value: int) -> void:
	_run_scene("res://tests/scenario_02.tscn", seed_value, func(scenario):
		var phases: Dictionary = scenario.get_phase_durations_sec()
		_s2_rows.append({
			"seed": seed_value,
			"winner": scenario.get_winner_id(),
			"combat": phases.combat_sec,
			"rout": scenario.get_strength_at_rout(),
		})
	)


func _run_s3() -> void:
	_run_scene("res://tests/scenario_03.tscn", 1000, func(scenario):
		var phases: Dictionary = scenario.get_phase_durations_sec()
		var s1_ref: float = _s1_rows[0].combat if not _s1_rows.is_empty() else 1.0
		var ratio: float = phases.combat_sec / s1_ref if s1_ref > 0.0 else 0.0
		print("[WO-013] S3 seed 1000 combat=%.1fs ratio=%.3f rout=%.2f" % [
			phases.combat_sec, ratio, scenario.get_blue_a_strength_at_rout()
		])
		_print_tables()
		if _scenario != null:
			_scenario.free()
		quit(0)
	)


func _run_scene(path: String, seed_value: int, on_done: Callable) -> void:
	if _scenario != null:
		_scenario.free()
		_scenario = null
	var rng: Node = root.get_node("RNG")
	rng.set_seed(seed_value)
	var packed: PackedScene = load(path)
	_scenario = packed.instantiate()
	_scenario.headless_mode = true
	_scenario.fast_sim_mode = true
	_scenario.set_battle_seed(seed_value)
	root.add_child(_scenario)
	call_deferred("_simulate_scene", on_done)


func _simulate_scene(on_done: Callable) -> void:
	if _scenario == null or not _scenario.is_node_ready():
		call_deferred("_simulate_scene", on_done)
		return
	_sim_harness.run_to_completion(_scenario, _sim_harness.RunMode.FAST)
	on_done.call(_scenario)
	_advance()


func _advance() -> void:
	match _phase:
		"s1":
			_seed_idx += 1
			if _seed_idx < ALL_SEEDS.size():
				_run_s1(ALL_SEEDS[_seed_idx])
			else:
				_phase = "s2"
				_seed_idx = 0
				_run_s2(ALL_SEEDS[0])
		"s2":
			_seed_idx += 1
			if _seed_idx < ALL_SEEDS.size():
				_run_s2(ALL_SEEDS[_seed_idx])
			else:
				_phase = "s3"
				_run_s3()


func _print_tables() -> void:
	print("[WO-013] S1 re-baseline:")
	for row in _s1_rows:
		print(
			"  %d: winner=%s combat=%.1f winner_strength=%.2f"
			% [row.seed, row.winner, row.combat, row.winner_strength]
		)
	print("[WO-013] S2 re-baseline:")
	for row in _s2_rows:
		print("  %d: winner=%s combat=%.1f rout=%.2f" % [row.seed, row.winner, row.combat, row.rout])
