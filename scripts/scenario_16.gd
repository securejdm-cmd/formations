class_name Scenario16
extends Scenario01

const TRACE_PREFIX := "scenario_16"

@export var plate_mode: bool = false


func _spawn_units() -> void:
	var archer_profile := UnitProfileLoader.load_profile("test_archer")
	var target_profile: Dictionary
	if plate_mode:
		target_profile = UnitProfileLoader.load_profile("test_plate_defender").duplicate(true)
	else:
		target_profile = UnitProfileLoader.load_profile("test_light_leather").duplicate(true)
	target_profile["speed"] = 0
	target_profile["skip_auto_engage"] = true
	# Static quiver dump at half-range (75m): falloff 100%, outside dead zone.
	var half_distance_px := 37.5 * Constants.get_float("px_per_meter")

	var archer: Unit = UNIT_SCENE.instantiate()
	add_child(archer)
	archer.configure("red_archer", "red", archer_profile, Vector2(-half_distance_px, 0.0), Vector2.RIGHT)
	archer.current_order = Unit.Order.HOLD
	archer._set_state(Unit.State.HOLD)
	_units.append(archer)

	var target: Unit = UNIT_SCENE.instantiate()
	add_child(target)
	target.configure("blue_target", "blue", target_profile, Vector2(half_distance_px, 0.0), Vector2.LEFT)
	target.current_order = Unit.Order.HOLD
	target._set_state(Unit.State.HOLD)
	_units.append(target)

	for unit in _units:
		unit.set_render_camera(_camera)


func _write_trace_file() -> void:
	var suffix := "_plate" if plate_mode else "_leather"
	var file_path := TRACE_DIR + TRACE_PREFIX + "%s_%d.csv" % [suffix, _battle_seed]
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
	print("[Scenario 16] Trace written: %s" % file_path)


func count_volley_events() -> int:
	var count := 0
	for line in _trace_lines:
		if line.contains("EVENT,volley,"):
			count += 1
	return count


func target_strength_lost() -> float:
	var max_s: float = Constants.get_float("strength_max")
	var final_strength := max_s
	for line in _trace_lines:
		var parts := line.split(",")
		if parts.size() >= 3 and parts[1] == "blue_target":
			final_strength = float(parts[2])
	return max_s - final_strength


func had_ammo_empty() -> bool:
	return "EVENT,ammo_empty," in get_trace_text()


func first_volley_chip_dominated(expected_chip_per_volley: float, tol: float = 0.05) -> bool:
	## True when observed per-volley loss matches chip floor (within tol × chip).
	var prev := -1.0
	var matches := 0
	var checked := 0
	for line in _trace_lines:
		var parts := line.split(",")
		if parts.size() < 8 or parts[1] != "blue_target":
			continue
		var strength: float = float(parts[2])
		if prev >= 0.0:
			var delta: float = prev - strength
			if delta > 0.001:
				checked += 1
				if absf(delta - expected_chip_per_volley) <= maxf(tol * expected_chip_per_volley, 0.01):
					matches += 1
		prev = strength
	return checked > 0 and matches >= int(checked * 0.8)
