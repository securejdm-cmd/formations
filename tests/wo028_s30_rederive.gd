extends SceneTree
## Re-derive S30 magnitude floors under QoD-on σ=0.045.


func _initialize() -> void:
	call_deferred("_run")


func _consts():
	return root.get_node("/root/Constants")


func _run_one(seed_value: int) -> Dictionary:
	_consts().set_constant("quality_of_day_enabled", true)
	_consts().set_constant("quality_of_day_sigma", 0.045)
	var packed: PackedScene = load("res://tests/scenario_30.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.auto_run = false
	sc.suppress_io = true
	sc.set_battle_seed(seed_value)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(1000)
		spins += 1
	var ticks := 0
	while not sc.is_battle_over() and ticks < 20000:
		sc.advance_one_tick()
		ticks += 1
	var out := {
		"seed": seed_value,
		"sk_t": float(sc.skirm_withdraw_s),
		"sp_t": float(sc.spears_withdraw_s),
		"sk_lost": float(sc.skirm_str_lost),
		"sp_lost": float(sc.spears_str_lost),
		"sk_coh": float(sc.skirm_coh_lost),
		"sp_coh": float(sc.spears_coh_lost),
	}
	sc.free()
	return out


func _stats(vals: Array) -> Dictionary:
	var sorted: Array = vals.duplicate()
	sorted.sort()
	var n := sorted.size()
	var sum := 0.0
	for v in sorted:
		sum += float(v)
	var mean := sum / float(maxi(n, 1))
	var var_acc := 0.0
	for v in sorted:
		var d := float(v) - mean
		var_acc += d * d
	var sd := sqrt(var_acc / float(maxi(n - 1, 1)))
	return {
		"n": n,
		"mean": mean,
		"sd": sd,
		"min": float(sorted[0]),
		"max": float(sorted[n - 1]),
		"m3": mean - 3.0 * sd,
		"p3": mean + 3.0 * sd,
	}


func _run() -> void:
	print("WO028_S30_REDERIVE")
	var rows: Array = []
	for seed_value in range(1000, 1500):
		var row := _run_one(seed_value)
		rows.append(row)
		if (seed_value - 1000) % 50 == 0:
			print(
				"S30_PROG seed=%d sk_t=%.2f sp_t=%.2f sk_lost=%.2f sp_lost=%.2f"
				% [seed_value, float(row.sk_t), float(row.sp_t), float(row.sk_lost), float(row.sp_lost)]
			)
	var keys := ["sk_t", "sp_t", "sk_lost", "sp_lost", "sk_coh", "sp_coh"]
	for k in keys:
		var vals: Array = []
		for r in rows:
			vals.append(float(r[k]))
		var s := _stats(vals)
		print(
			"S30_STATS metric=%s n=%d mean=%.6f sd=%.6f min=%.6f max=%.6f m3sd=%.6f p3sd=%.6f"
			% [k, s.n, s.mean, s.sd, s.min, s.max, s.m3, s.p3]
		)
	# Direction: sk finishes before spears; spears coh >= skirm coh
	var dir_fail := 0
	for r in rows:
		if float(r.sk_t) > float(r.sp_t) or float(r.sp_coh) + 0.05 < float(r.sk_coh):
			dir_fail += 1
	print("S30_DIRECTION_FAILS %d/%d" % [dir_fail, rows.size()])
	_consts().reload_from_file()
	print("WO028_S30_REDERIVE_DONE")
	quit(0)
