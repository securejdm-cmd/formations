extends SceneTree
## WO-020 magnetism + S1 drift probe.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var C: Node = root.get_node("Constants")
	print("engage_radius=%.1f disengage_base=%.1f rotate_drain=%.1f" % [
		C.get_float("engage_radius_m"), C.get_float("disengage_base_s"), C.get_float("rotate_under_contact_drain")
	])
	# Analytic flank timing check
	var gallop := 13.4
	var radius: float = C.get_float("engage_radius_m")
	var cross_s: float = radius / gallop
	print("flank_timing: gallop crosses %.1fm in %.3fs" % [radius, cross_s])
	# infantry turn 90 deg
	var turn_inf: float = 2.5 * (50.0 / 50.0) / 1.0
	var t90: float = (PI * 0.5) / turn_inf
	print("infantry_90deg_turn=%.3fs (> cross => cannot reface even if unpinned)" % t90)
	print("pinned_defender: gravity skip by R19; flanker not in defender front arc")

	# S1 byte check seed 1000
	var base_path := "res://tests/baselines/scenario_01_1000.csv"
	var sc: Scenario01 = SimHarnessRunner.instantiate_scenario("res://tests/scenario_01.tscn", 1000, true, false)
	SimHarnessRunner.attach_and_wait_ready(self, sc)
	SimHarness.run_to_completion(sc, SimHarness.RunMode.FAST)
	var trace := sc.get_trace_text()
	var baseline := FileAccess.get_file_as_string(base_path)
	print("S1_1000 winner=%s combat=%.1f byte_identical=%s" % [
		sc.get_winner_id(),
		float(sc.get_phase_durations_sec().get("combat_sec", -1)),
		str(trace == baseline),
	])
	if trace != baseline:
		print("S1_DRIFT ESCALATE")
		var bl := baseline.split("\n")
		var tl := trace.split("\n")
		print("baseline_lines=%d trace_lines=%d" % [bl.size(), tl.size()])
	sc.free()

	for path_tag in [
		["res://tests/scenario_30.tscn", "S30"],
		["res://tests/scenario_31.tscn", "S31"],
		["res://tests/scenario_33.tscn", "S33"],
		["res://tests/scenario_34.tscn", "S34"],
	]:
		var s: Scenario01 = SimHarnessRunner.instantiate_scenario(path_tag[0], 1000, true, false)
		SimHarnessRunner.attach_and_wait_ready(self, s)
		SimHarness.run_to_completion(s, SimHarness.RunMode.FAST)
		print("%s finished over=%s" % [path_tag[1], s.is_battle_over()])
		s.free()
	quit(0)
