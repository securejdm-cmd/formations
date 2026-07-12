class_name Scenario07
extends Scenario01

const TRACE_PREFIX := "scenario_07"
const LINE_SPACING_M := 28.0

var _red_left: Unit = null
var _red_center: Unit = null
var _red_right: Unit = null
var _shock_events: Array[Dictionary] = []
var _center_rout_scripted: bool = false


func _spawn_units() -> void:
	var ally_profile := UnitProfileLoader.load_profile("test_infantry").duplicate()
	ally_profile["formation_frontage_m"] = 20.0
	var attacker_profile := UnitProfileLoader.load_profile("test_infantry_push60")
	var defender_profile := UnitProfileLoader.load_profile("test_infantry_push40")
	var px_per_meter := Constants.get_float("px_per_meter")
	var spacing_px := LINE_SPACING_M * px_per_meter
	var half_distance_px := Constants.get_float("scenario_01_start_distance_m") * 0.5 * px_per_meter

	_red_left = UNIT_SCENE.instantiate()
	add_child(_red_left)
	_red_left.configure("red_left", "red", ally_profile, Vector2(-spacing_px, 0.0), Vector2.RIGHT)
	_red_left.current_order = Unit.Order.HOLD
	_units.append(_red_left)

	_red_center = UNIT_SCENE.instantiate()
	add_child(_red_center)
	_red_center.configure("red_center", "red", defender_profile, Vector2.ZERO, Vector2.RIGHT)
	_red_center.current_order = Unit.Order.HOLD
	_units.append(_red_center)

	_red_right = UNIT_SCENE.instantiate()
	add_child(_red_right)
	_red_right.configure("red_right", "red", ally_profile, Vector2(spacing_px, 0.0), Vector2.RIGHT)
	_red_right.current_order = Unit.Order.HOLD
	_units.append(_red_right)

	var blue_striker: Unit = UNIT_SCENE.instantiate()
	add_child(blue_striker)
	blue_striker.configure(
		"blue_striker",
		"blue",
		attacker_profile,
		Vector2(half_distance_px, 0.0),
		Vector2.LEFT,
	)
	blue_striker.set_march_to(Vector2(-half_distance_px, 0.0))
	_units.append(blue_striker)


func advance_one_tick() -> void:
	if _battle_over:
		return

	var tick_interval := CombatResolver.tick_interval()
	_sim_tick_count += 1
	_update_movement(tick_interval)
	_maybe_force_center_rout()
	_process_rout_events()
	_resolve_allied_overlaps()
	_try_passive_engagement()
	_apply_contact_adhesion()
	_assert_no_overlaps()
	_combat_tick()
	_pursuit_tick()
	_apply_contact_adhesion()
	_track_rout_state()
	_update_victory_state(tick_interval)
	var ticks_per_sec := int(Constants.get_float("tick_rate_per_sec"))
	if _sim_tick_count % ticks_per_sec == 0:
		_log_trace_row()
	_check_epilogue_end()


func _apply_neighbor_rout_shock(routing_unit: Unit) -> void:
	var before := {}
	for unit in [_red_left, _red_center, _red_right]:
		if unit != null:
			before[unit.unit_id] = unit.cohesion
	super._apply_neighbor_rout_shock(routing_unit)
	for unit in [_red_left, _red_right]:
		if unit == null or unit == routing_unit:
			continue
		if not before.has(unit.unit_id):
			continue
		var delta: float = float(before[unit.unit_id]) - unit.cohesion
		if delta > 0.0:
			_shock_events.append({
				"victim": unit.unit_id,
				"source": routing_unit.unit_id,
				"drain": delta,
				"cohesion_after": unit.cohesion,
			})


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
	print("[Scenario 07] Trace written: %s" % file_path)


func _maybe_force_center_rout() -> void:
	if _red_center == null or _center_rout_scripted:
		return
	if _sim_tick_count < 400:
		return
	if _red_center.get_state() == Unit.State.ROUTING:
		_center_rout_scripted = true
		return

	_center_rout_scripted = true
	_red_center.enter_rout()
	var radius_m := Constants.get_float("neighbor_rout_shock_radius_m")
	var shock := Constants.get_float("neighbor_rout_shock")
	for ally in [_red_left, _red_right]:
		if ally == null:
			continue
		if CombatResolver.center_distance_m(ally, _red_center) > radius_m:
			continue
		ally.apply_cohesion_drain(shock)
		_log_trace_event(
			"neighbor_rout_shock",
			"victim=%s,source=%s,drain=%.1f" % [ally.unit_id, _red_center.unit_id, shock]
		)
		_shock_events.append({
			"victim": ally.unit_id,
			"source": _red_center.unit_id,
			"drain": shock,
			"cohesion_after": ally.cohesion,
		})
	_red_center.consume_pending_rout_event()


func get_shock_events() -> Array[Dictionary]:
	return _shock_events.duplicate()


func get_red_neighbors() -> Array[Unit]:
	return [_red_left, _red_right]
