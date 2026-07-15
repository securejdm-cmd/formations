extends SceneTree
## WO-024 Task 3 — Push sensitivity curve (DATA ONLY; no constant commits).
## Identical infantry profiles except attacker pushing_power.
## Flat ground, gait 1.0 both sides (NO charge). Ephemeral overrides only.

const SEEDS := [1000, 1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009, 12345]
const DEF_PUSH := 50.0
const ATK_PUSHES := [50.0, 51.0, 52.5, 55.0, 60.0, 75.0]
const OUT_CSV := "res://docs/reports/evidence_wo024/sensitivity_curve.csv"
const OUT_MD := "res://docs/reports/evidence_wo024/sensitivity_curve.md"


func _initialize() -> void:
	call_deferred("_run")


func _consts():
	return Engine.get_main_loop().root.get_node("/root/Constants")


func _run_duel(atk_push: float, def_push: float, seed_value: int, wobble: float) -> Dictionary:
	var saved_wobble: float = float(_consts().get_float("wobble_pct"))
	_consts().set_constant("wobble_pct", wobble)
	var packed: PackedScene = load("res://tests/scenario_01.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.auto_run = false
	sc.set_battle_seed(seed_value)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(1000)
		spins += 1
	for u in sc._units.duplicate():
		sc.remove_child(u)
		u.free()
	sc._units.clear()
	var base_p: Dictionary = UnitProfileLoader.load_profile("test_infantry")
	var atk_p: Dictionary = base_p.duplicate(true)
	var def_p: Dictionary = base_p.duplicate(true)
	atk_p["pushing_power"] = atk_push
	def_p["pushing_power"] = def_push
	# Gait 1.0 both sides; no charge doctrine extras.
	atk_p["charge_gait_mult"] = 1.0
	def_p["charge_gait_mult"] = 1.0
	var px := float(_consts().get_float("px_per_meter"))
	var half := float(_consts().get_float("scenario_01_start_distance_m")) * 0.5 * px
	var atk: Unit = load("res://scenes/unit.tscn").instantiate()
	sc.add_child(atk)
	atk.configure("attacker", "red", atk_p, Vector2(-half, 0.0), Vector2.RIGHT)
	var deff: Unit = load("res://scenes/unit.tscn").instantiate()
	sc.add_child(deff)
	deff.configure("defender", "blue", def_p, Vector2(half, 0.0), Vector2.LEFT)
	atk.set_march_to(Vector2(half + 20.0 * px, 0.0))
	if atk.has_method("start_from_rest"):
		atk.start_from_rest()
	deff.current_order = Unit.Order.HOLD
	deff._set_state(Unit.State.HOLD)
	deff.current_speed_m_s = 0.0
	sc._units.append(atk)
	sc._units.append(deff)
	for unit in sc._units:
		unit.set_render_camera(sc._camera)
	sc._ensure_sim_core()
	sc._sim_core.capture_from_units(sc._units)
	sc._sim_core.write_trace_header()
	sc._sim_core.log_trace_row()
	sc._sync_state_from_core()
	var ticks := 0
	while not sc.is_battle_over() and ticks < 12000:
		sc.advance_one_tick()
		ticks += 1
	var phases: Dictionary = sc.get_phase_durations_sec()
	var winner: String = sc.get_winner_id()
	var loser_str := -1.0
	for u in sc._units:
		if u.get_state() == Unit.State.ROUTING or u.get_state() == Unit.State.REMOVED:
			loser_str = u.strength
			break
	var out := {
		"atk_push": atk_push,
		"def_push": def_push,
		"edge_pct": ((atk_push - def_push) / def_push) * 100.0,
		"wobble": wobble,
		"seed": seed_value,
		"winner": winner,
		"atk_won": winner == "attacker",
		"combat_sec": float(phases.get("combat_sec", -1.0)),
		"strength_at_rout": loser_str,
		"ticks": ticks,
		"over": sc.is_battle_over(),
	}
	sc.free()
	_consts().set_constant("wobble_pct", saved_wobble)
	return out


func _agg(rows: Array) -> Dictionary:
	var wins := 0
	var combat_sum := 0.0
	var combat_n := 0
	var rout_sum := 0.0
	var rout_n := 0
	for r in rows:
		if bool(r.atk_won):
			wins += 1
		if float(r.combat_sec) >= 0.0:
			combat_sum += float(r.combat_sec)
			combat_n += 1
		if float(r.strength_at_rout) >= 0.0:
			rout_sum += float(r.strength_at_rout)
			rout_n += 1
	return {
		"n": rows.size(),
		"wins": wins,
		"win_rate": 100.0 * float(wins) / float(rows.size()),
		"mean_combat": combat_sum / float(combat_n) if combat_n > 0 else -1.0,
		"mean_str_at_rout": rout_sum / float(rout_n) if rout_n > 0 else -1.0,
	}


func _run() -> void:
	var abs_dir := ProjectSettings.globalize_path("res://docs/reports/evidence_wo024")
	DirAccess.make_dir_recursive_absolute(abs_dir)
	print("WO024_SENS_START seeds=%d" % SEEDS.size())
	var default_wobble: float = float(_consts().get_float("wobble_pct"))
	print("WO024_SENS default_wobble_pct=%.3f" % default_wobble)

	var csv := FileAccess.open(OUT_CSV, FileAccess.WRITE)
	csv.store_line(
		"row,atk_push,def_push,edge_pct,wobble_pct,n,atk_win_rate_pct,mean_combat_sec,mean_strength_at_rout"
	)
	var md := "# WO-024 Push Sensitivity Curve\n\n"
	md += "DATA ONLY — no tuning. Flat ground; gait 1.0; defender push=50; NO charge.\n\n"
	md += "| Edge | Atk push | Wobble | Atk win% | Mean combat_s | Mean STR@rout |\n"
	md += "|---:|---:|---:|---:|---:|---:|\n"

	var curve_rows: Array = []
	for push in ATK_PUSHES:
		var rows: Array = []
		for seed_value in SEEDS:
			var row: Dictionary = _run_duel(push, DEF_PUSH, seed_value, default_wobble)
			rows.append(row)
			print(
				"WO024_SENS_ROW push=%.1f edge=%.1f%% wobble=%.0f%% seed=%d winner=%s combat=%.1f str_rout=%.2f"
				% [
					push,
					float(row.edge_pct),
					default_wobble * 100.0,
					seed_value,
					str(row.winner),
					float(row.combat_sec),
					float(row.strength_at_rout),
				]
			)
		var a: Dictionary = _agg(rows)
		curve_rows.append({"push": push, "wobble": default_wobble, "agg": a})
		csv.store_line(
			"curve,%.1f,%.1f,%.1f,%.3f,%d,%.1f,%.2f,%.2f"
			% [
				push,
				DEF_PUSH,
				((push - DEF_PUSH) / DEF_PUSH) * 100.0,
				default_wobble,
				int(a.n),
				float(a.win_rate),
				float(a.mean_combat),
				float(a.mean_str_at_rout),
			]
		)
		md += "| %.0f%% | %.1f | ±%.0f%% | %.1f | %.1f | %.2f |\n" % [
			((push - DEF_PUSH) / DEF_PUSH) * 100.0,
			push,
			default_wobble * 100.0,
			float(a.win_rate),
			float(a.mean_combat),
			float(a.mean_str_at_rout),
		]
		print(
			"WO024_SENS_AGG push=%.1f win%%=%.1f combat=%.1f str_rout=%.2f"
			% [push, float(a.win_rate), float(a.mean_combat), float(a.mean_str_at_rout)]
		)

	md += "\n## Wobble raised to ±15% (ephemeral; 0%% and 5%% edges only)\n\n"
	md += "| Edge | Atk push | Wobble | Atk win% | Mean combat_s | Mean STR@rout | Δ win% vs default |\n"
	md += "|---:|---:|---:|---:|---:|---:|---:|\n"

	for push in [50.0, 52.5]:
		var rows2: Array = []
		for seed_value in SEEDS:
			var row2: Dictionary = _run_duel(push, DEF_PUSH, seed_value, 0.15)
			rows2.append(row2)
			print(
				"WO024_SENS_W15 push=%.1f seed=%d winner=%s combat=%.1f"
				% [push, seed_value, str(row2.winner), float(row2.combat_sec)]
			)
		var a2: Dictionary = _agg(rows2)
		var base_wr := -1.0
		for cr in curve_rows:
			if absf(float(cr.push) - push) < 0.01:
				base_wr = float(cr.agg.win_rate)
				break
		var delta := float(a2.win_rate) - base_wr
		csv.store_line(
			"wobble15,%.1f,%.1f,%.1f,0.150,%d,%.1f,%.2f,%.2f"
			% [
				push,
				DEF_PUSH,
				((push - DEF_PUSH) / DEF_PUSH) * 100.0,
				int(a2.n),
				float(a2.win_rate),
				float(a2.mean_combat),
				float(a2.mean_str_at_rout),
			]
		)
		md += "| %.0f%% | %.1f | ±15%% | %.1f | %.1f | %.2f | %+.1f |\n" % [
			((push - DEF_PUSH) / DEF_PUSH) * 100.0,
			push,
			float(a2.win_rate),
			float(a2.mean_combat),
			float(a2.mean_str_at_rout),
			delta,
		]
		print(
			"WO024_SENS_W15_AGG push=%.1f win%%=%.1f delta_vs_default=%+.1f"
			% [push, float(a2.win_rate), delta]
		)

	csv.close()
	_consts().reload_from_file()
	var md_file := FileAccess.open(OUT_MD, FileAccess.WRITE)
	md_file.store_string(md)
	md_file.close()
	print("WO024_SENS_CSV %s" % OUT_CSV)
	print("WO024_SENS_MD %s" % OUT_MD)
	print("WO024_SENS_DONE")
	quit(0)
