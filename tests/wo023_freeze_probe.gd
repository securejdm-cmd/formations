extends SceneTree
## At freeze (tick ~3580), dump Gap geometry / contact classifiers for spears↔cav.
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
	var ticks := 0
	while ticks < 3600 and not sc.is_battle_over():
		sc.advance_one_tick(); ticks += 1
		if ticks >= 3575 and ticks <= 3590:
			var core = sc._sim_core
			var pa = core.get_unit_by_id("attacker") if core.has_method("get_unit_by_id") else null
			# Use scene units synced - prefer proxies via units array
			var ua = null; var ub = null
			for u in core.units:
				if u.unit_id == "attacker": ua = u
				if u.unit_id == "defender": ub = u
			var sep = ua.position.distance_to(ub.position) / px
			var anyc = CombatResolver.units_have_any_contact(ua, ub)
			var front = CombatResolver.units_have_front_contact(ua, ub)
			var head = CombatResolver.is_head_on_pair(ua, ub)
			var clas = CombatResolver.pair_has_classifier_contact(ua, ub)
			var could = CombatResolver.could_have_contact(ua, ub)
			var cab = EdgeContact.classify_contact(ua, ub)
			var cba = EdgeContact.classify_contact(ub, ua)
			var gap := -999.0
			print("FRZ %d sep=%.3f any=%s front=%s head=%s clas=%s could=%s gap=%.3f ab=%s ba=%s partners=%d/%d dest=%s spd=%.3f/%0.3f facingA=%.2f,%.2f facingB=%.2f,%.2f state=%s/%s" % [
				ticks, sep, anyc, front, head, clas, could, gap,
				cab.get("has_contact", false), cba.get("has_contact", false),
				ua.get_contact_partners().size(), ub.get_contact_partners().size(),
				str(ua.destination) if "destination" in ua else "?",
				ua.current_speed_m_s, ub.current_speed_m_s,
				ua.facing.x, ua.facing.y, ub.facing.x, ub.facing.y,
				ua.get_state(), ub.get_state()])
	sc.free(); quit(0)
