class_name Scenario27
extends Scenario01

## S27 — Gait visibility: cavalry from 200m; sample speed each second commit→contact.

const TRACE_PREFIX := "scenario_27"

var _cavalry: Unit = null
var _infantry: Unit = null
var speed_samples: Array = []  # {t_sec, speed, committed}
var _sample_accum: float = 0.0
var _contact_logged: bool = false


func _spawn_units() -> void:
	var cav_profile := UnitProfileLoader.load_profile("test_cavalry")
	var inf_profile := UnitProfileLoader.load_profile("test_infantry")
	var px := Constants.get_float("px_per_meter")
	var run_up_m := 200.0
	var half := run_up_m * 0.5 * px

	_cavalry = UNIT_SCENE.instantiate()
	add_child(_cavalry)
	_cavalry.configure("red_cav", "red", cav_profile, Vector2(-half, 0.0), Vector2.RIGHT)
	_cavalry.start_from_rest()
	_cavalry.set_march_to(Vector2(half + 40.0 * px, 0.0))
	_units.append(_cavalry)

	_infantry = UNIT_SCENE.instantiate()
	add_child(_infantry)
	_infantry.configure("blue_inf", "blue", inf_profile, Vector2(half, 0.0), Vector2.LEFT)
	_infantry.current_order = Unit.Order.HOLD
	_infantry._set_state(Unit.State.HOLD)
	_infantry.current_speed_m_s = 0.0
	_units.append(_infantry)

	for unit in _units:
		unit.set_render_camera(_camera)


func advance_one_tick() -> void:
	super.advance_one_tick()
	_sample_accum += CombatResolver.tick_interval()
	if _sample_accum >= 1.0 - 0.0001:
		_sample_accum = 0.0
		if _cavalry != null:
			speed_samples.append({
				"t_sec": float(_sim_tick_count) * CombatResolver.tick_interval(),
				"speed": _cavalry.current_speed_m_s,
				"committed": _cavalry.charge_committed,
			})
	if not _contact_logged and _cavalry != null and _cavalry.has_contact_with(_infantry):
		_contact_logged = true


func _write_trace_file() -> void:
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
	print("[Scenario 27] Trace written: %s" % file_path)


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


func combat_duration_sec() -> float:
	return get_phase_durations_sec().get("combat_sec", 0.0)
