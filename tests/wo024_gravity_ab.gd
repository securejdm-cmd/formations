extends SceneTree
## WO-024 Task 2 — S1/S2/S3 gravity A/B (engage_radius 4 vs 0 must be byte-identical).


func _initialize() -> void:
	call_deferred("_run")


func _consts():
	return root.get_node("/root/Constants")


func _run_scenario(scene_path: String, radius: float, seed_value: int) -> Dictionary:
	_consts().set_constant("engage_radius_m", radius)
	var packed: PackedScene = load(scene_path)
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.set_battle_seed(seed_value)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(2000)
		spins += 1
	var ticks := 0
	while not sc.is_battle_over() and ticks < 30000:
		sc.advance_one_tick()
		ticks += 1
	var out := {
		"winner": str(sc.get_winner_id()),
		"combat": float(sc.get_phase_durations_sec().get("combat_sec", -1.0)),
		"trace": sc.get_trace_text(),
		"ticks": ticks,
	}
	sc.free()
	return out


func _ab(label: String, scene_path: String, seed_value: int) -> bool:
	var a: Dictionary = _run_scenario(scene_path, 4.0, seed_value)
	var b: Dictionary = _run_scenario(scene_path, 0.0, seed_value)
	var identical: bool = str(a["trace"]) == str(b["trace"])
	print(
		"WO024_GRAV_AB %s r4 combat=%.1f winner=%s ticks=%d"
		% [label, float(a["combat"]), str(a["winner"]), int(a["ticks"])]
	)
	print(
		"WO024_GRAV_AB %s r0 combat=%.1f winner=%s ticks=%d identical=%s"
		% [label, float(b["combat"]), str(b["winner"]), int(b["ticks"]), str(identical)]
	)
	if not identical:
		var ta: PackedStringArray = str(a["trace"]).split("\n")
		var tb: PackedStringArray = str(b["trace"]).split("\n")
		print("WO024_GRAV_AB %s lens=%d/%d" % [label, ta.size(), tb.size()])
		var n: int = mini(ta.size(), tb.size())
		for i in range(n):
			if ta[i] != tb[i]:
				print("WO024_GRAV_AB %s first_diff line=%d" % [label, i + 1])
				print("WO024_GRAV_AB %s r4=%s" % [label, ta[i].substr(0, 160)])
				print("WO024_GRAV_AB %s r0=%s" % [label, tb[i].substr(0, 160)])
				break
	return identical


func _run() -> void:
	var ok := true
	ok = _ab("S1", "res://tests/scenario_01.tscn", 12345) and ok
	ok = _ab("S2", "res://tests/scenario_02.tscn", 12345) and ok
	ok = _ab("S3", "res://tests/scenario_03.tscn", 12345) and ok
	_consts().reload_from_file()
	print("WO024_GRAV_AB_ALL identical=%s" % str(ok))
	quit(0 if ok else 2)
