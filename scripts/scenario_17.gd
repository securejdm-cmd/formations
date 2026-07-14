class_name Scenario17
extends Scenario01

## Cavalry charge vs unbraced infantry (long run-up). Optional adjacent / pre-drain.

const TRACE_PREFIX := "scenario_17"

@export var adjacent_control: bool = false
## When > 0, infantry starts at this cohesion (S17b: shaken line → charge may finish).
@export var infantry_start_cohesion: float = -1.0

var _cavalry: Unit = null
var _infantry: Unit = null


func _spawn_units() -> void:
	var cav_profile := UnitProfileLoader.load_profile("test_cavalry")
	var inf_profile := UnitProfileLoader.load_profile("test_infantry")
	var px := Constants.get_float("px_per_meter")
	# Adjacent: sit just outside contact from rest so closing stays below charge_min.
	# (8m centers nested the 15m-deep blocks and could stall adhesion.)
	var run_up_m := 20.0 if adjacent_control else 180.0
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
	if infantry_start_cohesion >= 0.0:
		_infantry.cohesion = infantry_start_cohesion
		_infantry._refresh_morale_state()
	_units.append(_infantry)

	for unit in _units:
		unit.set_render_camera(_camera)


func _write_trace_file() -> void:
	var suffix := "_adj" if adjacent_control else ""
	if infantry_start_cohesion >= 0.0 and not adjacent_control:
		suffix = "_predrain"
	var file_path := TRACE_DIR + TRACE_PREFIX + suffix + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
	print("[Scenario 17] Trace written: %s" % file_path)


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
	if _infantry == null:
		return -1.0
	return _infantry.cohesion


func infantry_strength_at_rout() -> float:
	# Approximate from final strength after combat if routed.
	if _infantry == null:
		return -1.0
	return _infantry.strength


func combat_duration_sec() -> float:
	return get_phase_durations_sec().get("combat_sec", 0.0)
