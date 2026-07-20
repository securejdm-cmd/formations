extends SceneTree
## Quick WO-032 probe: S46/S47/S48 + one S45 seed.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_probe_s46()
	_probe_s48()
	_probe_s47()
	_probe_s45()
	quit(0)


func _probe_s46() -> void:
	var packed = load("res://tests/scenario_46.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.auto_run = false
	sc.suppress_io = true
	sc.set_battle_seed(1000)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(1000)
		spins += 1
	var r: Dictionary = sc.run_full_matrix()
	print("S46_RESULT all_ok=%s massive=%s" % [str(r.get("all_ok")), str(r.get("massive_rejected"))])
	for row in r.get("rows", []):
		if not bool(row.get("ok", false)):
			print("S46_FAIL %s" % str(row))
	sc.free()


func _probe_s48() -> void:
	var packed = load("res://tests/scenario_48.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.auto_run = false
	sc.suppress_io = true
	sc.set_battle_seed(1000)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(1000)
		spins += 1
	var r: Dictionary = sc.run_penalty_probes()
	print("S48_RESULT %s" % str(r))
	sc.free()


func _probe_s47() -> void:
	var packed = load("res://tests/scenario_47.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.auto_run = false
	sc.suppress_io = true
	sc.set_battle_seed(1000)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(1000)
		spins += 1
	sc._ensure_sim_core()
	sc._sync_core_from_units()
	for i in 1200:
		sc.advance_one_tick()
	sc.evaluate_after_ticks()
	print("S47_RESULT fit=%s perm=%s" % [str(sc.fit_half_out_rejected), str(sc.reveal_permanence_ok)])
	sc.free()


func _probe_s45() -> void:
	for conceal in [true, false]:
		var packed = load("res://tests/scenario_45.tscn")
		var sc = packed.instantiate()
		sc.headless_mode = true
		sc.fast_sim_mode = true
		sc.auto_run = false
		sc.suppress_io = true
		sc.use_concealment = conceal
		sc.set_battle_seed(1000)
		root.add_child(sc)
		var spins := 0
		while not sc.is_node_ready() and spins < 512:
			OS.delay_usec(1000)
			spins += 1
		sc._ensure_sim_core()
		sc._sync_core_from_units()
		for i in 4500:
			sc.advance_one_tick()
			if sc.is_battle_over():
				break
		print(
			"S45_RESULT conceal=%s tier=%d edge=%s reveal_t=%.1f coh=%.1f str=%.1f"
			% [
				str(conceal),
				sc.get_brace_tier(),
				sc.get_charge_edge(),
				sc.get_reveal_time(),
				sc.column_cohesion(),
				sc.column_strength(),
			]
		)
		# Dump conceal state of ambushers early from traces
		var reveals := 0
		for line in sc.get_trace_text().split("\n"):
			if "EVENT,reveal," in line:
				reveals += 1
				print("  %s" % line)
		print("  reveal_events=%d" % reveals)
		sc.free()
