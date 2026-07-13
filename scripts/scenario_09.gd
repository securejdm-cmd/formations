class_name Scenario09
extends Scenario01

const TRACE_PREFIX := "scenario_09"


func _spawn_units() -> void:
	var heavy_profile := UnitProfileLoader.load_profile("test_heavy_mail")
	var light_profile := UnitProfileLoader.load_profile("test_light_leather")
	var start_distance_m := Constants.get_float("scenario_01_start_distance_m")
	var half_distance_px := start_distance_m * 0.5 * Constants.get_float("px_per_meter")

	var red: Unit = UNIT_SCENE.instantiate()
	add_child(red)
	red.configure("red_1", "red", heavy_profile, Vector2(-half_distance_px, 0.0), Vector2.RIGHT)
	red.set_march_to(Vector2(half_distance_px, 0.0))
	_units.append(red)

	var blue: Unit = UNIT_SCENE.instantiate()
	add_child(blue)
	blue.configure("blue_1", "blue", light_profile, Vector2(half_distance_px, 0.0), Vector2.LEFT)
	blue.set_march_to(Vector2(-half_distance_px, 0.0))
	_units.append(blue)

	for unit in _units:
		unit.set_render_camera(_camera)


func _write_trace_file() -> void:
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
	print("[Scenario 09] Trace written: %s" % file_path)


func get_casualty_ratio() -> float:
	var heavy: Unit = _units[0] if _units.size() > 0 else null
	var light: Unit = _units[1] if _units.size() > 1 else null
	if heavy == null or light == null:
		return 0.0
	var heavy_lost: float = Constants.get_float("strength_max") - heavy.strength
	var light_lost: float = Constants.get_float("strength_max") - light.strength
	if light_lost <= 0.0:
		return INF
	return heavy_lost / light_lost


func get_heavy_unit() -> Unit:
	return _units[0] if _units.size() > 0 else null
