extends SceneTree

## WO-035 — UI-launch smoke: deploy via UI data path, assert no-overlap + coherence.
## Also runs FULL-ENCIRCLEMENT (3+ edges engaged) stressing overlap resolution.
## Run: godot --headless -s res://tests/wo035_ui_launch_smoke.gd

const SCENE := "res://tests/scenario_from_data.tscn"
const UI_BATTLE := "res://data/battles/wo034_pitched_deploy.json"
const ENC_BATTLE := "res://data/battles/wo035_encirclement.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var BD = load("res://scripts/battle_scenario_data.gd")
	var ok_ui: bool = _run_ui_path(BD)
	var ok_enc: bool = _run_encirclement()
	if ok_ui and ok_enc:
		print("[WO-035] UI-LAUNCH SMOKE PASS (ui_path + encirclement)")
		quit(0)
	else:
		push_error("[WO-035] UI-LAUNCH SMOKE FAIL ui=%s enc=%s" % [str(ok_ui), str(ok_enc)])
		quit(1)


func _run_ui_path(BD) -> bool:
	## Same merge the deployment screen writes on Ready.
	var battle: Dictionary = BD.load_path(UI_BATTLE)
	var placements: Array = battle.get("hand_authored_placements", [])
	var merged: Dictionary = BD.merge_deployed_battle(battle, placements)
	var v: Dictionary = BD.validate_placements(battle, placements)
	if not bool(v.ok):
		push_error("UI path placements invalid: %s" % str(v.errors))
		return false
	return _simulate_integrity(merged, "ui_deploy", false)


func _run_encirclement() -> bool:
	var raw := FileAccess.get_file_as_string(ENC_BATTLE)
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("encirclement JSON missing")
		return false
	return _simulate_integrity(parsed, "encirclement", true)


func _simulate_integrity(merged: Dictionary, label: String, require_multi_edge: bool) -> bool:
	var packed = load(SCENE)
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.auto_run = false
	sc.use_sim_thread = false
	sc.suppress_io = true
	sc.ui_integrity_watch = true
	sc.set_battle_data(merged)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(1000)
		spins += 1
	if sc.has_method("stop_sim_thread_for_harness"):
		sc.stop_sim_thread_for_harness()
	sc._ensure_sim_core()
	sc._sim_core.capture_from_units(sc._units)
	sc._sim_core.headless_mode = true
	sc._sim_core.fast_sim_mode = true

	var saw_multi_edge := false
	var max_edges := 0
	var ticks := 0
	var max_ticks := 4000
	while ticks < max_ticks and not sc.is_battle_over():
		sc.advance_one_tick()
		ticks += 1
		if sc.had_overlap_failure():
			push_error("[%s] overlap assert failed at tick %d" % [label, ticks])
			sc.free()
			return false
		if sc.had_adhesion_invariant_failure():
			push_error("[%s] contact coherence failed at tick %d" % [label, ticks])
			sc.free()
			return false
		if require_multi_edge:
			var edges: int = _victim_edge_count(sc)
			var partners: int = _victim_partner_count(sc)
			max_edges = maxi(max_edges, maxi(edges, partners))
			if edges >= 3 or partners >= 3:
				saw_multi_edge = true

	var ov: bool = sc.had_overlap_failure()
	var ad: bool = sc.had_adhesion_invariant_failure()
	print(
		"[WO-035] %s ticks=%d over=%s overlap=%s coherence=%s max_edges=%d multi=%s"
		% [label, ticks, str(sc.is_battle_over()), str(ov), str(ad), max_edges, str(saw_multi_edge)]
	)
	var ok: bool = (not ov) and (not ad)
	if require_multi_edge and not saw_multi_edge:
		push_error("[%s] never saw 3+ edges/partners on victim (max=%d)" % [label, max_edges])
		ok = false
	sc.free()
	return ok


func _victim_edge_count(sc) -> int:
	var core = sc._sim_core
	if core == null:
		return 0
	for u in core.units:
		if str(u.unit_id) != "victim":
			continue
		var uniq: Dictionary = {}
		var label: String = str(u.get_active_contact_edges()).to_lower()
		if not label.is_empty():
			for part in label.split(";"):
				var s := str(part).strip_edges()
				for channel in ["front", "left", "right", "rear"]:
					if s.contains(channel):
						uniq[channel] = true
		var drains: Dictionary = u._edge_cohesion_drain_totals
		for k in ["front", "left", "right", "rear"]:
			if float(drains.get(k, 0.0)) > 0.01:
				uniq[k] = true
		if not uniq.is_empty():
			return uniq.size()
		return u.get_contact_partners().size()
	return 0


func _victim_partner_count(sc) -> int:
	var core = sc._sim_core
	if core == null:
		return 0
	for u in core.units:
		if str(u.unit_id) != "victim":
			continue
		return u.get_contact_partners().size()
	return 0
