class_name Scenario41
extends Scenario01

## S41 — Hammer and anvil (WO-031): absolute_hold anvil + swing_and_charge cavalry.

const TRACE_PREFIX := "scenario_41"

var _anvil: Unit = null
var _enemy: Unit = null
var _cavalry: Unit = null

var observed_charge_edge: String = ""
var observed_charge_shock: float = -1.0
var anvil_start: Vector2 = Vector2.ZERO


func _spawn_units() -> void:
	# R25 schema: pitched default; posture fields on units.
	var px := Constants.get_float("px_per_meter")
	var inf := UnitProfileLoader.load_profile("test_infantry")
	var cav := UnitProfileLoader.load_profile("test_cavalry")

	_anvil = UNIT_SCENE.instantiate()
	add_child(_anvil)
	_anvil.configure("anvil", "blue", inf, Vector2.ZERO, Vector2.RIGHT)
	_anvil.starting_posture = "normal"
	_anvil.set_order_queue([
		{"primitive": "absolute_hold", "params": {}, "trigger": {"type": "at_start"}},
	])
	_units.append(_anvil)
	anvil_start = _anvil.position

	_enemy = UNIT_SCENE.instantiate()
	add_child(_enemy)
	_enemy.configure("enemy_line", "red", inf, Vector2(120.0 * px, 0.0), Vector2.LEFT)
	_enemy.set_order_queue([
		{
			"primitive": "advance_to",
			"params": {"point": {"x": -20.0, "y": 0.0}},
			"trigger": {"type": "at_start"},
		},
	])
	_units.append(_enemy)

	_cavalry = UNIT_SCENE.instantiate()
	add_child(_cavalry)
	# Start north of the line with run-up room; swing right around to enemy flank/rear.
	_cavalry.configure("hammer_cav", "blue", cav, Vector2(40.0 * px, -110.0 * px), Vector2.DOWN)
	_cavalry.start_from_rest()
	_cavalry.set_order_queue([
		{
			"primitive": "swing_and_charge",
			"params": {"side": "right", "target": "enemy_line", "flank_arc_offset_m": 100.0},
			"trigger": {"type": "unit_engages", "unit": "anvil"},
		},
	])
	_units.append(_cavalry)

	for unit in _units:
		unit.set_render_camera(_camera)


func _ready() -> void:
	super._ready()
	_ensure_sim_core()
	_sim_core.battle_type = "pitched"
	_sim_core.deployment_zones = {
		"blue": {"x": -80.0, "y": -150.0, "w": 100.0, "h": 300.0},
		"red": {"x": 40.0, "y": -150.0, "w": 100.0, "h": 300.0},
	}
	_sim_core.victory_spec = {"mode": "rout"}


func advance_one_tick() -> void:
	super.advance_one_tick()
	_observe_charge()


func _observe_charge() -> void:
	_ensure_sim_core()
	for ev in _sim_core.last_charge_events:
		if str(ev.get("attacker", "")) != "hammer_cav":
			continue
		if not bool(ev.get("charged", false)):
			continue
		observed_charge_edge = str(ev.get("edge", ""))
		observed_charge_shock = float(ev.get("shock", -1.0))


func _write_trace_file() -> void:
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
	print("[Scenario 41] Trace written: %s" % file_path)


func get_charge_edge() -> String:
	return observed_charge_edge


func get_charge_shock() -> float:
	return observed_charge_shock


func anvil_displacement_m() -> float:
	if _anvil == null:
		return -1.0
	var px := Constants.get_float("px_per_meter")
	return anvil_start.distance_to(_anvil.position) / px
