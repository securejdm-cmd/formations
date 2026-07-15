extends SceneTree
## S40 outcome across standard 11 seeds + lightweight FPS sample (Gate 2).
## Avoids threaded realtime (overlap-assert flood in headless).


const SEEDS := [1000, 1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009, 12345]


func _initialize() -> void:
	call_deferred("_run")


func _run_seed(seed_value: int) -> Dictionary:
	var packed: PackedScene = load("res://tests/scenario_40_mixed.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.set_battle_seed(seed_value)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(2000)
		spins += 1
	var ticks := 0
	while not sc.is_battle_over() and ticks < 8000:
		sc.advance_one_tick()
		ticks += 1
	var phases: Dictionary = sc.get_phase_durations_sec()
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
		"ticks": ticks,
		"alive_blue": _alive(sc, "blue"),
		"alive_red": _alive(sc, "red"),
	}
	sc.free()
	return out


func _alive(sc, team: String) -> int:
	var n := 0
	for u in sc._units:
		if u.team_id == team and u.get_state() != Unit.State.REMOVED and u.get_state() != Unit.State.ROUTING:
			n += 1
	return n


func _fps_sample() -> Dictionary:
	## Main-thread step timing at sim tick cadence (cloud environmental; designer desktop is the Gate).
	var packed: PackedScene = load("res://tests/scenario_40_mixed.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = false
	sc.use_sim_thread = false
	sc.set_battle_seed(1000)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(2000)
		spins += 1
	var times: Array[float] = []
	for _i in 300:
		var t0 := Time.get_ticks_usec()
		sc.simulate_realtime_step(0.1)
		times.append(float(Time.get_ticks_usec() - t0) / 1000.0)
		if sc.is_battle_over():
			break
	times.sort()
	var sum := 0.0
	for t in times:
		sum += t
	var avg := sum / float(times.size()) if not times.is_empty() else 0.0
	var p95 := times[int(floor(float(times.size() - 1) * 0.95))] if not times.is_empty() else 0.0
	# Equivalent FPS if each frame ran one sim step of work.
	var equiv_fps := 1000.0 / maxf(avg, 0.001)
	var out := {"avg_step_ms": avg, "p95_step_ms": p95, "equiv_fps": equiv_fps, "samples": times.size()}
	sc.free()
	return out


func _run() -> void:
	print("S40_SEEDS_START")
	for seed_value in SEEDS:
		var row: Dictionary = _run_seed(seed_value)
		print(
			"S40_SEED %d winner=%s combat=%.1f showcase=%s alive_b/r=%d/%d volley=%s melee=%s flank=%s shock=%s brace=%s"
			% [
				seed_value,
				row.winner,
				row.combat,
				row.showcase,
				row.alive_blue,
				row.alive_red,
				row.volley,
				row.melee,
				row.flank,
				row.shock,
				row.brace,
			]
		)
	print("S40_FPS_SAMPLE")
	var fps: Dictionary = _fps_sample()
	print(
		"S40_FPS equiv_fps=%.1f avg_step_ms=%.3f p95_step_ms=%.3f samples=%d (cloud env; designer desktop Gate is ≥60 FPS)"
		% [fps.equiv_fps, fps.avg_step_ms, fps.p95_step_ms, fps.samples]
	)
	quit(0)
