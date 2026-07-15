extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("flank_cross_s=%.3f inf_90_s=%.3f" % [4.0 / 13.4, (PI * 0.5) / 2.5])
	var packed: PackedScene = load("res://tests/scenario_01.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.use_sim_thread = false
	sc.set_battle_seed(1000)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(2000)
		spins += 1
	var ticks := 0
	while not sc.is_battle_over() and ticks < 20000:
		sc.advance_one_tick()
		ticks += 1
	var baseline: String = FileAccess.get_file_as_string("res://tests/baselines/scenario_01_1000.csv")
	var trace: String = sc.get_trace_text()
	var identical := trace == baseline
	print("S1 winner=%s combat=%.1f identical=%s ticks=%d" % [
		sc.get_winner_id(),
		float(sc.get_phase_durations_sec().get("combat_sec", -1.0)),
		str(identical),
		ticks,
	])
	sc.free()
	quit(0 if identical else 2)
