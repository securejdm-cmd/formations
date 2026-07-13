class_name Scenario06
extends Scenario01

const TRACE_PREFIX := "scenario_06"

var _blue_rally: Unit = null
var _red_pursuer: Unit = null
var _pursuit_tick_count: int = 0


func _spawn_units() -> void:
	var rally_profile := UnitProfileLoader.load_profile("test_infantry_rally")
	var striker_profile := UnitProfileLoader.load_profile("test_infantry_push60")
	var defender_profile := UnitProfileLoader.load_profile("test_infantry_push40")
	var px_per_meter := Constants.get_float("px_per_meter")
	var start_distance_m := Constants.get_float("scenario_01_start_distance_m")
	var half_distance_px := start_distance_m * 0.5 * px_per_meter

	_blue_rally = UNIT_SCENE.instantiate()
	add_child(_blue_rally)
	_blue_rally.configure(
		"blue_rally",
		"blue",
		rally_profile,
		Vector2(half_distance_px, 0.0),
		Vector2.LEFT,
	)
	_blue_rally.profile["pushing_power"] = defender_profile.get("pushing_power", 40.0)
	_blue_rally.set_march_to(Vector2(-half_distance_px, 0.0))
	_units.append(_blue_rally)

	var red_striker: Unit = UNIT_SCENE.instantiate()
	add_child(red_striker)
	red_striker.configure(
		"red_striker",
		"red",
		striker_profile,
		Vector2(-half_distance_px, 0.0),
		Vector2.RIGHT,
	)
	red_striker.set_march_to(Vector2(half_distance_px, 0.0))
	_units.append(red_striker)

	# Duplicate profile before skip_auto_engage — shared dict would also mark
	# red_striker, and WO-014 partner-side skip then prevents blue_rally engagement.
	var pursuer_profile: Dictionary = striker_profile.duplicate(true)
	pursuer_profile["skip_auto_engage"] = true
	_red_pursuer = UNIT_SCENE.instantiate()
	add_child(_red_pursuer)
	_red_pursuer.configure(
		"red_pursuer",
		"red",
		pursuer_profile,
		Vector2(-half_distance_px - 100.0 * px_per_meter, 0.0),
		Vector2.RIGHT,
	)
	_red_pursuer.set_march_to(Vector2(half_distance_px + 200.0 * px_per_meter, 0.0))
	_units.append(_red_pursuer)


func advance_one_tick() -> void:
	super.advance_one_tick()
	_update_pursuer_march_target()


func advance_post_battle_tick() -> void:
	super.advance_post_battle_tick()
	_update_pursuer_march_target()


func _update_pursuer_march_target() -> void:
	if _red_pursuer == null or _blue_rally == null:
		return
	if _blue_rally.get_state() != Unit.State.ROUTING:
		return
	var px := Constants.get_float("px_per_meter")
	var target_x := Constants.get_float("scenario_01_start_distance_m") * 0.5 * px + 200.0 * px
	_red_pursuer.set_march_to(Vector2(target_x, 0.0))
	_sync_core_from_units()


func _pursuit_tick() -> void:
	var before := get_trace_events().size()
	super._pursuit_tick()
	var after := get_trace_events().size()
	if after > before:
		_pursuit_tick_count += after - before


func _update_movement(delta: float) -> void:
	super._update_movement(delta)
	if (
		_red_pursuer != null
		and _blue_rally != null
		and _blue_rally.get_state() == Unit.State.ROUTING
	):
		var px := Constants.get_float("px_per_meter")
		var target_x := (
			Constants.get_float("scenario_01_start_distance_m") * 0.5 * px + 200.0 * px
		)
		_red_pursuer.set_march_to(Vector2(target_x, 0.0))


func _try_begin_engagement(unit: Unit) -> void:
	if unit.unit_id == "red_pursuer":
		return
	super._try_begin_engagement(unit)


func _try_passive_engagement() -> void:
	for unit in _units:
		if unit.unit_id == "red_pursuer":
			continue
		if unit.get_state() != Unit.State.HOLD or not unit.is_rallied_hold():
			continue
		for other in _units:
			if other == unit or other.get_state() == Unit.State.REMOVED:
				continue
			if other.team_id == unit.team_id or other.unit_id == "red_pursuer":
				continue
			if other.get_state() == Unit.State.ROUTING or other.get_state() == Unit.State.RALLYING:
				continue
			if not CombatResolver.units_have_any_contact(unit, other):
				continue
			unit.add_contact_partner(other)
			other.add_contact_partner(unit)


func _write_trace_file() -> void:
	var dir := DirAccess.open("res://tests")
	if dir == null:
		return
	if not dir.dir_exists("traces"):
		dir.make_dir("traces")
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
	print("[Scenario 06] Trace written: %s" % file_path)


func get_blue_rally() -> Unit:
	return _blue_rally


func get_pursuit_tick_count() -> int:
	if _pursuit_tick_count > 0:
		return _pursuit_tick_count
	var count := 0
	for line in get_trace_events():
		if ",pursuit_damage," in line:
			count += 1
	return count
