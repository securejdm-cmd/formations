extends SceneTree
## Diagnose cert / determinism under QoD-on default.


func _initialize() -> void:
	call_deferred("_run")


func _consts():
	return root.get_node("/root/Constants")


func _run_once(tag: String, fast: bool, threaded: bool = false) -> String:
	var packed: PackedScene = load("res://tests/scenario_01.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = fast
	sc.auto_run = false
	sc.suppress_io = true
	sc.force_trace_logging = true
	sc.set_battle_seed(12345)
	if threaded and "use_sim_thread" in sc:
		sc.use_sim_thread = true
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(1000)
		spins += 1
	var ticks := 0
	while not sc.is_battle_over() and ticks < 30000:
		sc.advance_one_tick()
		ticks += 1
	var trace: String = sc.get_trace_text()
	var winner: String = str(sc.get_winner_id())
	var combat: float = float(sc.get_phase_durations_sec().get("combat_sec", -1.0))
	var qods: Array = []
	for u in sc._units:
		qods.append("%s=%.6f" % [u.unit_id, float(u.quality_of_day)])
	print("CERT_DIAG %s winner=%s combat=%.1f ticks=%d qod=[%s] trace_len=%d" % [
		tag, winner, combat, ticks, ", ".join(qods), trace.length(),
	])
	# Extract QUALITY_OF_DAY events
	for line in trace.split("\n"):
		if "QUALITY_OF_DAY" in line:
			print("CERT_DIAG %s EVENT %s" % [tag, line])
	sc.free()
	return trace


func _run() -> void:
	print("WO028_CERT_DIAG qod_enabled=%s sigma=%s" % [
		str(_consts().get_constant("quality_of_day_enabled", false)),
		str(_consts().get_constant("quality_of_day_sigma", -1.0)),
	])
	var a := _run_once("A_fast", true)
	var b := _run_once("B_fast", true)
	print("CERT_DIAG A_vs_B_fast identical=%s" % str(a == b))
	if a != b:
		var al := a.split("\n")
		var bl := b.split("\n")
		var n := mini(al.size(), bl.size())
		for i in n:
			if al[i] != bl[i]:
				print("CERT_DIAG FIRST_DIFF line=%d" % i)
				print("CERT_DIAG A %s" % al[i])
				print("CERT_DIAG B %s" % bl[i])
				break
		print("CERT_DIAG lenA=%d lenB=%d" % [al.size(), bl.size()])
	var rt := _run_once("C_realtime_adv", false)
	print("CERT_DIAG fast_vs_realtime_advance identical=%s" % str(a == rt))
	quit(0)
