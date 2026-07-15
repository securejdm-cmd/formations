extends SceneTree
## WO-023 Task 2 — spears→cavalry stall trace (seed 1000).
## Logs strength, cohesion, push, displacement, contact for both units.

const SEED := 1000
const MAX_TICKS := 4000
const SAMPLE_EVERY := 50


func _initialize() -> void:
	call_deferred("_go")


func _consts():
	return Engine.get_main_loop().root.get_node("/root/Constants")


func _go() -> void:
	print("STALL_TRACE_START spears>cavalry seed=%d" % SEED)
	var packed: PackedScene = load("res://tests/scenario_01.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.auto_run = false
	sc.set_battle_seed(SEED)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(1000)
		spins += 1
	for u in sc._units.duplicate():
		sc.remove_child(u)
		u.free()
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
	if atk.has_method("start_from_rest"):
		atk.start_from_rest()
	deff.current_order = Unit.Order.HOLD
	deff._set_state(Unit.State.HOLD)
	deff.current_speed_m_s = 0.0
	# Matrix: Pierce defenders pre-braced
	deff._brace_hold_sec = float(_consts().get_float("brace_time_s")) + 0.1
	deff._braced = true
	if deff.has_method("_update_brace_visual"):
		deff._update_brace_visual()
	sc._units.append(atk)
	sc._units.append(deff)
	for unit in sc._units:
		unit.set_render_camera(sc._camera)
	sc._ensure_sim_core()
	sc._sim_core.capture_from_units(sc._units)
	sc._sim_core.write_trace_header()
	sc._sim_core.log_trace_row()
	sc._sync_state_from_core()

	var atk0 := Vector2(atk.global_position)
	var def0 := Vector2(deff.global_position)
	var contact_breaks := 0
	var was_contact := false
	var max_push_sep := 0.0
	print(
		"STALL_HDR tick,atk_str,atk_coh,def_str,def_coh,atk_spd,def_spd,sep_m,contact,atk_state,def_state,atk_disp_m,def_disp_m"
	)
	var ticks := 0
	while not sc.is_battle_over() and ticks < MAX_TICKS:
		sc.advance_one_tick()
		ticks += 1
		var sep_m: float = atk.global_position.distance_to(deff.global_position) / px
		var atk_partners: int = atk._contact_partners.size() if "_contact_partners" in atk else 0
		var def_partners: int = deff._contact_partners.size() if "_contact_partners" in deff else 0
		var contact := atk_partners > 0 or def_partners > 0
		if was_contact and not contact:
			contact_breaks += 1
		was_contact = contact
		if sep_m > max_push_sep and ticks > 200:
			max_push_sep = sep_m
		if ticks == 1 or ticks % SAMPLE_EVERY == 0 or sc.is_battle_over():
			var atk_disp := atk0.distance_to(atk.global_position) / px
			var def_disp := def0.distance_to(deff.global_position) / px
			print(
				"STALL_ROW %d,%.2f,%.2f,%.2f,%.2f,%.3f,%.3f,%.2f,%s,atk_n=%d,def_n=%d,%s,%s,%.2f,%.2f"
				% [
					ticks,
					atk.strength,
					atk.cohesion,
					deff.strength,
					deff.cohesion,
					float(atk.current_speed_m_s) if "current_speed_m_s" in atk else 0.0,
					float(deff.current_speed_m_s) if "current_speed_m_s" in deff else 0.0,
					sep_m,
					contact,
					atk_partners,
					def_partners,
					str(atk.get_state()),
					str(deff.get_state()),
					atk_disp,
					def_disp,
				]
			)
	print(
		"STALL_SUMMARY ticks=%d over=%s winner=%s breaks=%d max_sep_after200=%.2f atk_str=%.2f def_str=%.2f atk_coh=%.2f def_coh=%.2f"
		% [
			ticks,
			sc.is_battle_over(),
			sc.get_winner_id(),
			contact_breaks,
			max_push_sep,
			atk.strength,
			deff.strength,
			atk.cohesion,
			deff.cohesion,
		]
	)
	sc.free()
	quit(0)
