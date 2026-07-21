extends SceneTree
## WO-033 Task 0: order-path micro-profile on pitched no-order (perf_40).

const _TickProfiler := preload("res://scripts/tick_profiler.gd")
const _OrderExec := preload("res://scripts/orders/order_executor.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
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

	_TickProfiler.enabled = true
	_TickProfiler.reset()
	_OrderExec.reset_profile_counters()
	var core = sc._sim_core
	var n := 800
	var ti := 0.1
	for i in n:
		core.advance_one_tick_profiled(ti)

	var report: Dictionary = _TickProfiler.get_report(40)
	print("TASK0_SECTIONS %s" % str(report.get("sections_ms", {})))
	print(
		"TASK0_ORDERS_ARMED=%s scan_done=%s executor_null=%s"
		% [str(core.orders_armed), str(core.orders_scan_done), str(core.order_executor == null)]
	)
	print(
		"TASK0_ORDER_COUNTS trigger_evals=%d step_checks=%d order_state_emits=%d per_unit_allocs=%d tick_entries=%d"
		% [
			_OrderExec.prof_trigger_evals,
			_OrderExec.prof_step_checks,
			_OrderExec.prof_order_state_emits,
			_OrderExec.prof_per_unit_allocs,
			_OrderExec.prof_tick_entries,
		]
	)
	sc.free()

	# Canonical GAMEPLAY_TICK (scenario wall clock).
	sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = false
	sc.auto_run = false
	sc.suppress_io = true
	sc.use_sim_thread = false
	sc.set_battle_seed(1000)
	root.add_child(sc)
	spins = 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(1000)
		spins += 1
	if sc.has_method("stop_sim_thread_for_harness"):
		sc.stop_sim_thread_for_harness()
	sc._ensure_sim_core()
	sc._sync_core_from_units()
	for i in n:
		sc.advance_one_tick()
	var gstats: Dictionary = sc.get_perf_stats()
	print(
		"TASK0_GAMEPLAY_TICK p95=%.3f avg=%.3f n=%s"
		% [
			float(gstats.get("p95_tick_ms", -1)),
			float(gstats.get("avg_tick_ms", -1)),
			str(gstats.get("tick_count", "?")),
		]
	)
	sc.free()
	quit(0)
