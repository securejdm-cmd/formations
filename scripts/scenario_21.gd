class_name Scenario21
extends Scenario01

## Flank (or rear) cavalry charge vs fresh unbraced infantry — expects edge-weighted rout.

const TRACE_PREFIX := "scenario_21"

enum Approach { FLANK, REAR }

@export var approach: Approach = Approach.FLANK

var _cavalry: Unit = null
var _infantry: Unit = null


func _spawn_units() -> void:
	var cav_profile := UnitProfileLoader.load_profile("test_cavalry")
	var inf_profile := UnitProfileLoader.load_profile("test_infantry")
	var px := Constants.get_float("px_per_meter")
	var frontage_m := float(inf_profile.get("formation_frontage_m", Constants.get_float("default_infantry_block_frontage_m")))
	var depth_m := float(inf_profile.get("formation_depth_m", Constants.get_float("default_infantry_block_depth_m")))
	var run_up_m := 120.0

	_infantry = UNIT_SCENE.instantiate()
	add_child(_infantry)
	# Face +X so left flank is toward -Y and rear is -X.
	_infantry.configure("blue_inf", "blue", inf_profile, Vector2.ZERO, Vector2.RIGHT)
	_infantry.current_order = Unit.Order.HOLD
	_infantry._set_state(Unit.State.HOLD)
	_infantry.current_speed_m_s = 0.0
	_units.append(_infantry)

	_cavalry = UNIT_SCENE.instantiate()
	add_child(_cavalry)
	var cav_pos := Vector2.ZERO
	var cav_face := Vector2.RIGHT
	var march_to := Vector2.ZERO
	match approach:
		Approach.FLANK:
			# Approach from the north into the defender LEFT edge.
			cav_pos = Vector2(0.0, -(frontage_m * 0.5 + depth_m * 0.5 + run_up_m) * px)
			cav_face = Vector2.DOWN
			march_to = Vector2(0.0, (frontage_m * 0.25) * px)
		Approach.REAR:
			# Approach from behind into the defender REAR edge.
			cav_pos = Vector2(-(depth_m + run_up_m) * px, 0.0)
			cav_face = Vector2.RIGHT
			march_to = Vector2(depth_m * 0.25 * px, 0.0)
	_cavalry.configure("red_cav", "red", cav_profile, cav_pos, cav_face)
	_cavalry.start_from_rest()
	_cavalry.set_march_to(march_to)
	_units.append(_cavalry)

	for unit in _units:
		unit.set_render_camera(_camera)


func _write_trace_file() -> void:
	var suffix := "_flank" if approach == Approach.FLANK else "_rear"
	var file_path := TRACE_DIR + TRACE_PREFIX + suffix + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
	print("[Scenario 21] Trace written: %s" % file_path)


func get_charge_events() -> Array:
	_ensure_sim_core()
	return _sim_core.last_charge_events.duplicate(true)


func primary_charge_event() -> Dictionary:
	for ev in get_charge_events():
		if str(ev.get("attacker", "")) == "red_cav" and bool(ev.get("charged", false)):
			return ev
	for ev in get_charge_events():
		if str(ev.get("attacker", "")) == "red_cav":
			return ev
	return {}


func infantry_cohesion() -> float:
	if _infantry == null:
		return -1.0
	return _infantry.cohesion


func combat_duration_sec() -> float:
	return get_phase_durations_sec().get("combat_sec", 0.0)
