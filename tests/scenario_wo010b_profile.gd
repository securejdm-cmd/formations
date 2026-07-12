extends SceneTree

## WO-010c: tick subsystem breakdown at 4/20/40 units (gameplay path, overlap assert off).

const TickProfilerClass := preload("res://scripts/tick_profiler.gd")

const PROFILE_TICKS := 800
const WARMUP_TICKS := 600
const UNIT_COUNTS := [4, 20, 40]
const PAIR_COUNTS := [2, 10, 20]


func _initialize() -> void:
	TickProfilerClass.enabled = true
	var harness: Script = load("res://scripts/sim_harness.gd")
	var runner: Script = load("res://tests/sim_harness_runner.gd")
	var reports: Array[Dictionary] = []

	for i in UNIT_COUNTS.size():
		var units: int = UNIT_COUNTS[i]
		var pairs: int = PAIR_COUNTS[i]
		var scene_path := (
			"res://tests/scenario_40_perf.tscn"
			if units >= 40
			else "res://tests/scenario_perf_scale.tscn"
		)
		var scenario: Scenario01 = runner.instantiate_scenario(scene_path, 1000, false)
		if scene_path.ends_with("scenario_perf_scale.tscn"):
			scenario.set("unit_pairs", pairs)
		root.add_child(scenario)
		while not scenario.is_node_ready():
			await self.process_frame
		for _w in WARMUP_TICKS:
			scenario.advance_one_tick()
		TickProfilerClass.reset()
		for _t in PROFILE_TICKS:
			scenario.advance_one_tick()
		reports.append(TickProfilerClass.get_report(units))
		scenario.free()

	_print_reports(reports, "WO-010c")
	quit(0)


func _print_reports(reports: Array[Dictionary], label: String) -> void:
	print("[WO-010c] Tick breakdown %s (warmup=%d profile=%d ticks, gameplay path)" % [label, WARMUP_TICKS, PROFILE_TICKS])
	for row in reports:
		var sections: Dictionary = row.get("sections_ms", {})
		print(
			"  units=%d avg_total_ms=%.3f grid=%.3f movement=%.3f allied=%.3f adhesion=%.3f adhesion_post=%.3f classify=%.3f combat=%.3f overlap=%.3f trace=%.3f victory=%.3f"
			% [
				row.get("unit_count", 0),
				sections.get("total", 0.0),
				sections.get("grid_overhead", 0.0),
				sections.get("movement", 0.0),
				sections.get("allied_separation", 0.0),
				sections.get("adhesion", 0.0),
				sections.get("adhesion_post", 0.0),
				sections.get("contact_classification", 0.0),
				sections.get("combat", 0.0),
				sections.get("overlap_assert", 0.0),
				sections.get("trace_logging", 0.0),
				sections.get("victory_epilogue", 0.0),
			]
		)
		print(
			"    classifier_calls/tick=%.1f adhesion_classifier/tick=%.1f binary_search_iters/tick=%.1f adhesion_pairs/tick=%.1f"
			% [
				row.get("classifier_calls_per_tick", 0.0),
				row.get("adhesion_classifier_calls_per_tick", 0.0),
				row.get("binary_search_iterations_per_tick", 0.0),
				row.get("adhesion_pairs_per_tick", 0.0),
			]
		)
