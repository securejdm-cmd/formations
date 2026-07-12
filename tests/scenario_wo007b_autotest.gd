extends SceneTree

## WO-007b: K_dmg mini-sweep with fixed drains (0.8 / 2.5).

const ALL_SEEDS := [1000, 1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009, 12345]
const K_DMG_VALUES := [0.0020, 0.0025, 0.0030]

const BASELINE_S1_WINNERS := {
	1000: "red_1", 1001: "red_1", 1002: "blue_1", 1003: "blue_1", 1004: "red_1",
	1005: "red_1", 1006: "red_1", 1007: "red_1", 1008: "red_1", 1009: "red_1", 12345: "blue_1",
}
const BASELINE_S2_WINNERS := {
	1000: "red_1", 1001: "red_1", 1002: "red_1", 1003: "red_1", 1004: "red_1",
	1005: "red_1", 1006: "red_1", 1007: "red_1", 1008: "red_1", 1009: "red_1", 12345: "red_1",
}

var _constants: Node
var _scenario = null
var _phase: String = "idle"
var _test_mode: String = "sweep"
var _k_index: int = 0
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
	_begin_k_cell()


func _on_process_frame() -> void:
	if _scenario == null:
		return
	if not _scenario.is_node_ready():
		return
	if _phase == "simulate":
		_sim_harness.run_to_completion(_scenario, _sim_harness.RunMode.FAST)
		_finish_current_scenario()


func _begin_k_cell() -> void:
	_constants.reload_from_file()
	_constants.set_constant("drain_per_meter_lost", 0.8)
	_constants.set_constant("drain_per_strength_pct_lost", 2.5)
	_constants.set_constant("k_dmg", K_DMG_VALUES[_k_index])
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
		_finalize_k_cell()
		_k_index += 1
		if _k_index < K_DMG_VALUES.size():
			_begin_k_cell()
		else:
			_print_matrix()
			_select_and_report()
			process_frame.disconnect(_on_process_frame)
			if _scenario != null:
				_scenario.free()
			quit(0)


func _finalize_k_cell() -> void:
	var k_dmg: float = K_DMG_VALUES[_k_index]
	var mean_s1 := 0.0
	var mean_s2 := 0.0
	var mean_s2_rout := 0.0
	var s1_w_chg := 0
	var s2_w_chg := 0

	for r in _accum_s1:
		mean_s1 += r.combat_sec
		if BASELINE_S1_WINNERS.get(r.seed, "") != r.winner:
			s1_w_chg += 1
	for r in _accum_s2:
		mean_s2 += r.combat_sec
		mean_s2_rout += r.strength_at_rout
		if BASELINE_S2_WINNERS.get(r.seed, "") != r.winner:
			s2_w_chg += 1

	mean_s1 /= float(_accum_s1.size())
	mean_s2 /= float(_accum_s2.size())
	mean_s2_rout /= float(_accum_s2.size())

	_rows.append({
		"k_dmg": k_dmg,
		"mean_s1_combat": mean_s1,
		"mean_s2_combat": mean_s2,
		"mean_s2_rout": mean_s2_rout,
		"s1_winner_changes": s1_w_chg,
		"s2_winner_changes": s2_w_chg,
	})


func _print_matrix() -> void:
	print("[WO-007b] K_dmg sweep (drain_meter=0.8, drain_strength=2.5):")
	print("  k_dmg | mean_s1_combat | mean_s2_combat | mean_s2_rout | s1_w_chg | s2_w_chg")
	for row in _rows:
		print(
			"  %.4f | %.1fs | %.1fs | %.2f | %d | %d"
			% [
				row.k_dmg,
				row.mean_s1_combat,
				row.mean_s2_combat,
				row.mean_s2_rout,
				row.s1_winner_changes,
				row.s2_winner_changes,
			]
		)


func _select_and_report() -> void:
	var target_s1 := 80.0
	var best: Dictionary = {}
	var best_dist := INF

	for row in _rows:
		if row.mean_s2_rout < 55.0 or row.mean_s2_rout > 80.0:
			continue
		var dist := absf(row.mean_s1_combat - target_s1)
		if dist < best_dist:
			best_dist = dist
			best = row

	if best.is_empty():
		print("[WO-007b] SELECTION: NONE — no cell satisfies S2 rout 55-80%")
	else:
		print(
			"[WO-007b] SELECTION: k_dmg=%.4f | S1=%.1fs | S2 rout=%.2f"
			% [best.k_dmg, best.mean_s1_combat, best.mean_s2_rout]
		)
