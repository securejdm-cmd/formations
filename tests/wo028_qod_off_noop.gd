extends SceneTree
## WO-028 Task 4 — QoD-off A/B retained as no-op proof vs WO-024 frontal.


func _initialize() -> void:
	call_deferred("_run")


func _consts():
	return root.get_node("/root/Constants")


func _run_s1(enabled: bool) -> Dictionary:
	_consts().set_constant("quality_of_day_enabled", enabled)
	_consts().set_constant("quality_of_day_sigma", 0.045)
	var packed: PackedScene = load("res://tests/scenario_01.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.auto_run = false
	sc.suppress_io = true
	sc.set_battle_seed(12345)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(1000)
		spins += 1
	var ticks := 0
	while not sc.is_battle_over() and ticks < 30000:
		sc.advance_one_tick()
		ticks += 1
	var out := {
		"trace": sc.get_trace_text(),
		"combat": float(sc.get_phase_durations_sec().get("combat_sec", -1.0)),
		"winner": str(sc.get_winner_id()),
		"has_qod": sc.get_trace_text().find("QUALITY_OF_DAY") >= 0,
	}
	sc.free()
	return out


func _run() -> void:
	var a := _run_s1(false)
	var b := _run_s1(false)
	_consts().reload_from_file()
	var identical: bool = str(a.trace) == str(b.trace)
	var no_event: bool = not bool(a.has_qod)
	var match_wo024: bool = absf(float(a.combat) - 81.6) < 0.05 and str(a.winner) == "blue_1"
	print(
		"QOD_OFF_NOOP identical=%s has_event=%s combat=%.1f winner=%s wo024_match=%s"
		% [str(identical), str(a.has_qod), float(a.combat), str(a.winner), str(match_wo024)]
	)
	var ok := identical and no_event and match_wo024
	print("WO028_QOD_OFF_NOOP ok=%s" % str(ok))
	quit(0 if ok else 2)
