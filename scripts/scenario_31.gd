class_name Scenario31
extends Scenario01

## S31 — Rotation under contact: spears (A30) vs infantry (A50) wheel 90° while engaged.

const TRACE_PREFIX := "scenario_31"

var _spears: Unit = null
var _inf: Unit = null
var _phase: String = "engage"
var spears_time_s: float = -1.0
var inf_time_s: float = -1.0
var spears_drain: float = -1.0
var inf_drain: float = -1.0
var _wheel_start_tick: int = -1


func _spawn_units() -> void:
	var sp_p := UnitProfileLoader.load_profile("test_spears")
	var inf_p := UnitProfileLoader.load_profile("test_infantry")
	var px := Constants.get_float("px_per_meter")
	var half := 40.0 * px

	_spears = UNIT_SCENE.instantiate()
	add_child(_spears)
	_spears.configure("red_spears", "red", sp_p, Vector2(-half, 0.0), Vector2.RIGHT)
	_spears.set_march_to(Vector2(half + 20.0 * px, 0.0))
	_units.append(_spears)

	_inf = UNIT_SCENE.instantiate()
	add_child(_inf)
	_inf.configure("blue_inf", "blue", inf_p, Vector2(half, 0.0), Vector2.LEFT)
	_inf.set_march_to(Vector2(-half - 20.0 * px, 0.0))
	_units.append(_inf)

	for unit in _units:
		unit.set_render_camera(_camera)


func advance_one_tick() -> void:
	super.advance_one_tick()
	if _phase == "engage":
		if _spears != null and _inf != null and _spears.has_contact_with(_inf):
			_spears.begin_wheel_facing(Vector2.DOWN)
			_inf.begin_wheel_facing(Vector2.DOWN)
			_wheel_start_tick = _sim_tick_count
			_phase = "wheel"
	elif _phase == "wheel":
		if spears_time_s < 0.0 and _spears != null and not _spears.wheeling:
			spears_time_s = (_sim_tick_count - _wheel_start_tick) * CombatResolver.tick_interval()
			spears_drain = _spears.rotate_under_contact_drain_accum
		if inf_time_s < 0.0 and _inf != null and not _inf.wheeling:
			inf_time_s = (_sim_tick_count - _wheel_start_tick) * CombatResolver.tick_interval()
			inf_drain = _inf.rotate_under_contact_drain_accum
		if spears_time_s >= 0.0 and inf_time_s >= 0.0:
			_phase = "done"
			_sim_core.battle_over = true
			_battle_over = true


func _write_trace_file() -> void:
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
	print("[Scenario 31] Trace written: %s" % file_path)
