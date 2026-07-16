extends SceneTree
## WO-025 Task 2 — quality_of_day sigma sweep (33 seeds 1000–1032).
## Selection rule (R21 / WO-025):
##   0%→50±10; 3%→55–68; 5%→62–75; 10%→78–90; 20%→90–98; 50%→≥98

const DEF_PUSH := 50.0
const ATK_PUSHES := [50.0, 51.0, 51.5, 52.5, 55.0, 60.0, 75.0]
const EDGE_LABELS := ["0%", "2%", "3%", "5%", "10%", "20%", "50%"]
const SEED_START := 1000
const SEED_COUNT := 33
const SIGMAS := [0.02, 0.03, 0.04, 0.05, 0.06, 0.08, 0.10, 0.12, 0.15]
const OUT_CSV := "res://docs/reports/evidence_wo025/qod_sweep.csv"
const OUT_MD := "res://docs/reports/evidence_wo025/qod_sweep.md"


func _initialize() -> void:
	call_deferred("_run")


func _consts():
	return Engine.get_main_loop().root.get_node("/root/Constants")


func _seeds() -> Array:
	var out: Array = []
	for i in SEED_COUNT:
		out.append(SEED_START + i)
	return out


func _run_duel(atk_push: float, def_push: float, seed_value: int, sigma: float, enabled: bool) -> Dictionary:
	_consts().set_constant("quality_of_day_enabled", enabled)
	_consts().set_constant("quality_of_day_sigma", sigma)
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
	# Task 3 finding may change posture — keep WO-024 protocol (march vs hold)
	# unless anomaly fix requires symmetric posture.
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
	var winner: String = sc.get_winner_id()
	var q_atk := 1.0
	var q_def := 1.0
	for u in sc._units:
		if u.unit_id == "attacker":
			q_atk = float(u.quality_of_day)
		elif u.unit_id == "defender":
			q_def = float(u.quality_of_day)
	var out := {
		"atk_push": atk_push,
		"winner": winner,
		"atk_won": winner == "attacker",
		"combat": float(sc.get_phase_durations_sec().get("combat_sec", -1.0)),
		"q_atk": q_atk,
		"q_def": q_def,
		"seed": seed_value,
	}
	sc.free()
	return out


func _win_rate(rows: Array) -> float:
	var w := 0
	for r in rows:
		if bool(r.atk_won):
			w += 1
	return 100.0 * float(w) / float(maxi(rows.size(), 1))


func _meets_rule(edge_label: String, wr: float) -> bool:
	match edge_label:
		"0%":
			return wr >= 40.0 and wr <= 60.0
		"3%":
			return wr >= 55.0 and wr <= 68.0
		"5%":
			return wr >= 62.0 and wr <= 75.0
		"10%":
			return wr >= 78.0 and wr <= 90.0
		"20%":
			return wr >= 90.0 and wr <= 98.0
		"50%":
			return wr >= 98.0
		_:
			return true  # 2% informational


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://docs/reports/evidence_wo025")
	)
	var seeds: Array = _seeds()
	print(
		"WO025_SWEEP_START seeds=%d..%d n=%d sigmas=%s"
		% [SEED_START, SEED_START + SEED_COUNT - 1, seeds.size(), str(SIGMAS)]
	)
	var csv := FileAccess.open(OUT_CSV, FileAccess.WRITE)
	csv.store_line("sigma,enabled,edge,atk_push,n,atk_win_rate_pct,rule_ok")
	var md := "# WO-025 quality_of_day sigma sweep\n\n"
	md += "Seeds: **%d–%d** (n=%d). Flat; gait 1.0; defender push=50; march-vs-hold.\n\n" % [
		SEED_START, SEED_START + SEED_COUNT - 1, SEED_COUNT
	]
	md += "Distribution: Gaussian N(1, σ) via Box-Muller on battle RNG stream.\n\n"

	var chosen_sigma := -1.0
	for sigma in SIGMAS:
		md += "## sigma = %.2f\n\n" % sigma
		md += "| Edge | Atk push | Win% | Rule |\n|---:|---:|---:|:---|\n"
		var all_ok := true
		var rule_edges_ok := true
		for i in ATK_PUSHES.size():
			var push: float = float(ATK_PUSHES[i])
			var label: String = str(EDGE_LABELS[i])
			var rows: Array = []
			for seed_value in seeds:
				rows.append(_run_duel(push, DEF_PUSH, int(seed_value), float(sigma), true))
			var wr: float = _win_rate(rows)
			var ok: bool = _meets_rule(label, wr)
			if label in ["0%", "3%", "5%", "10%", "20%", "50%"]:
				rule_edges_ok = rule_edges_ok and ok
			all_ok = all_ok and ok
			csv.store_line(
				"%.2f,true,%s,%.1f,%d,%.1f,%s"
				% [sigma, label, push, rows.size(), wr, str(ok)]
			)
			md += "| %s | %.1f | %.1f | %s |\n" % [label, push, wr, "PASS" if ok else "FAIL"]
			print(
				"SWEEP sigma=%.2f edge=%s win%%=%.1f rule=%s"
				% [sigma, label, wr, "PASS" if ok else "FAIL"]
			)
		md += "\n**Rule set (6 edges): %s**\n\n" % ("PASS" if rule_edges_ok else "FAIL")
		print("SWEEP_SIGMA_DONE sigma=%.2f rule_set=%s" % [sigma, "PASS" if rule_edges_ok else "FAIL"])
		if rule_edges_ok and chosen_sigma < 0.0:
			chosen_sigma = float(sigma)

	# Also baseline enabled=false at 0% for comparison
	var rows0: Array = []
	for seed_value in seeds:
		rows0.append(_run_duel(50.0, DEF_PUSH, int(seed_value), 0.05, false))
	var wr0: float = _win_rate(rows0)
	csv.store_line("0.00,false,0%,50.0,%d,%.1f,n/a" % [rows0.size(), wr0])
	md += "## enabled=false baseline (0%% edge)\n\nWin%% = **%.1f** (expect ~63.6 marcher bias)\n\n" % wr0
	print("SWEEP_BASELINE enabled=false 0%% win%%=%.1f" % wr0)

	if chosen_sigma >= 0.0:
		md += "## SELECTED sigma = %.2f\n\nMeets all six R21 bands.\n" % chosen_sigma
		print("SWEEP_SELECTED sigma=%.2f" % chosen_sigma)
	else:
		md += "## NO SIGMA SATISFIES ALL SIX — ESCALATE\n"
		print("SWEEP_SELECTED none — ESCALATE")

	csv.close()
	_consts().reload_from_file()
	var md_file := FileAccess.open(OUT_MD, FileAccess.WRITE)
	md_file.store_string(md)
	md_file.close()
	print("WO025_SWEEP_CSV %s" % OUT_CSV)
	print("WO025_SWEEP_MD %s" % OUT_MD)
	print("WO025_SWEEP_DONE")
	quit(0)
