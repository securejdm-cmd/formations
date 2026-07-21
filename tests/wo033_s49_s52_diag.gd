extends SceneTree
func _initialize(): call_deferred("_run")
func _run():
	_diag49()
	_diag52()
	quit(0)

func _diag49():
	var sc = load("res://tests/scenario_49.tscn").instantiate()
	sc.headless_mode = true; sc.fast_sim_mode = true; sc.auto_run = false; sc.suppress_io = true
	sc.use_ridge = true; sc.set_battle_seed(1000)
	root.add_child(sc)
	var spins:=0
	while not sc.is_node_ready() and spins<512: OS.delay_usec(1000); spins+=1
	sc._ensure_sim_core(); sc._sync_core_from_units()
	print("S49 hf=%s peak=%.1f" % [str(sc.get_height_field().label if sc.get_height_field() else null), sc.get_height_field().peak_height_m() if sc.get_height_field() else -1])
	for i in 4500:
		sc.advance_one_tick()
		if sc.is_battle_over(): break
	print("S49 ticks=%d win=%s routed=%s combat=%.1f str=%.1f winner=%s" % [
		sc._sim_core.sim_tick_count, str(sc.defender_won()), sc.routed_id, sc.combat_sec(), sc.strength_at_rout, sc.get_winner_id()])
	for u in sc._sim_core.units:
		print("  %s state=%s coh=%.1f str=%.1f pos=%s" % [u.unit_id, u.get_state_name(), u.cohesion, u.strength, str(u.position)])
	sc.free()

func _diag52():
	var sc = load("res://tests/scenario_52.tscn").instantiate()
	sc.headless_mode = true; sc.fast_sim_mode = true; sc.auto_run = false; sc.suppress_io = true
	sc.use_feint = true; sc.set_battle_seed(1000)
	root.add_child(sc)
	var spins:=0
	while not sc.is_node_ready() and spins<512: OS.delay_usec(1000); spins+=1
	sc._ensure_sim_core(); sc._sync_core_from_units()
	for i in 4500:
		sc.advance_one_tick()
		if sc.is_battle_over(): break
	print("S52 ticks=%d sprung=%s edge=%s pursuer_coh=%.1f flags=%s" % [
		sc._sim_core.sim_tick_count, str(sc.trap_sprung), sc.pursuer_flank_edge, sc.pursuer_cohesion_end, str(sc._sim_core.order_started_flags)])
	print("charge_events=%s" % str(sc._sim_core.last_charge_events))
	for u in sc._sim_core.units:
		print("  %s state=%s coh=%.1f prim=%s phase=%s step=%d pos=%s" % [
			u.unit_id, u.get_state_name(), u.cohesion, u.order_primitive, u.order_phase, u.order_step_index, str(u.position)])
	sc.free()
