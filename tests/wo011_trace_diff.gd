extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var runner := load("res://tests/sim_harness_runner.gd")
	var harness := load("res://scripts/sim_harness.gd")

	var fast: Scenario01 = runner.instantiate_scenario("res://tests/scenario_01.tscn", 12345, true)
	_wait_ready(fast)
	harness.run_to_completion(fast, harness.RunMode.FAST)
	var ft := fast.get_trace_text()
	fast.free()

	var threaded: Scenario01 = runner.instantiate_scenario("res://tests/scenario_01.tscn", 12345, false, true)
	_wait_ready(threaded)
	harness.run_threaded_to_completion(threaded)
	var tt := threaded.get_trace_text()
	threaded.free()

	var fl := ft.split("\n")
	var tl := tt.split("\n")
	print("fast_lines=%d threaded_lines=%d" % [fl.size(), tl.size()])
	for i in mini(fl.size(), tl.size()):
		if fl[i] != tl[i]:
			print("diff@%d fast=%s" % [i, fl[i]])
			print("diff@%d thr=%s" % [i, tl[i]])
			quit(1)
			return
	if fl.size() != tl.size():
		print("length mismatch")
		quit(1)
		return
	print("TRACE MATCH")
	quit(0)


func _wait_ready(scenario: Scenario01) -> void:
	root.add_child(scenario)
	var spins := 0
	while not scenario.is_node_ready() and spins < 512:
		OS.delay_usec(16000)
		spins += 1
