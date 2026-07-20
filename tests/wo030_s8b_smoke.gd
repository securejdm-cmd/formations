extends SceneTree
func _initialize():
	call_deferred("_run")
func _run():
	var packed = load("res://tests/scenario_08b.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.auto_run = false
	sc.suppress_io = true
	sc.attacker_count = 3
	sc.set_battle_seed(1000)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(1000)
		spins += 1
	var ticks := 0
	while not sc.is_battle_over() and ticks < 20000:
		sc.advance_one_tick()
		ticks += 1
	print("S8B_SMOKE max_partners=%d multi_ticks=%d dmg=%.3f" % [sc.max_defender_partners, sc.multi_partner_ticks, sc.get_defender_damage_taken()])
	sc.free()
	quit(0)
