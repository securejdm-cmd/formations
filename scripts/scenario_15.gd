class_name Scenario15
extends Scenario01

const TRACE_PREFIX := "scenario_15"


func _spawn_units() -> void:
	var archer_profile := UnitProfileLoader.load_profile("test_archer").duplicate(true)
	archer_profile["ammo_volleys"] = 3
	var infantry_profile := UnitProfileLoader.load_profile("test_infantry").duplicate(true)
	infantry_profile["speed"] = 5
	var start_distance_m := 200.0
	var half_distance_px := start_distance_m * 0.5 * Constants.get_float("px_per_meter")

	var archer: Unit = UNIT_SCENE.instantiate()
	add_child(archer)
	archer.configure("red_archer", "red", archer_profile, Vector2(-half_distance_px, 0.0), Vector2.RIGHT)
	archer.ammo_remaining = 3
	archer.current_order = Unit.Order.HOLD
	archer._set_state(Unit.State.HOLD)
	_units.append(archer)

	var infantry: Unit = UNIT_SCENE.instantiate()
	add_child(infantry)
	infantry.configure("blue_1", "blue", infantry_profile, Vector2(half_distance_px, 0.0), Vector2.LEFT)
	infantry.set_march_to(Vector2(-half_distance_px, 0.0))
	_units.append(infantry)

	for unit in _units:
		unit.set_render_camera(_camera)


func _write_trace_file() -> void:
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
	print("[Scenario 15] Trace written: %s" % file_path)


func count_volley_events() -> int:
	var count := 0
	for line in _trace_lines:
		if line.contains("EVENT,volley,"):
			count += 1
	return count


func had_ammo_empty_event() -> bool:
	return "EVENT,ammo_empty,unit=red_archer" in get_trace_text()


func volleys_after_ammo_empty() -> int:
	var empty_time := -1.0
	for line in _trace_lines:
		if "EVENT,ammo_empty,unit=red_archer" in line:
			empty_time = float(line.split(",")[0])
			break
	if empty_time < 0.0:
		return 0
	var count := 0
	for line in _trace_lines:
		if not line.contains("EVENT,volley,shooter=red_archer,"):
			continue
		if float(line.split(",")[0]) > empty_time + 0.01:
			count += 1
	return count
