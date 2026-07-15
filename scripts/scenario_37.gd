class_name Scenario37
extends Scenario01

## S37 — Slope charge (R6 thesis): identical cav run-ups downhill vs uphill.
## NO charge-specific slope code — difference must emerge from movement alone.

const TRACE_PREFIX := "scenario_37"
const RUN_UP_M := 120.0

var _cav_down: Unit = null
var _inf_down: Unit = null
var _cav_up: Unit = null
var _inf_up: Unit = null


func _ready() -> void:
	ensure_test_hill()
	super._ready()


func _spawn_units() -> void:
	var cav_p := UnitProfileLoader.load_profile("test_cavalry")
	var inf_p := UnitProfileLoader.load_profile("test_infantry")
	var px := Constants.get_float("px_per_meter")
	var half := RUN_UP_M * 0.5 * px
	var lane_dn := -80.0 * px
	var lane_up := 80.0 * px

	# Downhill (mid-ramp): cav starts uphill (east), rides west.
	var contact_dn := 0.0
	_cav_down = UNIT_SCENE.instantiate()
	add_child(_cav_down)
	_cav_down.configure("red_cav_down", "red", cav_p, Vector2(contact_dn + half, lane_dn), Vector2.LEFT)
	_cav_down.start_from_rest()
	_cav_down.set_march_to(Vector2(contact_dn - half - 40.0 * px, lane_dn))
	_units.append(_cav_down)

	_inf_down = UNIT_SCENE.instantiate()
	add_child(_inf_down)
	_inf_down.configure("blue_inf_down", "blue", inf_p, Vector2(contact_dn - half, lane_dn), Vector2.RIGHT)
	_inf_down.current_order = Unit.Order.HOLD
	_inf_down._set_state(Unit.State.HOLD)
	_inf_down.current_speed_m_s = 0.0
	_units.append(_inf_down)

	# Uphill: cav starts downhill (west), rides east.
	var contact_up := 0.0
	_cav_up = UNIT_SCENE.instantiate()
	add_child(_cav_up)
	_cav_up.configure("red_cav_up", "red", cav_p, Vector2(contact_up - half, lane_up), Vector2.RIGHT)
	_cav_up.start_from_rest()
	_cav_up.set_march_to(Vector2(contact_up + half + 40.0 * px, lane_up))
	_units.append(_cav_up)

	_inf_up = UNIT_SCENE.instantiate()
	add_child(_inf_up)
	_inf_up.configure("blue_inf_up", "blue", inf_p, Vector2(contact_up + half, lane_up), Vector2.LEFT)
	_inf_up.current_order = Unit.Order.HOLD
	_inf_up._set_state(Unit.State.HOLD)
	_inf_up.current_speed_m_s = 0.0
	_units.append(_inf_up)

	for unit in _units:
		unit.set_render_camera(_camera)


func _charge_for(attacker_id: String) -> Dictionary:
	_ensure_sim_core()
	for ev in _sim_core.last_charge_events:
		if str(ev.get("attacker", "")) == attacker_id and bool(ev.get("charged", false)):
			return ev
	for ev in _sim_core.last_charge_events:
		if str(ev.get("attacker", "")) == attacker_id:
			return ev
	return {}


func downhill_charge() -> Dictionary:
	return _charge_for("red_cav_down")


func uphill_charge() -> Dictionary:
	return _charge_for("red_cav_up")


func impact_ratio() -> float:
	var d: float = float(downhill_charge().get("impact", 0.0))
	var u: float = float(uphill_charge().get("impact", 0.0))
	if u <= 0.0:
		return 0.0
	return d / u


func _write_trace_file() -> void:
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
	var dn := downhill_charge()
	var up := uphill_charge()
	print("[Scenario 37] Trace written: %s" % file_path)
	print(
		"[Scenario 37] SUMMARY | down_v=%.3f/i=%.3f up_v=%.3f/i=%.3f ratio=%.3f"
		% [
			float(dn.get("closing_speed", 0.0)),
			float(dn.get("impact", 0.0)),
			float(up.get("closing_speed", 0.0)),
			float(up.get("impact", 0.0)),
			impact_ratio(),
		]
	)
