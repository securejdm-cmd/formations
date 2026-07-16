extends SceneTree
## WO-028 Task 1 — S34 per-tick edge + facing diagnostic (QoD on vs off, seed 1000).

const SEED := 1000
const SIGMA := 0.045


func _initialize() -> void:
	call_deferred("_run")


func _consts():
	return root.get_node("/root/Constants")


func _run_s34(enabled: bool) -> Dictionary:
	_consts().set_constant("quality_of_day_enabled", enabled)
	_consts().set_constant("quality_of_day_sigma", SIGMA)
	var packed: PackedScene = load("res://tests/scenario_34.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.set_battle_seed(SEED)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(2000)
		spins += 1
	# Instrument every tick once flank contact starts (mirror scenario_34 sample logic
	# but denser: full engagement window).
	var rows: Array = []
	var phase := "front_engage"
	var sample_n := 0
	var ticks := 0
	var a_face0 := Vector2.ZERO
	while not sc.is_battle_over() and ticks < 20000:
		sc.advance_one_tick()
		ticks += 1
		var a = sc._a
		var b = sc._b
		var c = sc._c
		if a == null:
			continue
		if phase == "front_engage" and a.has_contact_with(b):
			phase = "flank"
			a_face0 = a.facing.normalized()
		if phase == "flank" and a.has_contact_with(c):
			phase = "sample"
		if phase == "sample" and sample_n < 40:
			var info: Dictionary = EdgeContact.classify_contact(c, a)
			var edges: Dictionary = info.get("edge_lengths_m", {})
			var morale: Dictionary = ChargeCombat.charge_edge_morale_mult(c, a, edges)
			var edge: String = str(morale.get("edge", ""))
			var mult: float = float(morale.get("mult", 0.0))
			var to_c: Vector2 = (c.position - a.position).normalized()
			var facing: Vector2 = a.facing.normalized()
			var angle_deg: float = rad_to_deg(facing.angle())
			var turn_from_start: float = rad_to_deg(a_face0.angle_to(facing))
			var dot: float = facing.dot(to_c)
			var left_m: float = float(edges.get(EdgeContact.EDGE_LEFT, 0.0))
			var front_m: float = float(edges.get(EdgeContact.EDGE_FRONT, 0.0))
			var right_m: float = float(edges.get(EdgeContact.EDGE_RIGHT, 0.0))
			var rear_m: float = float(edges.get(EdgeContact.EDGE_REAR, 0.0))
			rows.append({
				"t": ticks * CombatResolver.tick_interval(),
				"edge": edge,
				"mult": mult,
				"dot": dot,
				"angle_deg": angle_deg,
				"turn_deg": turn_from_start,
				"left_m": left_m,
				"front_m": front_m,
				"right_m": right_m,
				"rear_m": rear_m,
			})
			sample_n += 1
	var out := {
		"enabled": enabled,
		"flank_persisted": bool(sc.flank_persisted),
		"a_did_not_reface": bool(sc.a_did_not_reface),
		"samples_scenario": sc.edge_samples.size(),
		"rows": rows,
		"q_a": float(sc._a.quality_of_day) if "quality_of_day" in sc._a else 1.0,
		"q_b": float(sc._b.quality_of_day) if "quality_of_day" in sc._b else 1.0,
		"q_c": float(sc._c.quality_of_day) if "quality_of_day" in sc._c else 1.0,
	}
	sc.free()
	return out


func _summarize(tag: String, d: Dictionary) -> void:
	print(
		"S34_DIAG tag=%s flank_persist=%s no_reface=%s q=%.4f/%.4f/%.4f n_rows=%d"
		% [
			tag,
			str(d.flank_persisted),
			str(d.a_did_not_reface),
			float(d.q_a),
			float(d.q_b),
			float(d.q_c),
			(d.rows as Array).size(),
		]
	)
	var max_abs_turn := 0.0
	var max_dot := -2.0
	var min_mult := 99.0
	var left_n := 0
	var front_n := 0
	var other_n := 0
	var mult_gt1 := 0
	for row in d.rows:
		max_abs_turn = maxf(max_abs_turn, absf(float(row.turn_deg)))
		max_dot = maxf(max_dot, float(row.dot))
		min_mult = minf(min_mult, float(row.mult))
		var e := str(row.edge)
		if e == "left":
			left_n += 1
		elif e == "front":
			front_n += 1
		else:
			other_n += 1
		if float(row.mult) > 1.0 + 0.001:
			mult_gt1 += 1
	print(
		"S34_DIAG_SUM tag=%s max_abs_turn_deg=%.2f max_dot_to_flanker=%.3f min_mult=%.3f edges left=%d front=%d other=%d mult_gt1=%d/%d"
		% [tag, max_abs_turn, max_dot, min_mult, left_n, front_n, other_n, mult_gt1, (d.rows as Array).size()]
	)
	print("S34_DIAG_ROWS tag=%s t,edge,mult,dot,angle_deg,turn_deg,left_m,front_m" % tag)
	for row in d.rows:
		print(
			"S34_ROW %s t=%.1f edge=%s mult=%.3f dot=%.3f angle=%.2f turn=%.2f left_m=%.2f front_m=%.2f"
			% [
				tag,
				float(row.t),
				str(row.edge),
				float(row.mult),
				float(row.dot),
				float(row.angle_deg),
				float(row.turn_deg),
				float(row.left_m),
				float(row.front_m),
			]
		)


func _run() -> void:
	print("WO028_S34_DIAG_START seed=%d sigma=%.3f" % [SEED, SIGMA])
	var off: Dictionary = _run_s34(false)
	_summarize("QOD_OFF", off)
	var on: Dictionary = _run_s34(true)
	_summarize("QOD_ON", on)
	# Verdict heuristics for the report.
	var on_rows: Array = on.rows
	var max_turn := 0.0
	var max_dot := -2.0
	var min_mult := 99.0
	for row in on_rows:
		max_turn = maxf(max_turn, absf(float(row.turn_deg)))
		max_dot = maxf(max_dot, float(row.dot))
		min_mult = minf(min_mult, float(row.mult))
	var verdict := "c"
	if max_dot >= 0.5 or max_turn >= 25.0:
		verdict = "a"  # real un-pin / reface
	elif bool(on.a_did_not_reface) and min_mult > 1.0:
		verdict = "b"  # classification drift; still flanked for morale
	elif bool(on.a_did_not_reface) and min_mult <= 1.0:
		verdict = "b_or_c"  # need human read of rows — corner may drop mult to 1
	print(
		"S34_DIAG_VERDICT verdict=%s max_turn=%.2f max_dot=%.3f min_mult=%.3f scenario_flank_persist=%s no_reface=%s"
		% [
			verdict,
			max_turn,
			max_dot,
			min_mult,
			str(on.flank_persisted),
			str(on.a_did_not_reface),
		]
	)
	_consts().reload_from_file()
	print("WO028_S34_DIAG_DONE")
	quit(0)
