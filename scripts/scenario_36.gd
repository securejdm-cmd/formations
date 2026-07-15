class_name Scenario36
extends Scenario01

## S36 — Uphill push: identical infantry, downhill vs uphill on test hill.

const TRACE_PREFIX := "scenario_36"

var _downhill: Unit = null
var _uphill: Unit = null
var _contact_x_m: float = 0.0
var _rout_x_m: float = 0.0
var _strength_at_rout: float = -1.0
var _routed_id: String = ""


func _ready() -> void:
	ensure_test_hill()
	super._ready()


func _spawn_units() -> void:
	var profile := UnitProfileLoader.load_profile("test_infantry")
	var px := Constants.get_float("px_per_meter")
	# Mid-ramp: downhill faces west; uphill faces east.
	var meet_x := 0.0
	var half_gap := 40.0 * px

	_downhill = UNIT_SCENE.instantiate()
	add_child(_downhill)
	_downhill.configure("red_downhill", "red", profile, Vector2(meet_x + half_gap, 0.0), Vector2.LEFT)
	_downhill.set_march_to(Vector2(meet_x - half_gap - 20.0 * px, 0.0))
	_units.append(_downhill)

	_uphill = UNIT_SCENE.instantiate()
	add_child(_uphill)
	_uphill.configure("blue_uphill", "blue", profile, Vector2(meet_x - half_gap, 0.0), Vector2.RIGHT)
	_uphill.set_march_to(Vector2(meet_x + half_gap + 20.0 * px, 0.0))
	_units.append(_uphill)

	for unit in _units:
		unit.set_render_camera(_camera)


func _mid_x_m() -> float:
	var px := Constants.get_float("px_per_meter")
	return (_downhill.position.x + _uphill.position.x) * 0.5 / px


func _on_first_contact() -> void:
	if _first_contact_tick >= 0:
		return
	_first_contact_tick = _sim_tick_count
	_contact_x_m = _mid_x_m()


func _on_first_rout() -> void:
	if _first_rout_tick >= 0:
		return
	for unit in _units:
		if unit.get_state() == Unit.State.ROUTING:
			_strength_at_rout = unit.strength
			_routed_id = unit.unit_id
			_rout_x_m = _mid_x_m()
			break
	_first_rout_tick = _sim_tick_count


func ground_displacement_m() -> float:
	## Positive = contact line moved downhill (west / negative x).
	return _contact_x_m - _rout_x_m


func downhill_won_push() -> bool:
	return _routed_id == "blue_uphill" or ground_displacement_m() > 1.0


func get_routed_id() -> String:
	return _routed_id


func strength_at_rout() -> float:
	return _strength_at_rout


func _write_trace_file() -> void:
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
	print("[Scenario 36] Trace written: %s" % file_path)
	var phases := get_phase_durations_sec()
	print(
		"[Scenario 36] SUMMARY | winner=%s | combat=%.1fs | displace_m=%.2f | routed=%s | str_at_rout=%.2f"
		% [
			get_winner_id(),
			float(phases.get("combat_sec", -1.0)),
			ground_displacement_m(),
			_routed_id,
			_strength_at_rout,
		]
	)
