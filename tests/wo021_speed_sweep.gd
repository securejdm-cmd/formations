extends SceneTree
## Sweep slope_speed_bonus against S37 Impact(down)/Impact(up) ≥ 1.4.


func _initialize() -> void:
	call_deferred("_run")


func _consts():
	return root.get_node("/root/Constants")


func _run_s37(bonus: float) -> Dictionary:
	_consts().set_constant("slope_speed_bonus", bonus)
	var packed: PackedScene = load("res://tests/scenario_37.tscn")
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
	while not sc.is_battle_over() and ticks < 4500:
		sc.advance_one_tick()
		ticks += 1
	var dn: Dictionary = sc.downhill_charge()
	var up: Dictionary = sc.uphill_charge()
	var out := {
		"bonus": bonus,
		"down_v": float(dn.get("closing_speed", 0.0)),
		"down_i": float(dn.get("impact", 0.0)),
		"up_v": float(up.get("closing_speed", 0.0)),
		"up_i": float(up.get("impact", 0.0)),
		"ratio": float(sc.impact_ratio()),
		"ticks": ticks,
	}
	sc.free()
	return out


func _run() -> void:
	var candidates := [0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.45, 0.50, 0.55, 0.60]
	var best_bonus := -1.0
	var best_ratio := -1.0
	print("SWEEP_HEADER bonus,down_v,down_i,up_v,up_i,ratio")
	for b in candidates:
		var row: Dictionary = _run_s37(float(b))
		print(
			"SWEEP %.2f,%.3f,%.3f,%.3f,%.3f,%.3f"
			% [row.bonus, row.down_v, row.down_i, row.up_v, row.up_i, row.ratio]
		)
		if float(row.ratio) >= 1.4 and (best_bonus < 0.0 or float(b) < best_bonus):
			best_bonus = float(b)
			best_ratio = float(row.ratio)
		elif best_bonus < 0.0 and float(row.ratio) > best_ratio:
			best_ratio = float(row.ratio)
	_consts().reload_from_file()
	print("SWEEP_PICK bonus=%.2f ratio=%.3f (lowest that meets ≥1.4; -1 if none)" % [best_bonus, best_ratio])
	quit(0 if best_bonus >= 0.0 else 2)
