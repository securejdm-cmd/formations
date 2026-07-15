extends SceneTree
## Quick WO-019 charge spectrum / S29 probe (headless).

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var C: Node = root.get_node("Constants")
	print("=== WO-019 probe base_accel=%.3f scale=%.4f pct=%.3f ===" % [
		C.get_float("base_accel"),
		C.get_float("charge_impact_scale"),
		C.get_float("charge_min_speed_pct"),
	])
	var mass := 1.6
	var a: float = C.get_float("base_accel") / mass
	var vg := 13.5
	print("cavalry accel=%.4f d_gait=%.1f t_gait=%.1f" % [a, vg * vg / (2.0 * a), vg / a])

	_probe("res://tests/scenario_23.tscn", "S23 T1", {})
	_probe("res://tests/scenario_26.tscn", "S26 T3", {})
	_probe("res://tests/scenario_21.tscn", "S21 flank", {})
	_probe("res://tests/scenario_17.tscn", "S17b T1@40", {"infantry_start_cohesion": 40.0})
	_probe("res://tests/scenario_28.tscn", "S28 inf", {})
	for d in [20.0, 60.0, 120.0, 200.0]:
		var sc: Scenario01 = SimHarnessRunner.instantiate_scenario(
			"res://tests/scenario_29.tscn", 1000, true, false
		)
		sc.set("run_up_m", d)
		SimHarnessRunner.attach_and_wait_ready(self, sc)
		SimHarness.run_to_completion(sc, SimHarness.RunMode.FAST)
		var ev: Dictionary = sc.primary_charge_event()
		print("S29 %.0fm closing=%.3f impact=%.3f charged=%s" % [
			d, float(ev.get("closing_speed", -1)), float(ev.get("impact", -1)), ev.get("charged", false)
		])
		sc.free()
	quit(0)


func _probe(path: String, tag: String, exports: Dictionary) -> void:
	var sc: Scenario01 = SimHarnessRunner.instantiate_scenario(path, 1000, true, false)
	for k in exports.keys():
		sc.set(str(k), exports[k])
	SimHarnessRunner.attach_and_wait_ready(self, sc)
	SimHarness.run_to_completion(sc, SimHarness.RunMode.FAST)
	var ev: Dictionary = sc.primary_charge_event()
	var shock := float(ev.get("shock", 0.0))
	var land := float(ev.get("defender_cohesion_after", 100.0 - shock))
	print("%s closing=%.3f impact=%.3f shock=%.2f land=%.2f tier=%s edge=%s charged=%s" % [
		tag,
		float(ev.get("closing_speed", -1)),
		float(ev.get("impact", -1)),
		shock,
		land,
		str(ev.get("brace_tier", "")),
		str(ev.get("edge", "")),
		ev.get("charged", false),
	])
	sc.free()
