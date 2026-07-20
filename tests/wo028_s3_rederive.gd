extends SceneTree
## WO-028 Task 2 — re-derive S3 magnitude bands under QoD enabled σ=0.045.
## Args (cmdline user):
##   (none)     — seeds 1000..1499
##   START=N    — first seed
##   COUNT=N    — seed count
##   WORKER=ID  — tag for shard output

const S1_REF := 75.8
const SIGMA := 0.045
const SEED_START_DEFAULT := 1000
const SEED_COUNT_DEFAULT := 500
const OUT_DIR := "res://docs/reports/evidence_wo028"


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


func _run_one(seed_value: int) -> Dictionary:
	_consts().set_constant("quality_of_day_enabled", true)
	_consts().set_constant("quality_of_day_sigma", SIGMA)
	var packed: PackedScene = load("res://tests/scenario_03.tscn")
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
	var ticks := 0
	while not sc.is_battle_over() and ticks < 20000:
		sc.advance_one_tick()
		ticks += 1
	var combat: float = float(sc.get_phase_durations_sec().get("combat_sec", -1.0))
	var ratio: float = combat / S1_REF if S1_REF > 0.0 else 0.0
	var rout: float = float(sc.get_blue_a_strength_at_rout())
	var left: float = float(sc.get_blue_a_edge_drains().get("left", 0.0))
	var winner: String = str(sc.get_winner_id())
	var out := {
		"seed": seed_value,
		"combat": combat,
		"ratio": ratio,
		"rout": rout,
		"left": left,
		"winner": winner,
		"flank_wins": winner.begins_with("red"),
	}
	sc.free()
	return out


func _stats(vals: Array) -> Dictionary:
	var n := vals.size()
	if n == 0:
		return {}
	var sorted: Array = vals.duplicate()
	sorted.sort()
	var sum := 0.0
	var mn: float = float(sorted[0])
	var mx: float = float(sorted[n - 1])
	for v in sorted:
		sum += float(v)
	var mean := sum / float(n)
	var var_acc := 0.0
	for v in sorted:
		var d := float(v) - mean
		var_acc += d * d
	var sd := sqrt(var_acc / float(maxi(n - 1, 1)))
	return {
		"n": n,
		"mean": mean,
		"sd": sd,
		"min": mn,
		"max": mx,
		"p01": _percentile(sorted, 0.01),
		"p995": _percentile(sorted, 0.995),
		"p005": _percentile(sorted, 0.005),
		"p99": _percentile(sorted, 0.99),
		"mean_m3sd": mean - 3.0 * sd,
		"mean_p3sd": mean + 3.0 * sd,
	}


func _percentile(sorted_vals: Array, p: float) -> float:
	var n := sorted_vals.size()
	if n == 0:
		return 0.0
	if n == 1:
		return float(sorted_vals[0])
	var idx := clampf(p, 0.0, 1.0) * float(n - 1)
	var lo := int(floor(idx))
	var hi := int(ceil(idx))
	var t := idx - float(lo)
	return lerpf(float(sorted_vals[lo]), float(sorted_vals[hi]), t)


func _run() -> void:
	var args := _arg_map()
	var start := SEED_START_DEFAULT
	var count := SEED_COUNT_DEFAULT
	if args.has("START"):
		start = int(args["START"])
	if args.has("COUNT"):
		count = int(args["COUNT"])
	var worker := str(args.get("WORKER", "all"))
	print("WO028_S3_REDERIVE start=%d count=%d sigma=%.3f worker=%s" % [start, count, SIGMA, worker])
	var rows: Array = []
	var t0 := Time.get_ticks_msec()
	for i in count:
		var seed_value := start + i
		var row := _run_one(seed_value)
		rows.append(row)
		if (i + 1) % 25 == 0 or i == 0:
			print(
				"S3_PROG worker=%s i=%d/%d seed=%d ratio=%.4f rout=%.2f left=%.2f flank=%s"
				% [
					worker,
					i + 1,
					count,
					seed_value,
					float(row.ratio),
					float(row.rout),
					float(row.left),
					str(row.flank_wins),
				]
			)
	var ratios: Array = []
	var routs: Array = []
	var lefts: Array = []
	var flank_wins := 0
	for r in rows:
		ratios.append(float(r.ratio))
		routs.append(float(r.rout))
		lefts.append(float(r.left))
		if bool(r.flank_wins):
			flank_wins += 1
	var rs := _stats(ratios)
	var ro := _stats(routs)
	var ls := _stats(lefts)
	var ms := Time.get_ticks_msec() - t0
	print("WO028_S3_STATS metric=ratio n=%d mean=%.6f sd=%.6f min=%.6f max=%.6f p01=%.6f p99=%.6f p005=%.6f p995=%.6f m3=%.6f p3=%.6f" % [
		rs.n, rs.mean, rs.sd, rs.min, rs.max, rs.p01, rs.p99, rs.p005, rs.p995, rs.mean_m3sd, rs.mean_p3sd,
	])
	print("WO028_S3_STATS metric=rout n=%d mean=%.6f sd=%.6f min=%.6f max=%.6f p01=%.6f p99=%.6f p005=%.6f p995=%.6f m3=%.6f p3=%.6f" % [
		ro.n, ro.mean, ro.sd, ro.min, ro.max, ro.p01, ro.p99, ro.p005, ro.p995, ro.mean_m3sd, ro.mean_p3sd,
	])
	print("WO028_S3_STATS metric=left n=%d mean=%.6f sd=%.6f min=%.6f max=%.6f p01=%.6f p99=%.6f p005=%.6f p995=%.6f m3=%.6f p3=%.6f" % [
		ls.n, ls.mean, ls.sd, ls.min, ls.max, ls.p01, ls.p99, ls.p005, ls.p995, ls.mean_m3sd, ls.mean_p3sd,
	])
	print("WO028_S3_FLANK_WINS %d/%d ms=%d" % [flank_wins, rows.size(), ms])

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var csv_path := OUT_DIR + "/s3_rederive_%s.csv" % worker
	var f := FileAccess.open(csv_path, FileAccess.WRITE)
	if f != null:
		f.store_line("seed,combat,ratio,rout,left,winner,flank_wins")
		for r in rows:
			f.store_line(
				"%d,%.6f,%.6f,%.6f,%.6f,%s,%s"
				% [int(r.seed), float(r.combat), float(r.ratio), float(r.rout), float(r.left), str(r.winner), str(r.flank_wins)]
			)
		f.close()
		print("WO028_S3_CSV %s" % csv_path)
	var summary_path := OUT_DIR + "/s3_rederive_%s_summary.txt" % worker
	var sf := FileAccess.open(summary_path, FileAccess.WRITE)
	if sf != null:
		sf.store_line("ratio mean=%.6f sd=%.6f min=%.6f max=%.6f p01=%.6f p99=%.6f p005=%.6f p995=%.6f m3sd=%.6f p3sd=%.6f" % [
			rs.mean, rs.sd, rs.min, rs.max, rs.p01, rs.p99, rs.p005, rs.p995, rs.mean_m3sd, rs.mean_p3sd,
		])
		sf.store_line("rout mean=%.6f sd=%.6f min=%.6f max=%.6f p01=%.6f p99=%.6f p005=%.6f p995=%.6f m3sd=%.6f p3sd=%.6f" % [
			ro.mean, ro.sd, ro.min, ro.max, ro.p01, ro.p99, ro.p005, ro.p995, ro.mean_m3sd, ro.mean_p3sd,
		])
		sf.store_line("left mean=%.6f sd=%.6f min=%.6f max=%.6f p01=%.6f p99=%.6f p005=%.6f p995=%.6f m3sd=%.6f p3sd=%.6f" % [
			ls.mean, ls.sd, ls.min, ls.max, ls.p01, ls.p99, ls.p005, ls.p995, ls.mean_m3sd, ls.mean_p3sd,
		])
		sf.store_line("flank_wins=%d/%d" % [flank_wins, rows.size()])
		sf.close()
	_consts().reload_from_file()
	print("WO028_S3_REDERIVE_DONE worker=%s" % worker)
	quit(0)
