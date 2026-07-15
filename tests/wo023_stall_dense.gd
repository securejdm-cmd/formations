extends SceneTree
const SEED := 1000
func _initialize() -> void:
	call_deferred("_go")
func _consts():
	return Engine.get_main_loop().root.get_node("/root/Constants")
func _go() -> void:
	var packed: PackedScene = load("res://tests/scenario_01.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.auto_run = false
	sc.set_battle_seed(SEED)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(1000); spins += 1
	for u in sc._units.duplicate():
		sc.remove_child(u); u.free()
	sc._units.clear()
	var atk_p := UnitProfileLoader.load_profile("test_spears")
	var def_p := UnitProfileLoader.load_profile("test_cavalry")
	var px := float(_consts().get_float("px_per_meter"))
	var half := float(_consts().get_float("scenario_01_start_distance_m")) * 0.5 * px
	var atk: Unit = load("res://scenes/unit.tscn").instantiate()
	sc.add_child(atk)
	atk.configure("attacker", "red", atk_p, Vector2(-half, 0.0), Vector2.RIGHT)
	var deff: Unit = load("res://scenes/unit.tscn").instantiate()
	sc.add_child(deff)
	deff.configure("defender", "blue", def_p, Vector2(half, 0.0), Vector2.LEFT)
	atk.set_march_to(Vector2(half + 20.0 * px, 0.0))
	if atk.has_method("start_from_rest"): atk.start_from_rest()
	deff.current_order = Unit.Order.HOLD
	deff._set_state(Unit.State.HOLD)
	deff.current_speed_m_s = 0.0
	deff._brace_hold_sec = float(_consts().get_float("brace_time_s")) + 0.1
	deff._braced = true
	sc._units.append(atk); sc._units.append(deff)
	for unit in sc._units: unit.set_render_camera(sc._camera)
	sc._ensure_sim_core(); sc._sim_core.capture_from_units(sc._units)
	sc._sim_core.write_trace_header(); sc._sim_core.log_trace_row(); sc._sync_state_from_core()
	print("DENSE_START engage_snap=%s contact_depth related via sep" % _consts().get_float("engage_snap_max_m"))
	var ticks := 0
	var contact_ticks := 0
	var breaks := 0
	var was := false
	while ticks < 4500 and not sc.is_battle_over():
		sc.advance_one_tick(); ticks += 1
		var c := atk._contact_partners.size() > 0 or deff._contact_partners.size() > 0
		if c: contact_ticks += 1
		if was and not c: breaks += 1
		was = c
		var sep = atk.global_position.distance_to(deff.global_position) / px
		# Print every tick near first combat window and freeze window
		if (ticks >= 1320 and ticks <= 1380) or (ticks >= 3550 and ticks <= 3620) or (c and ticks % 10 == 0):
			print("DENSE %d sep=%.2f contact=%s atk_n=%d def_n=%d str=%.2f/%.2f coh=%.2f/%.2f st=%s/%s spd=%.3f/%.3f" % [
				ticks, sep, c, atk._contact_partners.size(), deff._contact_partners.size(),
				atk.strength, deff.strength, atk.cohesion, deff.cohesion,
				atk.get_state(), deff.get_state(), atk.current_speed_m_s, deff.current_speed_m_s])
	print("DENSE_SUMMARY ticks=%d contact_ticks=%d breaks=%d contact_pct=%.1f over=%s" % [
		ticks, contact_ticks, breaks, 100.0*float(contact_ticks)/float(ticks), sc.is_battle_over()])
	sc.free(); quit(0)
