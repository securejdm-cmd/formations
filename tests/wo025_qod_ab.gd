extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _consts():
	return root.get_node("/root/Constants")
func _run_s1(enabled: bool) -> Dictionary:
	_consts().set_constant("quality_of_day_enabled", enabled)
	var packed = load("res://tests/scenario_01.tscn")
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
	var t = sc.get_trace_text()
	var out = {
		"trace": t,
		"combat": float(sc.get_phase_durations_sec().get("combat_sec",-1)),
		"winner": str(sc.get_winner_id()),
		"has_qod_event": t.find("QUALITY_OF_DAY") >= 0,
	}
	sc.free()
	return out
func _run() -> void:
	var a = _run_s1(false)
	var b = _run_s1(false)
	_consts().reload_from_file()
	var ok = (str(a.trace)==str(b.trace)) and (not bool(a.has_qod_event)) and float(a.combat)==81.6
	print("QOD_AB identical=%s has_event=%s combat=%.1f winner=%s" % [
		str(str(a.trace)==str(b.trace)), str(a.has_qod_event), float(a.combat), str(a.winner)
	])
	print("QOD_AB_WO024_MATCH combat81.6=%s" % str(absf(float(a.combat)-81.6)<0.05))
	quit(0 if ok else 2)
