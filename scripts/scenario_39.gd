class_name Scenario39
extends Scenario01

## S39 — High ground composite: defender holds crest; identical attacker climbs.

const TRACE_PREFIX := "scenario_39"

var _defender: Unit = null
var _attacker: Unit = null
var _strength_at_rout: float = -1.0
var _routed_id: String = ""


func _ready() -> void:
	ensure_test_hill()
	super._ready()


func _spawn_units() -> void:
	var profile := UnitProfileLoader.load_profile("test_infantry")
	var px := Constants.get_float("px_per_meter")
	# Defender on crest; attacker climbs from west.
	_defender = UNIT_SCENE.instantiate()
	add_child(_defender)
	_defender.configure("blue_hold", "blue", profile, Vector2(0.0, 0.0), Vector2.LEFT)
	_defender.current_order = Unit.Order.HOLD
	_defender._set_state(Unit.State.HOLD)
	_defender.current_speed_m_s = 0.0
	_units.append(_defender)

	_attacker = UNIT_SCENE.instantiate()
	add_child(_attacker)
	_attacker.configure("red_climb", "red", profile, Vector2(-160.0 * px, 0.0), Vector2.RIGHT)
	_attacker.set_march_to(Vector2(40.0 * px, 0.0))
	_units.append(_attacker)

	for unit in _units:
		unit.set_render_camera(_camera)


func _on_first_rout() -> void:
	if _first_rout_tick >= 0:
		return
	for unit in _units:
		if unit.get_state() == Unit.State.ROUTING:
			_strength_at_rout = unit.strength
			_routed_id = unit.unit_id
			break
	_first_rout_tick = _sim_tick_count


func defender_won() -> bool:
	return get_winner_id() == "blue_hold" or _routed_id == "red_climb"


func strength_at_rout() -> float:
	return _strength_at_rout


func get_routed_id() -> String:
	return _routed_id


func _write_trace_file() -> void:
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
	var phases := get_phase_durations_sec()
	print("[Scenario 39] Trace written: %s" % file_path)
	print(
		"[Scenario 39] SUMMARY | winner=%s | combat=%.1fs | routed=%s | str_at_rout=%.2f"
		% [
			get_winner_id(),
			float(phases.get("combat_sec", -1.0)),
			_routed_id,
			_strength_at_rout,
		]
	)
