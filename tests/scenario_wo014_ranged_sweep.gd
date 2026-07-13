extends SceneTree

## Sweep k_ranged_scale for WO-014 TD correction.
## Gates: S12 approach attrition ∈ [8,20]%; S16 leather ∈ [30,45]%; S16 plate chip-dominated.

const CANDIDATES := [
	0.08, 0.09, 0.10, 0.105, 0.11, 0.115, 0.12, 0.13, 0.14, 0.15, 0.16,
]

var _constants: Node


func _initialize() -> void:
	_constants = root.get_node("Constants")
	call_deferred("_run")


func _c_float(key: String) -> float:
	return float(_constants.get_constant(key))


func _run() -> void:
	print("[WO-014 Sweep] start")
	var rows: Array[Dictionary] = []
	for k_val in CANDIDATES:
		var k: float = float(k_val)
		_constants.set_constant("k_ranged_scale", k)
		var s12: float = _run_s12()
		var s16_leather: float = _run_s16(false)
		var s16_plate: float = _run_s16(true)
		var chip_dom: bool = _plate_chip_dominated(k, s16_plate)
		var ok: bool = (s12 >= 8.0 and s12 <= 20.0) and (s16_leather >= 30.0 and s16_leather <= 45.0) and chip_dom
		rows.append({
			"k": k,
			"s12": s12,
			"s16_leather": s16_leather,
			"s16_plate": s16_plate,
			"chip": chip_dom,
			"ok": ok,
		})
		print(
			"k=%.3f S12=%.2f%% S16L=%.2f%% S16P=%.2f%% chip=%s GATE=%s"
			% [k, s12, s16_leather, s16_plate, chip_dom, ok]
		)
	var selected: float = -1.0
	for row in rows:
		if row.ok:
			selected = row.k
			break
	if selected < 0.0:
		push_error("[WO-014 Sweep] ESCALATE — no k_ranged_scale satisfies all three gates")
		for row in rows:
			print(
				"  k=%.3f s12=%.2f s16L=%.2f s16P=%.2f chip=%s"
				% [row.k, row.s12, row.s16_leather, row.s16_plate, row.chip]
			)
		quit(2)
		return
	_commit_k(selected)
	print("[WO-014 Sweep] COMMITTED k_ranged_scale=%.3f to combat_constants.json" % selected)
	quit(0)


func _commit_k(k: float) -> void:
	var path := "res://data/combat_constants.json"
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	data["k_ranged_scale"] = k
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t") + "\n")
	file.close()
	_constants.reload_from_file()


func _run_s12() -> float:
	var sc = load("res://tests/scenario_12.tscn").instantiate()
	sc.set_battle_seed(1000)
	sc.headless_mode = true
	sc.fast_sim_mode = true
	root.add_child(sc)
	while not sc.is_node_ready():
		OS.delay_usec(5000)
	var ticks := 0
	while not sc.is_battle_over() and ticks < 4000:
		sc.advance_one_tick()
		ticks += 1
		if sc._first_contact_tick >= 0:
			break
	for _i in 5:
		if sc.is_battle_over():
			break
		sc.advance_one_tick()
	var lost: float = _strength_lost_before_contact(sc)
	sc.free()
	return lost


func _strength_lost_before_contact(sc) -> float:
	var max_s: float = _c_float("strength_max")
	var contact_sec := INF
	if sc._first_contact_tick >= 0:
		contact_sec = float(sc._first_contact_tick) / _c_float("tick_rate_per_sec")
	var last := max_s
	for line in sc.get_trace_text().split("\n", false):
		var parts: PackedStringArray = line.split(",")
		if parts.size() < 8 or parts[1] != "blue_1":
			continue
		var t: float = float(parts[0])
		if t >= contact_sec - 0.001:
			break
		last = float(parts[2])
	return max_s - last


func _run_s16(plate: bool) -> float:
	var sc = load("res://tests/scenario_16.tscn").instantiate()
	sc.set_battle_seed(1000)
	sc.plate_mode = plate
	sc.headless_mode = true
	sc.fast_sim_mode = true
	root.add_child(sc)
	while not sc.is_node_ready():
		OS.delay_usec(5000)
	for _i in 2000:
		sc.advance_one_tick()
		if sc.count_volley_events() >= 30 and sc.had_ammo_empty():
			break
	var lost: float = sc.target_strength_lost()
	sc.free()
	return lost


func _plate_chip_dominated(k: float, plate_lost: float) -> bool:
	var expected: float = 30.0 * 18.0 * k * _c_float("chip_floor_pct")
	return absf(plate_lost - expected) <= maxf(0.05 * expected, 0.5)
