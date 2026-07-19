extends SceneTree
## WO-029b: S40 fast vs sim-thread via the same harness path as suite certs.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("WO029B_S40_TRACE_COMPARE_START")
	var runner = load("res://tests/sim_harness_runner.gd")
	var harness = load("res://scripts/sim_harness.gd")

	var fast: Scenario01 = runner.instantiate_scenario(
		"res://tests/scenario_40_mixed.tscn", 1000, true, false
	)
	fast.force_trace_logging = true
	fast.suppress_io = true
	runner.attach_and_wait_ready(self, fast)
	# Cap: advance a fixed number then stop (full S40 is long under overlap spam).
	var ticks := 900
	for _i in ticks:
		if fast.is_battle_over():
			break
		fast.advance_one_tick()
	var fast_trace: String = fast.get_trace_text()
	var fast_ticks := int(fast._sim_core.sim_tick_count) if fast._sim_core != null else -1
	print("S40_TRACE tag=FAST ticks=%d trace_bytes=%d" % [fast_ticks, fast_trace.length()])
	fast.free()

	var threaded: Scenario01 = runner.instantiate_scenario(
		"res://tests/scenario_40_mixed.tscn", 1000, false, true
	)
	threaded.force_trace_logging = true
	threaded.suppress_io = true
	runner.attach_and_wait_ready(self, threaded)
	# auto_run=true started unpaced worker; wait until tick cap then stop.
	var guard := 0
	while guard < 120000:
		if threaded._sim_core != null and int(threaded._sim_core.sim_tick_count) >= ticks:
			break
		if threaded.is_battle_over():
			break
		OS.delay_msec(1)
		guard += 1
	threaded.stop_sim_thread_for_harness()
	threaded._sync_state_from_core()
	var th_trace: String = threaded.get_trace_text()
	var th_ticks := int(threaded._sim_core.sim_tick_count) if threaded._sim_core != null else -1
	print(
		"S40_TRACE tag=THREAD ticks=%d trace_bytes=%d guard=%d"
		% [th_ticks, th_trace.length(), guard]
	)
	threaded.free()

	var same := fast_trace == th_trace
	print(
		"S40_TRACE_IDENTICAL=%s fast_len=%d thread_len=%d"
		% [str(same), fast_trace.length(), th_trace.length()]
	)
	if not same:
		var al := fast_trace.split("\n")
		var bl := th_trace.split("\n")
		var n: int = mini(al.size(), bl.size())
		var diffs := 0
		for i in n:
			if al[i] != bl[i]:
				if diffs < 16:
					print("DIFF %d\n  FA %s\n  TH %s" % [i, al[i], bl[i]])
				diffs += 1
		print(
			"S40_TRACE_DIFF_LINES=%d fa_lines=%d th_lines=%d"
			% [diffs, al.size(), bl.size()]
		)
		# Normalize event timestamps (first column) — detect pure time-base shift.
		var norm_same := true
		var norm_diffs := 0
		for i in n:
			var fa_parts: PackedStringArray = al[i].split(",", true, 1)
			var th_parts: PackedStringArray = bl[i].split(",", true, 1)
			var fa_rest := fa_parts[1] if fa_parts.size() > 1 else al[i]
			var th_rest := th_parts[1] if th_parts.size() > 1 else bl[i]
			if fa_rest != th_rest:
				norm_same = false
				norm_diffs += 1
		print("S40_TRACE_IDENTICAL_IGNORING_TIME_COL=%s residual_diffs=%d" % [str(norm_same), norm_diffs])
	print("WO029B_S40_TRACE_COMPARE_DONE")
	quit(0 if same else 1)
