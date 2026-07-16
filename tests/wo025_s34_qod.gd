extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var C = root.get_node("/root/Constants")
	for enabled in [false, true]:
		C.set_constant("quality_of_day_enabled", enabled)
		C.set_constant("quality_of_day_sigma", 0.05)
		var packed = load("res://tests/scenario_34.tscn")
		var sc = packed.instantiate()
		sc.headless_mode = true
		sc.fast_sim_mode = true
		sc.set_battle_seed(1000)
		root.add_child(sc)
		var spins := 0
		while not sc.is_node_ready() and spins < 512:
			OS.delay_usec(2000); spins += 1
		var ticks := 0
		while not sc.is_battle_over() and ticks < 20000:
			sc.advance_one_tick(); ticks += 1
		print("S34_QOD enabled=%s flank=%s no_reface=%s samples=%d ticks=%d" % [
			str(enabled), str(sc.flank_persisted), str(sc.a_did_not_reface),
			sc.edge_samples.size(), ticks
		])
		sc.free()
	C.reload_from_file()
	quit(0)
