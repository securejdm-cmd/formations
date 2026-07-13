class_name Scenario10
extends Scenario01

const TRACE_PREFIX := "scenario_10"

var _plate_unit: Unit = null
var _attacker_unit: Unit = null


func _spawn_units() -> void:
	var attacker_profile := UnitProfileLoader.load_profile("test_infantry")
	var plate_profile := UnitProfileLoader.load_profile("test_plate_defender")
	var start_distance_m := Constants.get_float("scenario_01_start_distance_m")
	var half_distance_px := start_distance_m * 0.5 * Constants.get_float("px_per_meter")

	_attacker_unit = UNIT_SCENE.instantiate()
	add_child(_attacker_unit)
	_attacker_unit.configure("red_1", "red", attacker_profile, Vector2(-half_distance_px, 0.0), Vector2.RIGHT)
	_attacker_unit.set_march_to(Vector2(half_distance_px, 0.0))
	_units.append(_attacker_unit)

	_plate_unit = UNIT_SCENE.instantiate()
	add_child(_plate_unit)
	_plate_unit.configure("blue_1", "blue", plate_profile, Vector2(half_distance_px, 0.0), Vector2.LEFT)
	_plate_unit.set_march_to(Vector2(-half_distance_px, 0.0))
	_units.append(_plate_unit)

	for unit in _units:
		unit.set_render_camera(_camera)


func _write_trace_file() -> void:
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
	print("[Scenario 10] Trace written: %s" % file_path)


func get_plate_unit() -> Unit:
	return _plate_unit


func get_attacker_unit() -> Unit:
	return _attacker_unit
