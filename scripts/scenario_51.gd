class_name Scenario51
extends Scenario01

## S51 — Cross-slope flank (WO-033): edge + slope compose without special-casing.

const TRACE_PREFIX := "scenario_51"

var observed_edge: String = ""
var slope_push_mod_attacker: float = -1.0
var slope_speed_mult_attacker: float = -1.0


func _ready() -> void:
	# Constant 10% grade along +Y (north high).
	set_height_field(_HeightField.make_cross_slope(0.10))
	super._ready()
	_ensure_sim_core()


func _spawn_units() -> void:
	var inf := UnitProfileLoader.load_profile("test_infantry")
	var cav := UnitProfileLoader.load_profile("test_cavalry")
	var px := Constants.get_float("px_per_meter")

	# Defender faces west; north flank is uphill (+Y).
	var defender := UNIT_SCENE.instantiate()
	add_child(defender)
	defender.configure("hill_def", "blue", inf, Vector2(40.0 * px, 0.0), Vector2.LEFT)
	defender.current_order = Unit.Order.HOLD
	defender._set_state(Unit.State.HOLD)
	defender.current_speed_m_s = 0.0
	_units.append(defender)

	# Flank charge from the high (+Y) side downhill into the defender's flank.
	var flanker := UNIT_SCENE.instantiate()
	add_child(flanker)
	flanker.configure("hill_flank", "red", cav, Vector2(40.0 * px, 110.0 * px), Vector2.UP)
	flanker.start_from_rest()
	flanker.set_order_queue([
		{
			"primitive": "swing_and_charge",
			"params": {"side": "right", "target": "hill_def", "flank_arc_offset_m": 60.0},
			"trigger": {"type": "at_start"},
		},
	])
	_units.append(flanker)

	for unit in _units:
		unit.set_render_camera(_camera)


func advance_one_tick() -> void:
	super.advance_one_tick()
	_observe()


func _observe() -> void:
	_ensure_sim_core()
	for u in _sim_core.units:
		if str(u.unit_id) == "hill_flank":
			slope_push_mod_attacker = u.slope_push_mod
			slope_speed_mult_attacker = u.slope_speed_mult
	for ev in _sim_core.last_charge_events:
		if str(ev.get("attacker", "")) != "hill_flank":
			continue
		if not bool(ev.get("charged", false)):
			continue
		observed_edge = str(ev.get("edge", ""))
		break


func _write_trace_file() -> void:
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
