class_name Scenario32
extends Scenario01

## S32 — Hit and run: cav charges braced spears, disengages, withdraws ≥150m, re-charges.

const TRACE_PREFIX := "scenario_32"

var _cavalry: Unit = null
var _spears: Unit = null
var _phase: String = "charge1"
var strength_after_fail: float = -1.0
var strength_after_disengage: float = -1.0
var strength_after_recharge: float = -1.0
var second_charge_impact: float = -1.0
var _withdraw_target: Vector2 = Vector2.ZERO
var _recharge_ordered: bool = false
var _hold_victory: bool = true


func _spawn_units() -> void:
	var cav_p := UnitProfileLoader.load_profile("test_cavalry")
	var sp_p := UnitProfileLoader.load_profile("test_spears")
	var px := Constants.get_float("px_per_meter")
	var run_up_m := 180.0
	var half := run_up_m * 0.5 * px

	_cavalry = UNIT_SCENE.instantiate()
	add_child(_cavalry)
	_cavalry.configure("red_cav", "red", cav_p, Vector2(-half, 0.0), Vector2.RIGHT)
	_cavalry.start_from_rest()
	_cavalry.set_march_to(Vector2(half + 40.0 * px, 0.0))
	_units.append(_cavalry)

	_spears = UNIT_SCENE.instantiate()
	add_child(_spears)
	_spears.configure("blue_spears", "blue", sp_p, Vector2(half, 0.0), Vector2.LEFT)
	_spears.current_order = Unit.Order.HOLD
	_spears._set_state(Unit.State.HOLD)
	_spears.current_speed_m_s = 0.0
	_units.append(_spears)

	_withdraw_target = Vector2(-half - 220.0 * px, 0.0)
	for unit in _units:
		unit.set_render_camera(_camera)


func advance_one_tick() -> void:
	_maybe_script_orders()
	super.advance_one_tick()
	# Suppress victory until the scripted re-charge completes.
	if _hold_victory and _sim_core != null and _phase != "done":
		if _sim_core.battle_over or _battle_over or int(_sim_core.battle_phase) != int(_SimBattleCore.BattlePhase.ACTIVE):
			_sim_core.battle_over = false
			_battle_over = false
			_fast_finish_handled = false
			_sim_core.watch_epilogue = false
			_sim_core.victory_delay_accum = 0.0
			_sim_core.battle_phase = _SimBattleCore.BattlePhase.ACTIVE
			_battle_phase = BattlePhase.ACTIVE
			_sim_core.winner_id = ""
			_victory_team = ""
	_maybe_collect()


func _maybe_script_orders() -> void:
	if _cavalry == null or _spears == null:
		return
	match _phase:
		"charge1":
			if _cavalry.has_contact_with(_spears):
				strength_after_fail = _cavalry.strength
				_cavalry.set_march_to(_withdraw_target)
				_phase = "disengage"
		"disengage":
			pass
		"withdraw":
			var dist: float = ChargeCombat.distance_m(_cavalry, _spears)
			# Need full charge-commit runway (150m) plus margin so second impact is full gait.
			if dist >= 200.0 and not _recharge_ordered:
				_ensure_sim_core()
				_sim_core.clear_charge_pair_latch("red_cav", "blue_spears")
				_sim_core.clear_charge_pair_latch("blue_spears", "red_cav")
				_cavalry.set_march_to(_spears.position + Vector2(40.0 * Constants.get_float("px_per_meter"), 0.0))
				_recharge_ordered = true
				_phase = "recharge"


func _maybe_collect() -> void:
	if _cavalry == null:
		return
	match _phase:
		"disengage":
			if not _cavalry.is_disengaging() and not _cavalry.has_contact_with(_spears):
				strength_after_disengage = _cavalry.strength
				_phase = "withdraw"
		"recharge":
			var events: Array = get_charge_events()
			var charged_count := 0
			var last_impact := -1.0
			for ev in events:
				if str(ev.get("attacker", "")) == "red_cav" and bool(ev.get("charged", false)):
					charged_count += 1
					last_impact = float(ev.get("impact", -1.0))
			if charged_count >= 2:
				second_charge_impact = last_impact
				strength_after_recharge = _cavalry.strength
				_phase = "done"
				_hold_victory = false
				_sim_core.battle_over = true
				_battle_over = true


func get_charge_events() -> Array:
	_ensure_sim_core()
	return _sim_core.last_charge_events.duplicate(true)


func _write_trace_file() -> void:
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
	print("[Scenario 32] Trace written: %s" % file_path)
