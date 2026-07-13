class_name Scenario11
extends Scenario01

const TRACE_PREFIX := "scenario_11"

@export var attacker_anti_armor: float = 15.0

var _attacker_unit: Unit = null
var _plate_unit: Unit = null
var _total_damage_to_plate: float = 0.0


func _spawn_units() -> void:
	var attacker_profile := UnitProfileLoader.load_profile("test_anti_armor_striker").duplicate()
	attacker_profile["anti_armor"] = attacker_anti_armor
	var plate_profile := UnitProfileLoader.load_profile("test_plate_target")
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
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d_aa%d.csv" % [_battle_seed, int(attacker_anti_armor)]
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
	print("[Scenario 11] Trace written: %s" % file_path)


func get_combat_duration_sec() -> float:
	return get_phase_durations_sec().combat_sec


func get_plate_damage_taken() -> float:
	if _plate_unit == null:
		return 0.0
	return Constants.get_float("strength_max") - _plate_unit.strength


func get_plate_unit() -> Unit:
	return _plate_unit


func get_attacker_unit() -> Unit:
	return _attacker_unit
