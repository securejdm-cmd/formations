extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var runner = load("res://tests/sim_harness_runner.gd")
	var harness = load("res://scripts/sim_harness.gd").new()
	var rt = runner.instantiate_scenario("res://tests/scenario_01.tscn", 12345, false)
	rt.force_trace_logging = true
	root.add_child(rt)
	var spins := 0
	while not rt.is_node_ready() and spins < 512:
		OS.delay_usec(1000); spins += 1
	harness.run_to_completion(rt, harness.RunMode.REALTIME)
	var t_rt = rt.get_trace_text()
	rt.free()
	var fs = runner.instantiate_scenario("res://tests/scenario_01.tscn", 12345, true)
	root.add_child(fs)
	spins = 0
	while not fs.is_node_ready() and spins < 512:
		OS.delay_usec(1000); spins += 1
	harness.run_to_completion(fs, harness.RunMode.FAST)
	var t_fs = fs.get_trace_text()
	fs.free()
	print("CERT_SMOKE rt_len=%d fs_len=%d identical=%s" % [t_rt.length(), t_fs.length(), str(t_rt==t_fs)])
	if t_rt != t_fs:
		var a = t_rt.split("\n"); var b = t_fs.split("\n")
		var n = mini(a.size(), b.size())
		for i in range(n):
			if a[i] != b[i]:
				print("first_diff line=%d" % (i+1))
				print("rt=%s" % a[i].substr(0,160))
				print("fs=%s" % b[i].substr(0,160))
				break
	# Also GAMEPLAY without force should have empty/minimal traces
	var gp = runner.instantiate_scenario("res://tests/scenario_01.tscn", 12345, false)
	gp.force_trace_logging = false
	root.add_child(gp)
	spins = 0
	while not gp.is_node_ready() and spins < 512:
		OS.delay_usec(1000); spins += 1
	for _i in 50:
		gp.advance_one_tick()
	print("GAMEPLAY_TRACE_LEN ticks50=%d (expect near-empty)" % gp.get_trace_text().length())
	gp.free()
	quit(0 if t_rt == t_fs else 2)
