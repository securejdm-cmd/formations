class_name Scenario28
extends Scenario01

## S28 — Infantry charge (gait 2.0) vs standing braced infantry (gait 1.0).

const TRACE_PREFIX := "scenario_28"

var _charger: Unit = null
var _defender: Unit = null


func _spawn_units() -> void:
	var charge_profile := UnitProfileLoader.load_profile("test_infantry_charge")
	var inf_profile := UnitProfileLoader.load_profile("test_infantry")
	var px := Constants.get_float("px_per_meter")
	var run_up_m := 120.0
	var half := run_up_m * 0.5 * px

	_charger = UNIT_SCENE.instantiate()
	add_child(_charger)
	_charger.configure("red_charge", "red", charge_profile, Vector2(-half, 0.0), Vector2.RIGHT)
	_charger.start_from_rest()
	_charger.set_march_to(Vector2(half + 40.0 * px, 0.0))
	_units.append(_charger)

	_defender = UNIT_SCENE.instantiate()
	add_child(_defender)
	_defender.configure("blue_inf", "blue", inf_profile, Vector2(half, 0.0), Vector2.LEFT)
	_defender.current_order = Unit.Order.HOLD
	_defender._set_state(Unit.State.HOLD)
	_defender.current_speed_m_s = 0.0
	_units.append(_defender)

	for unit in _units:
		unit.set_render_camera(_camera)


func _write_trace_file() -> void:
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
	print("[Scenario 28] Trace written: %s" % file_path)


func get_charge_events() -> Array:
	_ensure_sim_core()
	return _sim_core.last_charge_events.duplicate(true)


func primary_charge_event() -> Dictionary:
	for ev in get_charge_events():
		if str(ev.get("attacker", "")) == "red_charge" and bool(ev.get("charged", false)):
			return ev
	for ev in get_charge_events():
		if str(ev.get("attacker", "")) == "red_charge":
			return ev
	return {}


func combat_duration_sec() -> float:
	return get_phase_durations_sec().get("combat_sec", 0.0)
