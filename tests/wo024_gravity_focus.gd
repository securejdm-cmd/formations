extends SceneTree
## WO-024 Task 2 — S33 square-up + flank timing analytic + S34 pinning probe.


func _initialize() -> void:
	call_deferred("_run")


func _consts():
	return root.get_node("/root/Constants")


func _run_named(path: String, tag: String, max_ticks: int) -> Dictionary:
	var packed: PackedScene = load(path)
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.set_battle_seed(1000)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(2000)
		spins += 1
	var ticks := 0
	while not sc.is_battle_over() and ticks < max_ticks:
		sc.advance_one_tick()
		ticks += 1
	var out := {"tag": tag, "over": sc.is_battle_over(), "ticks": ticks, "sc": sc}
	return out


func _run() -> void:
	var base: float = _consts().get_float("base_turn_rate_rad")
	var radius: float = _consts().get_float("engage_radius_m")
	var gallop: float = 13.4
	var flank_cross: float = radius / gallop
	var inf90: float = (PI * 0.5) / (base * (50.0 / 50.0) / 1.0)
	print(
		"WO024_FLANK_ANALYTIC flank_cross_s=%.3f inf_90_s=%.3f ratio=%.1f (radius=%.1f gallop=%.1f base_turn=%.3f)"
		% [flank_cross, inf90, inf90 / flank_cross, radius, gallop, base]
	)
	var safe := flank_cross < inf90 * 0.25
	print("WO024_FLANK_VERDICT safe=%s (cross << 90deg wheel; R19 intent)" % str(safe))

	var s33 = _run_named("res://tests/scenario_33.tscn", "S33", 12000)
	var sc33 = s33.sc
	print(
		"WO024_S33 edges=%s/%s dots=%.3f/%.3f rot_deg=%.1f/%.1f ticks=%d"
		% [
			str(sc33.contact_edge_red),
			str(sc33.contact_edge_blue),
			float(sc33.red_facing_dot_at_contact),
			float(sc33.blue_facing_dot_at_contact),
			float(sc33.red_rotation_deg),
			float(sc33.blue_rotation_deg),
			int(s33.ticks),
		]
	)
	print(
		"WO024_S33_NOTE before_fix_rot≈1.1deg; after_fix expect substantially larger square-up"
	)
	sc33.free()

	var s34 = _run_named("res://tests/scenario_34.tscn", "S34", 20000)
	var sc34 = s34.sc
	print(
		"WO024_S34 flank_persist=%s no_reface=%s samples=%d"
		% [
			str(sc34.flank_persisted),
			str(sc34.a_did_not_reface),
			sc34.edge_samples.size(),
		]
	)
	sc34.free()
	quit(0)
