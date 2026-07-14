class_name Scenario25
extends Scenario01

## S25 — Caught marching: infantry at full speed → no Tier 1 (speed cap), full frontal shock.

const TRACE_PREFIX := "scenario_25"

var _cavalry: Unit = null
var _infantry: Unit = null


func _spawn_units() -> void:
	var cav_profile := UnitProfileLoader.load_profile("test_cavalry")
	var inf_profile := UnitProfileLoader.load_profile("test_infantry")
	var px := Constants.get_float("px_per_meter")
	var run_up_m := 180.0
	var half := run_up_m * 0.5 * px

	_cavalry = UNIT_SCENE.instantiate()
	add_child(_cavalry)
	_cavalry.configure("red_cav", "red", cav_profile, Vector2(-half, 0.0), Vector2.RIGHT)
	_cavalry.start_from_rest()
	_cavalry.set_march_to(Vector2(half + 40.0 * px, 0.0))
	_units.append(_cavalry)

	_infantry = UNIT_SCENE.instantiate()
	add_child(_infantry)
	# March toward the cavalry (facing it) so speed exceeds brace_max_own_speed_pct.
	_infantry.configure("blue_inf", "blue", inf_profile, Vector2(half, 0.0), Vector2.LEFT)
	_infantry.set_march_to(Vector2(-half - 40.0 * px, 0.0))
	_units.append(_infantry)

	for unit in _units:
		unit.set_render_camera(_camera)


func _write_trace_file() -> void:
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
	print("[Scenario 25] Trace written: %s" % file_path)


func get_charge_events() -> Array:
	_ensure_sim_core()
	return _sim_core.last_charge_events.duplicate(true)


func primary_charge_event() -> Dictionary:
	for ev in get_charge_events():
		if str(ev.get("attacker", "")) == "red_cav" and bool(ev.get("charged", false)):
			return ev
	for ev in get_charge_events():
		if str(ev.get("attacker", "")) == "red_cav":
			return ev
	return {}


func infantry_cohesion() -> float:
	return -1.0 if _infantry == null else _infantry.cohesion


func combat_duration_sec() -> float:
	return get_phase_durations_sec().get("combat_sec", 0.0)
