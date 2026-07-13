extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://tests/scenario_40_perf.tscn")
	var scenario: Scenario40Perf = packed.instantiate()
	scenario.headless_mode = true
	scenario.fast_sim_mode = false
	scenario.use_sim_thread = true
	scenario.set_battle_seed(1000)
	root.add_child(scenario)
	var spins := 0
	while not scenario.is_node_ready() and spins < 512:
		OS.delay_usec(16000)
		spins += 1
	for _i in 1200:
		scenario.simulate_realtime_step()
		if scenario.is_battle_over():
			break
	scenario.wait_for_threaded_completion()
	var stats: Dictionary = scenario.get_perf_stats()
	var sim: Dictionary = stats.get("sim_thread", {})
	print("PERF40_P95_MS=%.3f" % sim.get("p95_tick_ms", 0.0))
	print("PERF40_AVG_MS=%.3f" % sim.get("avg_tick_ms", 0.0))
	print("PERF40_MAX_MS=%.3f" % sim.get("max_tick_ms", 0.0))
	print("PERF40_TICKS=%d" % sim.get("tick_count", 0))
	quit(0)
