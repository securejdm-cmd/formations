extends SceneTree
## Reusable Gate 2 / Phase 5 matchup matrix runner (flat ground, 200m approach).
## Every profile × every profile as attacker/defender across standard 11 seeds.
## DO NOT TUNE — deliver as data.

const PROFILES := [
	"test_infantry",
	"test_infantry_charge",
	"test_spears",
	"test_archer",
	"test_cavalry",
	"test_skirmisher",
]

const SEEDS := [1000, 1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009, 12345]
const OUT_CSV := "res://docs/reports/evidence_wo022/matchup_matrix.csv"
const OUT_MD := "res://docs/reports/evidence_wo022/matchup_matrix.md"


func _initialize() -> void:
	call_deferred("_run")


func _run_pair(atk_id: String, def_id: String, seed_value: int) -> Dictionary:
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
	# Replace default S1 units with requested profiles.
	for u in sc._units.duplicate():
		sc.remove_child(u)
		u.free()
	sc._units.clear()
	var atk_p := UnitProfileLoader.load_profile(atk_id)
	var def_p := UnitProfileLoader.load_profile(def_id)
	var px := Constants.get_float("px_per_meter")
	var half := Constants.get_float("scenario_01_start_distance_m") * 0.5 * px
	var atk: Unit = load("res://scenes/unit.tscn").instantiate()
	sc.add_child(atk)
	atk.configure("attacker", "red", atk_p, Vector2(-half, 0.0), Vector2.RIGHT)
	var deff: Unit = load("res://scenes/unit.tscn").instantiate()
	sc.add_child(deff)
	deff.configure("defender", "blue", def_p, Vector2(half, 0.0), Vector2.LEFT)
	var atk_is_ranged: bool = (
		float(atk_p.get("ranged_damage", 0.0)) > 0.0
		and float(atk_p.get("close_damage", 0.0)) < float(atk_p.get("ranged_damage", 0.0))
	)
	if atk_is_ranged:
		# S12 pattern: shooter holds; defender approaches through the fire.
		atk.current_order = Unit.Order.HOLD
		atk._set_state(Unit.State.HOLD)
		deff.set_march_to(Vector2(-half - 20.0 * px, 0.0))
	else:
		atk.set_march_to(Vector2(half + 20.0 * px, 0.0))
		if atk.has_method("start_from_rest"):
			atk.start_from_rest()
		deff.current_order = Unit.Order.HOLD
		deff._set_state(Unit.State.HOLD)
		deff.current_speed_m_s = 0.0
	# Spears facing charge: pre-warm brace (Gate 2 triangle uses braced spears).
	if str(def_p.get("melee_damage_type", "")) == "Pierce":
		deff._brace_hold_sec = Constants.get_float("brace_time_s") + 0.1
		deff._braced = true
		if deff.has_method("_update_brace_visual"):
			deff._update_brace_visual()
	sc._units.append(atk)
	sc._units.append(deff)
	for unit in sc._units:
		unit.set_render_camera(sc._camera)
	# Kick sim
	sc._ensure_sim_core()
	sc._sim_core.capture_from_units(sc._units)
	sc._sim_core.write_trace_header()
	sc._sim_core.log_trace_row()
	sc._sync_state_from_core()
	var ticks := 0
	while not sc.is_battle_over() and ticks < 8000:
		sc.advance_one_tick()
		ticks += 1
	var phases: Dictionary = sc.get_phase_durations_sec()
	var winner: String = sc.get_winner_id()
	var winner_str := -1.0
	var loser_rout := -1.0
	for u in sc._units:
		if u.unit_id == winner:
			winner_str = u.strength
		if u.get_state() == Unit.State.ROUTING or u.get_state() == Unit.State.REMOVED:
			if loser_rout < 0.0:
				loser_rout = u.strength
	var out := {
		"attacker": atk_id,
		"defender": def_id,
		"seed": seed_value,
		"winner": winner,
		"atk_won": winner == "attacker",
		"combat_sec": float(phases.get("combat_sec", -1.0)),
		"winner_str": winner_str,
		"loser_str_at_rout": loser_rout,
		"ticks": ticks,
	}
	sc.free()
	return out


func _aggregate(rows: Array) -> Dictionary:
	## Key "atk|def" → stats
	var cells: Dictionary = {}
	for row in rows:
		var key: String = "%s|%s" % [row.attacker, row.defender]
		if not cells.has(key):
			cells[key] = {
				"attacker": row.attacker,
				"defender": row.defender,
				"wins": 0,
				"n": 0,
				"combat_sum": 0.0,
				"wstr_sum": 0.0,
				"lstr_sum": 0.0,
				"wstr_n": 0,
				"lstr_n": 0,
			}
		var c: Dictionary = cells[key]
		c.n += 1
		if bool(row.atk_won):
			c.wins += 1
		if float(row.combat_sec) >= 0.0:
			c.combat_sum += float(row.combat_sec)
		if float(row.winner_str) >= 0.0:
			c.wstr_sum += float(row.winner_str)
			c.wstr_n += 1
		if float(row.loser_str_at_rout) >= 0.0:
			c.lstr_sum += float(row.loser_str_at_rout)
			c.lstr_n += 1
		cells[key] = c
	return cells


func _write_outputs(cells: Dictionary) -> void:
	var csv := FileAccess.open(OUT_CSV, FileAccess.WRITE)
	csv.store_line("attacker,defender,win_rate_pct,n,mean_combat_sec,mean_winner_str,mean_loser_str_at_rout")
	var md := "# Matchup matrix (WO-022)\n\n"
	md += "Flat ground, 200m approach, 11 seeds. Attacker marches (archers hold-and-shoot); defender holds"
	md += " (Pierce defenders pre-braced).\n\n"
	md += "| Attacker \\ Defender |"
	for d in PROFILES:
		md += " %s |" % d.replace("test_", "")
	md += "\n|"
	for _i in PROFILES.size() + 1:
		md += "---|"
	md += "\n"
	for a in PROFILES:
		md += "| **%s** |" % a.replace("test_", "")
		for d in PROFILES:
			var key := "%s|%s" % [a, d]
			var c: Dictionary = cells[key]
			var wr: float = 100.0 * float(c.wins) / float(c.n)
			var mc: float = c.combat_sum / float(c.n)
			var mw: float = c.wstr_sum / float(c.wstr_n) if int(c.wstr_n) > 0 else -1.0
			var ml: float = c.lstr_sum / float(c.lstr_n) if int(c.lstr_n) > 0 else -1.0
			csv.store_line(
				"%s,%s,%.1f,%d,%.2f,%.2f,%.2f" % [a, d, wr, c.n, mc, mw, ml]
			)
			md += " %.0f%% |" % wr
		md += "\n"
	md += "\n### Cell detail (mean combat / winner STR / loser STR@rout)\n\n"
	md += "| Attacker | Defender | Win% | Combat_s | WinSTR | LoseSTR |\n|---|---|---:|---:|---:|---:|\n"
	for a in PROFILES:
		for d in PROFILES:
			var key2 := "%s|%s" % [a, d]
			var c2: Dictionary = cells[key2]
			var wr2: float = 100.0 * float(c2.wins) / float(c2.n)
			var mc2: float = c2.combat_sum / float(c2.n)
			var mw2: float = c2.wstr_sum / float(c2.wstr_n) if int(c2.wstr_n) > 0 else -1.0
			var ml2: float = c2.lstr_sum / float(c2.lstr_n) if int(c2.lstr_n) > 0 else -1.0
			md += "| %s | %s | %.1f | %.1f | %.1f | %.1f |\n" % [
				a.replace("test_", ""),
				d.replace("test_", ""),
				wr2,
				mc2,
				mw2,
				ml2,
			]
	csv.close()
	var md_file := FileAccess.open(OUT_MD, FileAccess.WRITE)
	md_file.store_string(md)
	md_file.close()
	print("MATRIX_CSV %s" % OUT_CSV)
	print("MATRIX_MD %s" % OUT_MD)


func _fingerprint(cells: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for a in PROFILES:
		for d in PROFILES:
			var c: Dictionary = cells["%s|%s" % [a, d]]
			parts.append("%s:%d/%d" % ["%s|%s" % [a, d], c.wins, c.n])
	return ",".join(parts)


func _run() -> void:
	var abs_dir := ProjectSettings.globalize_path("res://docs/reports/evidence_wo022")
	DirAccess.make_dir_recursive_absolute(abs_dir)
	print("MATRIX_START profiles=%d seeds=%d pairs=%d" % [PROFILES.size(), SEEDS.size(), PROFILES.size() * PROFILES.size()])
	var rows: Array = []
	for a in PROFILES:
		for d in PROFILES:
			for seed_value in SEEDS:
				var row: Dictionary = _run_pair(a, d, seed_value)
				rows.append(row)
				print(
					"MATRIX_ROW %s>%s seed=%d winner=%s combat=%.1f"
					% [a, d, seed_value, row.winner, row.combat_sec]
				)
	var cells: Dictionary = _aggregate(rows)
	_write_outputs(cells)
	# Determinism: re-run one seed slice and compare fingerprint of that slice via full re-aggregate of seed 1000 only.
	var rows2: Array = []
	for a in PROFILES:
		for d in PROFILES:
			rows2.append(_run_pair(a, d, 1000))
	var ok := true
	for i in rows2.size():
		# Find matching seed-1000 row in first pass
		var r2: Dictionary = rows2[i]
		var found := false
		for r1 in rows:
			if int(r1.seed) != 1000:
				continue
			if r1.attacker == r2.attacker and r1.defender == r2.defender:
				found = true
				if str(r1.winner) != str(r2.winner) or absf(float(r1.combat_sec) - float(r2.combat_sec)) > 0.05:
					push_error(
						"MATRIX determinism fail %s>%s w1=%s/%.1f w2=%s/%.1f"
						% [r1.attacker, r1.defender, r1.winner, r1.combat_sec, r2.winner, r2.combat_sec]
					)
					ok = false
				break
		if not found:
			ok = false
	print("MATRIX_DETERMINISM %s" % ("PASS" if ok else "FAIL"))
	print("MATRIX_DONE rows=%d" % rows.size())
	quit(0 if ok else 2)
