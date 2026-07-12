class_name Scenario05
extends Scenario01

const TRACE_PREFIX := "scenario_05"
const LANE_OFFSET_M := 80.0

var _blue_standard: Unit = null
var _blue_rally: Unit = null


func _spawn_units() -> void:
	var standard_profile := UnitProfileLoader.load_profile("test_infantry")
	var rally_profile := UnitProfileLoader.load_profile("test_infantry_rally")
	var attacker_profile := UnitProfileLoader.load_profile("test_infantry_push60")
	var defender_profile := UnitProfileLoader.load_profile("test_infantry_push40")
	var px_per_meter := Constants.get_float("px_per_meter")
	var start_distance_m := Constants.get_float("scenario_01_start_distance_m")
	var half_distance_px := start_distance_m * 0.5 * px_per_meter
	var lane_offset_px := LANE_OFFSET_M * px_per_meter

	var blue_standard: Unit = UNIT_SCENE.instantiate()
	add_child(blue_standard)
	blue_standard.configure(
		"blue_standard",
		"blue",
		defender_profile,
		Vector2(half_distance_px, -lane_offset_px),
		Vector2.LEFT,
	)
	blue_standard.set_march_to(Vector2(-half_distance_px, -lane_offset_px))
	_units.append(blue_standard)
	_blue_standard = blue_standard

	var red_standard: Unit = UNIT_SCENE.instantiate()
	add_child(red_standard)
	red_standard.configure(
		"red_standard",
		"red",
		attacker_profile,
		Vector2(-half_distance_px, -lane_offset_px),
		Vector2.RIGHT,
	)
	red_standard.set_march_to(Vector2(half_distance_px, -lane_offset_px))
	_units.append(red_standard)

	var rally_lane_profile := rally_profile.duplicate()
	rally_lane_profile["pushing_power"] = defender_profile.get("pushing_power", 40.0)

	var blue_rally: Unit = UNIT_SCENE.instantiate()
	add_child(blue_rally)
	blue_rally.configure(
		"blue_rally",
		"blue",
		rally_lane_profile,
		Vector2(half_distance_px, lane_offset_px),
		Vector2.LEFT,
	)
	blue_rally.set_march_to(Vector2(-half_distance_px, lane_offset_px))
	_units.append(blue_rally)
	_blue_rally = blue_rally

	var red_rally: Unit = UNIT_SCENE.instantiate()
	add_child(red_rally)
	red_rally.configure(
		"red_rally",
		"red",
		attacker_profile,
		Vector2(-half_distance_px, lane_offset_px),
		Vector2.RIGHT,
	)
	red_rally.set_march_to(Vector2(half_distance_px, lane_offset_px))
	_units.append(red_rally)


func advance_one_tick() -> void:
	super.advance_one_tick()
	_guard_lane_epilogue()


func _guard_lane_epilogue() -> void:
	_guard_pair(_blue_standard, "red_standard")
	_guard_pair(_blue_rally, "red_rally")


func _guard_pair(blue: Unit, red_id: String) -> void:
	if blue == null:
		return
	var red := _find_unit(red_id)
	if red == null:
		return
	if blue.get_state() == Unit.State.ROUTING or blue.is_rallied_hold():
		red.current_order = Unit.Order.HOLD
		red.break_engagement(blue)
		blue.break_engagement(red)
	if blue.is_rallied_hold():
		var away := blue.position - red.position
		if away.length_squared() <= 1.0:
			away = Vector2(0.0, -1.0)
		red.position = (
			blue.position
			+ away.normalized() * Constants.get_float("pursuit_radius_m") * Constants.get_float("px_per_meter")
		)


func _find_unit(unit_id: String) -> Unit:
	for unit in _units:
		if unit.unit_id == unit_id:
			return unit
	return null
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
	print("[Scenario 05] Trace written: %s" % file_path)


func get_blue_standard() -> Unit:
	return _blue_standard


func get_blue_rally() -> Unit:
	return _blue_rally
