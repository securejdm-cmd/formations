extends SceneTree
## WO-029b Task 0 — S8 sublinear DIRECTION + variance diagnosis (n=500, QoD on σ=0.045).
## Args: START=N COUNT=N WORKER=id

const SIGMA := 0.045
const SEED_START_DEFAULT := 1000
const SEED_COUNT_DEFAULT := 500
const OUT_DIR := "res://docs/reports/evidence_wo029b"


func _initialize() -> void:
	call_deferred("_run")


func _consts():
	return root.get_node("/root/Constants")


func _arg_map() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		var s := str(a)
		if s.contains("="):
			var parts := s.split("=", false, 1)
			out[parts[0]] = parts[1]
		else:
			out[s] = "1"
	return out


func _run_s8(seed_value: int, attackers: int) -> Dictionary:
	_consts().set_constant("quality_of_day_enabled", true)
	_consts().set_constant("quality_of_day_sigma", SIGMA)
	var packed: PackedScene = load("res://tests/scenario_08.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.auto_run = false
	sc.suppress_io = true
	sc.attacker_count = attackers
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
	var qods: Array = []
	var first_contact := -1
	for u in sc._units:
		qods.append("%.6f" % float(u.quality_of_day))
	if sc._sim_core != null:
		first_contact = int(sc._sim_core.first_contact_tick)
	var combat: float = float(sc.get_phase_durations_sec().get("combat_sec", -1.0))
	var out := {
		"dmg": dmg,
		"combat": combat,
		"ticks": ticks,
		"first_contact": first_contact,
		"qods": "|".join(qods),
		"winner": str(sc.get_winner_id()),
	}
	sc.free()
	return out


func _run() -> void:
	var args := _arg_map()
	var start := SEED_START_DEFAULT
	var count := SEED_COUNT_DEFAULT
	if args.has("START"):
		start = int(args["START"])
	if args.has("COUNT"):
		count = int(args["COUNT"])
	var worker := str(args.get("WORKER", "all"))
	print("WO029B_S8_SWEEP start=%d count=%d sigma=%.3f worker=%s" % [start, count, SIGMA, worker])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var csv_path := OUT_DIR + "/s8_sweep_%s.csv" % worker
	var f := FileAccess.open(csv_path, FileAccess.WRITE)
	f.store_line(
		"seed,single_dmg,triple_dmg,ratio,single_combat,triple_combat,single_contact,triple_contact,single_qod,triple_qod,ge3"
	)
	var ratios: Array = []
	var ge3 := 0
	var t0 := Time.get_ticks_msec()
	for i in count:
		var seed_value := start + i
		var s1 := _run_s8(seed_value, 1)
		var s3 := _run_s8(seed_value, 3)
		var ratio: float = float(s3.dmg) / float(s1.dmg) if float(s1.dmg) > 0.0 else 0.0
		ratios.append(ratio)
		var hit_ge3: bool = ratio >= 3.0 - 1e-9
		if hit_ge3:
			ge3 += 1
		f.store_line(
			"%d,%.6f,%.6f,%.6f,%.3f,%.3f,%d,%d,%s,%s,%s"
			% [
				seed_value,
				float(s1.dmg),
				float(s3.dmg),
				ratio,
				float(s1.combat),
				float(s3.combat),
				int(s1.first_contact),
				int(s3.first_contact),
				str(s1.qods),
				str(s3.qods),
				str(hit_ge3),
			]
		)
		if (i + 1) % 25 == 0 or i == 0:
			print(
				"S8_PROG worker=%s i=%d/%d seed=%d ratio=%.4f ge3_so_far=%d"
				% [worker, i + 1, count, seed_value, ratio, ge3]
			)
	f.close()
	var sorted: Array = ratios.duplicate()
	sorted.sort()
	var n := sorted.size()
	var sum := 0.0
	for r in sorted:
		sum += float(r)
	var mean := sum / float(maxi(n, 1))
	var var_acc := 0.0
	for r in sorted:
		var d := float(r) - mean
		var_acc += d * d
	var sd := sqrt(var_acc / float(maxi(n - 1, 1)))
	var cv := (sd / mean) if mean > 0.0 else 0.0
	print(
		"WO029B_S8_STATS worker=%s n=%d mean=%.6f sd=%.6f cv=%.4f min=%.6f max=%.6f ge3=%d ms=%d"
		% [
			worker,
			n,
			mean,
			sd,
			cv,
			float(sorted[0]) if n > 0 else 0.0,
			float(sorted[n - 1]) if n > 0 else 0.0,
			ge3,
			Time.get_ticks_msec() - t0,
		]
	)
	_consts().reload_from_file()
	print("WO029B_S8_SWEEP_DONE worker=%s csv=%s" % [worker, csv_path])
	quit(1 if ge3 > 0 else 0)
