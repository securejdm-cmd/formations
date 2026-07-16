extends SceneTree
## WO-026 — Movement micro-profile + charge-commit-radius disable probe.
## Modes via cmdline user args[0]:
##   PROFILE              — GAMEPLAY micro-breakdown (baseline)
##   DISABLE_COMMIT       — PROFILE with charge_commit_range omitted from march query
##   COMPARE_DISABLE      — PROFILE then DISABLE_COMMIT (prints delta)
##   REPEAT_GAMEPLAY      — GAMEPLAY_TICK ×5 variance (no profiler)

const SEED := 1000
const TICKS := 800
const TickProfilerClass := preload("res://scripts/tick_profiler.gd")


func _initialize() -> void:
	call_deferred("_go")


func _spawn(fast: bool):
	var packed: PackedScene = load("res://tests/scenario_40_perf.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = fast
	sc.use_sim_thread = false
	sc.auto_run = true
	sc.set_battle_seed(SEED)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(1000)
		spins += 1
	return sc


func _run_ticks(fast: bool, label: String) -> Dictionary:
	TickProfilerClass.enabled = false
	TickProfilerClass.debug_disable_charge_commit_radius = false
	var sc = _spawn(fast)
	for _i in TICKS:
		sc.advance_one_tick()
	var stats: Dictionary = sc.get_perf_stats()
	var out := {
		"mode": label,
		"fast_sim": fast,
		"n": int(stats.get("tick_count", 0)),
		"avg_ms": float(stats.get("avg_tick_ms", 0.0)),
		"p95_ms": float(stats.get("p95_tick_ms", 0.0)),
		"max_ms": float(stats.get("max_tick_ms", 0.0)),
	}
	if sc.has_method("stop_sim_thread_for_harness"):
		sc.call("stop_sim_thread_for_harness")
	sc.free()
	return out


func _run_profile(disable_commit: bool) -> Dictionary:
	TickProfilerClass.enabled = true
	TickProfilerClass.debug_disable_charge_commit_radius = disable_commit
	TickProfilerClass.reset()
	var sc = _spawn(false)
	for _w in 100:
		sc.advance_one_tick()
	TickProfilerClass.reset()
	for _i in TICKS:
		sc.advance_one_tick()
	var report: Dictionary = TickProfilerClass.get_report(40)
	var wall: Dictionary = sc.get_perf_stats()
	# Outcome fingerprint for Task 2 (cavalry absent — should not change).
	var alive_blue := 0
	var alive_red := 0
	var strength_sum := 0.0
	if sc.has_method("get_sim_core") or " _sim_core" in sc:
		pass
	var core = sc.get("_sim_core") if sc.get("_sim_core") != null else null
	if core == null and sc.get("sim_core") != null:
		core = sc.get("sim_core")
	if core != null and "units" in core:
		for u in core.units:
			if u == null:
				continue
			var st = u.get_state() if u.has_method("get_state") else -1
			if st == 6:  # REMOVED — fragile; use name if available
				continue
			if u.has_method("get_state_name") and str(u.get_state_name()) == "removed":
				continue
			strength_sum += float(u.strength)
			if str(u.team_id) == "blue":
				alive_blue += 1
			elif str(u.team_id) == "red":
				alive_red += 1
	TickProfilerClass.enabled = false
	TickProfilerClass.debug_disable_charge_commit_radius = false
	if sc.has_method("stop_sim_thread_for_harness"):
		sc.call("stop_sim_thread_for_harness")
	sc.free()
	return {
		"profiler": report,
		"wall": wall,
		"disable_commit": disable_commit,
		"outcome": {
			"alive_blue": alive_blue,
			"alive_red": alive_red,
			"strength_sum": strength_sum,
		},
	}


func _print_row(d: Dictionary) -> void:
	print(
		"WO026_PERF mode=%s n=%d avg=%.3f p95=%.3f max=%.3f fast_sim=%s"
		% [d.mode, d.n, d.avg_ms, d.p95_ms, d.max_ms, str(d.fast_sim)]
	)


func _print_variance(label: String, rows: Array) -> void:
	var avgs: Array = []
	var p95s: Array = []
	for r in rows:
		avgs.append(float(r.avg_ms))
		p95s.append(float(r.p95_ms))
	avgs.sort()
	p95s.sort()
	var avg_mean := 0.0
	var p95_mean := 0.0
	for v in avgs:
		avg_mean += float(v)
	for v in p95s:
		p95_mean += float(v)
	avg_mean /= float(avgs.size())
	p95_mean /= float(p95s.size())
	print(
		"WO026_VARIANCE label=%s n=%d avg_mean=%.3f avg_min=%.3f avg_max=%.3f avg_span=%.3f p95_mean=%.3f p95_min=%.3f p95_max=%.3f p95_span=%.3f"
		% [
			label,
			avgs.size(),
			avg_mean,
			float(avgs[0]),
			float(avgs[-1]),
			float(avgs[-1]) - float(avgs[0]),
			p95_mean,
			float(p95s[0]),
			float(p95s[-1]),
			float(p95s[-1]) - float(p95s[0]),
		]
	)


func _print_profile(bundle: Dictionary, tag: String) -> void:
	var report: Dictionary = bundle.get("profiler", {})
	var sections: Dictionary = report.get("sections_ms", {})
	var micro: Dictionary = report.get("movement_micro", {})
	var wall: Dictionary = bundle.get("wall", {})
	var outcome: Dictionary = bundle.get("outcome", {})
	print(
		"WO026_PROFILE tag=%s disable_commit=%s units=%d tick_samples=%d wall_avg=%.3f wall_p95=%.3f"
		% [
			tag,
			str(bundle.get("disable_commit", false)),
			int(report.get("unit_count", 0)),
			int(report.get("tick_samples", 0)),
			float(wall.get("avg_tick_ms", 0.0)),
			float(wall.get("p95_tick_ms", 0.0)),
		]
	)
	print(
		"WO026_SUBSYSTEM ms/tick total=%.3f grid=%.3f slope=%.3f movement=%.3f allied=%.3f adhesion=%.3f adhesion_post=%.3f classify=%.3f combat=%.3f"
		% [
			float(sections.get("total", 0.0)),
			float(sections.get("grid_overhead", 0.0)),
			float(sections.get("slope_sampling", 0.0)),
			float(sections.get("movement", 0.0)),
			float(sections.get("allied_separation", 0.0)),
			float(sections.get("adhesion", 0.0)),
			float(sections.get("adhesion_post", 0.0)),
			float(sections.get("contact_classification", 0.0)),
			float(sections.get("combat", 0.0)),
		]
	)
	print(
		"WO026_MOVE_MICRO enemy_query calls/tick=%.1f ms/tick=%.3f mean_usec=%.1f cells/tick=%.1f cells/call=%.1f candidates/tick=%.1f frac_of_movement=%.3f"
		% [
			float(micro.get("enemy_query_calls_per_tick", 0.0)),
			float(micro.get("enemy_query_ms_per_tick", 0.0)),
			float(micro.get("enemy_query_mean_usec", 0.0)),
			float(micro.get("enemy_query_cells_scanned_per_tick", 0.0)),
			float(micro.get("enemy_query_cells_per_call", 0.0)),
			float(micro.get("enemy_query_candidates_per_tick", 0.0)),
			float(micro.get("enemy_query_frac_of_movement", 0.0)),
		]
	)
	print(
		"WO026_MOVE_MICRO radius_calc calls/tick=%.1f ms/tick=%.3f max_scan calls/tick=%.1f ms/tick=%.3f"
		% [
			float(micro.get("radius_calc_calls_per_tick", 0.0)),
			float(micro.get("radius_calc_ms_per_tick", 0.0)),
			float(micro.get("max_scan_calls_per_tick", 0.0)),
			float(micro.get("max_scan_ms_per_tick", 0.0)),
		]
	)
	print(
		"WO026_MOVE_MICRO substep iterations/tick=%.1f unit_ticks/tick=%.1f"
		% [
			float(micro.get("substep_iterations_per_tick", 0.0)),
			float(micro.get("substep_unit_ticks_per_tick", 0.0)),
		]
	)
	print(
		"WO026_MOVE_MICRO charge_commit calls/tick=%.1f ms/tick=%.3f mean_usec=%.1f"
		% [
			float(micro.get("charge_commit_calls_per_tick", 0.0)),
			float(micro.get("charge_commit_ms_per_tick", 0.0)),
			float(micro.get("charge_commit_mean_usec", 0.0)),
		]
	)
	print(
		"WO026_MOVE_MICRO gravity calls/tick=%.1f ms/tick=%.3f mean_usec=%.1f auto_rot calls/tick=%.1f ms/tick=%.3f"
		% [
			float(micro.get("gravity_calls_per_tick", 0.0)),
			float(micro.get("gravity_ms_per_tick", 0.0)),
			float(micro.get("gravity_mean_usec", 0.0)),
			float(micro.get("auto_rotation_calls_per_tick", 0.0)),
			float(micro.get("auto_rotation_ms_per_tick", 0.0)),
		]
	)
	print(
		"WO026_MOVE_MICRO position calls/tick=%.1f ms/tick=%.3f contact_from_movement calls/tick=%.1f ms/tick=%.3f mean_usec=%.1f"
		% [
			float(micro.get("position_integrate_calls_per_tick", 0.0)),
			float(micro.get("position_integrate_ms_per_tick", 0.0)),
			float(micro.get("contact_from_movement_calls_per_tick", 0.0)),
			float(micro.get("contact_from_movement_ms_per_tick", 0.0)),
			float(micro.get("contact_from_movement_mean_usec", 0.0)),
		]
	)
	print(
		"WO026_MOVE_MICRO alloc arrays/tick=%.1f dicts/tick=%.1f classifier/tick=%.1f"
		% [
			float(micro.get("alloc_arrays_per_tick", 0.0)),
			float(micro.get("alloc_dicts_per_tick", 0.0)),
			float(report.get("classifier_calls_per_tick", 0.0)),
		]
	)
	print(
		"WO026_OUTCOME alive_blue=%d alive_red=%d strength_sum=%.3f"
		% [
			int(outcome.get("alive_blue", 0)),
			int(outcome.get("alive_red", 0)),
			float(outcome.get("strength_sum", 0.0)),
		]
	)


func _print_delta(base: Dictionary, disabled: Dictionary) -> void:
	var b_sec: Dictionary = base.get("profiler", {}).get("sections_ms", {})
	var d_sec: Dictionary = disabled.get("profiler", {}).get("sections_ms", {})
	var b_micro: Dictionary = base.get("profiler", {}).get("movement_micro", {})
	var d_micro: Dictionary = disabled.get("profiler", {}).get("movement_micro", {})
	var b_wall: Dictionary = base.get("wall", {})
	var d_wall: Dictionary = disabled.get("wall", {})
	print(
		"WO026_DISABLE_DELTA wall_avg=%.3f→%.3f (Δ%.3f) wall_p95=%.3f→%.3f (Δ%.3f) movement=%.3f→%.3f (Δ%.3f) enemy_query_ms=%.3f→%.3f (Δ%.3f) contact_ms=%.3f→%.3f (Δ%.3f) cells/call=%.1f→%.1f"
		% [
			float(b_wall.get("avg_tick_ms", 0.0)),
			float(d_wall.get("avg_tick_ms", 0.0)),
			float(d_wall.get("avg_tick_ms", 0.0)) - float(b_wall.get("avg_tick_ms", 0.0)),
			float(b_wall.get("p95_tick_ms", 0.0)),
			float(d_wall.get("p95_tick_ms", 0.0)),
			float(d_wall.get("p95_tick_ms", 0.0)) - float(b_wall.get("p95_tick_ms", 0.0)),
			float(b_sec.get("movement", 0.0)),
			float(d_sec.get("movement", 0.0)),
			float(d_sec.get("movement", 0.0)) - float(b_sec.get("movement", 0.0)),
			float(b_micro.get("enemy_query_ms_per_tick", 0.0)),
			float(d_micro.get("enemy_query_ms_per_tick", 0.0)),
			float(d_micro.get("enemy_query_ms_per_tick", 0.0))
			- float(b_micro.get("enemy_query_ms_per_tick", 0.0)),
			float(b_micro.get("contact_from_movement_ms_per_tick", 0.0)),
			float(d_micro.get("contact_from_movement_ms_per_tick", 0.0)),
			float(d_micro.get("contact_from_movement_ms_per_tick", 0.0))
			- float(b_micro.get("contact_from_movement_ms_per_tick", 0.0)),
			float(b_micro.get("enemy_query_cells_per_call", 0.0)),
			float(d_micro.get("enemy_query_cells_per_call", 0.0)),
		]
	)
	var b_out: Dictionary = base.get("outcome", {})
	var d_out: Dictionary = disabled.get("outcome", {})
	var same := (
		int(b_out.get("alive_blue", -1)) == int(d_out.get("alive_blue", -2))
		and int(b_out.get("alive_red", -1)) == int(d_out.get("alive_red", -2))
		and absf(float(b_out.get("strength_sum", 0.0)) - float(d_out.get("strength_sum", 1.0)))
		< 0.001
	)
	print("WO026_DISABLE_OUTCOME_UNCHANGED=%s" % str(same))


func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := "COMPARE_DISABLE"
	if args.size() > 0:
		mode = str(args[0]).to_upper()
	print("WO026_PERF_START mode=%s" % mode)
	match mode:
		"PROFILE":
			_print_profile(_run_profile(false), "BASELINE")
		"DISABLE_COMMIT":
			_print_profile(_run_profile(true), "DISABLE_COMMIT")
		"COMPARE_DISABLE":
			var base: Dictionary = _run_profile(false)
			_print_profile(base, "BASELINE")
			var disabled: Dictionary = _run_profile(true)
			_print_profile(disabled, "DISABLE_COMMIT")
			_print_delta(base, disabled)
		"REPEAT_GAMEPLAY":
			var rows: Array = []
			for i in 5:
				var g: Dictionary = _run_ticks(false, "GAMEPLAY_TICK_R%d" % (i + 1))
				_print_row(g)
				rows.append(g)
			_print_variance("GAMEPLAY_TICK", rows)
		_:
			_print_profile(_run_profile(false), "BASELINE")
	print("WO026_PERF_DONE")
	quit(0)
