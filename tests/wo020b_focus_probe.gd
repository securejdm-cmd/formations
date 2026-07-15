extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _consts():
	return root.get_node("/root/Constants")
func _run_named(path: String, tag: String, max_ticks: int) -> void:
	var packed: PackedScene = load(path)
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.set_battle_seed(1000)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(2000); spins += 1
	var ticks := 0
	while not sc.is_battle_over() and ticks < max_ticks:
		sc.advance_one_tick(); ticks += 1
	print("%s over=%s ticks=%d" % [tag, sc.is_battle_over(), ticks])
	if tag == "S30":
		print("  sk=%.2f/%.2f sp=%.2f/%.2f ratio=%.2f" % [
			float(sc.skirm_withdraw_s), float(sc.skirm_str_lost),
			float(sc.spears_withdraw_s), float(sc.spears_str_lost),
			float(sc.spears_str_lost)/maxf(float(sc.skirm_str_lost),0.001)])
	elif tag == "S31":
		print("  spears_t=%.2f drain=%.2f inf_t=%.2f drain=%.2f" % [
			float(sc.spears_time_s), float(sc.spears_drain),
			float(sc.inf_time_s), float(sc.inf_drain)])
	elif tag == "S32":
		print("  str=%.1f/%.1f/%.1f impact2=%.3f" % [
			float(sc.strength_after_fail), float(sc.strength_after_disengage),
			float(sc.strength_after_recharge), float(sc.second_charge_impact)])
	elif tag == "S33":
		print("  edges=%s/%s dots=%.2f/%.2f rot=%.1f/%.1f" % [
			str(sc.contact_edge_red), str(sc.contact_edge_blue),
			float(sc.red_facing_dot_at_contact), float(sc.blue_facing_dot_at_contact),
			float(sc.red_rotation_deg), float(sc.blue_rotation_deg)])
	elif tag == "S34":
		print("  flank=%s no_reface=%s" % [str(sc.flank_persisted), str(sc.a_did_not_reface)])
	sc.free()

func _s1_ab() -> void:
	var traces := []
	for radius in [4.0, 0.0]:
		_consts().set_constant("engage_radius_m", radius)
		var packed: PackedScene = load("res://tests/scenario_01.tscn")
		var sc = packed.instantiate()
		sc.headless_mode = true
		sc.fast_sim_mode = true
		sc.set_battle_seed(12345)
		root.add_child(sc)
		var spins := 0
		while not sc.is_node_ready() and spins < 512:
			OS.delay_usec(2000); spins += 1
		var ticks := 0
		while not sc.is_battle_over() and ticks < 30000:
			sc.advance_one_tick(); ticks += 1
		traces.append(sc.get_trace_text())
		print("S1_AB r=%.1f combat=%.1f winner=%s" % [
			radius, float(sc.get_phase_durations_sec().get("combat_sec",-1)), str(sc.get_winner_id())])
		sc.free()
	_consts().reload_from_file()
	print("S1_AB identical=%s" % str(traces[0]==traces[1]))

func _run() -> void:
	var base: float = _consts().get_float("base_turn_rate_rad")
	var inf90: float = (PI*0.5) / (base * (50.0/50.0) / 1.0)
	print("flank_cross_s=%.3f inf_90_s=%.3f (base_turn=%.3f)" % [4.0/13.4, inf90, base])
	_run_named("res://tests/scenario_30.tscn", "S30", 8000)
	_run_named("res://tests/scenario_31.tscn", "S31", 30000)
	_run_named("res://tests/scenario_33.tscn", "S33", 12000)
	_run_named("res://tests/scenario_34.tscn", "S34", 20000)
	_run_named("res://tests/scenario_32.tscn", "S32", 40000)
	_s1_ab()
	quit(0)
