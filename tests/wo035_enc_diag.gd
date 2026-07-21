extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var raw := FileAccess.get_file_as_string("res://data/battles/wo035_encirclement.json")
	var merged = JSON.parse_string(raw)
	var packed = load("res://tests/scenario_from_data.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.auto_run = false
	sc.use_sim_thread = false
	sc.suppress_io = true
	sc.set_battle_data(merged)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(1000)
		spins += 1
	sc.stop_sim_thread_for_harness()
	sc._ensure_sim_core()
	sc._sim_core.capture_from_units(sc._units)
	sc._sim_core.headless_mode = true
	sc._sim_core.fast_sim_mode = true
	for t in range(1, 801):
		sc.advance_one_tick()
		if t % 50 == 0 or sc.is_battle_over():
			for u in sc._sim_core.units:
				if str(u.unit_id) != "victim":
					continue
				var pids := []
				for p in u.get_contact_partners():
					pids.append(p.unit_id)
				print("t=%d edges=%s partners=%s drains=%s ov=%s" % [
					t, u.get_active_contact_edges(), str(pids),
					str(u._edge_cohesion_drain_totals), str(sc.had_overlap_failure())
				])
		if sc.is_battle_over():
			break
	quit(0)
