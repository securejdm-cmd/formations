extends SceneTree

## Headless smoke test for WO-001 acceptance criteria.


func _initialize() -> void:
	var exit_code := 0
	var constants: Node = root.get_node("Constants")
	var rng: Node = root.get_node("RNG")

	if not _test_constants_loaded(constants):
		exit_code = 1
	if not _test_rng_determinism(rng):
		exit_code = 1
	if not _test_battlefield_scene_loads():
		exit_code = 1

	quit(exit_code)


func _test_constants_loaded(constants: Node) -> bool:
	var required_keys := [
		"tick_rate_per_sec",
		"wobble_pct",
		"waver_threshold",
		"waver_effect",
		"rout_threshold",
		"k_melee_scale",
		"chip_floor_pct",
		"push_loser_damage_factor",
		"drain_per_strength_pct_lost",
		"drain_per_meter_lost",
		"edge_mult_side_shift",
		"edge_mult_rear_shift",
		"edge_mult_side_casualty",
		"edge_mult_rear_casualty",
		"neighbor_rout_shock",
		"neighbor_rout_shock_radius_m",
		"general_slain_drain",
		"idle_recovery_per_sec",
		"rout_flee_speed_pct",
		"pursuit_damage_multiplier",
		"pursuit_radius_m",
		"pursuit_contact_m",
		"t_rally_sec",
		"rally_cohesion_reset",
		"rally_per_battle_limit",
		"ordered_retreat_drain_per_sec",
		"px_per_meter",
		"battlefield_width_m",
		"battlefield_height_m",
		"grind_band_min_screen_px",
		"crack_band_gain",
		"crack_band_edge_wobble",
		"shock_floater_duration_s",
		"shock_floater_font_px",
		"shock_floater_rise_px",
		"stat_card_edge_margin_px",
		"spatial_grid_cell_m",
	]

	for key in required_keys:
		if not constants.has_constant(key):
			push_error("Missing constant: %s" % key)
			return false

	print("[Test] Constants: PASS (%d keys present)" % required_keys.size())
	return true


func _test_rng_determinism(rng: Node) -> bool:
	var test_seed := 42
	var sequence_a: Array[float] = []
	var sequence_b: Array[float] = []

	rng.set_seed(test_seed)
	for _i in 5:
		sequence_a.append(rng.randf_range(0.0, 1.0))

	rng.set_seed(test_seed)
	for _i in 5:
		sequence_b.append(rng.randf_range(0.0, 1.0))

	if sequence_a != sequence_b:
		push_error("RNG sequences differ for same seed")
		return false

	print("[Test] RNG determinism: PASS")
	return true


func _test_battlefield_scene_loads() -> bool:
	var scene := load("res://scenes/battlefield.tscn")
	if scene == null:
		push_error("Failed to load battlefield scene")
		return false

	var instance: Node = scene.instantiate()
	if instance == null:
		push_error("Failed to instantiate battlefield scene")
		return false

	instance.free()
	print("[Test] Battlefield scene load: PASS")
	return true
