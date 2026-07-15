extends SceneTree
func _initialize() -> void: call_deferred("_go")
func _consts():
	return Engine.get_main_loop().root.get_node("/root/Constants")
func _go() -> void:
	var packed: PackedScene = load("res://tests/scenario_01.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true; sc.fast_sim_mode = true; sc.auto_run = false
	sc.set_battle_seed(1000)
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
	var dest := Vector2(half + 20.0 * px, 0.0)
	atk.set_march_to(dest)
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
	var ticks := 0
	while ticks < 3620 and not sc.is_battle_over():
		sc.advance_one_tick(); ticks += 1
		if ticks < 3575: continue
		var ua = null; var ub = null
		for u in sc._sim_core.units:
			if u.unit_id == "attacker": ua = u
			if u.unit_id == "defender": ub = u
		var sep = ua.position.distance_to(ub.position) / px
		var gap = CombatResolver._raw_center_gap_m(ua, ub)
		var halfsum = ua.effective_depth_m()*0.5 + ub.effective_depth_m()*0.5
		var to_dest = ua.march_target.distance_to(ua.position) / px if "march_target" in ua else -1.0
		var grav = Magnetism.find_gravity_target(ua, [ub]) if ClassDB.class_exists("Magnetism") else null
		# Magnetism is preload script
		var Mag = load("res://scripts/magnetism.gd")
		grav = Mag.find_gravity_target(ua, [ub])
		print("FZ2 %d sep=%.3f gap=%.3f halfsum=%.3f str=%.1f/%.1f dest_dist=%.2f grav=%s locked=%s state=%s/%s partners=%d any=%s" % [
			ticks, sep, gap, halfsum, ua.strength, ub.strength, to_dest,
			grav != null, ua.auto_engage_locked, ua.get_state(), ub.get_state(),
			ua.get_contact_partners().size(), CombatResolver.units_have_any_contact(ua, ub)])
	sc.free(); quit(0)
