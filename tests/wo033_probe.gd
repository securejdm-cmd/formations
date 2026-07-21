extends SceneTree
## Quick WO-033 probe: calibration + S49–S54 smoke.

const _HeightField := preload("res://scripts/height_field.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cal()
	_one("res://tests/scenario_49.tscn", "use_ridge", true, 2000)
	_one("res://tests/scenario_50.tscn", "use_valley", true, 2000)
	_one("res://tests/scenario_51.tscn", "", false, 2500)
	_one("res://tests/scenario_52.tscn", "use_feint", true, 3000)
	_one("res://tests/scenario_53.tscn", "", false, 1500)
	_one("res://tests/scenario_54.tscn", "", false, 800)
	quit(0)


func _cal() -> void:
	var hf = _HeightField.make_cross_slope(0.10)
	var px := 2.0
	var speed_dn: float = hf.speed_mult_at(Vector2.ZERO, Vector2.DOWN)
	var push_dn: float = hf.push_mod_at(Vector2.ZERO, Vector2.DOWN)
	var range_dn: float = hf.range_mult_toward(Vector2.ZERO, Vector2(0.0, -50.0 * px))
	print("CAL speed=%.3f push=%.3f range=%.3f" % [speed_dn, push_dn, range_dn])
	# Multi-feature map
	var multi = _HeightField.make_from_features([
		{"type": "ridge_x", "crest_x": -40.0, "half_width": 40.0, "height": 10.0},
		{"type": "gaussian_hill", "cx": 60.0, "cy": 40.0, "sigma": 30.0, "peak": 12.0},
	], -1.0, "multi")
	print("MULTI peak=%.2f label=%s" % [multi.peak_height_m(), multi.label])
	var flat = _HeightField.make_flat()
	print("FLAT identity speed=%.3f" % flat.speed_mult_at(Vector2.ZERO, Vector2.RIGHT))


func _one(path: String, flag: String, flag_val: bool, ticks: int) -> void:
	var sc = load(path).instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.auto_run = false
	sc.suppress_io = true
	if not flag.is_empty():
		sc.set(flag, flag_val)
	sc.set_battle_seed(1000)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(1000)
		spins += 1
	sc._ensure_sim_core()
	sc._sync_core_from_units()
	for i in ticks:
		sc.advance_one_tick()
		if sc.is_battle_over():
			break
	var msg := path.get_file()
	if sc.has_method("defender_won"):
		msg += " win=%s combat=%.1f" % [str(sc.defender_won()), float(sc.combat_sec())]
	if sc.has_method("closing_speed"):
		msg += " v=%.3f i=%.3f" % [float(sc.closing_speed()), float(sc.impact())]
	if "observed_edge" in sc:
		msg += " edge=%s push=%.3f" % [str(sc.observed_edge), float(sc.slope_push_mod_attacker)]
	if "trap_sprung" in sc:
		msg += " sprung=%s coh=%.1f" % [str(sc.trap_sprung), float(sc.pursuer_cohesion_end)]
	if "did_rout" in sc:
		msg += " rout=%s t=%.1f" % [str(sc.did_rout), float(sc.rout_time_sec)]
	if sc.has_method("deception_ok"):
		msg += " deception=%s fired=%s" % [str(sc.deception_ok()), str(sc.enemy_routs_fired)]
	print("PROBE %s" % msg)
	sc.free()
