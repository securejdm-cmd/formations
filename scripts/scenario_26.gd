class_name Scenario26
extends Scenario01

## S26 — Late front-arc entry (~0.5s): reaction window unmet → no Tier 1, full shock.

const TRACE_PREFIX := "scenario_26"

var _cavalry: Unit = null
var _infantry: Unit = null
var _turned_to_face: bool = false


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
	# Face away until late turn so threat_front_sec cannot reach brace_reaction_s.
	_infantry.configure("blue_inf", "blue", inf_profile, Vector2(half, 0.0), Vector2.RIGHT)
	_infantry.current_order = Unit.Order.HOLD
	_infantry._set_state(Unit.State.HOLD)
	_infantry.current_speed_m_s = 0.0
	_units.append(_infantry)

	for unit in _units:
		unit.set_render_camera(_camera)


func advance_one_tick() -> void:
	_maybe_turn_infantry()
	super.advance_one_tick()


func advance_post_battle_tick() -> void:
	_maybe_turn_infantry()
	super.advance_post_battle_tick()


func _maybe_turn_infantry() -> void:
	if _turned_to_face or _cavalry == null or _infantry == null:
		return
	var px := Constants.get_float("px_per_meter")
	var gap_m := absf(_cavalry.position.x - _infantry.position.x) / px
	# ~0.5s before impact at cavalry ~4 sim-m/s.
	if gap_m <= 15.5:
		_infantry.facing = Vector2.LEFT
		_infantry.rotation = _infantry.facing.angle()
		_infantry._threat_front_sec = 0.0
		_infantry._brace_hold_sec = 0.0
		_infantry._braced = false
		_turned_to_face = true
		_sync_core_from_units()


func _write_trace_file() -> void:
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
	print("[Scenario 26] Trace written: %s" % file_path)


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
