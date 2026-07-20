extends SceneTree
## WO-023 Task 3 — infantry_charge dominance isolation (NO TUNING of ship constants).
## Conditions (ephemeral overrides on constants / scenario for the run only):
##   FULL          — normal
##   NO_AMP        — charge_amp_peak := 1.0 (no damage/push amp window)
##   NO_SHOCK      — charge_impact_scale := 0.0 (no cohesion shock from charge)
##   NO_BOTH       — both

const SEEDS := [1000, 1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009, 12345]


func _initialize() -> void:
	call_deferred("_go")


func _consts():
	return Engine.get_main_loop().root.get_node("/root/Constants")


func _set_float(key: String, value: float) -> void:
	_consts().set_constant(key, value)


func _get_float(key: String) -> float:
	return float(_consts().get_float(key))


func _run_pair(seed_value: int) -> Dictionary:
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
	var p := UnitProfileLoader.load_profile("test_infantry_charge")
	var px := float(_consts().get_float("px_per_meter"))
	var half := float(_consts().get_float("scenario_01_start_distance_m")) * 0.5 * px
	var atk: Unit = load("res://scenes/unit.tscn").instantiate()
	sc.add_child(atk)
	atk.configure("attacker", "red", p, Vector2(-half, 0.0), Vector2.RIGHT)
	var deff: Unit = load("res://scenes/unit.tscn").instantiate()
	sc.add_child(deff)
	deff.configure("defender", "blue", p, Vector2(half, 0.0), Vector2.LEFT)
	atk.set_march_to(Vector2(half + 20.0 * px, 0.0))
	if atk.has_method("start_from_rest"):
		atk.start_from_rest()
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
	var ticks := 0
	while not sc.is_battle_over() and ticks < 8000:
		sc.advance_one_tick()
		ticks += 1
	var out := {
		"seed": seed_value,
		"winner": sc.get_winner_id(),
		"atk_won": sc.get_winner_id() == "attacker",
		"combat": float(sc.get_phase_durations_sec().get("combat_sec", -1.0)),
		"ticks": ticks,
	}
	sc.free()
	return out


func _condition(label: String, amp: float, impact: float) -> void:
	_set_float("charge_amp_peak", amp)
	_set_float("charge_impact_scale", impact)
	print(
		"INFCHARGE_COND %s amp_peak=%.3f impact_scale=%.3f"
		% [label, _get_float("charge_amp_peak"), _get_float("charge_impact_scale")]
	)
	var wins := 0
	var combat_sum := 0.0
	for seed_value in SEEDS:
		var row: Dictionary = _run_pair(seed_value)
		if bool(row.atk_won):
			wins += 1
		combat_sum += float(row.combat)
		print(
			"INFCHARGE_ROW %s seed=%d winner=%s combat=%.1f"
			% [label, seed_value, row.winner, row.combat]
		)
	var wr := 100.0 * float(wins) / float(SEEDS.size())
	print(
		"INFCHARGE_SUMMARY %s win_rate=%.1f%% mean_combat=%.1f"
		% [label, wr, combat_sum / float(SEEDS.size())]
	)


func _go() -> void:
	print("INFCHARGE_DIAG_START")
	var amp0 := _get_float("charge_amp_peak")
	var imp0 := _get_float("charge_impact_scale")
	print("INFCHARGE_BASELINE amp_peak=%.3f impact_scale=%.3f" % [amp0, imp0])
	_condition("FULL", amp0, imp0)
	_condition("NO_AMP", 1.0, imp0)
	_condition("NO_SHOCK", amp0, 0.0)
	_condition("NO_BOTH", 1.0, 0.0)
	# Restore
	_set_float("charge_amp_peak", amp0)
	_set_float("charge_impact_scale", imp0)
	print("INFCHARGE_DIAG_DONE restored")
	quit(0)
