class_name Scenario49
extends Scenario01

## S49 — Ridge line (WO-033): defender on crest vs climber; optional flat control.

const TRACE_PREFIX := "scenario_49"

@export var use_ridge: bool = true

var _defender: Unit = null
var _attacker: Unit = null
var strength_at_rout: float = -1.0
var routed_id: String = ""


func _ready() -> void:
	if use_ridge:
		# Crest plateau east of x=0; 12% west face (general multi-feature field).
		set_height_field(
			_HeightField.make_from_features(
				[
					{"type": "ramp_x", "x0": -150.0, "x1": 0.0, "grade": 0.15},
					{"type": "gaussian_hill", "cx": 90.0, "cy": 50.0, "sigma": 40.0, "peak": 10.0},
				],
				-1.0,
				"ridge_line"
			)
		)
	else:
		set_height_field(_HeightField.make_flat())
	super._ready()
	_ensure_sim_core()
	_sim_core.battle_type = "pitched"


func _spawn_units() -> void:
	var profile := UnitProfileLoader.load_profile("test_infantry")
	var px := Constants.get_float("px_per_meter")
	# Mirror S39 geometry on the general field: defender on high ground.
	_defender = UNIT_SCENE.instantiate()
	add_child(_defender)
	_defender.configure("ridge_def", "blue", profile, Vector2(80.0 * px, 0.0), Vector2.LEFT)
	_defender.current_order = Unit.Order.HOLD
	_defender._set_state(Unit.State.HOLD)
	_defender.current_speed_m_s = 0.0
	_units.append(_defender)

	_attacker = UNIT_SCENE.instantiate()
	add_child(_attacker)
	_attacker.configure("ridge_atk", "red", profile, Vector2(-120.0 * px, 0.0), Vector2.RIGHT)
	_attacker.set_march_to(Vector2(100.0 * px, 0.0))
	_units.append(_attacker)

	for unit in _units:
		unit.set_render_camera(_camera)


func _on_first_rout() -> void:
	if _first_rout_tick >= 0:
		return
	for unit in _units:
		if unit.get_state() == Unit.State.ROUTING:
			strength_at_rout = unit.strength
			routed_id = unit.unit_id
			break
	_first_rout_tick = _sim_tick_count


func defender_won() -> bool:
	return get_winner_id() == "ridge_def" or routed_id == "ridge_atk"


func combat_sec() -> float:
	return float(get_phase_durations_sec().get("combat_sec", -1.0))


func _write_trace_file() -> void:
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
