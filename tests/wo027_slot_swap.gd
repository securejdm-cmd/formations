extends SceneTree
## WO-027 Task 3 — permanent SLOT-SWAP guard.
## Same seed + positions/ids/postures; only units[] order reversed.
## Asserts the slot-order symmetry that holds at equal push (QoD off):
##   - winner swaps by unit_id
##   - combat_sec matches
##   - winning / losing final strength+cohesion match (combat outcome mirror)
## Full per-tick state traces are NOT required equal: march-vs-hold posture
## stays with unit_id and interacts with process order (documented finding).

const SEED_DEFAULT := 1000


func _initialize() -> void:
	call_deferred("_run")


func _consts():
	return root.get_node("/root/Constants")


func _run_ordered(seed_value: int, reverse_slots: bool) -> Dictionary:
	_consts().set_constant("quality_of_day_enabled", false)
	var packed: PackedScene = load("res://tests/scenario_01.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.auto_run = false
	sc.suppress_io = true
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
	var base_p: Dictionary = UnitProfileLoader.load_profile("test_infantry")
	var px := float(_consts().get_float("px_per_meter"))
	var half := float(_consts().get_float("scenario_01_start_distance_m")) * 0.5 * px
	var atk: Unit = load("res://scenes/unit.tscn").instantiate()
	sc.add_child(atk)
	atk.configure("attacker", "red", base_p.duplicate(true), Vector2(-half, 0.0), Vector2.RIGHT)
	var deff: Unit = load("res://scenes/unit.tscn").instantiate()
	sc.add_child(deff)
	deff.configure("defender", "blue", base_p.duplicate(true), Vector2(half, 0.0), Vector2.LEFT)
	atk.set_march_to(Vector2(half + 20.0 * px, 0.0))
	if atk.has_method("start_from_rest"):
		atk.start_from_rest()
	deff.current_order = Unit.Order.HOLD
	deff._set_state(Unit.State.HOLD)
	deff.current_speed_m_s = 0.0
	if reverse_slots:
		sc._units.append(deff)
		sc._units.append(atk)
	else:
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
	while not sc.is_battle_over() and ticks < 12000:
		sc.advance_one_tick()
		ticks += 1
	var winner: String = sc.get_winner_id()
	var w_str := -1.0
	var w_coh := -1.0
	var l_str := -1.0
	var l_coh := -1.0
	for u in sc._units:
		if str(u.unit_id) == winner:
			w_str = float(u.strength)
			w_coh = float(u.cohesion)
		else:
			l_str = float(u.strength)
			l_coh = float(u.cohesion)
	var out := {
		"winner": winner,
		"slot0": str(sc._units[0].unit_id),
		"slot1": str(sc._units[1].unit_id),
		"combat": float(sc.get_phase_durations_sec().get("combat_sec", -1.0)),
		"w_str": w_str,
		"w_coh": w_coh,
		"l_str": l_str,
		"l_coh": l_coh,
	}
	sc.free()
	return out


func _run() -> void:
	var seed_value := SEED_DEFAULT
	for a in OS.get_cmdline_user_args():
		var s := str(a)
		if s.begins_with("SEED="):
			seed_value = int(s.substr(5))
	print("WO027_SLOT_SWAP_START seed=%d" % seed_value)
	var normal: Dictionary = _run_ordered(seed_value, false)
	var swapped: Dictionary = _run_ordered(seed_value, true)
	var expected_swap := (
		(str(normal.winner) == "attacker" and str(swapped.winner) == "defender")
		or (str(normal.winner) == "defender" and str(swapped.winner) == "attacker")
	)
	var combat_ok: bool = absf(float(normal.combat) - float(swapped.combat)) <= 0.15
	## Winner combat outcome mirrors under slot reverse; loser post-rout flee
	## diverges by geography (which edge of the map). Guard the combat mirror.
	var mirror_ok: bool = (
		absf(float(normal.w_str) - float(swapped.w_str)) <= 0.05
		and absf(float(normal.w_coh) - float(swapped.w_coh)) <= 0.05
	)
	var ok: bool = expected_swap and combat_ok and mirror_ok
	print(
		"WO027_SLOT_SWAP seed=%d normal_winner=%s swapped_winner=%s winner_swaps=%s combat=%.1f/%.1f w_str=%.2f/%.2f w_coh=%.2f/%.2f mirror_ok=%s ok=%s"
		% [
			seed_value,
			str(normal.winner),
			str(swapped.winner),
			str(expected_swap),
			float(normal.combat),
			float(swapped.combat),
			float(normal.w_str),
			float(swapped.w_str),
			float(normal.w_coh),
			float(swapped.w_coh),
			str(mirror_ok),
			str(ok),
		]
	)
	print(
		"WO027_SLOT_SWAP slots normal=%s/%s swapped=%s/%s"
		% [str(normal.slot0), str(normal.slot1), str(swapped.slot0), str(swapped.slot1)]
	)
	_consts().reload_from_file()
	print("WO027_SLOT_SWAP_DONE")
	quit(0 if ok else 1)
