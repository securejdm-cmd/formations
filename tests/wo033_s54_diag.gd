extends SceneTree
func _initialize(): call_deferred("_run")
func _run():
	var sc = load("res://tests/scenario_54.tscn").instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.auto_run = false
	sc.suppress_io = true
	sc.set_battle_seed(1000)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(1000); spins += 1
	sc._ensure_sim_core(); sc._sync_core_from_units()
	for i in 40:
		sc.advance_one_tick()
	print("samples=%d deception=%s fired=%s" % [sc.window_samples.size(), str(sc.deception_ok()), str(sc.enemy_routs_fired)])
	for s in sc.window_samples:
		print(s)
		if float(s.get("t",0)) > 3.0:
			break
	for u in sc._sim_core.units:
		print("unit %s state=%s feign=%s left=%.2f prim=%s" % [u.unit_id, u.get_state_name(), str(u.feign_active), u.feign_deception_remaining_s, u.order_primitive])
	quit(0)
