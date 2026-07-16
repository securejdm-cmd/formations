extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var C = root.get_node("/root/Constants")
	C.set_constant("quality_of_day_enabled", true)
	C.set_constant("quality_of_day_sigma", 0.05)
	var packed = load("res://tests/scenario_01.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.set_battle_seed(1000)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(2000); spins += 1
	for _i in 5:
		sc.advance_one_tick()
	var t = sc.get_trace_text()
	var has_q = t.find("QUALITY_OF_DAY") >= 0
	print("QOD_TRACE has_event=%s q0=%.4f q1=%.4f" % [str(has_q), sc._units[0].quality_of_day, sc._units[1].quality_of_day])
	# Determinism: same seed same rolls
	var q0 = sc._units[0].quality_of_day
	var q1 = sc._units[1].quality_of_day
	sc.free()
	var sc2 = packed.instantiate()
	sc2.headless_mode = true
	sc2.fast_sim_mode = true
	sc2.set_battle_seed(1000)
	root.add_child(sc2)
	spins = 0
	while not sc2.is_node_ready() and spins < 512:
		OS.delay_usec(2000); spins += 1
	for _i in 5:
		sc2.advance_one_tick()
	print("QOD_DET match=%s q=%.4f/%.4f vs %.4f/%.4f" % [
		str(absf(sc2._units[0].quality_of_day-q0)<1e-9 and absf(sc2._units[1].quality_of_day-q1)<1e-9),
		sc2._units[0].quality_of_day, sc2._units[1].quality_of_day, q0, q1
	])
	sc2.free()
	C.reload_from_file()
	quit(0)
