class_name OrderExecutor
extends RefCounted

## WO-031 headless order queue executor. Pure no-op when no queues / horns.

const _Schema := preload("res://scripts/orders/order_schema.gd")
const _Charge := preload("res://scripts/charge_combat.gd")

## WO-033 Task 0 micro-profile counters (accumulate while TickProfiler.enabled).
static var prof_tick_entries: int = 0
static var prof_trigger_evals: int = 0
static var prof_step_checks: int = 0
static var prof_order_state_emits: int = 0
static var prof_per_unit_allocs: int = 0

var _core = null  # SimBattleCore
var _active: bool = false
var _last_trace_sec: int = -1


static func reset_profile_counters() -> void:
	prof_tick_entries = 0
	prof_trigger_evals = 0
	prof_step_checks = 0
	prof_order_state_emits = 0
	prof_per_unit_allocs = 0


func bind(core) -> void:
	_core = core


func is_active() -> bool:
	return _active


func activate_if_needed() -> void:
	if _core == null:
		return
	if _active:
		return
	for unit in _core.units:
		if unit == null:
			continue
		if not unit.order_queue_steps.is_empty():
			_active = true
			return
	if not _core.horn_schedule.is_empty() or not _core.horn_sounded.is_empty():
		_active = true


func tick(delta: float) -> void:
	if _core == null:
		return
	activate_if_needed()
	if not _active:
		return
	prof_tick_entries += 1
	_tick_horn_schedule()
	for unit in _core.units:
		if unit == null:
			continue
		if unit.get_state() == Unit.State.REMOVED or unit.get_state() == Unit.State.ROUTING:
			continue
		if unit.horn_retreating:
			_tick_horn_retreat(unit, delta)
			continue
		_ensure_runtime(unit)
		_tick_unit(unit, delta)
	_maybe_log_order_traces()


func _ensure_runtime(unit) -> void:
	if unit.order_runtime_ready:
		return
	unit.order_runtime_ready = true
	unit.order_step_index = 0
	unit.order_phase = _Schema.PHASE_IDLE
	unit.order_primitive = ""
	unit.order_prim_phase = ""
	unit.order_trigger_type = ""
	unit.order_trigger_live = false
	unit.post_anchor = unit.position
	if unit.order_queue_steps.is_empty():
		unit.order_phase = _Schema.PHASE_TERMINAL
		return
	_enter_step(unit, 0)


func _enter_step(unit, idx: int) -> void:
	if idx >= unit.order_queue_steps.size():
		_enter_hold_terminal(unit)
		return
	unit.order_step_index = idx
	var step: Dictionary = unit.order_queue_steps[idx]
	var trigger: Dictionary = step.get("trigger", {})
	if trigger.is_empty():
		trigger = {"type": _Schema.TRIG_AT_START}
	unit.order_trigger_type = str(trigger.get("type", _Schema.TRIG_AT_START))
	unit.order_trigger_live = false
	unit.order_primitive = str(step.get("primitive", ""))
	unit.order_prim_phase = ""
	unit.order_params = step.get("params", {}).duplicate(true)
	unit.order_trigger = trigger.duplicate(true)
	if _eval_trigger(unit, trigger):
		unit.order_trigger_live = true
		_begin_primitive(unit)
	else:
		unit.order_phase = _Schema.PHASE_WAITING


func _tick_unit(unit, delta: float) -> void:
	prof_step_checks += 1
	match unit.order_phase:
		_Schema.PHASE_WAITING:
			unit.order_trigger_live = _eval_trigger(unit, unit.order_trigger)
			if unit.order_trigger_live:
				_begin_primitive(unit)
		_Schema.PHASE_EXECUTING:
			_tick_primitive(unit, delta)
		_Schema.PHASE_TERMINAL, _Schema.PHASE_IDLE:
			_tick_terminal(unit, delta)


func _begin_primitive(unit) -> void:
	unit.order_phase = _Schema.PHASE_EXECUTING
	var prim: String = unit.order_primitive
	_core.note_order_started(str(unit.unit_id), prim)
	match prim:
		_Schema.PRIM_ADVANCE_TO:
			var pt: Vector2 = _Schema.point_to_px(unit.order_params.get("point", {}))
			unit.absolute_hold = false
			unit.set_march_to(pt)
			unit.order_prim_phase = "marching"
		_Schema.PRIM_HOLD:
			unit.absolute_hold = false
			unit.current_order = Unit.Order.HOLD
			unit.charge_committed = false
			if unit.get_contact_partners().is_empty():
				unit._set_state(Unit.State.HOLD)
			unit.order_prim_phase = "holding"
			# Non-final hold completes immediately so the queue can advance.
			if unit.order_step_index + 1 < unit.order_queue_steps.size():
				_complete_step(unit)
			else:
				unit.order_phase = _Schema.PHASE_TERMINAL
		_Schema.PRIM_ABSOLUTE_HOLD:
			unit.absolute_hold = true
			unit.post_anchor = unit.position
			unit.current_order = Unit.Order.HOLD
			unit.charge_committed = false
			unit.current_speed_m_s = 0.0
			if unit.get_contact_partners().is_empty():
				unit._set_state(Unit.State.HOLD)
			unit.order_prim_phase = "absolute"
			if unit.order_step_index + 1 < unit.order_queue_steps.size():
				_complete_step(unit)
			else:
				unit.order_phase = _Schema.PHASE_TERMINAL
				unit.absolute_hold = true
		_Schema.PRIM_ATTACK_NEAREST:
			unit.absolute_hold = false
			unit.order_prim_phase = "seeking"
			_seek_nearest(unit)
		_Schema.PRIM_ATTACK_TARGET:
			unit.absolute_hold = false
			unit.order_prim_phase = "seeking"
			_seek_named(unit, str(unit.order_params.get("unit", "")))
		_Schema.PRIM_FEIGN_RETREAT:
			unit.absolute_hold = false
			_start_feign(unit)
		_Schema.PRIM_FLANK_MOVE:
			unit.absolute_hold = false
			_start_flank_move(unit)
		_Schema.PRIM_SWING_AND_CHARGE:
			unit.absolute_hold = false
			_start_swing_and_charge(unit)
		_:
			_enter_hold_terminal(unit)


func _tick_primitive(unit, delta: float) -> void:
	match unit.order_primitive:
		_Schema.PRIM_ADVANCE_TO:
			if unit.get_state() == Unit.State.HOLD and not unit.disengaging:
				var px := Constants.get_float("px_per_meter")
				if unit.position.distance_to(unit.march_target) <= px * 0.5:
					_complete_step(unit)
		_Schema.PRIM_ATTACK_NEAREST:
			_tick_attack_seek(unit, true)
		_Schema.PRIM_ATTACK_TARGET:
			_tick_attack_seek(unit, false)
		_Schema.PRIM_FEIGN_RETREAT:
			_tick_feign(unit, delta)
		_Schema.PRIM_FLANK_MOVE:
			_tick_flank(unit)
		_Schema.PRIM_SWING_AND_CHARGE:
			_tick_swing(unit)
		_:
			pass


func _tick_terminal(unit, _delta: float) -> void:
	if unit.absolute_hold:
		# Face-only gravity; position locked to post (push may still shift — restored after move).
		return
	if unit.order_primitive == _Schema.PRIM_ATTACK_NEAREST:
		_tick_attack_seek(unit, true)
	elif unit.order_primitive == _Schema.PRIM_ATTACK_TARGET:
		_tick_attack_seek(unit, false)


func _complete_step(unit) -> void:
	var next: int = unit.order_step_index + 1
	if next >= unit.order_queue_steps.size():
		_enter_hold_terminal(unit)
	else:
		_enter_step(unit, next)


func _enter_hold_terminal(unit) -> void:
	unit.absolute_hold = false
	unit.order_phase = _Schema.PHASE_TERMINAL
	unit.order_primitive = _Schema.PRIM_HOLD
	unit.order_prim_phase = "hold"
	unit.current_order = Unit.Order.HOLD
	unit.charge_committed = false
	if unit.get_contact_partners().is_empty() and not unit.disengaging:
		unit._set_state(Unit.State.HOLD)


func _seek_nearest(unit) -> void:
	var target = _nearest_living_enemy(unit)
	if target == null:
		_complete_step(unit)
		return
	unit.order_attack_target_id = str(target.unit_id)
	unit.set_march_to(target.position)


func _seek_named(unit, tid: String) -> void:
	var target = _unit_by_id(tid)
	if target == null or not _is_living_enemy(unit, target):
		_complete_step(unit)
		return
	unit.order_attack_target_id = tid
	unit.set_march_to(target.position)


func _tick_attack_seek(unit, nearest: bool) -> void:
	var tid: String = str(unit.order_attack_target_id)
	var target = _unit_by_id(tid) if not tid.is_empty() else null
	if nearest:
		if target == null or not _is_living_enemy(unit, target):
			target = _nearest_living_enemy(unit)
			if target == null:
				_complete_step(unit)
				return
			unit.order_attack_target_id = str(target.unit_id)
	else:
		if target == null or not _is_living_enemy(unit, target):
			_complete_step(unit)
			return
	if unit.has_contact_with(target):
		unit.order_prim_phase = "engaged"
		# Stay engaged — step remains executing/terminal until target routs.
		if unit.order_phase == _Schema.PHASE_EXECUTING:
			unit.order_phase = _Schema.PHASE_TERMINAL
		return
	unit.set_march_to(target.position)


func _start_feign(unit) -> void:
	## Combat Core §5 / WO-033: fighting withdrawal if engaged, then retire dist,
	## deception window hides "still ordered" from enemy-visible state.
	var dist: float = float(unit.order_params.get("dist", 40.0))
	unit.feign_dist_m = dist
	unit.feign_start_pos = unit.position
	unit.feign_active = true
	unit.feign_deception_remaining_s = Constants.get_float("feign_deception_window_s")
	# Sec 5 fighting-withdrawal cost when breaking contact.
	if not unit.get_contact_partners().is_empty() and not unit.disengaging:
		if unit.has_method("begin_disengage"):
			unit.begin_disengage()
	var away: Vector2 = -unit.facing.normalized()
	if away.length_squared() < 0.0001:
		away = Vector2.LEFT if str(unit.team_id) == "red" else Vector2.RIGHT
	var px := Constants.get_float("px_per_meter")
	var dest: Vector2 = unit.position + away * dist * px
	unit.order_prim_phase = "retreating"
	unit.set_march_to(dest)


func _tick_feign(unit, delta: float) -> void:
	if unit.feign_deception_remaining_s > 0.0:
		unit.feign_deception_remaining_s = maxf(0.0, unit.feign_deception_remaining_s - delta)
	var drain: float = _Schema.ordered_retreat_drain_per_sec(unit) * delta
	unit.apply_cohesion_drain(drain)
	# Genuine rout can interrupt a low-skill feign (counter-play).
	if unit.get_state() == Unit.State.ROUTING:
		unit.feign_active = false
		unit.feign_deception_remaining_s = 0.0
		unit.order_phase = _Schema.PHASE_TERMINAL
		return
	if unit.order_prim_phase == "retreating":
		var px := Constants.get_float("px_per_meter")
		var travelled: float = unit.feign_start_pos.distance_to(unit.position) / px
		if travelled >= unit.feign_dist_m - 0.5 or unit.get_state() == Unit.State.HOLD:
			_finish_feign_turn(unit)


func _finish_feign_turn(unit) -> void:
	## Turn and fight: clear feign flags (enemy now sees ordered state).
	unit.feign_active = false
	unit.feign_deception_remaining_s = 0.0
	unit.order_primitive = _Schema.PRIM_ATTACK_NEAREST
	unit.order_phase = _Schema.PHASE_TERMINAL
	unit.order_prim_phase = "seeking"
	_seek_nearest(unit)


func _flank_offset_m(params: Dictionary) -> float:
	if params.has("flank_arc_offset_m"):
		return float(params["flank_arc_offset_m"])
	return Constants.get_float("flank_arc_offset_m")


func _build_flank_waypoints(unit, side: String, final_point: Vector2, offset_m: float) -> Array:
	var start: Vector2 = unit.position
	var to_final: Vector2 = final_point - start
	var along: Vector2 = to_final.normalized() if to_final.length_squared() > 0.0001 else unit.facing.normalized()
	var left: Vector2 = Vector2(-along.y, along.x)
	var side_sign: float = 1.0 if side == "left" else -1.0
	# "left"/"right" from the unit's march perspective toward the point.
	var px := Constants.get_float("px_per_meter")
	var mid: Vector2 = start + to_final * 0.5 + left * side_sign * offset_m * px
	return [mid, final_point]


func _start_flank_move(unit) -> void:
	var side: String = str(unit.order_params.get("side", "left"))
	var final_pt: Vector2 = _Schema.point_to_px(unit.order_params.get("point", {}))
	var offset: float = _flank_offset_m(unit.order_params)
	unit.flank_waypoints = _build_flank_waypoints(unit, side, final_pt, offset)
	unit.flank_wp_index = 0
	unit.order_prim_phase = "arc"
	unit.set_march_to(unit.flank_waypoints[0])


func _tick_flank(unit) -> void:
	var px := Constants.get_float("px_per_meter")
	if unit.flank_wp_index >= unit.flank_waypoints.size():
		_complete_step(unit)
		return
	var dest: Vector2 = unit.flank_waypoints[unit.flank_wp_index]
	if unit.position.distance_to(dest) <= px * 1.0 or (
		unit.get_state() == Unit.State.HOLD and unit.current_order == Unit.Order.MARCH_TO
	):
		unit.flank_wp_index += 1
		if unit.flank_wp_index >= unit.flank_waypoints.size():
			unit.current_order = Unit.Order.HOLD
			_complete_step(unit)
			return
		unit.set_march_to(unit.flank_waypoints[unit.flank_wp_index])
	else:
		unit.set_march_to(dest)


func _start_swing_and_charge(unit) -> void:
	var side: String = str(unit.order_params.get("side", "left"))
	var tid: String = str(unit.order_params.get("target", ""))
	unit.order_attack_target_id = tid
	var target = _unit_by_id(tid)
	if target == null:
		_complete_step(unit)
		return
	var offset: float = _flank_offset_m(unit.order_params)
	# Staging point near target's flank/rear relative to side.
	var px := Constants.get_float("px_per_meter")
	var to_self: Vector2 = unit.position - target.position
	var along: Vector2 = to_self.normalized() if to_self.length_squared() > 0.0001 else -target.facing
	var left: Vector2 = Vector2(-along.y, along.x)
	var side_sign: float = 1.0 if side == "left" else -1.0
	# For rear seal, bias staging behind the target.
	var rear: Vector2 = -target.facing.normalized()
	var staging: Vector2 = (
		target.position
		+ rear * (offset * 0.6) * px
		+ left * side_sign * offset * px
	)
	unit.flank_waypoints = _build_flank_waypoints(unit, side, staging, offset)
	unit.flank_wp_index = 0
	unit.order_prim_phase = "arc"
	unit.set_march_to(unit.flank_waypoints[0])


func _tick_swing(unit) -> void:
	var tid: String = str(unit.order_attack_target_id)
	var target = _unit_by_id(tid)
	if target == null or not _is_living_enemy(unit, target):
		_complete_step(unit)
		return
	var px := Constants.get_float("px_per_meter")
	if unit.order_prim_phase == "arc":
		if unit.flank_wp_index >= unit.flank_waypoints.size():
			unit.order_prim_phase = "charge"
			unit.set_march_to(target.position)
			return
		var dest: Vector2 = unit.flank_waypoints[unit.flank_wp_index]
		if unit.position.distance_to(dest) <= px * 2.0:
			unit.flank_wp_index += 1
			if unit.flank_wp_index >= unit.flank_waypoints.size():
				unit.order_prim_phase = "charge"
				unit.set_march_to(target.position)
			else:
				unit.set_march_to(unit.flank_waypoints[unit.flank_wp_index])
		else:
			unit.set_march_to(dest)
	elif unit.order_prim_phase == "charge":
		unit.set_march_to(target.position)
		if unit.has_contact_with(target):
			unit.order_prim_phase = "impacted"
			unit.order_phase = _Schema.PHASE_TERMINAL


func _tick_horn_schedule() -> void:
	var t_sec: float = _core.sim_tick_count * (1.0 / Constants.get_float("tick_rate_per_sec"))
	for team in _core.horn_schedule.keys():
		if bool(_core.horn_sounded.get(team, false)):
			continue
		var at: float = float(_core.horn_schedule[team])
		if t_sec + 1e-6 >= at:
			_sound_horn(str(team))


func _sound_horn(team: String) -> void:
	if bool(_core.horn_sounded.get(team, false)):
		return
	_core.horn_sounded[team] = true
	_core.log_trace_event("horn_sounded", "team=%s" % team)
	for unit in _core.units:
		if unit == null or str(unit.team_id) != team:
			continue
		if unit.get_state() == Unit.State.REMOVED or unit.get_state() == Unit.State.ROUTING:
			continue
		_abort_to_horn(unit)


func _abort_to_horn(unit) -> void:
	unit.order_queue_steps.clear()
	unit.order_phase = _Schema.PHASE_TERMINAL
	unit.order_primitive = "horn_withdraw"
	unit.order_prim_phase = "withdrawing"
	unit.absolute_hold = false
	unit.horn_retreating = true
	unit._braced = false
	unit.auto_engage_locked = true
	var edge: Vector2 = _own_edge_point(unit)
	_core.horn_disengage_start_str[str(unit.unit_id)] = float(unit.strength)
	unit.set_march_to(edge)


func _tick_horn_retreat(unit, delta: float) -> void:
	var drain: float = _Schema.ordered_retreat_drain_per_sec(unit) * delta
	unit.apply_cohesion_drain(drain)
	var uid: String = str(unit.unit_id)
	if _core.horn_disengage_start_str.has(uid):
		var start_s: float = float(_core.horn_disengage_start_str[uid])
		var lost: float = maxf(0.0, start_s - float(unit.strength))
		_core.horn_disengage_cost[uid] = maxf(float(_core.horn_disengage_cost.get(uid, 0.0)), lost)
	if unit.disengaging:
		return
	var edge: Vector2 = _own_edge_point(unit)
	unit.set_march_to(edge)


func _own_edge_point(unit) -> Vector2:
	var px := Constants.get_float("px_per_meter")
	var half_w: float = Constants.get_float("battlefield_width_m") * 0.5 * px
	var y: float = unit.position.y
	# Convention: red owns left (−x), blue owns right (+x).
	if str(unit.team_id) == "red":
		return Vector2(-half_w, y)
	return Vector2(half_w, y)


func _eval_trigger(unit, trigger: Dictionary) -> bool:
	prof_trigger_evals += 1
	var t: String = str(trigger.get("type", _Schema.TRIG_AT_START))
	match t:
		_Schema.TRIG_AT_START:
			return true
		_Schema.TRIG_AFTER_SECONDS:
			var need: float = float(trigger.get("t", 0.0))
			var now: float = _core.sim_tick_count * (1.0 / Constants.get_float("tick_rate_per_sec"))
			return now + 1e-6 >= need
		_Schema.TRIG_ENEMY_WITHIN:
			var x: float = float(trigger.get("x", 30.0))
			return _enemy_within(unit, x)
		_Schema.TRIG_UNIT_ENGAGES:
			return _unit_engages(str(trigger.get("unit", "")))
		_Schema.TRIG_UNIT_ROUTS:
			return _unit_routs(unit, trigger)
		_Schema.TRIG_MY_COHESION_BELOW:
			return float(unit.cohesion) < float(trigger.get("c", 50.0))
		_Schema.TRIG_HORN_SOUNDED:
			return bool(_core.horn_sounded.get(str(unit.team_id), false))
		_Schema.TRIG_UNIT_ORDER_STARTED:
			var key: String = "%s:%s" % [str(trigger.get("unit", "")), str(trigger.get("primitive", ""))]
			return bool(_core.order_started_flags.get(key, false))
	return false


func _enemy_within(unit, x_m: float) -> bool:
	for other in _core.units:
		if not _is_living_enemy(unit, other):
			continue
		if _Charge.distance_m(unit, other) <= x_m:
			return true
	return false


func _unit_engages(uid: String) -> bool:
	var u = _unit_by_id(uid)
	if u == null:
		return false
	var st = u.get_state()
	if st != Unit.State.ENGAGED and st != Unit.State.WAVERING:
		return false
	return not u.get_contact_partners().is_empty()


func _unit_routs(self_unit, trigger: Dictionary) -> bool:
	var scope: String = str(trigger.get("scope", "any"))
	var specific: String = str(trigger.get("unit", ""))
	if not specific.is_empty():
		var u = _unit_by_id(specific)
		return u != null and u.get_state() == Unit.State.ROUTING
	for u in _core.units:
		if u == null or u.get_state() != Unit.State.ROUTING:
			continue
		match scope:
			"enemy":
				if str(u.team_id) != str(self_unit.team_id):
					return true
			"friendly":
				if str(u.team_id) == str(self_unit.team_id):
					return true
			_:
				return true
	return false


func _unit_by_id(uid: String):
	if uid.is_empty() or _core == null:
		return null
	for u in _core.units:
		if u != null and str(u.unit_id) == uid:
			return u
	return null


func _is_living_enemy(self_unit, other) -> bool:
	if other == null or self_unit == null:
		return false
	if str(other.team_id) == str(self_unit.team_id):
		return false
	var st = other.get_state()
	if st == Unit.State.REMOVED or st == Unit.State.ROUTING:
		return false
	# WO-032: enemy order triggers (enemy_within) and attack_* seek cannot see
	# concealed units. Own-side still sees living enemies (asymmetric).
	if _core != null and _core.has_method("is_visible_enemy"):
		if not _core.is_visible_enemy(self_unit, other):
			return false
	elif other.concealed and str(other.team_id) != str(self_unit.team_id):
		return false
	return true


func _nearest_living_enemy(unit):
	var best = null
	var best_d: float = INF
	for other in _core.units:
		if not _is_living_enemy(unit, other):
			continue
		var d: float = _Charge.distance_m(unit, other)
		if d < best_d:
			best_d = d
			best = other
	return best


func _maybe_log_order_traces() -> void:
	if _core == null or not _core.trace_logging_enabled():
		return
	var ticks_per_sec := int(Constants.get_float("tick_rate_per_sec"))
	if _core.sim_tick_count % ticks_per_sec != 0:
		return
	var sec: int = int(_core.sim_tick_count / ticks_per_sec)
	if sec == _last_trace_sec:
		return
	_last_trace_sec = sec
	for unit in _core.units:
		if unit == null:
			continue
		if not unit.order_runtime_ready and not unit.horn_retreating:
			continue
		prof_order_state_emits += 1
		prof_per_unit_allocs += 1
		_core.log_trace_event(
			"order_state",
			"unit=%s,step=%d,phase=%s,primitive=%s,trigger=%s,trigger_live=%s,prim_phase=%s"
			% [
				unit.unit_id,
				unit.order_step_index,
				unit.order_phase,
				unit.order_primitive,
				unit.order_trigger_type if not unit.order_trigger_type.is_empty() else "none",
				str(unit.order_trigger_live),
				unit.order_prim_phase,
			]
		)


## Face-only gravity for absolute_hold units (called from update_movement).
static func tick_absolute_hold_facing(unit, enemies: Array, delta: float) -> void:
	if unit == null or not unit.absolute_hold:
		return
	if unit.disengaging:
		return
	# Pinning: already in contact → do not auto-rotate (R19).
	var Magnetism = load("res://scripts/magnetism.gd")
	if Magnetism.is_pinned(unit):
		return
	var grav = Magnetism.find_gravity_target(unit, enemies)
	if grav == null:
		return
	var to_enemy: Vector2 = grav.position - unit.position
	if to_enemy.length_squared() > 0.0001:
		Magnetism.rotate_toward(unit, to_enemy, delta)
