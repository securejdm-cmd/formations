extends SceneTree
## Focused WO-020 scenario probe with tick caps.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_run_named("res://tests/scenario_30.tscn", "S30", 8000)
	_run_named("res://tests/scenario_31.tscn", "S31", 8000)
	_run_named("res://tests/scenario_33.tscn", "S33", 8000)
	_run_named("res://tests/scenario_34.tscn", "S34", 12000)
	_run_named("res://tests/scenario_32.tscn", "S32", 20000)
	quit(0)


func _run_named(path: String, tag: String, max_ticks: int) -> void:
	var packed: PackedScene = load(path)
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.set_battle_seed(1000)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(2000)
		spins += 1
	var ticks := 0
	while not sc.is_battle_over() and ticks < max_ticks:
		sc.advance_one_tick()
		ticks += 1
	print("%s over=%s ticks=%d" % [tag, sc.is_battle_over(), ticks])
	if tag == "S30":
		print("  sk=%.2f sp=%.2f sk_lost=%.2f sp_lost=%.2f" % [
			float(sc.skirm_withdraw_s), float(sc.spears_withdraw_s),
			float(sc.skirm_str_lost), float(sc.spears_str_lost)])
	elif tag == "S31":
		print("  spears_t=%.2f drain=%.3f inf_t=%.2f drain=%.3f" % [
			float(sc.spears_time_s), float(sc.spears_drain),
			float(sc.inf_time_s), float(sc.inf_drain)])
	elif tag == "S32":
		print("  str=%.1f/%.1f/%.1f impact2=%.3f" % [
			float(sc.strength_after_fail), float(sc.strength_after_disengage),
			float(sc.strength_after_recharge), float(sc.second_charge_impact)])
	elif tag == "S33":
		print("  edges=%s/%s dots=%.2f/%.2f" % [
			str(sc.contact_edge_red), str(sc.contact_edge_blue),
			float(sc.red_facing_dot_at_contact), float(sc.blue_facing_dot_at_contact)])
	elif tag == "S34":
		print("  flank=%s no_reface=%s samples=%d" % [
			str(sc.flank_persisted), str(sc.a_did_not_reface), sc.edge_samples.size()])
	sc.free()
