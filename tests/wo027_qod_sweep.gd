extends SceneTree
## WO-027 — quality_of_day measurable sweep (n=500, SE, monotonicity).
## Args (cmdline user):
##   ALL                  — full focused sigma set (default)
##   SIGMA=<float>        — one sigma only (for parallel workers)
##   BASELINE             — enabled=false 0% edge only
##   SLOT0                — enabled=false 0% edge (alias of BASELINE for Task 3)

const DEF_PUSH := 50.0
const ATK_PUSHES := [50.0, 51.0, 51.5, 52.5, 55.0, 60.0, 75.0]
const EDGE_LABELS := ["0%", "2%", "3%", "5%", "10%", "20%", "50%"]
const RULE_EDGES := ["0%", "3%", "5%", "10%", "20%", "50%"]
const SEED_START := 1000
const SEED_COUNT := 500
const SIGMAS := [0.03, 0.04, 0.045, 0.05, 0.055, 0.06, 0.07, 0.08, 0.09]
const OUT_DIR := "res://docs/reports/evidence_wo027"


func _initialize() -> void:
	call_deferred("_run")


func _consts():
	return Engine.get_main_loop().root.get_node("/root/Constants")


func _seeds() -> Array:
	var out: Array = []
	for i in SEED_COUNT:
		out.append(SEED_START + i)
	return out


func _se_pct(win_rate_pct: float, n: int) -> float:
	## SE of a proportion as percentage points: sqrt(p(1-p)/n)*100
	var p := clampf(win_rate_pct / 100.0, 0.0, 1.0)
	if n <= 0:
		return 0.0
	return 100.0 * sqrt(p * (1.0 - p) / float(n))


func _run_duel(atk_push: float, def_push: float, seed_value: int, sigma: float, enabled: bool) -> Dictionary:
	_consts().set_constant("quality_of_day_enabled", enabled)
	_consts().set_constant("quality_of_day_sigma", sigma)
	var packed: PackedScene = load("res://tests/scenario_01.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.auto_run = false
	sc.suppress_io = true
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
	# Keep in-memory traces off the disk path; skip header spam for speed.
	sc._sync_state_from_core()
	var ticks := 0
	while not sc.is_battle_over() and ticks < 12000:
		sc.advance_one_tick()
		ticks += 1
	var winner: String = sc.get_winner_id()
	var out := {
		"winner": winner,
		"atk_won": winner == "attacker",
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
			return true


func _monotonic_ok(edge_wrs: Dictionary, edge_ses: Dictionary) -> bool:
	## Non-decreasing across RULE_EDGES within 2-SE tolerance.
	for i in range(RULE_EDGES.size() - 1):
		var a: String = str(RULE_EDGES[i])
		var b: String = str(RULE_EDGES[i + 1])
		var wa: float = float(edge_wrs[a])
		var wb: float = float(edge_wrs[b])
		var sea: float = float(edge_ses[a])
		var seb: float = float(edge_ses[b])
		# Allow apparent dips only if 2σ intervals overlap in the right order.
		if wb + 2.0 * seb + 0.001 < wa - 2.0 * sea:
			return false
	return true


func _parse_args() -> Dictionary:
	var args := OS.get_cmdline_user_args()
	var mode := "ALL"
	var sigma_filter := -1.0
	if args.size() > 0:
		var a0 := str(args[0]).to_upper()
		if a0.begins_with("SIGMA="):
			mode = "SIGMA"
			sigma_filter = float(str(args[0]).substr(6))
		elif a0 == "BASELINE" or a0 == "SLOT0":
			mode = "BASELINE"
		elif a0 == "ALL":
			mode = "ALL"
		else:
			mode = a0
	return {"mode": mode, "sigma": sigma_filter}


func _run_baseline(seeds: Array, csv: FileAccess, md: String) -> String:
	var t0 := Time.get_ticks_msec()
	var rows: Array = []
	for seed_value in seeds:
		rows.append(_run_duel(50.0, DEF_PUSH, int(seed_value), 0.05, false))
	var wr: float = _win_rate(rows)
	var se: float = _se_pct(wr, rows.size())
	var elapsed := Time.get_ticks_msec() - t0
	csv.store_line(
		"0.00,false,0%%,50.0,%d,%.2f,%.2f,n/a,n/a"
		% [rows.size(), wr, se]
	)
	md += "## enabled=false baseline (0%% edge, Task 3)\n\n"
	md += "Win%% = **%.2f ± %.2f SE** (n=%d). Fair band: 50±5 → %s.\n\n" % [
		wr,
		se,
		rows.size(),
		"PASS" if absf(wr - 50.0) <= 5.0 else "FAIL — slot bias",
	]
	print(
		"WO027_BASELINE enabled=false 0%% win%%=%.2f se=%.2f n=%d elapsed_ms=%d fair50pm5=%s"
		% [wr, se, rows.size(), elapsed, str(absf(wr - 50.0) <= 5.0)]
	)
	return md


func _run_sigma(sigma: float, seeds: Array, csv: FileAccess) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var edge_wrs: Dictionary = {}
	var edge_ses: Dictionary = {}
	var rule_ok := true
	var lines: Array = []
	for i in ATK_PUSHES.size():
		var push: float = float(ATK_PUSHES[i])
		var label: String = str(EDGE_LABELS[i])
		var rows: Array = []
		for seed_value in seeds:
			rows.append(_run_duel(push, DEF_PUSH, int(seed_value), sigma, true))
		var wr: float = _win_rate(rows)
		var se: float = _se_pct(wr, rows.size())
		var ok: bool = _meets_rule(label, wr)
		edge_wrs[label] = wr
		edge_ses[label] = se
		if label in RULE_EDGES:
			rule_ok = rule_ok and ok
		csv.store_line(
			"%.3f,true,%s,%.1f,%d,%.2f,%.2f,%s,"
			% [sigma, label, push, rows.size(), wr, se, str(ok)]
		)
		lines.append(
			"| %s | %.1f | %.2f | %.2f | %s |"
			% [label, push, wr, se, "PASS" if ok else "FAIL"]
		)
		print(
			"SWEEP sigma=%.3f edge=%s win%%=%.2f se=%.2f rule=%s"
			% [sigma, label, wr, se, "PASS" if ok else "FAIL"]
		)
	var mono := _monotonic_ok(edge_wrs, edge_ses)
	var elapsed := Time.get_ticks_msec() - t0
	print(
		"SWEEP_SIGMA_DONE sigma=%.3f rule_set=%s mono=%s elapsed_ms=%d"
		% [sigma, "PASS" if rule_ok else "FAIL", "PASS" if mono else "FAIL", elapsed]
	)
	return {
		"sigma": sigma,
		"rule_ok": rule_ok,
		"mono_ok": mono,
		"edge_wrs": edge_wrs,
		"edge_ses": edge_ses,
		"lines": lines,
		"elapsed_ms": elapsed,
	}


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var parsed: Dictionary = _parse_args()
	var mode: String = str(parsed.mode)
	var seeds: Array = _seeds()
	var tag := mode
	if mode == "SIGMA":
		tag = "sigma_%.3f" % float(parsed.sigma)
	var csv_path := "%s/qod_sweep_%s.csv" % [OUT_DIR, tag.to_lower().replace(".", "p")]
	var md_path := "%s/qod_sweep_%s.md" % [OUT_DIR, tag.to_lower().replace(".", "p")]
	print(
		"WO027_SWEEP_START mode=%s seeds=%d..%d n=%d"
		% [mode, SEED_START, SEED_START + SEED_COUNT - 1, seeds.size()]
	)
	var csv := FileAccess.open(csv_path, FileAccess.WRITE)
	csv.store_line("sigma,enabled,edge,atk_push,n,atk_win_rate_pct,se_pct,rule_ok,mono_ok")
	var md := "# WO-027 quality_of_day measurable sweep\n\n"
	md += "Seeds: **%d–%d** (n=%d). Flat; gait 1.0; defender push=50; march-vs-hold.\n\n" % [
		SEED_START, SEED_START + SEED_COUNT - 1, SEED_COUNT
	]
	md += "SE = 100×√(p(1−p)/n) percentage points.\n\n"
	md += "Mode: `%s`\n\n" % mode

	if mode == "BASELINE":
		md = _run_baseline(seeds, csv, md)
	else:
		var sigmas: Array = SIGMAS.duplicate()
		if mode == "SIGMA":
			sigmas = [float(parsed.sigma)]
		var chosen := -1.0
		for sigma in sigmas:
			var res: Dictionary = _run_sigma(float(sigma), seeds, csv)
			md += "## sigma = %.3f\n\n" % float(sigma)
			md += "| Edge | Atk push | Win% | SE | Rule |\n|---:|---:|---:|---:|:---|\n"
			for line in res.lines:
				md += str(line) + "\n"
			md += "\n**Rule set (6 edges): %s** · **Monotonicity: %s**\n\n" % [
				"PASS" if bool(res.rule_ok) else "FAIL",
				"PASS" if bool(res.mono_ok) else "FAIL",
			]
			# Patch last csv rows for this sigma with mono — rewrite via summary line
			csv.store_line(
				"%.3f,true,SUMMARY,0.0,%d,0.0,0.0,%s,%s"
				% [
					float(sigma),
					SEED_COUNT,
					str(bool(res.rule_ok)),
					str(bool(res.mono_ok)),
				]
			)
			if bool(res.rule_ok) and bool(res.mono_ok) and chosen < 0.0:
				chosen = float(sigma)
		if mode == "ALL" or mode == "SIGMA":
			if chosen >= 0.0:
				md += "## SELECTED sigma = %.3f\n\nMeets all six R21 bands + monotonicity.\n" % chosen
				print("SWEEP_SELECTED sigma=%.3f" % chosen)
			else:
				md += "## NO SIGMA SATISFIES ALL SIX + MONOTONICITY — ESCALATE\n"
				print("SWEEP_SELECTED none — ESCALATE")

	csv.close()
	_consts().reload_from_file()
	var md_file := FileAccess.open(md_path, FileAccess.WRITE)
	md_file.store_string(md)
	md_file.close()
	print("WO027_SWEEP_CSV %s" % csv_path)
	print("WO027_SWEEP_MD %s" % md_path)
	print("WO027_SWEEP_DONE")
	quit(0)
