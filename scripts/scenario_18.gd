class_name Scenario18
extends Scenario01

## Cavalry vs braced spears (held facing ≥ brace_time_s).

const TRACE_PREFIX := "scenario_18"

var _cavalry: Unit = null
var _spears: Unit = null


func _spawn_units() -> void:
	var cav_profile := UnitProfileLoader.load_profile("test_cavalry")
	var spear_profile := UnitProfileLoader.load_profile("test_spears")
	var px := Constants.get_float("px_per_meter")
	var run_up_m := 180.0
	var half := run_up_m * 0.5 * px

	_cavalry = UNIT_SCENE.instantiate()
	add_child(_cavalry)
	_cavalry.configure("red_cav", "red", cav_profile, Vector2(-half, 0.0), Vector2.RIGHT)
	_cavalry.start_from_rest()
	_cavalry.set_march_to(Vector2(half + 40.0 * px, 0.0))
	_units.append(_cavalry)

	_spears = UNIT_SCENE.instantiate()
	add_child(_spears)
	_spears.configure("blue_spears", "blue", spear_profile, Vector2(half, 0.0), Vector2.LEFT)
	_spears.current_order = Unit.Order.HOLD
	_spears._set_state(Unit.State.HOLD)
	_spears.current_speed_m_s = 0.0
	# Pre-warm brace timer: facing charger long enough before contact.
	_spears._brace_hold_sec = Constants.get_float("brace_time_s") + 0.1
	_spears._braced = true
	_spears._update_brace_visual()
	_units.append(_spears)

	for unit in _units:
		unit.set_render_camera(_camera)


func _write_trace_file() -> void:
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
	print("[Scenario 18] Trace written: %s" % file_path)


func get_charge_events() -> Array:
	_ensure_sim_core()
	return _sim_core.last_charge_events.duplicate(true)


func primary_charge_event() -> Dictionary:
	for ev in get_charge_events():
		if str(ev.get("attacker", "")) == "red_cav":
			return ev
	return {}


func cavalry_strength_at_rout() -> float:
	if _cavalry == null:
		return -1.0
	return _cavalry.strength
