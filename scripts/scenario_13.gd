class_name Scenario13
extends Scenario01

const TRACE_PREFIX := "scenario_13"

@export var doctrine_mode: String = "FIRE_ON_SIGHT"
@export var include_blocker: bool = false


func _spawn_units() -> void:
	var archer_profile := UnitProfileLoader.load_profile("test_archer").duplicate(true)
	archer_profile["fire_doctrine"] = doctrine_mode
	var infantry_profile := UnitProfileLoader.load_profile("test_infantry")
	var blocker_profile := UnitProfileLoader.load_profile("test_blocker_narrow")
	var start_distance_m := 200.0
	var half_distance_px := start_distance_m * 0.5 * Constants.get_float("px_per_meter")

	var archer: Unit = UNIT_SCENE.instantiate()
	add_child(archer)
	archer.configure("red_archer", "red", archer_profile, Vector2(-half_distance_px, 0.0), Vector2.RIGHT)
	archer.current_order = Unit.Order.HOLD
	archer._set_state(Unit.State.HOLD)
	_units.append(archer)

	if include_blocker:
		var blocker: Unit = UNIT_SCENE.instantiate()
		add_child(blocker)
		blocker.configure(
			"red_blocker",
			"red",
			blocker_profile,
			Vector2(20.0 * Constants.get_float("px_per_meter"), 0.0),
			Vector2.RIGHT,
		)
		blocker.current_order = Unit.Order.HOLD
		blocker._set_state(Unit.State.HOLD)
		_units.append(blocker)

	var infantry: Unit = UNIT_SCENE.instantiate()
	add_child(infantry)
	var infantry_spawn := Vector2(half_distance_px, 0.0)
	if include_blocker and doctrine_mode == "FIRE_ON_ENGAGED":
		infantry_spawn = Vector2(30.0 * Constants.get_float("px_per_meter"), 0.0)
	infantry.configure("blue_1", "blue", infantry_profile, infantry_spawn, Vector2.LEFT)
	infantry.set_march_to(Vector2(-half_distance_px, 0.0))
	_units.append(infantry)

	if include_blocker and doctrine_mode == "FIRE_ON_ENGAGED":
		var blocker_unit: Unit = _find_unit("red_blocker")
		blocker_unit.add_contact_partner(infantry)
		infantry.add_contact_partner(blocker_unit)
		blocker_unit._set_state(Unit.State.ENGAGED)
		infantry._set_state(Unit.State.ENGAGED)

	for unit in _units:
		unit.set_render_camera(_camera)


func advance_one_tick() -> void:
	super.advance_one_tick()
	if include_blocker:
		_maybe_force_blocker_engagement()


func _maybe_force_blocker_engagement() -> void:
	var blocker: Unit = _find_unit("red_blocker")
	var enemy: Unit = _find_unit("blue_1")
	var archer: Unit = _find_unit("red_archer")
	if blocker == null or enemy == null or archer == null:
		return
	if blocker.get_state() == Unit.State.ENGAGED:
		return
	if CombatResolver.center_distance_m(archer, enemy) > 100.0:
		return
	if not CombatResolver.could_have_contact(blocker, enemy):
		return
	blocker.add_contact_partner(enemy)
	enemy.add_contact_partner(blocker)
	if CombatResolver.is_head_on_pair(blocker, enemy):
		CombatResolver.snap_pair_to_contact(blocker, enemy)


func _find_unit(unit_id: String) -> Unit:
	for unit in _units:
		if unit.unit_id == unit_id:
			return unit
	return null


func _write_trace_file() -> void:
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%s_%d.csv" % [doctrine_mode, _battle_seed]
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
	print("[Scenario 13] Trace written: %s" % file_path)


func first_volley_distance_m(_archer_id: String = "red_archer") -> float:
	for line in _trace_lines:
		if not line.contains("EVENT,volley,"):
			continue
		if not line.contains("shooter=red_archer,"):
			continue
		var idx := line.find("dist_m=")
		if idx < 0:
			continue
		var tail := line.substr(idx + 7)
		return float(tail.split(",")[0])
	return -1.0
