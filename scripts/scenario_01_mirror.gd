class_name Scenario01Mirror
extends Scenario01

## Side-swapped Scenario 1 for mirror-bias audit. Does not modify scenario_01.gd.

const TRACE_PREFIX := "scenario_01_mirror"


func _spawn_units() -> void:
	var profile := UnitProfileLoader.load_profile("test_infantry")
	var start_distance_m := Constants.get_float("scenario_01_start_distance_m")
	var half_distance_px := start_distance_m * 0.5 * Constants.get_float("px_per_meter")

	var red: Unit = UNIT_SCENE.instantiate()
	add_child(red)
	red.configure("red_1", "red", profile, Vector2(half_distance_px, 0.0), Vector2.LEFT)
	red.set_march_to(Vector2(-half_distance_px, 0.0))
	_units.append(red)

	var blue: Unit = UNIT_SCENE.instantiate()
	add_child(blue)
	blue.configure("blue_1", "blue", profile, Vector2(-half_distance_px, 0.0), Vector2.RIGHT)
	blue.set_march_to(Vector2(half_distance_px, 0.0))
	_units.append(blue)


func _write_trace_file() -> void:
	var dir := DirAccess.open("res://tests")
	if dir == null:
		push_error("Scenario 01 Mirror: cannot access tests directory")
		return

	if not dir.dir_exists("traces"):
		dir.make_dir("traces")

	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("Scenario 01 Mirror: cannot write trace file %s" % file_path)
		return

	for line in _trace_lines:
		file.store_line(line)

	print("[Scenario 01 Mirror] Trace written: %s" % file_path)
