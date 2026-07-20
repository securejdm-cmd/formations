extends SceneTree
func _initialize() -> void: call_deferred("_go")
func _go() -> void:
	var packed: PackedScene = load("res://tests/scenario_01.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.auto_run = false
	sc.set_battle_seed(12345)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(1000); spins += 1
	sc._ensure_sim_core()
	sc._sim_core.capture_from_units(sc._units)
	sc._sim_core.write_trace_header(); sc._sim_core.log_trace_row(); sc._sync_state_from_core()
	var ticks := 0
	while not sc.is_battle_over() and ticks < 8000:
		sc.advance_one_tick(); ticks += 1
	var d = sc.get_phase_durations_sec()
	print("S1_CHECK winner=%s combat=%.1f over=%s ticks=%d adhesion=%s" % [
		sc.get_winner_id(), d.get("combat_sec", -1), sc.is_battle_over(), ticks,
		sc.had_adhesion_invariant_failure()])
	sc.free(); quit(0)
