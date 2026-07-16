extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _consts():
	return root.get_node("/root/Constants")
func _run_s1() -> String:
	var packed = load("res://tests/scenario_01.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.set_battle_seed(12345)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(2000); spins += 1
	var ticks := 0
	while not sc.is_battle_over() and ticks < 30000:
		sc.advance_one_tick(); ticks += 1
	var t = sc.get_trace_text()
	print("QOD_AB combat=%.1f winner=%s q=%s/%s" % [
		float(sc.get_phase_durations_sec().get("combat_sec",-1)),
		str(sc.get_winner_id()),
		str(sc._units[0].quality_of_day) if sc._units.size()>0 else "?",
		str(sc._units[1].quality_of_day) if sc._units.size()>1 else "?"
	])
	sc.free()
	return t
func _run() -> void:
	_consts().set_constant("quality_of_day_enabled", false)
	var a = _run_s1()
	_consts().set_constant("quality_of_day_enabled", false)
	var b = _run_s1()
	_consts().reload_from_file()
	print("QOD_AB identical=%s" % str(a==b))
	quit(0 if a==b else 2)
