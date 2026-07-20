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
	var c_ticks := 0
	var breaks := 0
	var was := false
	var a = sc._units[0]
	var b = sc._units[1]
	var px := float(Engine.get_main_loop().root.get_node("/root/Constants").get_float("px_per_meter"))
	while not sc.is_battle_over() and ticks < 3500:
		sc.advance_one_tick(); ticks += 1
		var c: bool = a._contact_partners.size() > 0 or b._contact_partners.size() > 0
		if c: c_ticks += 1
		if was and not c: breaks += 1
		was = c
		if ticks >= 650 and ticks <= 720:
			print("S1D %d contact=%s sep=%.2f st=%s/%s" % [ticks, c,
				a.global_position.distance_to(b.global_position)/px, a.get_state(), b.get_state()])
	print("S1D_SUM ticks=%d contact=%d breaks=%d pct=%.1f combat=%.1f" % [
		ticks, c_ticks, breaks, 100.0*float(c_ticks)/float(maxi(ticks,1)),
		sc.get_phase_durations_sec().get("combat_sec", -1)])
	sc.free(); quit(0)
