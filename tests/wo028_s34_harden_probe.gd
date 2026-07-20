extends SceneTree
## WO-028 — S34 hardened pin check across seeds 1000-1009, QoD on/off.

const SIGMA := 0.045
const SEED0 := 1000
const SEED_N := 10


func _initialize() -> void:
	call_deferred("_run")


func _consts():
	return root.get_node("/root/Constants")


func _eval_pin(sc) -> Dictionary:
	## Hardened R19 pin metrics from scenario edge_samples + facing.
	var samples: Array = sc.edge_samples
	var max_dot := -2.0
	var sum_mult := 0.0
	var gt1 := 0
	for row in samples:
		max_dot = maxf(max_dot, float(row.get("a_facing_dot_to_c", -2.0)))
		var m: float = float(row.get("mult", 0.0))
		sum_mult += m
		if m > 1.0 + 0.001:
			gt1 += 1
	var n: int = maxi(samples.size(), 1)
	var mean_mult: float = sum_mult / float(n)
	var no_reface: bool = max_dot < 0.5
	var flank_mult_holds: bool = mean_mult > 1.0 + 0.001 and float(gt1) / float(n) >= 0.5
	return {
		"n": samples.size(),
		"max_dot": max_dot,
		"mean_mult": mean_mult,
		"frac_gt1": float(gt1) / float(n),
		"no_reface": no_reface,
		"flank_mult_holds": flank_mult_holds,
		"soft_flank_persist": bool(sc.flank_persisted),
		"soft_no_reface": bool(sc.a_did_not_reface),
		"hard_ok": no_reface and flank_mult_holds,
	}


func _run_one(seed_value: int, enabled: bool) -> Dictionary:
	_consts().set_constant("quality_of_day_enabled", enabled)
	_consts().set_constant("quality_of_day_sigma", SIGMA)
	var sc = load("res://tests/scenario_34.tscn").instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.set_battle_seed(seed_value)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(2000)
		spins += 1
	var ticks := 0
	while not sc.is_battle_over() and ticks < 20000:
		sc.advance_one_tick()
		ticks += 1
	var ev: Dictionary = _eval_pin(sc)
	ev["seed"] = seed_value
	ev["enabled"] = enabled
	sc.free()
	return ev


func _run() -> void:
	print("WO028_S34_HARDEN_START seeds=%d..%d sigma=%.3f" % [SEED0, SEED0 + SEED_N - 1, SIGMA])
	var fail_soft := 0
	var fail_hard := 0
	for enabled in [false, true]:
		for i in SEED_N:
			var seed_value: int = SEED0 + i
			var ev: Dictionary = _run_one(seed_value, enabled)
			if not bool(ev.soft_flank_persist) or not bool(ev.soft_no_reface):
				fail_soft += 1
			if not bool(ev.hard_ok):
				fail_hard += 1
			print(
				"S34_HARDEN qod=%s seed=%d soft_persist=%s soft_noreface=%s hard_ok=%s max_dot=%.3f mean_mult=%.3f frac_gt1=%.2f n=%d"
				% [
					str(enabled),
					seed_value,
					str(ev.soft_flank_persist),
					str(ev.soft_no_reface),
					str(ev.hard_ok),
					float(ev.max_dot),
					float(ev.mean_mult),
					float(ev.frac_gt1),
					int(ev.n),
				]
			)
	print("S34_HARDEN_SUMMARY soft_fails=%d hard_fails=%d" % [fail_soft, fail_hard])
	_consts().reload_from_file()
	print("WO028_S34_HARDEN_DONE")
	quit(0 if fail_hard == 0 else 1)
