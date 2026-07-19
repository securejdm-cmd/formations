extends SceneTree
## WO-029b Task 1a — which thread advances the sim tick in realtime S40?


func _initialize() -> void:
	call_deferred("_run")


func _run_mode(tag: String, use_thread: bool, fast: bool) -> void:
	var packed: PackedScene = load("res://tests/scenario_40_mixed.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = fast
	sc.use_sim_thread = use_thread
	sc.auto_run = false
	sc.suppress_io = true
	sc.set_battle_seed(1000)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(1000)
		spins += 1
	var enabled: bool = sc._sim_thread_enabled() if sc.has_method("_sim_thread_enabled") else false
	# Probe: force setup path as designer realtime would
	if use_thread and not fast and sc._sim_thread == null:
		if sc.has_method("_setup_sim_thread"):
			sc._setup_sim_thread()
	var active: bool = sc._sim_thread_active() if sc.has_method("_sim_thread_active") else false
	var thread_obj = sc._sim_thread
	print(
		"S40_THREAD_DIAG tag=%s use_sim_thread=%s fast=%s _sim_thread_enabled=%s active=%s thread_null=%s"
		% [tag, str(use_thread), str(fast), str(enabled), str(active), str(thread_obj == null)]
	)
	# Advance a few steps and see who ticks
	var t0 := Time.get_ticks_usec()
	if fast:
		for _i in 50:
			sc.advance_one_tick()
	else:
		for _i in 50:
			sc.simulate_realtime_step(0.1)
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	var tick_count := 0
	if sc._sim_core != null:
		tick_count = int(sc._sim_core.sim_tick_count)
	var thread_stats: Dictionary = {}
	if sc.has_method("get_sim_thread_tick_stats"):
		thread_stats = sc.get_sim_thread_tick_stats()
	print(
		"S40_THREAD_DIAG tag=%s wall_ms=%.1f core_ticks=%d thread_stats=%s"
		% [tag, ms, tick_count, str(thread_stats)]
	)
	if sc.has_method("stop_sim_thread_for_harness"):
		sc.stop_sim_thread_for_harness()
	sc.free()


func _run() -> void:
	print("WO029B_S40_THREAD_DIAG_START")
	print(
		"DEFAULT_EXPORT use_sim_thread_default=%s (Scenario01 @export WO-029b)"
		% str(true)
	)
	# Pre-WO-029b designer path: main-thread ticks (explicit false)
	_run_mode("legacy_main_thread_realtime", false, false)
	# WO-029b designer default: realtime on sim thread
	_run_mode("designer_default_realtime_on_sim_thread", true, false)
	# Suite fast path
	_run_mode("suite_fast", false, true)
	print("WO029B_S40_THREAD_DIAG_DONE")
	quit(0)
