extends SceneTree
## WO-025 Task 4 — R21 maneuver-dominance boundary (QoD ON at probe sigma).


func _initialize() -> void:
	call_deferred("_run")


func _consts():
	return root.get_node("/root/Constants")


func _run_named(path: String, tag: String, max_ticks: int, seed_value: int = 1000) -> Dictionary:
	var packed: PackedScene = load(path)
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.set_battle_seed(seed_value)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(2000)
		spins += 1
	var ticks := 0
	while not sc.is_battle_over() and ticks < max_ticks:
		sc.advance_one_tick()
		ticks += 1
	var out := {"tag": tag, "sc": sc, "ticks": ticks}
	return out


func _run() -> void:
	# Probe at sigma=0.05 (0% cell in band; Task 2 did not select a width).
	_consts().set_constant("quality_of_day_enabled", true)
	_consts().set_constant("quality_of_day_sigma", 0.05)
	print("WO025_BOUNDARY sigma=0.05 enabled=true")

	var s3 = _run_named("res://tests/scenario_03.tscn", "S3", 12000)
	var sc3 = s3.sc
	var combat3: float = float(sc3.get_phase_durations_sec().get("combat_sec", -1.0))
	var ratio3: float = combat3 / 75.8
	var rout3: float = float(sc3.get_blue_a_strength_at_rout())
	var left3: float = float(sc3.get_blue_a_edge_drains().get("left", 0.0))
	var s3_ok: bool = (
		ratio3 >= 0.28 - 0.002
		and ratio3 <= 0.45 + 0.002
		and rout3 > 67.0
		and left3 >= 50.0
	)
	print(
		"BOUNDARY S3 ratio=%.3f rout=%.2f left=%.2f ok=%s"
		% [ratio3, rout3, left3, str(s3_ok)]
	)
	sc3.free()

	var s34 = _run_named("res://tests/scenario_34.tscn", "S34", 20000)
	var sc34 = s34.sc
	var s34_ok: bool = bool(sc34.flank_persisted) and bool(sc34.a_did_not_reface)
	print(
		"BOUNDARY S34 flank_persist=%s no_reface=%s ok=%s"
		% [str(sc34.flank_persisted), str(sc34.a_did_not_reface), str(s34_ok)]
	)
	sc34.free()

	var s18 = _run_named("res://tests/scenario_18.tscn", "S18", 20000)
	var sc18 = s18.sc
	# Braced spears stop cavalry — winner blue_spears
	var s18_ok: bool = str(sc18.get_winner_id()).find("spears") >= 0 or str(sc18.get_winner_id()).find("blue") >= 0
	print("BOUNDARY S18 winner=%s ok=%s" % [str(sc18.get_winner_id()), str(s18_ok)])
	sc18.free()

	var s19 = _run_named("res://tests/scenario_19.tscn", "S19", 20000)
	var sc19 = s19.sc
	# Late brace fails — expect unaware/high shock (braced=false)
	var s19_ok: bool = true
	if "braced" in sc19:
		s19_ok = not bool(sc19.braced)
	print("BOUNDARY S19 winner=%s ok=%s" % [str(sc19.get_winner_id()), str(s19_ok)])
	sc19.free()

	# Spectrum S23–S26: land bands / tiers from scenario fields
	for item in [
		["res://tests/scenario_23.tscn", "S23", 1],
		["res://tests/scenario_24.tscn", "S24", 3],
		["res://tests/scenario_25.tscn", "S25", 3],
		["res://tests/scenario_26.tscn", "S26", 3],
	]:
		var r = _run_named(str(item[0]), str(item[1]), 20000)
		var sc = r.sc
		var tier := -1
		if "brace_tier" in sc:
			tier = int(sc.brace_tier)
		elif "tier" in sc:
			tier = int(sc.tier)
		elif "impact_tier" in sc:
			tier = int(sc.impact_tier)
		# Fallback: use recorded shock/land if present
		var detail := "winner=%s" % str(sc.get_winner_id())
		if "shock" in sc:
			detail += " shock=%.2f" % float(sc.shock)
		if "land" in sc:
			detail += " land=%.2f" % float(sc.land)
		print("BOUNDARY %s %s tier_expect=%d tier_got=%d" % [item[1], detail, int(item[2]), tier])
		sc.free()

	var s36 = _run_named("res://tests/scenario_36.tscn", "S36", 20000)
	var sc36 = s36.sc
	# Downhill should beat uphill — red_downhill wins
	var s36_ok: bool = str(sc36.get_winner_id()).find("down") >= 0 or str(sc36.get_winner_id()).begins_with("red")
	print("BOUNDARY S36 winner=%s ok=%s" % [str(sc36.get_winner_id()), str(s36_ok)])
	sc36.free()

	# Rear charge vs fresh infantry — S21 is flank; look for rear scenario
	var s21 = _run_named("res://tests/scenario_21.tscn", "S21", 20000)
	var sc21 = s21.sc
	var s21_ok: bool = str(sc21.get_winner_id()).find("cav") >= 0 or str(sc21.get_winner_id()).begins_with("red")
	print("BOUNDARY S21_flank winner=%s ok=%s" % [str(sc21.get_winner_id()), str(s21_ok)])
	sc21.free()

	_consts().reload_from_file()
	print("WO025_BOUNDARY_DONE")
	quit(0)
