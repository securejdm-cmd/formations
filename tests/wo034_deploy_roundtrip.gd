extends SceneTree

## WO-034 — UI-deploy == hand-authored initial state (serialize → headless load).
## Run: godot --headless -s res://tests/wo034_deploy_roundtrip.gd

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var BD = load("res://scripts/battle_scenario_data.gd")
	var battle: Dictionary = BD.load_path()
	if battle.is_empty():
		push_error("WO-034 roundtrip: missing battle JSON")
		quit(1)
		return
	var hand_placements: Array = battle.get("hand_authored_placements", [])
	var ui_placements: Array = []
	for p in hand_placements:
		ui_placements.append(p.duplicate(true))
	var hand_merged: Dictionary = BD.merge_deployed_battle(battle, hand_placements)
	var ui_merged: Dictionary = BD.merge_deployed_battle(battle, ui_placements)
	var fp_hand: String = BD.canonical_units_fingerprint(hand_merged)
	var fp_ui: String = BD.canonical_units_fingerprint(ui_merged)
	if fp_hand != fp_ui:
		push_error("WO-034 serialize mismatch UI vs hand\nHAND:\n%s\nUI:\n%s" % [fp_hand, fp_ui])
		quit(1)
		return
	var v: Dictionary = BD.validate_placements(battle, ui_placements)
	if not bool(v.ok):
		push_error("WO-034 hand placements invalid: %s" % str(v.errors))
		quit(1)
		return
	var fp_core_a: String = _core_fp(BD, hand_merged)
	var fp_core_b: String = _core_fp(BD, ui_merged)
	if fp_core_a.is_empty() or fp_core_a != fp_core_b:
		push_error("WO-034 headless tick0 mismatch\nA:\n%s\nB:\n%s" % [fp_core_a, fp_core_b])
		quit(1)
		return
	print(
		"[WO-034] ROUNDTRIP PASS fingerprint_units_chars=%d tick0_chars=%d"
		% [fp_hand.length(), fp_core_a.length()]
	)
	print("[WO-034] tick0:\n%s" % fp_core_a)
	quit(0)


func _core_fp(BD, merged: Dictionary) -> String:
	var packed = load("res://tests/scenario_from_data.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.auto_run = false
	sc.use_sim_thread = false
	sc.suppress_io = true
	sc.set_battle_data(merged)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(1000)
		spins += 1
	if sc.has_method("stop_sim_thread_for_harness"):
		sc.stop_sim_thread_for_harness()
	var fp: String = sc.get_initial_core_fingerprint()
	sc.free()
	return fp
