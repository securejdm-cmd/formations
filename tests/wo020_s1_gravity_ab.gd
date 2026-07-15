extends SceneTree
## A/B: S1 with engage_radius_m = 4 vs 0 must be byte-identical (WO-020 Task 5).


func _initialize() -> void:
	call_deferred("_run")


func _consts():
	return root.get_node("/root/Constants")


func _run_s1(radius: float) -> Dictionary:
	_consts().set_constant("engage_radius_m", radius)
	var packed: PackedScene = load("res://tests/scenario_01.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.set_battle_seed(12345)
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


func _run() -> void:
	var a: Dictionary = _run_s1(4.0)
	var b: Dictionary = _run_s1(0.0)
	_consts().reload_from_file()
	var identical: bool = str(a["trace"]) == str(b["trace"])
	print(
		"S1_AB radius4 combat=%.1f winner=%s ticks=%d"
		% [float(a["combat"]), str(a["winner"]), int(a["ticks"])]
	)
	print(
		"S1_AB radius0 combat=%.1f winner=%s ticks=%d identical=%s"
		% [float(b["combat"]), str(b["winner"]), int(b["ticks"]), str(identical)]
	)
	if not identical:
		var ta: PackedStringArray = str(a["trace"]).split("\n")
		var tb: PackedStringArray = str(b["trace"]).split("\n")
		print("S1_AB lens=%d/%d" % [ta.size(), tb.size()])
		var n: int = mini(ta.size(), tb.size())
		for i in range(n):
			if ta[i] != tb[i]:
				print("S1_AB first_diff line=%d" % (i + 1))
				print("S1_AB r4=%s" % ta[i].substr(0, 160))
				print("S1_AB r0=%s" % tb[i].substr(0, 160))
				break
	quit(0 if identical else 2)
