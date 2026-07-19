extends SceneTree
## WO-030: scan all ge3 seeds for max concurrent partners + per-attacker damage.


func _initialize() -> void:
	call_deferred("_run")


func _consts():
	return root.get_node("/root/Constants")


func _probe(seed_value: int) -> Dictionary:
	_consts().set_constant("quality_of_day_enabled", true)
	_consts().set_constant("quality_of_day_sigma", 0.045)
	var packed: PackedScene = load("res://tests/scenario_08.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.auto_run = false
	sc.suppress_io = true
	sc.attacker_count = 3
	sc.set_battle_seed(seed_value)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(1000)
		spins += 1
	var max_p := 0
	var multi_ticks := 0
	var ticks := 0
	while not sc.is_battle_over() and ticks < 20000:
		sc.advance_one_tick()
		ticks += 1
		var core = sc._sim_core
		if core == null:
			continue
		for u in core.units:
			if str(u.unit_id) != "defender":
				continue
			var n: int = u.get_contact_partners().size()
			max_p = maxi(max_p, n)
			if n >= 2:
				multi_ticks += 1
	sc._sync_units_from_core()
	var dmg: float = float(sc.get_defender_damage_taken())
	var by: Dictionary = {}
	for u2 in sc._units:
		if str(u2.unit_id).begins_with("attacker"):
			by[str(u2.unit_id)] = float(u2.damage_dealt)
	sc.free()
	return {"max_partners": max_p, "multi_ticks": multi_ticks, "dmg": dmg, "by": by}


func _run_single(seed_value: int) -> float:
	_consts().set_constant("quality_of_day_enabled", true)
	_consts().set_constant("quality_of_day_sigma", 0.045)
	var packed: PackedScene = load("res://tests/scenario_08.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.auto_run = false
	sc.suppress_io = true
	sc.attacker_count = 1
	sc.set_battle_seed(seed_value)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(1000)
		spins += 1
	var ticks := 0
	while not sc.is_battle_over() and ticks < 20000:
		sc.advance_one_tick()
		ticks += 1
	var dmg: float = float(sc.get_defender_damage_taken())
	sc.free()
	return dmg


func _run() -> void:
	print("WO030_GE3_SCAN_START")
	var seeds: Array = [
		1321, 1287, 1370, 1476, 1415, 1484, 1346, 1233, 1001, 1195,
		1474, 1126, 1391, 1308, 1452, 1269, 1188, 1042, 1099, 1220,
	]
	# Prefer seeds from CSV if present
	var csv_seeds: Array = []
	var f := FileAccess.open("res://docs/reports/evidence_wo029b/s8_sweep_w0.csv", FileAccess.READ)
	# load all ge3 from merged logic
	for w in ["w0", "w1", "w2", "w3"]:
		var path := "res://docs/reports/evidence_wo029b/s8_sweep_%s.csv" % w
		var cf := FileAccess.open(path, FileAccess.READ)
		if cf == null:
			continue
		cf.get_line()
		while not cf.eof_reached():
			var line := cf.get_line().strip_edges()
			if line.is_empty():
				continue
			var parts := line.split(",")
			if parts.size() < 4:
				continue
			if float(parts[3]) >= 3.0:
				csv_seeds.append(int(parts[0]))
	if not csv_seeds.is_empty():
		seeds = csv_seeds
	print("SCANNING n=%d" % seeds.size())
	var any_multi := 0
	for seed_value in seeds:
		var s1: float = _run_single(int(seed_value))
		var t: Dictionary = _probe(int(seed_value))
		var ratio: float = float(t.dmg) / s1 if s1 > 0.0 else 0.0
		if int(t.max_partners) >= 2:
			any_multi += 1
		print(
			"SEED=%d ratio=%.3f single=%.2f triple=%.2f max_partners=%d multi_ticks=%d by=%s"
			% [
				int(seed_value),
				ratio,
				s1,
				float(t.dmg),
				int(t.max_partners),
				int(t.multi_ticks),
				str(t.by),
			]
		)
	print("SEEDS_WITH_2PLUS_PARTNERS=%d / %d" % [any_multi, seeds.size()])
	_consts().reload_from_file()
	print("WO030_GE3_SCAN_DONE")
	quit(0)
