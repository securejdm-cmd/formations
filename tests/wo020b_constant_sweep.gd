extends SceneTree
## WO-020b: sweep disengage_damage_mult and base_turn_rate against S30/S31 rules.


func _initialize() -> void:
	call_deferred("_run")


func _consts():
	return root.get_node("/root/Constants")


func _run_s30(dmg_mult: float) -> Dictionary:
	_consts().set_constant("disengage_damage_mult", dmg_mult)
	var packed: PackedScene = load("res://tests/scenario_30.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.set_battle_seed(1000)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(2000)
		spins += 1
	var ticks := 0
	while not sc.is_battle_over() and ticks < 12000:
		sc.advance_one_tick()
		ticks += 1
	var out := {
		"sk_t": float(sc.skirm_withdraw_s),
		"sp_t": float(sc.spears_withdraw_s),
		"sk_lost": float(sc.skirm_str_lost),
		"sp_lost": float(sc.spears_str_lost),
		"sk_coh": float(sc.skirm_coh_lost),
		"sp_coh": float(sc.spears_coh_lost),
	}
	sc.free()
	return out


func _run_s31(turn_rate: float) -> Dictionary:
	_consts().set_constant("base_turn_rate_rad", turn_rate)
	var packed: PackedScene = load("res://tests/scenario_31.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.set_battle_seed(1000)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(2000)
		spins += 1
	var ticks := 0
	while not sc.is_battle_over() and ticks < 60000:
		sc.advance_one_tick()
		ticks += 1
	var out := {
		"sp_t": float(sc.spears_time_s),
		"inf_t": float(sc.inf_time_s),
		"sp_d": float(sc.spears_drain),
		"inf_d": float(sc.inf_drain),
	}
	sc.free()
	return out


func _analytic_wheel_times(base: float) -> Dictionary:
	## time = (π/2) / (base × (A/50) / mass)
	var profiles := {
		"spears": {"a": 30.0, "m": 1.0},
		"infantry": {"a": 50.0, "m": 1.0},
		"cavalry": {"a": 70.0, "m": 1.6},
		"skirmisher": {"a": 80.0, "m": 0.6},
	}
	var out := {}
	for id in profiles.keys():
		var a: float = float(profiles[id]["a"])
		var m: float = float(profiles[id]["m"])
		var rate: float = base * (a / 50.0) / m
		var t90: float = (PI * 0.5) / rate if rate > 0.0 else INF
		var drain_rate: float = 2.0 * (1.0 - a / 150.0)
		out[id] = {"t90": t90, "drain90": drain_rate * t90, "rate": rate}
	return out


func _run() -> void:
	print("=== TASK1 disengage_damage_mult sweep (base_turn kept current) ===")
	var t1_rows: Array = []
	for mult in [1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 5.0]:
		var r: Dictionary = _run_s30(mult)
		var ratio: float = (
			float(r["sp_lost"]) / float(r["sk_lost"]) if float(r["sk_lost"]) > 0.001 else INF
		)
		var ok_sp: bool = float(r["sp_lost"]) >= 6.0
		var ok_sk: bool = float(r["sk_lost"]) <= 6.0
		var ok_ratio: bool = ratio >= 1.6 and ratio <= 1.8
		var pass_all: bool = ok_sp and ok_sk and ok_ratio
		print(
			"mult=%.1f sk_t=%.2f sk_lost=%.2f sp_t=%.2f sp_lost=%.2f ratio=%.3f ok_sp=%s ok_sk=%s ok_ratio=%s ALL=%s"
			% [
				mult,
				float(r["sk_t"]),
				float(r["sk_lost"]),
				float(r["sp_t"]),
				float(r["sp_lost"]),
				ratio,
				ok_sp,
				ok_sk,
				ok_ratio,
				pass_all,
			]
		)
		t1_rows.append(
			{
				"mult": mult,
				"sk_lost": float(r["sk_lost"]),
				"sp_lost": float(r["sp_lost"]),
				"ratio": ratio,
				"pass": pass_all,
			}
		)

	print("=== TASK2 base_turn_rate_rad analytic table ===")
	for base in [0.12, 0.15, 0.18, 0.20, 0.22, 0.25, 0.28, 0.35, 0.50, 1.0, 2.5]:
		var a: Dictionary = _analytic_wheel_times(base)
		var sp_d: float = float(a["spears"]["drain90"])
		var inf_d: float = float(a["infantry"]["drain90"])
		var ok_sp: bool = sp_d >= 15.0 and sp_d <= 30.0
		var ok_inf: bool = inf_d >= 7.0 and inf_d <= 15.0
		var ok_ratio: bool = (sp_d / inf_d) >= 1.6 if inf_d > 0.001 else false
		print(
			"base=%.2f spears_t=%.1fs drain=%.2f inf_t=%.1fs drain=%.2f cav_t=%.1fs sk_t=%.1fs ratio=%.2f ALL=%s"
			% [
				base,
				float(a["spears"]["t90"]),
				sp_d,
				float(a["infantry"]["t90"]),
				inf_d,
				float(a["cavalry"]["t90"]),
				float(a["skirmisher"]["t90"]),
				sp_d / inf_d if inf_d > 0.001 else INF,
				ok_sp and ok_inf and ok_ratio,
			]
		)

	print("=== TASK2 empirical S31 around preferred band ===")
	for base in [0.16, 0.18, 0.20, 0.22, 0.25]:
		var r31: Dictionary = _run_s31(base)
		var ratio31: float = (
			float(r31["sp_d"]) / float(r31["inf_d"]) if float(r31["inf_d"]) > 0.001 else INF
		)
		var ok: bool = (
			float(r31["sp_d"]) >= 15.0
			and float(r31["sp_d"]) <= 30.0
			and float(r31["inf_d"]) >= 7.0
			and float(r31["inf_d"]) <= 15.0
			and ratio31 >= 1.6
		)
		print(
			"base=%.2f sp_t=%.2f sp_d=%.2f inf_t=%.2f inf_d=%.2f ratio=%.2f OK=%s"
			% [
				base,
				float(r31["sp_t"]),
				float(r31["sp_d"]),
				float(r31["inf_t"]),
				float(r31["inf_d"]),
				ratio31,
				ok,
			]
		)

	_consts().reload_from_file()
	quit(0)
