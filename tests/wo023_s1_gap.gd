extends SceneTree
func _initialize() -> void: call_deferred("_go")
func _go() -> void:
	var packed: PackedScene = load("res://tests/scenario_01.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true; sc.fast_sim_mode = true; sc.auto_run = false
	sc.set_battle_seed(12345)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(1000); spins += 1
	sc._ensure_sim_core(); sc._sim_core.capture_from_units(sc._units)
	sc._sim_core.write_trace_header(); sc._sim_core.log_trace_row(); sc._sync_state_from_core()
	var ticks := 0
	while not sc.is_battle_over() and ticks < 1200:
		sc.advance_one_tick(); ticks += 1
		var ua = sc._sim_core.units[0]
		var ub = sc._sim_core.units[1]
		var gap = CombatResolver._raw_center_gap_m(ua, ub)
		var c = ua.get_contact_partners().size() > 0
		if ticks >= 650 and ticks <= 720:
			print("GAP %d c=%s gap=%.4f any=%s partners=%d dest_a=%.2f" % [
				ticks, c, gap, CombatResolver.units_have_any_contact(ua,ub),
				ua.get_contact_partners().size(),
				ua.position.distance_to(ua.march_target)/2.0])
	sc.free(); quit(0)
