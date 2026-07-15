extends SceneTree
## WO-024 Task 1 — GAMEPLAY_TICK vs MAIN_TICK (+ optional TickProfiler breakdown).
## Modes via cmdline user args[0]:
##   GAMEPLAY_TICK  — fast_sim=false, no thread, 800 advances (canonical for 50ms gate)
##   MAIN_TICK      — fast_sim=true,  no thread, 800 advances (test config comparison)
##   COMPARE        — both once
##   REPEAT_BOTH    — each ×5 for variance
##   PROFILE        — GAMEPLAY_TICK with TickProfiler ON (subsystem breakdown)

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


func _run_profile() -> Dictionary:
	TickProfilerClass.enabled = true
	TickProfilerClass.reset()
	var sc = _spawn(false)
	# Warmup outside profile window (WO-010b method).
	for _w in 100:
		sc.advance_one_tick()
	TickProfilerClass.reset()
	for _i in TICKS:
		sc.advance_one_tick()
	var report: Dictionary = TickProfilerClass.get_report(40)
	var wall: Dictionary = sc.get_perf_stats()
	TickProfilerClass.enabled = false
	if sc.has_method("stop_sim_thread_for_harness"):
		sc.call("stop_sim_thread_for_harness")
	sc.free()
	return {"profiler": report, "wall": wall}


func _print_row(d: Dictionary) -> void:
	print(
		"WO024_PERF mode=%s n=%d avg=%.3f p95=%.3f max=%.3f fast_sim=%s"
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
		"WO024_VARIANCE label=%s n=%d avg_mean=%.3f avg_min=%.3f avg_max=%.3f avg_span=%.3f p95_mean=%.3f p95_min=%.3f p95_max=%.3f p95_span=%.3f"
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


func _print_profile(bundle: Dictionary) -> void:
	var report: Dictionary = bundle.get("profiler", {})
	var sections: Dictionary = report.get("sections_ms", {})
	var wall: Dictionary = bundle.get("wall", {})
	print(
		"WO024_PROFILE units=%d tick_samples=%d wall_avg=%.3f wall_p95=%.3f"
		% [
			int(report.get("unit_count", 0)),
			int(report.get("tick_samples", 0)),
			float(wall.get("avg_tick_ms", 0.0)),
			float(wall.get("p95_tick_ms", 0.0)),
		]
	)
	print(
		"WO024_SUBSYSTEM ms/tick total=%.3f grid=%.3f slope=%.3f movement=%.3f allied=%.3f adhesion=%.3f adhesion_post=%.3f classify=%.3f combat=%.3f overlap=%.3f trace=%.3f victory=%.3f"
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
			float(sections.get("overlap_assert", 0.0)),
			float(sections.get("trace_logging", 0.0)),
			float(sections.get("victory_epilogue", 0.0)),
		]
	)
	print(
		"WO024_PROFILE_COUNTS classifier/tick=%.1f adhesion_classifier/tick=%.1f binary_search/tick=%.1f adhesion_pairs/tick=%.1f"
		% [
			float(report.get("classifier_calls_per_tick", 0.0)),
			float(report.get("adhesion_classifier_calls_per_tick", 0.0)),
			float(report.get("binary_search_iterations_per_tick", 0.0)),
			float(report.get("adhesion_pairs_per_tick", 0.0)),
		]
	)


func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := "COMPARE"
	if args.size() > 0:
		mode = str(args[0]).to_upper()
	print("WO024_PERF_START mode=%s" % mode)
	match mode:
		"GAMEPLAY_TICK":
			_print_row(_run_ticks(false, "GAMEPLAY_TICK"))
		"MAIN_TICK":
			_print_row(_run_ticks(true, "MAIN_TICK"))
		"REPEAT_BOTH":
			var g_rows: Array = []
			var m_rows: Array = []
			for i in 5:
				var g: Dictionary = _run_ticks(false, "GAMEPLAY_TICK_R%d" % (i + 1))
				_print_row(g)
				g_rows.append(g)
			for i in 5:
				var m: Dictionary = _run_ticks(true, "MAIN_TICK_R%d" % (i + 1))
				_print_row(m)
				m_rows.append(m)
			_print_variance("GAMEPLAY_TICK", g_rows)
			_print_variance("MAIN_TICK", m_rows)
			var g_p95 := 0.0
			var m_p95 := 0.0
			var g_avg := 0.0
			var m_avg := 0.0
			for r in g_rows:
				g_p95 += float(r.p95_ms)
				g_avg += float(r.avg_ms)
			for r in m_rows:
				m_p95 += float(r.p95_ms)
				m_avg += float(r.avg_ms)
			g_p95 /= 5.0
			m_p95 /= 5.0
			g_avg /= 5.0
			m_avg /= 5.0
			var d_p95 := m_p95 - g_p95
			var d_avg := m_avg - g_avg
			var pct_p95 := (d_p95 / g_p95) * 100.0 if g_p95 > 0.0 else 0.0
			var pct_avg := (d_avg / g_avg) * 100.0 if g_avg > 0.0 else 0.0
			print(
				"WO024_QA_DELTA avg_ms=%.3f (%.1f%% of GAMEPLAY) p95_ms=%.3f (%.1f%% of GAMEPLAY) — MAIN−GAMEPLAY"
				% [d_avg, pct_avg, d_p95, pct_p95]
			)
			var gate_ok := g_p95 <= 50.0
			print(
				"WO024_GATE_50MS GAMEPLAY_TICK_p95_mean=%.3f verdict=%s"
				% [g_p95, "PASS" if gate_ok else "FAIL"]
			)
		"PROFILE":
			_print_profile(_run_profile())
		_:
			var g2: Dictionary = _run_ticks(false, "GAMEPLAY_TICK")
			var m2: Dictionary = _run_ticks(true, "MAIN_TICK")
			_print_row(g2)
			_print_row(m2)
			var d_avg2 := float(m2.avg_ms) - float(g2.avg_ms)
			var d_p952 := float(m2.p95_ms) - float(g2.p95_ms)
			print(
				"WO024_QA_DELTA avg_ms=%.3f p95_ms=%.3f"
				% [d_avg2, d_p952]
			)
			print(
				"WO024_GATE_50MS GAMEPLAY_TICK_p95=%.3f verdict=%s"
				% [float(g2.p95_ms), "PASS" if float(g2.p95_ms) <= 50.0 else "FAIL"]
			)
	print("WO024_PERF_DONE")
	quit(0)
