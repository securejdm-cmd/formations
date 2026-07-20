extends SceneTree
## Mirror suite cert paths under QoD-on.


func _initialize() -> void:
	call_deferred("_run")


func _consts():
	return root.get_node("/root/Constants")


func _run() -> void:
	var runner = load("res://tests/sim_harness_runner.gd")
	var harness = load("res://scripts/sim_harness.gd")
	print("WO028_CERT_HARNESS qod=%s auto_run_default_probe" % str(_consts().get_constant("quality_of_day_enabled", false)))

	var realtime: Scenario01 = runner.instantiate_scenario("res://tests/scenario_01.tscn", 12345, false)
	print("HARNESS realtime auto_run=%s" % str(realtime.auto_run))
	realtime.force_trace_logging = true
	runner.attach_and_wait_ready(self, realtime)
	harness.run_to_completion(realtime, harness.RunMode.REALTIME)
	var rt_trace: String = realtime.get_trace_text()
	var rt_w: String = realtime.get_winner_id()
	var rt_c: float = float(realtime.get_phase_durations_sec().get("combat_sec", -1))
	print("HARNESS realtime winner=%s combat=%.1f len=%d" % [rt_w, rt_c, rt_trace.length()])
	for line in rt_trace.split("\n"):
		if "QUALITY_OF_DAY" in line:
			print("HARNESS realtime %s" % line)
	realtime.free()

	var fast: Scenario01 = runner.instantiate_scenario("res://tests/scenario_01.tscn", 12345, true)
	print("HARNESS fast auto_run=%s" % str(fast.auto_run))
	runner.attach_and_wait_ready(self, fast)
	harness.run_to_completion(fast, harness.RunMode.FAST)
	var fast_trace: String = fast.get_trace_text()
	var fast_w: String = fast.get_winner_id()
	var fast_c: float = float(fast.get_phase_durations_sec().get("combat_sec", -1))
	print("HARNESS fast winner=%s combat=%.1f len=%d" % [fast_w, fast_c, fast_trace.length()])
	for line in fast_trace.split("\n"):
		if "QUALITY_OF_DAY" in line:
			print("HARNESS fast %s" % line)
	fast.free()

	print("HARNESS rt_vs_fast identical=%s" % str(rt_trace == fast_trace))
	if rt_trace != fast_trace:
		var al := rt_trace.split("\n")
		var bl := fast_trace.split("\n")
		var n := mini(al.size(), bl.size())
		var diffs := 0
		for i in n:
			if al[i] != bl[i]:
				if diffs < 8:
					print("DIFF %d\n  RT %s\n  FA %s" % [i, al[i], bl[i]])
				diffs += 1
		print("HARNESS total_diff_lines=%d lenRT=%d lenFA=%d" % [diffs, al.size(), bl.size()])

	# Determinism A/B via harness fast
	var a: Scenario01 = runner.instantiate_scenario("res://tests/scenario_01.tscn", 12345, true)
	runner.attach_and_wait_ready(self, a)
	harness.run_to_completion(a, harness.RunMode.FAST)
	var ta := a.get_trace_text()
	a.free()
	var b: Scenario01 = runner.instantiate_scenario("res://tests/scenario_01.tscn", 12345, true)
	runner.attach_and_wait_ready(self, b)
	harness.run_to_completion(b, harness.RunMode.FAST)
	var tb := b.get_trace_text()
	b.free()
	print("HARNESS det_ab identical=%s" % str(ta == tb))

	# Threaded
	var th: Scenario01 = runner.instantiate_scenario("res://tests/scenario_01.tscn", 12345, false, true)
	th.force_trace_logging = true
	runner.attach_and_wait_ready(self, th)
	harness.run_threaded_to_completion(th)
	var th_trace: String = th.get_trace_text()
	print("HARNESS threaded winner=%s combat=%.1f identical_to_fast=%s" % [
		th.get_winner_id(),
		float(th.get_phase_durations_sec().get("combat_sec", -1)),
		str(th_trace == fast_trace),
	])
	for line in th_trace.split("\n"):
		if "QUALITY_OF_DAY" in line:
			print("HARNESS threaded %s" % line)
	th.free()
	quit(0)
