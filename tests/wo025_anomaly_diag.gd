extends SceneTree
## WO-025 Task 3 — diagnose 0% cell attacker bias (marcher vs standing).


func _initialize() -> void:
	call_deferred("_run")


func _consts():
	return root.get_node("/root/Constants")


func _run_pair(seed_value: int, atk_mode: String, def_mode: String) -> Dictionary:
	## atk_mode/def_mode: "march" | "hold"
	_consts().set_constant("quality_of_day_enabled", false)
	var packed: PackedScene = load("res://tests/scenario_01.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.auto_run = false
	sc.set_battle_seed(seed_value)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(1000)
		spins += 1
	for u in sc._units.duplicate():
		sc.remove_child(u)
		u.free()
	sc._units.clear()
	var base_p: Dictionary = UnitProfileLoader.load_profile("test_infantry")
	var px := float(_consts().get_float("px_per_meter"))
	var half := float(_consts().get_float("scenario_01_start_distance_m")) * 0.5 * px
	var atk: Unit = load("res://scenes/unit.tscn").instantiate()
	sc.add_child(atk)
	atk.configure("attacker", "red", base_p.duplicate(true), Vector2(-half, 0.0), Vector2.RIGHT)
	var deff: Unit = load("res://scenes/unit.tscn").instantiate()
	sc.add_child(deff)
	deff.configure("defender", "blue", base_p.duplicate(true), Vector2(half, 0.0), Vector2.LEFT)
	if atk_mode == "march":
		atk.set_march_to(Vector2(half + 20.0 * px, 0.0))
		if atk.has_method("start_from_rest"):
			atk.start_from_rest()
	else:
		atk.current_order = Unit.Order.HOLD
		atk._set_state(Unit.State.HOLD)
		atk.current_speed_m_s = 0.0
	if def_mode == "march":
		deff.set_march_to(Vector2(-half - 20.0 * px, 0.0))
		if deff.has_method("start_from_rest"):
			deff.start_from_rest()
	else:
		deff.current_order = Unit.Order.HOLD
		deff._set_state(Unit.State.HOLD)
		deff.current_speed_m_s = 0.0
	sc._units.append(atk)
	sc._units.append(deff)
	for unit in sc._units:
		unit.set_render_camera(sc._camera)
	sc._ensure_sim_core()
	sc._sim_core.capture_from_units(sc._units)
	sc._sim_core.write_trace_header()
	sc._sim_core.log_trace_row()
	sc._sync_state_from_core()
	var contact_tick := -1
	var atk_spd := 0.0
	var def_spd := 0.0
	var atk_amp := 0.0
	var def_amp := 0.0
	var ticks := 0
	while not sc.is_battle_over() and ticks < 12000:
		sc.advance_one_tick()
		ticks += 1
		if contact_tick < 0:
			var ua = sc._units[0]
			var ub = sc._units[1]
			if ua.has_contact_with(ub):
				contact_tick = ticks
				atk_spd = float(ua.current_speed_m_s)
				def_spd = float(ub.current_speed_m_s)
				atk_amp = float(ua.charge_amp_factor)
				def_amp = float(ub.charge_amp_factor)
	var winner: String = sc.get_winner_id()
	var out := {
		"seed": seed_value,
		"atk_mode": atk_mode,
		"def_mode": def_mode,
		"winner": winner,
		"atk_won": winner == "attacker",
		"combat": float(sc.get_phase_durations_sec().get("combat_sec", -1.0)),
		"contact_tick": contact_tick,
		"atk_spd": atk_spd,
		"def_spd": def_spd,
		"atk_amp": atk_amp,
		"def_amp": def_amp,
	}
	sc.free()
	return out


func _agg(rows: Array) -> float:
	var w := 0
	for r in rows:
		if bool(r.atk_won):
			w += 1
	return 100.0 * float(w) / float(rows.size())


func _run() -> void:
	var seeds := [1000, 1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009, 12345]
	print("WO025_ANOMALY_START")
	for pair in [["march", "hold"], ["hold", "march"], ["march", "march"], ["hold", "hold"]]:
		var rows: Array = []
		for s in seeds:
			var row: Dictionary = _run_pair(s, pair[0], pair[1])
			rows.append(row)
			print(
				"ANOMALY %s_vs_%s seed=%d winner=%s combat=%.1f contact_t=%d spd=%.3f/%.3f amp=%.3f/%.3f"
				% [
					pair[0],
					pair[1],
					s,
					row.winner,
					float(row.combat),
					int(row.contact_tick),
					float(row.atk_spd),
					float(row.def_spd),
					float(row.atk_amp),
					float(row.def_amp),
				]
			)
		print("ANOMALY_AGG %s_vs_%s atk_win%%=%.1f n=%d" % [pair[0], pair[1], _agg(rows), rows.size()])
	_consts().reload_from_file()
	print("WO025_ANOMALY_DONE")
	quit(0)
