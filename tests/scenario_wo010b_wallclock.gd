extends SceneTree

const TICKS := 800
const WARMUP := 600


func _initialize() -> void:
	var harness: Script = load("res://scripts/sim_harness.gd")
	var runner: Script = load("res://tests/sim_harness_runner.gd")
	var counts := [4, 20, 40]
	var pairs := [2, 10, 20]
	TickProfilerClass.enabled = false
	for i in counts.size():
		var scenario: Scenario01 = runner.instantiate_scenario(
			"res://tests/scenario_40_perf.tscn" if counts[i] >= 40 else "res://tests/scenario_perf_scale.tscn",
			1000,
			false,
		)
		if counts[i] < 40:
			scenario.set("unit_pairs", pairs[i])
		root.add_child(scenario)
		while not scenario.is_node_ready():
			await self.process_frame
		for _w in WARMUP:
			scenario.advance_one_tick()
		var times: Array[float] = []
		for _t in TICKS:
			var start := Time.get_ticks_usec()
			scenario.advance_one_tick()
			times.append(float(Time.get_ticks_usec() - start) / 1000.0)
		var sum := 0.0
		for t in times:
			sum += t
		print("[WO-010c] wall_clock units=%d avg_tick_ms=%.3f" % [counts[i], sum / float(times.size())])
		scenario.free()
	quit(0)

const TickProfilerClass := preload("res://scripts/tick_profiler.gd")
