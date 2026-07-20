extends SceneTree
## 5-run GAMEPLAY_TICK p95 for perf_40 (no queues) — matches autotest path.

func _initialize() -> void:
	call_deferred("_run")


func _one() -> float:
	var packed = load("res://tests/scenario_40_perf.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = false
	sc.auto_run = false
	sc.suppress_io = true
	sc.use_sim_thread = false
	sc.set_battle_seed(1000)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(1000)
		spins += 1
	if sc.has_method("stop_sim_thread_for_harness"):
		sc.stop_sim_thread_for_harness()
	sc._ensure_sim_core()
	sc._sync_core_from_units()
	for i in 800:
		sc.advance_one_tick()
	var stats: Dictionary = sc.get_perf_stats()
	var p95 := float(stats.get("p95_tick_ms", -1.0))
	var avg := float(stats.get("avg_tick_ms", -1.0))
	print("PERF40_RUN p95=%.3f avg=%.3f n=%s" % [p95, avg, str(stats.get("tick_count", stats.get("n", "?")))])
	sc.free()
	return p95


func _run() -> void:
	var vals: Array = []
	for i in 5:
		vals.append(_one())
	var mn: float = vals[0]
	var mx: float = vals[0]
	var sum: float = 0.0
	for v in vals:
		var f: float = float(v)
		mn = minf(mn, f)
		mx = maxf(mx, f)
		sum += f
	var mean: float = sum / 5.0
	print("PERF40_5RUN vals=%s min=%.3f max=%.3f mean=%.3f span=%.3f" % [str(vals), mn, mx, mean, mx - mn])
	quit(0)
