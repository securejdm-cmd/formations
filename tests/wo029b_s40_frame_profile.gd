extends SceneTree
## WO-029b Task 1b/c — S40 SIM vs RENDER frame breakdown (cloud proxy).
## Modes: MAIN (use_sim_thread=false), THREAD (use_sim_thread=true).
## Samples mid-engagement (post first contact) where GAMEPLAY_TICK peaks.


func _initialize() -> void:
	call_deferred("_run")


func _stats(vals: Array) -> Dictionary:
	if vals.is_empty():
		return {"n": 0, "min": 0.0, "avg": 0.0, "p95": 0.0, "max": 0.0}
	var s := vals.duplicate()
	s.sort()
	var sum := 0.0
	for v in s:
		sum += float(v)
	var n := s.size()
	return {
		"n": n,
		"min": float(s[0]),
		"avg": sum / float(n),
		"p95": float(s[int(floor(float(n - 1) * 0.95))]),
		"max": float(s[n - 1]),
	}


func _warmup_to_contact(sc, max_ticks: int = 2500) -> void:
	for _i in max_ticks:
		if sc.is_battle_over():
			return
		if sc._sim_core != null and int(sc._sim_core.first_contact_tick) >= 0:
			# Extra grind ticks after contact.
			for _j in 40:
				if sc.is_battle_over():
					return
				sc.advance_one_tick()
			return
		sc.advance_one_tick()


func _run_profile_main(tag: String, sample_ticks: int) -> void:
	var packed: PackedScene = load("res://tests/scenario_40_mixed.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true  # drive ticks explicitly
	sc.use_sim_thread = false
	sc.auto_run = false
	sc.suppress_io = true
	sc.set_battle_seed(1000)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(1000)
		spins += 1
	_warmup_to_contact(sc)
	var sim_ms: Array = []
	for _i in sample_ticks:
		if sc.is_battle_over():
			break
		var t0 := Time.get_ticks_usec()
		sc.advance_one_tick()
		sim_ms.append(float(Time.get_ticks_usec() - t0) / 1000.0)
	var ss := _stats(sim_ms)
	var fps_cap := 1000.0 / maxf(ss.p95, 0.001)
	print(
		"S40_PROFILE label=cloud_proxy tag=%s mode=MAIN_THREAD_SIM_AT_GRIND sim_ms min=%.3f avg=%.3f p95=%.3f max=%.3f n=%d designer_fps_cap_if_sim_on_main=%.1f"
		% [tag, ss.min, ss.avg, ss.p95, ss.max, ss.n, fps_cap]
	)
	sc.free()


func _run_profile_thread(tag: String) -> void:
	var packed: PackedScene = load("res://tests/scenario_40_mixed.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = false
	sc.use_sim_thread = true
	sc.auto_run = false
	sc.suppress_io = true
	sc.set_battle_seed(1000)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(1000)
		spins += 1
	if sc._sim_thread == null and sc.has_method("_setup_sim_thread"):
		sc._setup_sim_thread()

	# Wait until contact on unpaced worker, then sample main-frame cost for ~3s.
	var guard := 0
	while guard < 20000:
		if sc._sim_core != null and int(sc._sim_core.first_contact_tick) >= 0:
			break
		if sc.is_battle_over():
			break
		OS.delay_msec(2)
		guard += 1

	var main_ms: Array = []
	var t_end := Time.get_ticks_msec() + 3000
	var steps := 0
	while Time.get_ticks_msec() < t_end and not sc.is_battle_over():
		var t0 := Time.get_ticks_usec()
		sc.simulate_realtime_step(0.016)
		main_ms.append(float(Time.get_ticks_usec() - t0) / 1000.0)
		steps += 1
		OS.delay_msec(16)

	var st: Dictionary = {}
	if sc.has_method("get_sim_thread_tick_stats"):
		st = sc.get_sim_thread_tick_stats()
	print(
		"S40_PROFILE label=cloud_proxy tag=%s mode=SIM_THREAD_AT_GRIND main_steps=%d sim_tick_ms min=%.3f avg=%.3f p95=%.3f max=%.3f n=%d"
		% [
			tag,
			steps,
			float(st.get("min_tick_ms", 0.0)),
			float(st.get("avg_tick_ms", 0.0)),
			float(st.get("p95_tick_ms", 0.0)),
			float(st.get("max_tick_ms", 0.0)),
			int(st.get("tick_count", 0)),
		]
	)
	var ms := _stats(main_ms)
	var fps_from_main := 1000.0 / maxf(ms.p95, 0.001)
	print(
		"S40_PROFILE label=cloud_proxy tag=%s MAIN_FRAME_MS min=%.3f avg=%.3f p95=%.3f max=%.3f n=%d proxy_fps_from_main_p95=%.1f"
		% [tag, ms.min, ms.avg, ms.p95, ms.max, ms.n, fps_from_main]
	)
	if sc.has_method("stop_sim_thread_for_harness"):
		sc.stop_sim_thread_for_harness()
	OS.delay_msec(50)
	sc.free()


func _run() -> void:
	print("WO029B_S40_FRAME_PROFILE_START cloud_proxy")
	print(
		"DIAGNOSIS_BASELINE: designer realtime pre-fix ticks on MAIN thread "
		+ "(use_sim_thread defaulted false). GAMEPLAY_TICK p95~27ms ⇒ FPS~20-35."
	)
	_run_profile_main("grind_main", 200)
	_run_profile_thread("grind_thread")
	print("WO029B_S40_FRAME_PROFILE_DONE")
	print(
		"NOTE: Cloud is headless — RENDER (crack-band shader, grind/fissure, stat cards, "
		+ "arrow arcs, shaded relief) not measured here. With sim off the main thread, "
		+ "render budget is the full frame (~16.7ms at 60 FPS). Designer validates GPU locally "
		+ "via res://tests/scenario_40_mixed.tscn (use_sim_thread=true)."
	)
	quit(0)
