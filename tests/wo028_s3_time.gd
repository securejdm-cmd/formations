extends SceneTree
## Quick S3 timing probe (one seed).


func _initialize() -> void:
	call_deferred("_run")


func _consts():
	return root.get_node("/root/Constants")


func _run() -> void:
	_consts().set_constant("quality_of_day_enabled", true)
	_consts().set_constant("quality_of_day_sigma", 0.045)
	var t0 := Time.get_ticks_msec()
	var packed: PackedScene = load("res://tests/scenario_03.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.auto_run = false
	sc.suppress_io = true
	sc.set_battle_seed(1000)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(1000)
		spins += 1
	var ticks := 0
	while not sc.is_battle_over() and ticks < 20000:
		sc.advance_one_tick()
		ticks += 1
	var phases: Dictionary = sc.get_phase_durations_sec()
	var combat: float = float(phases.get("combat_sec", -1.0))
	var ratio: float = combat / 75.8
	var rout: float = float(sc.get_blue_a_strength_at_rout())
	var left: float = float(sc.get_blue_a_edge_drains().get("left", 0.0))
	var ms := Time.get_ticks_msec() - t0
	print(
		"S3_TIME seed=1000 ms=%d ticks=%d combat=%.2f ratio=%.4f rout=%.2f left=%.2f winner=%s"
		% [ms, ticks, combat, ratio, rout, left, str(sc.get_winner_id())]
	)
	sc.free()
	_consts().reload_from_file()
	quit(0)
