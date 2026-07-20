extends SceneTree
## Capture S1/S2 baselines + S8 ratio distribution under QoD-on.


func _initialize() -> void:
	call_deferred("_run")


func _consts():
	return root.get_node("/root/Constants")


func _run_scene(path: String, seed_value: int, configure: Callable = Callable()) -> Variant:
	var packed: PackedScene = load(path)
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.auto_run = false
	sc.suppress_io = true
	sc.set_battle_seed(seed_value)
	if configure.is_valid():
		configure.call(sc)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(1000)
		spins += 1
	var ticks := 0
	while not sc.is_battle_over() and ticks < 30000:
		sc.advance_one_tick()
		ticks += 1
	return sc


func _run() -> void:
	print("WO028_REBASELINE qod=%s sigma=%s" % [
		str(_consts().get_constant("quality_of_day_enabled", false)),
		str(_consts().get_constant("quality_of_day_sigma", -1.0)),
	])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/traces/baseline"))
	print("WO013_S1 := {")
	for seed_value in [1000, 1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009, 12345]:
		var sc = _run_scene("res://tests/scenario_01.tscn", seed_value)
		var combat: float = float(sc.get_phase_durations_sec().get("combat_sec", -1.0))
		var winner: String = str(sc.get_winner_id())
		print('	%d: {"winner": "%s", "combat": %.1f},' % [seed_value, winner, combat])
		var f := FileAccess.open("res://tests/traces/baseline/scenario_01_%d.csv" % seed_value, FileAccess.WRITE)
		if f != null:
			f.store_string(sc.get_trace_text())
			f.close()
		sc.free()
	print("}")
	print("WO013_S2 := {")
	for seed_value in [1000, 1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009, 12345]:
		var sc2 = _run_scene("res://tests/scenario_02.tscn", seed_value)
		var combat2: float = float(sc2.get_phase_durations_sec().get("combat_sec", -1.0))
		var winner2: String = str(sc2.get_winner_id())
		var rout2: float = float(sc2.get_strength_at_rout())
		print('	%d: {"winner": "%s", "combat": %.1f, "rout": %.2f},' % [seed_value, winner2, combat2, rout2])
		var f2 := FileAccess.open("res://tests/traces/baseline/scenario_02_%d.csv" % seed_value, FileAccess.WRITE)
		if f2 != null:
			f2.store_string(sc2.get_trace_text())
			f2.close()
		sc2.free()
	print("}")

	# S8 blob ratios across seeds 1000-1009 (suite gate seed is 1000; derive cap from data)
	var ratios: Array = []
	for seed_value in range(1000, 1010):
		var single = _run_scene("res://tests/scenario_08.tscn", seed_value, func(sc): sc.attacker_count = 1)
		var d1: float = float(single.get_defender_damage_taken())
		single.free()
		var triple = _run_scene("res://tests/scenario_08.tscn", seed_value, func(sc): sc.attacker_count = 3)
		var d3: float = float(triple.get_defender_damage_taken())
		triple.free()
		var ratio: float = d3 / d1 if d1 > 0.0 else 0.0
		ratios.append(ratio)
		print("S8_RATIO seed=%d single=%.4f triple=%.4f ratio=%.4f" % [seed_value, d1, d3, ratio])
	var sum := 0.0
	var mn: float = float(ratios[0])
	var mx: float = float(ratios[0])
	for r in ratios:
		sum += float(r)
		mn = minf(mn, float(r))
		mx = maxf(mx, float(r))
	var mean := sum / float(ratios.size())
	var var_acc := 0.0
	for r in ratios:
		var d := float(r) - mean
		var_acc += d * d
	var sd := sqrt(var_acc / float(maxi(ratios.size() - 1, 1)))
	print("S8_STATS n=%d mean=%.6f sd=%.6f min=%.6f max=%.6f m3sd=%.6f p3sd=%.6f" % [
		ratios.size(), mean, sd, mn, mx, mean - 3.0 * sd, mean + 3.0 * sd,
	])

	_consts().reload_from_file()
	print("WO028_REBASELINE_DONE")
	quit(0)
