class_name Scenario19
extends Scenario01

## Brace timing: spears face charger only ~0.5s before impact — brace FAILS.

const TRACE_PREFIX := "scenario_19"

var _cavalry: Unit = null
var _spears: Unit = null
var _turned_to_face: bool = false


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
	# Start facing AWAY so brace cannot accumulate until late turn.
	_spears.configure("blue_spears", "blue", spear_profile, Vector2(half, 0.0), Vector2.RIGHT)
	_spears.current_order = Unit.Order.HOLD
	_spears._set_state(Unit.State.HOLD)
	_spears.current_speed_m_s = 0.0
	_units.append(_spears)

	for unit in _units:
		unit.set_render_camera(_camera)


func advance_one_tick() -> void:
	_maybe_turn_spears()
	super.advance_one_tick()


func advance_post_battle_tick() -> void:
	_maybe_turn_spears()
	super.advance_post_battle_tick()


func _maybe_turn_spears() -> void:
	if _turned_to_face or _cavalry == null or _spears == null:
		return
	var px := Constants.get_float("px_per_meter")
	var gap_m := absf(_cavalry.position.x - _spears.position.x) / px
	# Contact at ~center gap of (cav_depth + spear_depth)/2 ≈ 13.5m.
	# Turn ~0.5s before impact (~2m at cavalry cruise ~4 m/s) → gap ≈ 15.5m.
	if gap_m <= 15.5:
		_spears.facing = Vector2.LEFT
		_spears.rotation = _spears.facing.angle()
		_spears._brace_hold_sec = 0.0
		_spears._braced = false
		_spears._update_brace_visual()
		_turned_to_face = true
		_sync_core_from_units()


func _write_trace_file() -> void:
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
	print("[Scenario 19] Trace written: %s" % file_path)


func get_charge_events() -> Array:
	_ensure_sim_core()
	return _sim_core.last_charge_events.duplicate(true)


func primary_charge_event() -> Dictionary:
	for ev in get_charge_events():
		if str(ev.get("attacker", "")) == "red_cav":
			return ev
	return {}
