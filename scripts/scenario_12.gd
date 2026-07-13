class_name Scenario12
extends Scenario01

const TRACE_PREFIX := "scenario_12"


func _spawn_units() -> void:
	var archer_profile := UnitProfileLoader.load_profile("test_archer")
	var infantry_profile := UnitProfileLoader.load_profile("test_infantry")
	var start_distance_m := 200.0
	var half_distance_px := start_distance_m * 0.5 * Constants.get_float("px_per_meter")

	var archer: Unit = UNIT_SCENE.instantiate()
	add_child(archer)
	archer.configure("red_archer", "red", archer_profile, Vector2(-half_distance_px, 0.0), Vector2.RIGHT)
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
	print("[Scenario 12] Trace written: %s" % file_path)


func count_volley_events() -> int:
	return _count_trace_events("volley")


func had_dead_zone_panic() -> bool:
	return "dead_zone_panic" in get_trace_text()


func infantry_strength_lost() -> float:
	return _strength_lost("blue_1")


func archer_strength_lost() -> float:
	return _strength_lost("red_archer")


func infantry_routed_by_missiles_only() -> bool:
	var contact_sec := -1.0
	if _first_contact_tick >= 0:
		contact_sec = float(_first_contact_tick) / Constants.get_float("tick_rate_per_sec")
	for line in _trace_lines:
		var parts := line.split(",")
		if parts.size() < 8 or parts[1] != "blue_1":
			continue
		if parts[7] != "routing":
			continue
		var t := float(parts[0])
		return contact_sec < 0.0 or t < contact_sec - 0.05
	return false


func approach_strength_lost() -> float:
	## Strength lost on infantry before first melee contact (missile attrition only).
	var max_s: float = Constants.get_float("strength_max")
	var contact_sec := INF
	if _first_contact_tick >= 0:
		contact_sec = float(_first_contact_tick) / Constants.get_float("tick_rate_per_sec")
	var last := max_s
	for line in _trace_lines:
		var parts: PackedStringArray = line.split(",")
		if parts.size() < 8 or parts[1] != "blue_1":
			continue
		if float(parts[0]) >= contact_sec - 0.001:
			break
		last = float(parts[2])
	return max_s - last


func _strength_lost(unit_id: String) -> float:
	var max_s: float = Constants.get_float("strength_max")
	var final_strength := max_s
	for line in _trace_lines:
		var parts := line.split(",")
		if parts.size() >= 3 and parts[1] == unit_id:
			final_strength = float(parts[2])
	return max_s - final_strength


func _count_trace_events(event_type: String) -> int:
	var count := 0
	for line in _trace_lines:
		if line.contains("EVENT,%s," % event_type):
			count += 1
	return count
