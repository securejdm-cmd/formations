extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var packed = load("res://tests/scenario_03.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.set_battle_seed(1000)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(2000); spins += 1
	var ticks := 0
	while not sc.is_battle_over() and ticks < 30000:
		sc.advance_one_tick(); ticks += 1
	var phases = sc.get_phase_durations_sec()
	var combat = float(phases.get("combat_sec", -1))
	var s1_ref = 75.8  # WO013 S1 seed 1000
	var rout = float(sc.get_blue_a_strength_at_rout())
	var drains = sc.get_blue_a_edge_drains()
	print("S3_METRICS combat=%.2f ratio=%.3f rout=%.2f left=%.2f front=%.2f right=%.2f rear=%.2f ticks=%d winner=%s" % [
		combat, combat/s1_ref, rout,
		float(drains.get("left",0)), float(drains.get("front",0)),
		float(drains.get("right",0)), float(drains.get("rear",0)),
		ticks, str(sc.get_winner_id())
	])
	# Write baseline candidate
	var path = ProjectSettings.globalize_path("res://tests/traces/scenario_03_1000.csv")
	print("S3_TRACE_PATH %s len=%d" % [path, sc.get_trace_text().length()])
	sc.free()
	quit(0)
