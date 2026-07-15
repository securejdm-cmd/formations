extends SceneTree
## Focused WO-021 scenario probe (S36–S39 + hill geometry + speed sweep points).


const _HeightField := preload("res://scripts/height_field.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run_scenario(path: String, ticks_max: int = 4500) -> Node:
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
	while not sc.is_battle_over() and ticks < ticks_max:
		sc.advance_one_tick()
		ticks += 1
	print("PROBE_TICKS %s %d" % [path.get_file(), ticks])
	return sc


func _run() -> void:
	var hf = _HeightField.make_test_hill()
	print("HILL_GEOM ", JSON.stringify(hf.geometry_report()))

	var s36 = _run_scenario("res://tests/scenario_36.tscn")
	print(
		"S36 displace=%.2f routed=%s combat=%.1f downhill_won=%s"
		% [
			s36.ground_displacement_m(),
			s36.get_routed_id(),
			float(s36.get_phase_durations_sec().get("combat_sec", -1.0)),
			s36.downhill_won_push(),
		]
	)
	s36.free()

	var s37 = _run_scenario("res://tests/scenario_37.tscn")
	var dn: Dictionary = s37.downhill_charge()
	var up: Dictionary = s37.uphill_charge()
	print(
		"S37 down_v=%.3f/i=%.3f up_v=%.3f/i=%.3f ratio=%.3f"
		% [
			float(dn.get("closing_speed", 0.0)),
			float(dn.get("impact", 0.0)),
			float(up.get("closing_speed", 0.0)),
			float(up.get("impact", 0.0)),
			s37.impact_ratio(),
		]
	)
	s37.free()

	var s38 = _run_scenario("res://tests/scenario_38.tscn", 2500)
	print("S38 down=%.1f up=%.1f" % [s38.first_volley_down_m, s38.first_volley_up_m])
	s38.free()

	var s39 = _run_scenario("res://tests/scenario_39.tscn")
	print(
		"S39 winner=%s combat=%.1f routed=%s str=%.2f"
		% [
			s39.get_winner_id(),
			float(s39.get_phase_durations_sec().get("combat_sec", -1.0)),
			s39.get_routed_id(),
			s39.strength_at_rout(),
		]
	)
	s39.free()
	quit(0)
