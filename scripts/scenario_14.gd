class_name Scenario14
extends Scenario01

const TRACE_PREFIX := "scenario_14"

@export var control_mode: bool = false


func _spawn_units() -> void:
	var archer_profile := UnitProfileLoader.load_profile("test_archer").duplicate(true)
	if control_mode:
		archer_profile["fire_doctrine"] = "FIRE_ON_ENGAGED"
	else:
		archer_profile["fire_doctrine"] = "FIRE_ON_SIGHT"

	var infantry_profile := UnitProfileLoader.load_profile("test_infantry")
	var px := Constants.get_float("px_per_meter")
	var archer_x := -130.0 * px

	var archer: Unit = UNIT_SCENE.instantiate()
	add_child(archer)
	archer.configure("red_archer", "red", archer_profile, Vector2(archer_x, 0.0), Vector2.RIGHT)
	archer.current_order = Unit.Order.HOLD
	archer._set_state(Unit.State.HOLD)
	_units.append(archer)

	var friendly: Unit = UNIT_SCENE.instantiate()
	add_child(friendly)
	friendly.configure("red_melee", "red", infantry_profile, Vector2(-10.0 * px, 0.0), Vector2.RIGHT)
	friendly.current_order = Unit.Order.HOLD
	friendly._set_state(Unit.State.HOLD)
	_units.append(friendly)

	var enemy: Unit = UNIT_SCENE.instantiate()
	add_child(enemy)
	enemy.configure("blue_scrum", "blue", infantry_profile, Vector2(10.0 * px, 0.0), Vector2.LEFT)
	enemy.current_order = Unit.Order.HOLD
	enemy._set_state(Unit.State.HOLD)
	_units.append(enemy)

	friendly.add_contact_partner(enemy)
	enemy.add_contact_partner(friendly)

	if control_mode:
		var reinforcement: Unit = UNIT_SCENE.instantiate()
		add_child(reinforcement)
		reinforcement.configure(
			"blue_reinforcement",
			"blue",
			infantry_profile,
			Vector2(180.0 * px, 80.0),
			Vector2.LEFT,
		)
		reinforcement.set_march_to(Vector2(120.0 * px, 80.0))
		_units.append(reinforcement)
	else:
		# Main run: archer has line of fire on engaged scrum target only.
		pass

	for unit in _units:
		unit.set_render_camera(_camera)


func _write_trace_file() -> void:
	var suffix := "_control" if control_mode else ""
	var file_path := TRACE_DIR + TRACE_PREFIX + "%s_%d.csv" % [suffix, _battle_seed]
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
	print("[Scenario 14] Trace written: %s" % file_path)


func friendly_fire_strength_lost() -> float:
	var max_s: float = Constants.get_float("strength_max")
	var final_strength := max_s
	for line in _trace_lines:
		var parts := line.split(",")
		if parts.size() >= 3 and parts[1] == "red_melee":
			final_strength = float(parts[2])
	return max_s - final_strength


func count_friendly_fire_events() -> int:
	var count := 0
	for line in _trace_lines:
		if line.contains("EVENT,friendly_fire,"):
			count += 1
	return count


func count_volley_events() -> int:
	var count := 0
	for line in _trace_lines:
		if line.contains("EVENT,volley,"):
			count += 1
	return count
