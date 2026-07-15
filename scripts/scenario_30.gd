class_name Scenario30
extends Scenario01

## S30 — Disengage differential: skirmisher (A80) vs spears (A30) vs identical infantry.

const TRACE_PREFIX := "scenario_30"

var _skirm: Unit = null
var _spears: Unit = null
var _inf_sk: Unit = null
var _inf_sp: Unit = null
var _phase: String = "engage"
var _sk_start_str: float = 100.0
var _sp_start_str: float = 100.0
var _sk_start_coh: float = 100.0
var _sp_start_coh: float = 100.0
var _sk_disengage_start_tick: int = -1
var _sp_disengage_start_tick: int = -1
var skirm_withdraw_s: float = -1.0
var spears_withdraw_s: float = -1.0
var skirm_str_lost: float = -1.0
var spears_str_lost: float = -1.0
var skirm_coh_lost: float = -1.0
var spears_coh_lost: float = -1.0


func _spawn_units() -> void:
	var sk_p := UnitProfileLoader.load_profile("test_skirmisher")
	var sp_p := UnitProfileLoader.load_profile("test_spears")
	var inf_p := UnitProfileLoader.load_profile("test_infantry")
	var px := Constants.get_float("px_per_meter")
	var half := 40.0 * px

	_skirm = UNIT_SCENE.instantiate()
	add_child(_skirm)
	_skirm.configure("red_skirm", "red", sk_p, Vector2(-half, -60.0 * px), Vector2.RIGHT)
	_skirm.set_march_to(Vector2(half + 20.0 * px, -60.0 * px))
	_units.append(_skirm)

	_inf_sk = UNIT_SCENE.instantiate()
	add_child(_inf_sk)
	_inf_sk.configure("blue_inf_sk", "blue", inf_p, Vector2(half, -60.0 * px), Vector2.LEFT)
	_inf_sk.current_order = Unit.Order.HOLD
	_inf_sk._set_state(Unit.State.HOLD)
	_units.append(_inf_sk)

	_spears = UNIT_SCENE.instantiate()
	add_child(_spears)
	_spears.configure("red_spears", "red", sp_p, Vector2(-half, 60.0 * px), Vector2.RIGHT)
	_spears.set_march_to(Vector2(half + 20.0 * px, 60.0 * px))
	_units.append(_spears)

	_inf_sp = UNIT_SCENE.instantiate()
	add_child(_inf_sp)
	_inf_sp.configure("blue_inf_sp", "blue", inf_p, Vector2(half, 60.0 * px), Vector2.LEFT)
	_inf_sp.current_order = Unit.Order.HOLD
	_inf_sp._set_state(Unit.State.HOLD)
	_units.append(_inf_sp)

	for unit in _units:
		unit.set_render_camera(_camera)


func advance_one_tick() -> void:
	super.advance_one_tick()
	if _phase == "engage":
		if (
			_skirm != null and _skirm.has_contact_with(_inf_sk)
			and _spears != null and _spears.has_contact_with(_inf_sp)
		):
			_sk_start_str = _skirm.strength
			_sp_start_str = _spears.strength
			_sk_start_coh = _skirm.cohesion
			_sp_start_coh = _spears.cohesion
			_skirm.set_march_to(Vector2(-200.0 * Constants.get_float("px_per_meter"), -60.0 * Constants.get_float("px_per_meter")))
			_spears.set_march_to(Vector2(-200.0 * Constants.get_float("px_per_meter"), 60.0 * Constants.get_float("px_per_meter")))
			_sk_disengage_start_tick = _sim_tick_count
			_sp_disengage_start_tick = _sim_tick_count
			_phase = "withdraw"
	elif _phase == "withdraw":
		if skirm_withdraw_s < 0.0 and _skirm != null and not _skirm.is_disengaging() and not _skirm.has_contact_with(_inf_sk):
			skirm_withdraw_s = (_sim_tick_count - _sk_disengage_start_tick) * CombatResolver.tick_interval()
			skirm_str_lost = _sk_start_str - _skirm.strength
			skirm_coh_lost = _sk_start_coh - _skirm.cohesion
		if spears_withdraw_s < 0.0 and _spears != null and not _spears.is_disengaging() and not _spears.has_contact_with(_inf_sp):
			spears_withdraw_s = (_sim_tick_count - _sp_disengage_start_tick) * CombatResolver.tick_interval()
			spears_str_lost = _sp_start_str - _spears.strength
			spears_coh_lost = _sp_start_coh - _spears.cohesion
		if skirm_withdraw_s >= 0.0 and spears_withdraw_s >= 0.0:
			_phase = "done"
			# End battle early once both free.
			_sim_core.battle_over = true
			_battle_over = true


func _write_trace_file() -> void:
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
	print("[Scenario 30] Trace written: %s" % file_path)
