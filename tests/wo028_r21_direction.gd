extends SceneTree
## WO-028 Task 3 — R21 BOUNDARY as DIRECTION checks only (QoD ON σ=0.045).
## Seeds 1000–1009. A single flipped maneuver winner is an R21 failure.


func _initialize() -> void:
	call_deferred("_run")


func _consts():
	return root.get_node("/root/Constants")


func _run_named(path: String, max_ticks: int, seed_value: int, configure: Callable = Callable()) -> Variant:
	var packed: PackedScene = load(path)
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.auto_run = false
	sc.suppress_io = true
	sc.set_battle_seed(seed_value)
	if configure.is_valid():
		configure.call(sc)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(1000)
		spins += 1
	var ticks := 0
	while not sc.is_battle_over() and ticks < max_ticks:
		sc.advance_one_tick()
		ticks += 1
	return sc


func _fail(msg: String) -> void:
	print("R21_FAIL %s" % msg)


func _ok(msg: String) -> void:
	print("R21_OK %s" % msg)


func _run() -> void:
	_consts().set_constant("quality_of_day_enabled", true)
	_consts().set_constant("quality_of_day_sigma", 0.045)
	print("WO028_R21_DIRECTION sigma=0.045 enabled=true seeds=1000-1009")
	var fails := 0
	for seed_value in range(1000, 1010):
		# S3: flank attacker wins; ratio << 1.0 (direction only — no magnitude band)
		var sc3 = _run_named("res://tests/scenario_03.tscn", 20000, seed_value)
		var combat3: float = float(sc3.get_phase_durations_sec().get("combat_sec", -1.0))
		var ratio3: float = combat3 / 75.8
		var winner3: String = str(sc3.get_winner_id())
		var s3_ok: bool = winner3.begins_with("red") and ratio3 < 0.95
		if s3_ok:
			_ok("seed=%d S3 winner=%s ratio=%.3f" % [seed_value, winner3, ratio3])
		else:
			_fail("seed=%d S3 winner=%s ratio=%.3f" % [seed_value, winner3, ratio3])
			fails += 1
		sc3.free()

		# S34: hardened pin (facing + mult > 1)
		var sc34 = _run_named("res://tests/scenario_34.tscn", 20000, seed_value)
		var s34_ok: bool = bool(sc34.a_did_not_reface) and bool(sc34.flank_persisted) and float(sc34.mean_flank_mult) > 1.0
		if s34_ok:
			_ok(
				"seed=%d S34 no_reface=%s mean_mult=%.3f frac_gt1=%.2f"
				% [seed_value, str(sc34.a_did_not_reface), float(sc34.mean_flank_mult), float(sc34.frac_mult_gt1)]
			)
		else:
			_fail(
				"seed=%d S34 no_reface=%s persist=%s mean_mult=%.3f"
				% [seed_value, str(sc34.a_did_not_reface), str(sc34.flank_persisted), float(sc34.mean_flank_mult)]
			)
			fails += 1
		sc34.free()

		# S18: braced spears beat cavalry (shock≈0, reflect>0, or spears/blue win path)
		var sc18 = _run_named("res://tests/scenario_18.tscn", 20000, seed_value)
		var ev18: Dictionary = sc18.primary_charge_event()
		var s18_ok: bool = (
			bool(ev18.get("charged", false))
			and bool(ev18.get("braced", false))
			and float(ev18.get("shock", 1.0)) <= 0.01
			and float(ev18.get("reflected", 0.0)) > 0.0
		)
		if s18_ok:
			_ok("seed=%d S18 braced_stop shock=%.3f reflected=%.3f winner=%s" % [
				seed_value, float(ev18.get("shock", -1.0)), float(ev18.get("reflected", 0.0)), str(sc18.get_winner_id()),
			])
		else:
			_fail("seed=%d S18 charged=%s braced=%s shock=%.3f winner=%s" % [
				seed_value, str(ev18.get("charged", false)), str(ev18.get("braced", false)),
				float(ev18.get("shock", -1.0)), str(sc18.get_winner_id()),
			])
			fails += 1
		sc18.free()

		# S19: late brace fails; charge lands
		var sc19 = _run_named("res://tests/scenario_19.tscn", 20000, seed_value)
		var ev19: Dictionary = sc19.primary_charge_event()
		var s19_ok: bool = (
			bool(ev19.get("charged", false))
			and not bool(ev19.get("braced", false))
			and float(ev19.get("shock", 0.0)) > 0.0
		)
		if s19_ok:
			_ok("seed=%d S19 late_brace_fails shock=%.3f" % [seed_value, float(ev19.get("shock", -1.0))])
		else:
			_fail("seed=%d S19 charged=%s braced=%s shock=%.3f" % [
				seed_value, str(ev19.get("charged", false)), str(ev19.get("braced", false)), float(ev19.get("shock", -1.0)),
			])
			fails += 1
		sc19.free()

		# S21 flank: flank charge routs fresh infantry
		var sc21 = _run_named("res://tests/scenario_21.tscn", 20000, seed_value)
		var ev21: Dictionary = sc21.primary_charge_event()
		var edge21: String = str(ev21.get("edge", ""))
		var land21 := 100.0 - float(ev21.get("shock", -1.0))
		var s21_ok: bool = (
			bool(ev21.get("charged", false))
			and (edge21 == "left" or edge21 == "right" or edge21 == "rear")
			and float(ev21.get("edge_mult", 0.0)) >= 1.4
			and land21 <= 10.0
		)
		if s21_ok:
			_ok("seed=%d S21_flank edge=%s land=%.2f winner=%s" % [seed_value, edge21, land21, str(sc21.get_winner_id())])
		else:
			_fail("seed=%d S21_flank edge=%s land=%.2f charged=%s" % [
				seed_value, edge21, land21, str(ev21.get("charged", false)),
			])
			fails += 1
		sc21.free()

		# Rear charge vs fresh infantry — still routs
		var sc21r = _run_named(
			"res://tests/scenario_21.tscn",
			20000,
			seed_value,
			func(sc): sc.approach = 1,  # Approach.REAR
		)
		var ev21r: Dictionary = sc21r.primary_charge_event()
		var land21r := 100.0 - float(ev21r.get("shock", -1.0))
		var edge21r: String = str(ev21r.get("edge", ""))
		var s21r_ok: bool = bool(ev21r.get("charged", false)) and land21r <= 10.0 and edge21r == "rear"
		if s21r_ok:
			_ok("seed=%d S21_rear edge=%s land=%.2f" % [seed_value, edge21r, land21r])
		else:
			_fail("seed=%d S21_rear edge=%s land=%.2f charged=%s" % [
				seed_value, edge21r, land21r, str(ev21r.get("charged", false)),
			])
			fails += 1
		sc21r.free()

		# S23–S26: brace tier winners unchanged (T1 holds / T3 breaks)
		var sc23 = _run_named("res://tests/scenario_23.tscn", 20000, seed_value)
		var ev23: Dictionary = sc23.primary_charge_event()
		var s23_ok: bool = int(ev23.get("brace_tier", 0)) == 1 and str(sc23.get_winner_id()) == "blue_inf"
		if s23_ok:
			_ok("seed=%d S23 T1 holds winner=%s" % [seed_value, str(sc23.get_winner_id())])
		else:
			_fail("seed=%d S23 tier=%s winner=%s" % [seed_value, str(ev23.get("brace_tier", "?")), str(sc23.get_winner_id())])
			fails += 1
		sc23.free()

		for item in [
			["res://tests/scenario_24.tscn", "S24"],
			["res://tests/scenario_25.tscn", "S25"],
			["res://tests/scenario_26.tscn", "S26"],
		]:
			var sc = _run_named(str(item[0]), 20000, seed_value)
			var ev: Dictionary = sc.primary_charge_event()
			var land := 100.0 - float(ev.get("shock", -1.0))
			var ok_t3: bool = int(ev.get("brace_tier", 0)) == 3 and land < 45.0
			if ok_t3:
				_ok("seed=%d %s T3 breaks land=%.2f" % [seed_value, item[1], land])
			else:
				_fail("seed=%d %s tier=%s land=%.2f" % [seed_value, item[1], str(ev.get("brace_tier", "?")), land])
				fails += 1
			sc.free()

		# S36–S39: downhill/high-ground winners unchanged (direction)
		var sc36 = _run_named("res://tests/scenario_36.tscn", 20000, seed_value)
		var s36_ok: bool = bool(sc36.downhill_won_push())
		if s36_ok:
			_ok("seed=%d S36 downhill_won" % seed_value)
		else:
			_fail("seed=%d S36 downhill lost routed=%s" % [seed_value, str(sc36.get_routed_id())])
			fails += 1
		sc36.free()

		var sc37 = _run_named("res://tests/scenario_37.tscn", 20000, seed_value)
		var ratio37: float = float(sc37.impact_ratio())
		var dn37: Dictionary = sc37.downhill_charge()
		var up37: Dictionary = sc37.uphill_charge()
		var s37_ok: bool = (
			bool(dn37.get("charged", false))
			and bool(up37.get("charged", false))
			and float(dn37.get("closing_speed", 0.0)) > float(up37.get("closing_speed", 0.0))
			and ratio37 > 1.0
		)
		if s37_ok:
			_ok("seed=%d S37 downhill_advantage ratio=%.3f" % [seed_value, ratio37])
		else:
			_fail("seed=%d S37 ratio=%.3f" % [seed_value, ratio37])
			fails += 1
		sc37.free()

		var sc38 = _run_named("res://tests/scenario_38.tscn", 20000, seed_value)
		var d_down: float = float(sc38.first_volley_down_m)
		var d_up: float = float(sc38.first_volley_up_m)
		var s38_ok: bool = d_down > d_up and d_down > 0.0 and d_up > 0.0
		if s38_ok:
			_ok("seed=%d S38 downhill_range>uphill %.1f>%.1f" % [seed_value, d_down, d_up])
		else:
			_fail("seed=%d S38 down=%.1f up=%.1f" % [seed_value, d_down, d_up])
			fails += 1
		sc38.free()

		var sc39 = _run_named("res://tests/scenario_39.tscn", 20000, seed_value)
		var s39_ok: bool = bool(sc39.defender_won())
		if s39_ok:
			_ok("seed=%d S39 high_ground defender_won" % seed_value)
		else:
			_fail("seed=%d S39 winner=%s" % [seed_value, str(sc39.get_winner_id())])
			fails += 1
		sc39.free()

		print("R21_SEED_DONE seed=%d fails_so_far=%d" % [seed_value, fails])

	_consts().reload_from_file()
	print("WO028_R21_DIRECTION_SUMMARY fails=%d" % fails)
	print("WO028_R21_DIRECTION_DONE")
	quit(1 if fails > 0 else 0)
