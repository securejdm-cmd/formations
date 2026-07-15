class_name Scenario35
extends Scenario01

## S35 — Agility-isolate disengage (R20 / Gate 2).
## Two profiles identical EXCEPT Agility (A30 vs A80); same armor/class/damage/mass/profile.

const TRACE_PREFIX := "scenario_35"

var _low: Unit = null
var _high: Unit = null
var _atk_low: Unit = null
var _atk_high: Unit = null
var _phase: String = "engage"
var _low_start_str: float = 100.0
var _high_start_str: float = 100.0
var _low_start_tick: int = -1
var _high_start_tick: int = -1
var low_withdraw_s: float = -1.0
var high_withdraw_s: float = -1.0
var low_str_lost: float = -1.0
var high_str_lost: float = -1.0
var _low_was_disengaging: bool = false
var _high_was_disengaging: bool = false


func _spawn_units() -> void:
	var base := UnitProfileLoader.load_profile("test_infantry").duplicate(true)
	var p_low := base.duplicate(true)
	p_low["id"] = "test_agility_low"
	p_low["display_name"] = "Agility 30"
	p_low["agility"] = 30.0
	var p_high := base.duplicate(true)
	p_high["id"] = "test_agility_high"
	p_high["display_name"] = "Agility 80"
	p_high["agility"] = 80.0
	var atk := UnitProfileLoader.load_profile("test_infantry")
	var px := Constants.get_float("px_per_meter")
	var half := 40.0 * px

	_low = UNIT_SCENE.instantiate()
	add_child(_low)
	_low.configure("red_a30", "red", p_low, Vector2(-half, -60.0 * px), Vector2.RIGHT)
	_low.set_march_to(Vector2(half + 20.0 * px, -60.0 * px))
	_units.append(_low)

	_atk_low = UNIT_SCENE.instantiate()
	add_child(_atk_low)
	_atk_low.configure("blue_atk_a30", "blue", atk, Vector2(half, -60.0 * px), Vector2.LEFT)
	_atk_low.current_order = Unit.Order.HOLD
	_atk_low._set_state(Unit.State.HOLD)
	_units.append(_atk_low)

	_high = UNIT_SCENE.instantiate()
	add_child(_high)
	_high.configure("red_a80", "red", p_high, Vector2(-half, 60.0 * px), Vector2.RIGHT)
	_high.set_march_to(Vector2(half + 20.0 * px, 60.0 * px))
	_units.append(_high)

	_atk_high = UNIT_SCENE.instantiate()
	add_child(_atk_high)
	_atk_high.configure("blue_atk_a80", "blue", atk, Vector2(half, 60.0 * px), Vector2.LEFT)
	_atk_high.current_order = Unit.Order.HOLD
	_atk_high._set_state(Unit.State.HOLD)
	_units.append(_atk_high)

	for unit in _units:
		unit.set_render_camera(_camera)


func advance_one_tick() -> void:
	_maybe_script_orders()
	super.advance_one_tick()
	_maybe_collect_results()


func _maybe_script_orders() -> void:
	if _phase != "engage":
		return
	if (
		_low != null and _low.has_contact_with(_atk_low)
		and _high != null and _high.has_contact_with(_atk_high)
	):
		_low_start_str = _low.strength
		_high_start_str = _high.strength
		_low.set_march_to(Vector2(-200.0 * Constants.get_float("px_per_meter"), -60.0 * Constants.get_float("px_per_meter")))
		_high.set_march_to(Vector2(-200.0 * Constants.get_float("px_per_meter"), 60.0 * Constants.get_float("px_per_meter")))
		_low_start_tick = _sim_tick_count
		_high_start_tick = _sim_tick_count
		_phase = "withdraw"


func _maybe_collect_results() -> void:
	if _phase != "withdraw":
		return
	if _low != null:
		if _low.is_disengaging():
			_low_was_disengaging = true
		elif _low_was_disengaging and low_withdraw_s < 0.0:
			low_withdraw_s = (_sim_tick_count - _low_start_tick) * CombatResolver.tick_interval()
			low_str_lost = _low_start_str - _low.strength
	if _high != null:
		if _high.is_disengaging():
			_high_was_disengaging = true
		elif _high_was_disengaging and high_withdraw_s < 0.0:
			high_withdraw_s = (_sim_tick_count - _high_start_tick) * CombatResolver.tick_interval()
			high_str_lost = _high_start_str - _high.strength
	if low_withdraw_s >= 0.0 and high_withdraw_s >= 0.0:
		_phase = "done"
		if _sim_core != null:
			_sim_core.battle_over = true
		_battle_over = true


func str_loss_ratio() -> float:
	if high_str_lost <= 0.0:
		return 0.0
	return low_str_lost / high_str_lost


func duration_ratio() -> float:
	if high_withdraw_s <= 0.0:
		return 0.0
	return low_withdraw_s / high_withdraw_s


func _write_trace_file() -> void:
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
	print("[Scenario 35] Trace written: %s" % file_path)
	print(
		"[Scenario 35] SUMMARY | a30_t=%.2fs lost=%.2f a80_t=%.2fs lost=%.2f str_ratio=%.2f dur_ratio=%.2f"
		% [low_withdraw_s, low_str_lost, high_withdraw_s, high_str_lost, str_loss_ratio(), duration_ratio()]
	)
