extends SceneTree
## WO-023 Task 1 — like-for-like perf_40 measurement.
## Modes:
##   MAIN_TICK     — fast_sim, no thread, 800 advance_one_tick (canonical cost)
##   SIM_NO_DELAY  — threaded, 1200 sync frames, NO delay (legacy-ish)
##   SIM_DELAY_1MS — threaded, 1200 sync frames, 1ms delay (WO-022 harness)
##   REPEAT_N      — MAIN_TICK ×5 for variance

const SEED := 1000


func _initialize() -> void:
	call_deferred("_go")


func _spawn(fast: bool, threaded: bool):
	var packed: PackedScene = load("res://tests/scenario_40_perf.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = fast
	sc.use_sim_thread = threaded
	sc.auto_run = true
	sc.set_battle_seed(SEED)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(1000)
		spins += 1
	return sc


func _p95_from_times(times: Array) -> Dictionary:
	if times.is_empty():
		return {"n": 0, "avg": 0.0, "p95": 0.0, "max": 0.0}
	var arr: Array = times.duplicate()
	arr.sort()
	var sum := 0.0
	for t in arr:
		sum += float(t)
	var p95_idx := int(floor(float(arr.size() - 1) * 0.95))
	return {
		"n": arr.size(),
		"avg": sum / float(arr.size()),
		"p95": float(arr[p95_idx]),
		"max": float(arr[-1]),
	}


func _run_main_tick() -> Dictionary:
	var sc = _spawn(true, false)
	for _i in 800:
		sc.advance_one_tick()
	var stats: Dictionary = sc.get_perf_stats()
	# Prefer Scenario40Perf tick timer when present.
	var n := int(stats.get("tick_count", 0))
	var out := {
		"mode": "MAIN_TICK",
		"n": n,
		"avg_ms": float(stats.get("avg_tick_ms", 0.0)),
		"p95_ms": float(stats.get("p95_tick_ms", 0.0)),
		"max_ms": float(stats.get("max_tick_ms", 0.0)),
	}
	if sc.has_method("stop_sim_thread_for_harness"):
		sc.call("stop_sim_thread_for_harness")
	sc.free()
	return out


func _run_sim_thread(delay_usec: int, label: String) -> Dictionary:
	var sc = _spawn(false, true)
	# Match harness: wait a moment for thread to start.
	OS.delay_msec(50)
	for _i in 1200:
		sc.simulate_realtime_step()
		if delay_usec > 0:
			OS.delay_usec(delay_usec)
		if sc.is_battle_over():
			break
	var stats: Dictionary = sc.get_perf_stats()
	var sim: Dictionary = stats.get("sim_thread", {})
	var out := {
		"mode": label,
		"n": int(sim.get("tick_count", 0)),
		"avg_ms": float(sim.get("avg_tick_ms", 0.0)),
		"p95_ms": float(sim.get("p95_tick_ms", 0.0)),
		"max_ms": float(sim.get("max_tick_ms", 0.0)),
		"delay_usec": delay_usec,
	}
	if sc.has_method("stop_sim_thread_for_harness"):
		sc.call("stop_sim_thread_for_harness")
	elif sc.get("_sim_thread") != null:
		pass
	sc.free()
	return out


func _print_row(d: Dictionary) -> void:
	print(
		"PERF40_PROBE mode=%s n=%d avg=%.3f p95=%.3f max=%.3f"
		% [d.mode, d.n, d.avg_ms, d.p95_ms, d.max_ms]
	)


func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := "ALL"
	if args.size() > 0:
		mode = str(args[0]).to_upper()
	print("PERF40_PROBE_START mode=%s sha_hint=env" % mode)
	match mode:
		"MAIN_TICK":
			_print_row(_run_main_tick())
		"SIM_NO_DELAY":
			_print_row(_run_sim_thread(0, "SIM_NO_DELAY"))
		"SIM_DELAY_1MS":
			_print_row(_run_sim_thread(1000, "SIM_DELAY_1MS"))
		"REPEAT_MAIN":
			for i in 5:
				var r: Dictionary = _run_main_tick()
				r.mode = "MAIN_TICK_R%d" % (i + 1)
				_print_row(r)
		_:
			_print_row(_run_main_tick())
			_print_row(_run_sim_thread(0, "SIM_NO_DELAY"))
			_print_row(_run_sim_thread(1000, "SIM_DELAY_1MS"))
			for i in 5:
				var r2: Dictionary = _run_main_tick()
				r2.mode = "MAIN_TICK_R%d" % (i + 1)
				_print_row(r2)
	print("PERF40_PROBE_DONE")
	quit(0)
