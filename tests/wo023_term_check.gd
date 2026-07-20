extends SceneTree
## Focused re-check: spears→cavalry and spears→skirmisher terminate after WO-023 adhesion fix.

const SEEDS := [1000, 1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009, 12345]
const PAIRS := [["test_spears", "test_cavalry"], ["test_spears", "test_skirmisher"]]


func _initialize() -> void:
	call_deferred("_go")


func _consts():
	return Engine.get_main_loop().root.get_node("/root/Constants")


func _run_pair(atk_id: String, def_id: String, seed_value: int) -> Dictionary:
	var packed: PackedScene = load("res://tests/scenario_01.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.auto_run = false
	sc.set_battle_seed(seed_value)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(1000)
		spins += 1
	for u in sc._units.duplicate():
		sc.remove_child(u)
		u.free()
	sc._units.clear()
	var atk_p := UnitProfileLoader.load_profile(atk_id)
	var def_p := UnitProfileLoader.load_profile(def_id)
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
	if str(def_p.get("melee_damage_type", "")) == "Pierce":
		deff._brace_hold_sec = float(_consts().get_float("brace_time_s")) + 0.1
		deff._braced = true
	sc._units.append(atk)
	sc._units.append(deff)
	for unit in sc._units:
		unit.set_render_camera(sc._camera)
	sc._ensure_sim_core()
	sc._sim_core.capture_from_units(sc._units)
	sc._sim_core.write_trace_header()
	sc._sim_core.log_trace_row()
	sc._sync_state_from_core()
	var ticks := 0
	while not sc.is_battle_over() and ticks < 8000:
		sc.advance_one_tick()
		ticks += 1
	var out := {
		"winner": sc.get_winner_id(),
		"over": sc.is_battle_over(),
		"ticks": ticks,
		"combat": float(sc.get_phase_durations_sec().get("combat_sec", -1.0)),
	}
	sc.free()
	return out


func _go() -> void:
	print("TERM_CHECK_START")
	for pair in PAIRS:
		var timeouts := 0
		for seed_value in SEEDS:
			var r: Dictionary = _run_pair(pair[0], pair[1], seed_value)
			if not bool(r.over):
				timeouts += 1
			print(
				"TERM_ROW %s>%s seed=%d over=%s winner=%s ticks=%d combat=%.1f"
				% [pair[0], pair[1], seed_value, r.over, r.winner, r.ticks, r.combat]
			)
		print("TERM_SUMMARY %s>%s timeouts=%d/%d" % [pair[0], pair[1], timeouts, SEEDS.size()])
	print("TERM_CHECK_DONE")
	quit(0)
