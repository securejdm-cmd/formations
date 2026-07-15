extends SceneTree
## S40 outcome across standard 11 seeds + realtime FPS sample (Gate 2).


const SEEDS := [1000, 1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009, 12345]


func _initialize() -> void:
	call_deferred("_run")


func _run_seed(seed_value: int, realtime_sample: bool) -> Dictionary:
	var packed: PackedScene = load("res://tests/scenario_40_mixed.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = not realtime_sample
	sc.use_sim_thread = realtime_sample
	sc.set_battle_seed(seed_value)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(2000)
		spins += 1
	if realtime_sample:
		for _i in 600:
			sc.simulate_realtime_step()
			if sc.is_battle_over():
				break
		if sc.has_method("wait_for_threaded_completion"):
			sc.wait_for_threaded_completion()
	else:
		var ticks := 0
		while not sc.is_battle_over() and ticks < 8000:
			sc.advance_one_tick()
			ticks += 1
	var phases: Dictionary = sc.get_phase_durations_sec()
	var perf: Dictionary = sc.get_perf_stats()
	var out := {
		"seed": seed_value,
		"winner": sc.get_winner_id(),
		"combat": float(phases.get("combat_sec", -1.0)),
		"volley": sc.observed_volley,
		"melee": sc.observed_melee,
		"flank": sc.observed_flank_charge,
		"shock": sc.observed_rout_shock,
		"brace": sc.observed_brace,
		"showcase": sc.showcase_ok(),
		"avg_fps": float(perf.get("avg_fps", 0.0)),
		"min_fps": float(perf.get("min_fps", 0.0)),
		"p95_tick_ms": float(perf.get("p95_tick_ms", 0.0)),
	}
	sc.free()
	return out


func _run() -> void:
	print("S40_SEEDS_START")
	for seed_value in SEEDS:
		var row: Dictionary = _run_seed(seed_value, false)
		print(
			"S40_SEED %d winner=%s combat=%.1f showcase=%s volley=%s melee=%s flank=%s shock=%s brace=%s"
			% [
				seed_value,
				row.winner,
				row.combat,
				row.showcase,
				row.volley,
				row.melee,
				row.flank,
				row.shock,
				row.brace,
			]
		)
	print("S40_REALTIME_SAMPLE")
	var rt: Dictionary = _run_seed(1000, true)
	print(
		"S40_FPS avg=%.1f min=%.1f p95_tick_ms=%.3f showcase=%s"
		% [rt.avg_fps, rt.min_fps, rt.p95_tick_ms, rt.showcase]
	)
	quit(0)
