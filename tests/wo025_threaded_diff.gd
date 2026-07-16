extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var runner = load("res://tests/sim_harness_runner.gd")
	var harness = load("res://scripts/sim_harness.gd").new()
	var fast = runner.instantiate_scenario("res://tests/scenario_01.tscn", 12345, true)
	root.add_child(fast)
	var spins := 0
	while not fast.is_node_ready() and spins < 512:
		OS.delay_usec(1000); spins += 1
	harness.run_to_completion(fast, harness.RunMode.FAST)
	var tf = fast.get_trace_text()
	fast.free()
	var th = runner.instantiate_scenario("res://tests/scenario_01.tscn", 12345, false, true)
	th.force_trace_logging = true
	root.add_child(th)
	spins = 0
	while not th.is_node_ready() and spins < 512:
		OS.delay_usec(1000); spins += 1
	harness.run_threaded_to_completion(th)
	var tt = th.get_trace_text()
	print("THREAD_DIFF flen=%d tlen=%d identical=%s winner_f/t combat" % [tf.length(), tt.length(), str(tf==tt)])
	if tf != tt:
		var a = tf.split("\n"); var b = tt.split("\n")
		print("lens %d/%d" % [a.size(), b.size()])
		var n = mini(a.size(), b.size())
		for i in range(n):
			if a[i] != b[i]:
				print("first_diff line=%d" % (i+1))
				print("fast=%s" % a[i].substr(0,180))
				print("thr =%s" % b[i].substr(0,180))
				break
		if a.size() != b.size():
			print("size_mismatch")
	th.free()
	quit(0)
