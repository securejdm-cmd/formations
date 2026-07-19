extends SceneTree
## WO-029b: designer-class path proxy on Xvfb (not headless) — measures displayed FPS.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("WO029B_S40_DISPLAY_FPS_START")
	var packed: PackedScene = load("res://tests/scenario_40_mixed.tscn")
	var sc = packed.instantiate()
	# Designer path: visible, realtime, sim thread on (WO-029b default).
	sc.headless_mode = false
	sc.fast_sim_mode = false
	sc.use_sim_thread = true
	sc.auto_run = true
	sc.suppress_io = true
	sc.set_battle_seed(1000)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		await process_frame
		spins += 1

	var frame_ms: Array = []
	var t_end := Time.get_ticks_msec() + 12000
	var last := Time.get_ticks_usec()
	while Time.get_ticks_msec() < t_end:
		await process_frame
		var now := Time.get_ticks_usec()
		frame_ms.append(float(now - last) / 1000.0)
		last = now
		if sc.is_battle_over():
			break

	frame_ms.sort()
	var n := frame_ms.size()
	var sum := 0.0
	for v in frame_ms:
		sum += float(v)
	var avg := sum / float(maxi(n, 1))
	var p95 := float(frame_ms[int(floor(float(n - 1) * 0.95))]) if n > 0 else 0.0
	var mn := float(frame_ms[0]) if n > 0 else 0.0
	var mx := float(frame_ms[n - 1]) if n > 0 else 0.0
	print(
		"S40_DISPLAY label=cloud_xvfb_designer_path RENDER_FRAME_MS min=%.3f avg=%.3f p95=%.3f max=%.3f n=%d fps_avg=%.1f fps_from_p95=%.1f use_sim_thread=true"
		% [mn, avg, p95, mx, n, 1000.0 / maxf(avg, 0.001), 1000.0 / maxf(p95, 0.001)]
	)
	if sc.has_method("get_perf_stats"):
		print("S40_DISPLAY scenario_perf=%s" % str(sc.get_perf_stats()))
	if sc.has_method("get_sim_thread_tick_stats"):
		print("S40_DISPLAY sim_thread=%s" % str(sc.get_sim_thread_tick_stats()))
	if sc.has_method("stop_sim_thread_for_harness"):
		sc.stop_sim_thread_for_harness()
	print("WO029B_S40_DISPLAY_FPS_DONE")
	quit(0)
