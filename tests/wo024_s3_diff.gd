extends SceneTree
## WO-024 — S3 gravity A/B detailed delta (escalation evidence).


func _initialize() -> void:
	call_deferred("_run")


func _consts():
	return root.get_node("/root/Constants")


func _run_once(radius: float) -> Dictionary:
	_consts().set_constant("engage_radius_m", radius)
	var packed: PackedScene = load("res://tests/scenario_03.tscn")
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
		"radius": radius,
		"combat": float(sc.get_phase_durations_sec().get("combat_sec", -1.0)),
		"winner": str(sc.get_winner_id()),
		"ticks": ticks,
		"str_rout": float(sc._blue_a_strength_at_rout),
		"trace": sc.get_trace_text(),
	}
	sc.free()
	return out


func _run() -> void:
	var a: Dictionary = _run_once(4.0)
	var b: Dictionary = _run_once(0.0)
	_consts().reload_from_file()
	print(
		"S3_DIFF_META r=4.0 combat=%.1f winner=%s ticks=%d str_rout=%.2f"
		% [float(a.combat), str(a.winner), int(a.ticks), float(a.str_rout)]
	)
	print(
		"S3_DIFF_META r=0.0 combat=%.1f winner=%s ticks=%d str_rout=%.2f"
		% [float(b.combat), str(b.winner), int(b.ticks), float(b.str_rout)]
	)
	var ta: PackedStringArray = str(a.trace).split("\n")
	var tb: PackedStringArray = str(b.trace).split("\n")
	var diffs := 0
	var n: int = mini(ta.size(), tb.size())
	for i in range(n):
		if ta[i] != tb[i]:
			diffs += 1
			if diffs <= 8:
				print("DIFF#%d line=%d" % [diffs, i + 1])
				print("  r4=%s" % ta[i].substr(0, 200))
				print("  r0=%s" % tb[i].substr(0, 200))
	print(
		"S3_DIFF_SUMMARY lines=%d/%d differing=%d identical=%s"
		% [ta.size(), tb.size(), diffs, str(diffs == 0)]
	)
	quit(0)
