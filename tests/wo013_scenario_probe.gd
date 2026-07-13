extends SceneTree

const SEEDS := [1000, 1002, 1003, 1007, 12345]

var _harness: Script
var _queue: Array[Dictionary] = []
var _idx := 0


func _initialize() -> void:
	_harness = load("res://scripts/sim_harness.gd")
	for seed in SEEDS:
		_queue.append({"path": "res://tests/scenario_09.tscn", "seed": seed, "aa": 0.0})
	for seed in [1000]:
		_queue.append({"path": "res://tests/scenario_10.tscn", "seed": seed, "aa": 0.0})
		_queue.append({"path": "res://tests/scenario_11.tscn", "seed": seed, "aa": 0.0})
		_queue.append({"path": "res://tests/scenario_11.tscn", "seed": seed, "aa": 15.0})
	call_deferred("_run_next")


func _run_next() -> void:
	if _idx >= _queue.size():
		quit(0)
		return
	var item: Dictionary = _queue[_idx]
	var rng: Node = root.get_node("RNG")
	rng.set_seed(item.seed)
	var packed: PackedScene = load(item.path)
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.set_battle_seed(item.seed)
	if item.path.ends_with("11.tscn"):
		sc.set("attacker_anti_armor", item.aa)
	root.add_child(sc)
	call_deferred("_simulate", sc, item)


func _simulate(sc, item: Dictionary) -> void:
	if not sc.is_node_ready():
		call_deferred("_simulate", sc, item)
		return
	_harness.run_to_completion(sc, _harness.RunMode.FAST)
	if item.path.ends_with("09.tscn"):
		print("S9 seed %d winner=%s ratio=%.3f" % [item.seed, sc.get_winner_id(), sc.get_casualty_ratio()])
	elif item.path.ends_with("10.tscn"):
		print("S10 seed %d winner=%s" % [item.seed, sc.get_winner_id()])
	else:
		print("S11 seed %d aa=%.0f combat=%.1fs plate_dmg=%.2f" % [
			item.seed, item.aa, sc.get_combat_duration_sec(), sc.get_plate_damage_taken()
		])
	sc.free()
	_idx += 1
	_run_next()
