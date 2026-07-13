extends SceneTree

## WO-013: k_melee_scale × k_armor_scale tuning sweep (WO-007b pattern).

const ALL_SEEDS := [1000, 1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009, 12345]
const K_MELEE_VALUES := [0.042, 0.050, 0.058, 0.066, 0.074]
const K_ARMOR_VALUES := [0.85, 1.0, 1.15]

var _constants: Node
var _scenario = null
var _phase: String = "idle"
var _melee_idx: int = 0
var _armor_idx: int = 0
var _seed_index: int = 0
var _scene: String = "scenario_01"
var _accum_s1: Array[Dictionary] = []
var _accum_s2: Array[Dictionary] = []
var _rows: Array[Dictionary] = []
var _sim_harness: Script


func _initialize() -> void:
	_constants = root.get_node("Constants")
	_sim_harness = load("res://scripts/sim_harness.gd")
	process_frame.connect(_on_process_frame)
	_begin_cell()


func _on_process_frame() -> void:
	if _scenario == null:
		return
	if not _scenario.is_node_ready():
		return
	if _phase == "simulate":
		_sim_harness.run_to_completion(_scenario, _sim_harness.RunMode.FAST)
		_finish_current_scenario()


func _begin_cell() -> void:
	_constants.reload_from_file()
	_constants.set_constant("k_melee_scale", K_MELEE_VALUES[_melee_idx])
	_constants.set_constant("k_armor_scale", K_ARMOR_VALUES[_armor_idx])
	_accum_s1.clear()
	_accum_s2.clear()
	_scene = "scenario_01"
	_seed_index = 0
	_start_scenario("scenario_01", ALL_SEEDS[0])


func _start_scenario(scene_key: String, seed_value: int) -> void:
	if _scenario != null:
		_scenario.free()
		_scenario = null

	_phase = "spawn"
	var rng: Node = root.get_node("RNG")
	rng.set_seed(seed_value)
	var scene_path := "res://tests/scenario_01.tscn"
	if scene_key == "scenario_02":
		scene_path = "res://tests/scenario_02.tscn"
	var packed: PackedScene = load(scene_path)
	_scenario = packed.instantiate()
	_scenario.headless_mode = true
	_scenario.fast_sim_mode = true
	_scenario.set_battle_seed(seed_value)
	root.add_child(_scenario)
	_phase = "simulate"


func _finish_current_scenario() -> void:
	var seed_value: int = ALL_SEEDS[_seed_index]
	var phases: Dictionary = _scenario.get_phase_durations_sec()
	if _scene == "scenario_01":
		_accum_s1.append({
			"seed": seed_value,
			"winner": _scenario.get_winner_id(),
			"combat_sec": phases.combat_sec,
			"winner_strength": _scenario.get_winner_strength(),
		})
	else:
		_accum_s2.append({
			"seed": seed_value,
			"winner": _scenario.get_winner_id(),
			"combat_sec": phases.combat_sec,
			"strength_at_rout": _scenario.get_strength_at_rout(),
		})

	_seed_index += 1
	if _seed_index < ALL_SEEDS.size():
		_start_scenario(_scene, ALL_SEEDS[_seed_index])
	elif _scene == "scenario_01":
		_scene = "scenario_02"
		_seed_index = 0
		_start_scenario("scenario_02", ALL_SEEDS[0])
	else:
		_finalize_cell()
		_armor_idx += 1
		if _armor_idx >= K_ARMOR_VALUES.size():
			_armor_idx = 0
			_melee_idx += 1
		if _melee_idx < K_MELEE_VALUES.size():
			_begin_cell()
		else:
			_print_matrix()
			_select_and_report()
			process_frame.disconnect(_on_process_frame)
			if _scenario != null:
				_scenario.free()
			quit(0)


func _finalize_cell() -> void:
	var mean_s1 := 0.0
	var mean_s2_rout := 0.0
	var mean_winner_strength := 0.0
	var max_winner_strength := 0.0

	for r in _accum_s1:
		mean_s1 += r.combat_sec
		mean_winner_strength += r.winner_strength
		max_winner_strength = maxf(max_winner_strength, r.winner_strength)
	for r in _accum_s2:
		mean_s2_rout += r.strength_at_rout

	mean_s1 /= float(_accum_s1.size())
	mean_s2_rout /= float(_accum_s2.size())
	mean_winner_strength /= float(_accum_s1.size())

	_rows.append({
		"k_melee_scale": K_MELEE_VALUES[_melee_idx],
		"k_armor_scale": K_ARMOR_VALUES[_armor_idx],
		"mean_s1_combat": mean_s1,
		"mean_s2_rout": mean_s2_rout,
		"mean_winner_strength": mean_winner_strength,
		"max_winner_strength": max_winner_strength,
	})


func _print_matrix() -> void:
	print("[WO-013] Melee tuning sweep (%d cells):" % _rows.size())
	print("  k_melee | k_armor | mean_s1 | mean_s2_rout | mean_win_str | max_win_str")
	for row in _rows:
		print(
			"  %.4f | %.2f | %.1fs | %.2f | %.2f | %.2f"
			% [
				row.k_melee_scale,
				row.k_armor_scale,
				row.mean_s1_combat,
				row.mean_s2_rout,
				row.mean_winner_strength,
				row.max_winner_strength,
			]
		)


func _select_and_report() -> void:
	var target_s1 := 80.0
	var best: Dictionary = {}
	var best_score := INF

	for row in _rows:
		if row.mean_s1_combat < 60.0 or row.mean_s1_combat > 90.0:
			continue
		if row.mean_s2_rout < 60.0 or row.mean_s2_rout > 75.0:
			continue
		if row.max_winner_strength >= 55.0:
			continue
		var score := absf(row.mean_s1_combat - target_s1)
		if score < best_score:
			best_score = score
			best = row

	if best.is_empty():
		print("[WO-013] SELECTION: NONE — no cell satisfies all three gates")
	else:
		print(
			"[WO-013] SELECTION: k_melee_scale=%.4f k_armor_scale=%.2f | S1=%.1fs | S2 rout=%.2f | mean_win=%.2f"
			% [
				best.k_melee_scale,
				best.k_armor_scale,
				best.mean_s1_combat,
				best.mean_s2_rout,
				best.mean_winner_strength,
			]
		)
