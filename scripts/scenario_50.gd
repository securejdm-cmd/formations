class_name Scenario50
extends Scenario01

## S50 — Valley charge (WO-033): downhill into floor vs flat control.

const TRACE_PREFIX := "scenario_50"
const RUN_UP_M := 120.0

@export var use_valley: bool = true

var _cav: Unit = null
var _inf: Unit = null


func _ready() -> void:
	if use_valley:
		# Floor at x=0; walls at ±100m height 20 → grade ≈ 0.20 on sides.
		set_height_field(_HeightField.make_valley(0.0, 100.0, 20.0))
	else:
		set_height_field(_HeightField.make_flat())
	super._ready()
	_ensure_sim_core()


func _spawn_units() -> void:
	var cav_p := UnitProfileLoader.load_profile("test_cavalry")
	var inf_p := UnitProfileLoader.load_profile("test_infantry")
	var px := Constants.get_float("px_per_meter")
	var half := RUN_UP_M * 0.5 * px
	# Cav starts on east wall (high), charges west downhill into floor.
	_cav = UNIT_SCENE.instantiate()
	add_child(_cav)
	_cav.configure("valley_cav", "red", cav_p, Vector2(half, 0.0), Vector2.LEFT)
	_cav.start_from_rest()
	_cav.set_march_to(Vector2(-half - 40.0 * px, 0.0))
	_units.append(_cav)

	_inf = UNIT_SCENE.instantiate()
	add_child(_inf)
	_inf.configure("valley_inf", "blue", inf_p, Vector2(-half * 0.15, 0.0), Vector2.RIGHT)
	_inf.current_order = Unit.Order.HOLD
	_inf._set_state(Unit.State.HOLD)
	_inf.current_speed_m_s = 0.0
	_units.append(_inf)

	for unit in _units:
		unit.set_render_camera(_camera)


func primary_charge() -> Dictionary:
	_ensure_sim_core()
	for ev in _sim_core.last_charge_events:
		if str(ev.get("attacker", "")) == "valley_cav" and bool(ev.get("charged", false)):
			return ev
	return {}


func closing_speed() -> float:
	return float(primary_charge().get("closing_speed", -1.0))


func impact() -> float:
	return float(primary_charge().get("impact", -1.0))


func _write_trace_file() -> void:
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
