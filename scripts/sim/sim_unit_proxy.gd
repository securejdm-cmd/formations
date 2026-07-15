class_name SimUnitProxy
extends RefCounted

const _ChargeCombat := preload("res://scripts/charge_combat.gd")
const _Magnetism := preload("res://scripts/magnetism.gd")

var unit_id: String = ""
var team_id: String = ""
var profile: Dictionary = {}
var position: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2.RIGHT
var strength: float = 100.0
var cohesion: float = 100.0
var current_order: Unit.Order = Unit.Order.HOLD
var march_target: Vector2 = Vector2.ZERO
var pushing_power: float = 0.0
var speed_stat: float = 0.0
var damage_dealt: float = 0.0
var _contact_partners: Array = []
var _partner_ids: Array[String] = []
var _active_contact_edges: String = ""
var _edge_cohesion_drain_totals: Dictionary = {
	"front": 0.0, "left": 0.0, "right": 0.0, "rear": 0.0,
}
var _state: Unit.State = Unit.State.HOLD
var _bump_gap_ratio: float = 0.0
var _bump_is_winner: bool = false
var _rally_elapsed_sec: float = 0.0
var _rallies_this_battle: int = 0
var _rallied_hold: bool = false
var _rally_reform_remaining_sec: float = 0.0
var _pending_rout_event: bool = false
var _crack_intensity: float = 0.0  # Legacy sync field; crack band is strength%-driven (render-only).
var _ammo_remaining: int = -1
var _reload_timer: float = 0.0
var _dead_zone_panic_done: bool = false
var current_speed_m_s: float = 0.0
var charge_amp_factor: float = 1.0
var _charge_amp_time_left: float = 0.0
## R17: charge gait commitment (physical acceleration to gait top).
var charge_committed: bool = false
var _charge_commit_target_id: String = ""
var _brace_hold_sec: float = 0.0
var _braced: bool = false
var _threat_front_sec: float = 0.0
var brace_tier_last: int = 0
var threat_front_sec: float:
	get:
		return _threat_front_sec
	set(value):
		_threat_front_sec = value
## WO-020 magnetism.
var disengaging: bool = false
var _disengage_time_left: float = 0.0
var wheeling: bool = false
var wheel_facing_target: Vector2 = Vector2.ZERO
var rotate_under_contact_drain_accum: float = 0.0
var _pending_charge_latch_clear: bool = false
var _pending_latch_partner_ids: Array[String] = []


static func from_unit(unit: Unit) -> SimUnitProxy:
	var p := SimUnitProxy.new()
	p.unit_id = unit.unit_id
	p.team_id = unit.team_id
	p.profile = unit.profile.duplicate(true)
	p.position = unit.position
	p.facing = unit.facing
	p.strength = unit.strength
	p.cohesion = unit.cohesion
	p.current_order = unit.current_order
	p.march_target = unit.march_target
	p.pushing_power = unit.pushing_power
	p.speed_stat = unit.speed_stat
	p.damage_dealt = unit.damage_dealt
	p._state = unit.get_state()
	p._active_contact_edges = unit.get_active_contact_edges()
	p._edge_cohesion_drain_totals = unit.get_edge_cohesion_drain_totals()
	p._bump_gap_ratio = unit._bump_gap_ratio
	p._bump_is_winner = unit._bump_is_winner
	p._rally_elapsed_sec = unit._rally_elapsed_sec
	p._rallies_this_battle = unit._rallies_this_battle
	p._rallied_hold = unit._rallied_hold
	p._rally_reform_remaining_sec = unit._rally_reform_remaining_sec
	p._pending_rout_event = unit._pending_rout_event
	p._crack_intensity = 0.0
	p._init_ranged_state_from_profile()
	p.current_speed_m_s = unit.current_speed_m_s
	p.charge_amp_factor = unit.charge_amp_factor
	p._charge_amp_time_left = unit._charge_amp_time_left
	p.charge_committed = unit.charge_committed
	p._charge_commit_target_id = unit._charge_commit_target_id
	p._brace_hold_sec = unit._brace_hold_sec
	p._braced = unit._braced
	p._threat_front_sec = unit._threat_front_sec
	p.brace_tier_last = unit.brace_tier_last
	p.disengaging = unit.disengaging
	p._disengage_time_left = unit._disengage_time_left
	p.wheeling = unit.wheeling
	p.wheel_facing_target = unit.wheel_facing_target
	p.rotate_under_contact_drain_accum = unit.rotate_under_contact_drain_accum
	if unit.ammo_remaining >= 0:
		p._ammo_remaining = unit.ammo_remaining
	for partner in unit.get_contact_partners():
		if partner != null:
			p._partner_ids.append(partner.unit_id)
	return p


func refresh_from_unit(unit: Unit) -> void:
	team_id = unit.team_id
	profile = unit.profile.duplicate(true)
	position = unit.position
	facing = unit.facing
	strength = unit.strength
	cohesion = unit.cohesion
	current_order = unit.current_order
	march_target = unit.march_target
	pushing_power = unit.pushing_power
	speed_stat = unit.speed_stat
	damage_dealt = unit.damage_dealt
	_state = unit.get_state()
	_active_contact_edges = unit.get_active_contact_edges()
	_edge_cohesion_drain_totals = unit.get_edge_cohesion_drain_totals()
	_bump_gap_ratio = unit._bump_gap_ratio
	_bump_is_winner = unit._bump_is_winner
	_rally_elapsed_sec = unit._rally_elapsed_sec
	_rallies_this_battle = unit._rallies_this_battle
	_rallied_hold = unit._rallied_hold
	_rally_reform_remaining_sec = unit._rally_reform_remaining_sec
	_pending_rout_event = unit._pending_rout_event
	_crack_intensity = 0.0
	if _ammo_remaining < 0:
		_init_ranged_state_from_profile()
	current_speed_m_s = unit.current_speed_m_s
	charge_amp_factor = unit.charge_amp_factor
	_charge_amp_time_left = unit._charge_amp_time_left
	charge_committed = unit.charge_committed
	_charge_commit_target_id = unit._charge_commit_target_id
	_brace_hold_sec = unit._brace_hold_sec
	_braced = unit._braced
	_threat_front_sec = unit._threat_front_sec
	brace_tier_last = unit.brace_tier_last
	disengaging = unit.disengaging
	_disengage_time_left = unit._disengage_time_left
	wheeling = unit.wheeling
	wheel_facing_target = unit.wheel_facing_target
	rotate_under_contact_drain_accum = unit.rotate_under_contact_drain_accum
	_partner_ids.clear()
	_contact_partners.clear()
	for partner in unit.get_contact_partners():
		if partner != null and partner.unit_id != unit_id:
			_partner_ids.append(partner.unit_id)


func duplicate_render_state() -> SimUnitProxy:
	var p := SimUnitProxy.new()
	p.unit_id = unit_id
	p.team_id = team_id
	p.profile = profile.duplicate(true)
	p.position = position
	p.facing = facing
	p.strength = strength
	p.cohesion = cohesion
	p.current_order = current_order
	p.march_target = march_target
	p.pushing_power = pushing_power
	p.speed_stat = speed_stat
	p.damage_dealt = damage_dealt
	p._partner_ids = _partner_ids.duplicate()
	p._active_contact_edges = _active_contact_edges
	p._edge_cohesion_drain_totals = _edge_cohesion_drain_totals.duplicate()
	p._state = _state
	p._bump_gap_ratio = _bump_gap_ratio
	p._bump_is_winner = _bump_is_winner
	p._rally_elapsed_sec = _rally_elapsed_sec
	p._rallies_this_battle = _rallies_this_battle
	p._rallied_hold = _rallied_hold
	p._rally_reform_remaining_sec = _rally_reform_remaining_sec
	p._pending_rout_event = _pending_rout_event
	p._crack_intensity = _crack_intensity
	p._ammo_remaining = _ammo_remaining
	p._reload_timer = _reload_timer
	p._dead_zone_panic_done = _dead_zone_panic_done
	p.current_speed_m_s = current_speed_m_s
	p.charge_amp_factor = charge_amp_factor
	p._charge_amp_time_left = _charge_amp_time_left
	p.charge_committed = charge_committed
	p._charge_commit_target_id = _charge_commit_target_id
	p._brace_hold_sec = _brace_hold_sec
	p._braced = _braced
	p._threat_front_sec = _threat_front_sec
	p.brace_tier_last = brace_tier_last
	p.disengaging = disengaging
	p._disengage_time_left = _disengage_time_left
	p.wheeling = wheeling
	p.wheel_facing_target = wheel_facing_target
	p.rotate_under_contact_drain_accum = rotate_under_contact_drain_accum
	return p


func resolve_partners(by_id: Dictionary) -> void:
	_contact_partners.clear()
	for pid in _partner_ids:
		if by_id.has(pid):
			var partner = by_id[pid]
			if partner not in _contact_partners:
				_contact_partners.append(partner)


func apply_to_unit(unit: Unit, all_units: Array = []) -> void:
	unit.position = position
	unit.facing = facing
	unit.rotation = facing.angle()
	unit.strength = strength
	unit.cohesion = cohesion
	unit.current_order = current_order
	unit.march_target = march_target
	unit.damage_dealt = damage_dealt
	unit._bump_gap_ratio = _bump_gap_ratio
	unit._bump_is_winner = _bump_is_winner
	unit._rally_elapsed_sec = _rally_elapsed_sec
	unit._rallies_this_battle = _rallies_this_battle
	unit._rally_reform_remaining_sec = _rally_reform_remaining_sec
	unit._pending_rout_event = _pending_rout_event
	unit._edge_cohesion_drain_totals = _edge_cohesion_drain_totals.duplicate()
	unit.ammo_remaining = _ammo_remaining
	unit.current_speed_m_s = current_speed_m_s
	unit.charge_amp_factor = charge_amp_factor
	unit._charge_amp_time_left = _charge_amp_time_left
	unit.charge_committed = charge_committed
	unit._charge_commit_target_id = _charge_commit_target_id
	unit._brace_hold_sec = _brace_hold_sec
	unit._braced = _braced
	unit._threat_front_sec = _threat_front_sec
	unit.brace_tier_last = brace_tier_last
	unit.disengaging = disengaging
	unit._disengage_time_left = _disengage_time_left
	unit.wheeling = wheeling
	unit.wheel_facing_target = wheel_facing_target
	unit.rotate_under_contact_drain_accum = rotate_under_contact_drain_accum
	if unit.has_method("_update_brace_visual"):
		unit._update_brace_visual()
	unit.set_active_contact_edges(_active_contact_edges)
	unit._rallied_hold = _rallied_hold
	_set_unit_state(unit, _state)
	_sync_unit_partners_to_nodes(unit, all_units)


func _sync_unit_partners_to_nodes(unit: Unit, all_units: Array) -> void:
	if all_units.is_empty():
		return
	var by_id: Dictionary = {}
	for node in all_units:
		if node != null:
			by_id[node.unit_id] = node
	for partner in unit.get_contact_partners().duplicate():
		if partner == null or partner.unit_id not in _partner_ids:
			unit.remove_contact_partner(partner)
	for pid in _partner_ids:
		if pid == unit.unit_id or not by_id.has(pid):
			continue
		var partner: Unit = by_id[pid]
		if not unit.has_contact_with(partner):
			unit.add_contact_partner(partner)


func _set_unit_state(unit: Unit, new_state: Unit.State) -> void:
	if unit.get_state() == new_state:
		return
	match new_state:
		Unit.State.MARCHING:
			unit._set_state(Unit.State.MARCHING)
		Unit.State.ENGAGED:
			unit._set_state(Unit.State.ENGAGED)
		Unit.State.WAVERING:
			unit._set_state(Unit.State.WAVERING)
		Unit.State.ROUTING:
			unit._set_state(Unit.State.ROUTING)
		Unit.State.RALLYING:
			unit._set_state(Unit.State.RALLYING)
		Unit.State.HOLD:
			unit._set_state(Unit.State.HOLD)
		Unit.State.REMOVED:
			unit.mark_removed()


func _sync_unit_partners(unit: Unit) -> void:
	var existing := unit.get_contact_partners()
	for p in existing:
		if p != null and p.unit_id not in _partner_ids:
			unit.remove_contact_partner(p)
	var by_id: Dictionary = {}
	for u in _contact_partners:
		by_id[u.unit_id] = u
	for pid in _partner_ids:
		if by_id.has(pid):
			continue
		for scene_unit in unit.get_tree().get_nodes_in_group("units") if unit.is_inside_tree() else []:
			pass
	# Partner sync via scenario apply pass — partners updated in capture_from_units each tick


func get_state() -> Unit.State:
	return _state


func get_state_name() -> String:
	match _state:
		Unit.State.MARCHING: return "marching"
		Unit.State.ENGAGED: return "engaged"
		Unit.State.WAVERING: return "wavering"
		Unit.State.ROUTING: return "routing"
		Unit.State.RALLYING: return "rallying"
		Unit.State.HOLD: return "hold"
		Unit.State.REMOVED: return "removed"
	return "unknown"


func effective_depth_m() -> float:
	var depth_m := float(profile.get("formation_depth_m", Constants.get_float("default_infantry_block_depth_m")))
	return depth_m * (strength / Constants.get_float("strength_max"))


func effective_frontage_m() -> float:
	return float(profile.get("formation_frontage_m", Constants.get_float("default_infantry_block_frontage_m")))


func full_depth_m() -> float:
	return float(profile.get("formation_depth_m", Constants.get_float("default_infantry_block_depth_m")))


func soldiers_defeated() -> int:
	var men_per_strength := Constants.get_float("men_per_full_unit") / Constants.get_float("strength_max")
	return int(round(damage_dealt * men_per_strength))


func record_damage_dealt(strength_damage: float) -> void:
	if strength_damage > 0.0:
		damage_dealt += strength_damage


func add_crack_intensity_from_damage(_strength_damage: float) -> void:
	pass


func get_display_name() -> String:
	return str(profile.get("display_name", unit_id))


func get_results_state_label() -> String:
	match _state:
		Unit.State.ROUTING: return "routed"
		Unit.State.REMOVED:
			return "destroyed" if strength <= 0.0 else "routed"
		_: return "fighting"


func speed_m_per_sec() -> float:
	return speed_stat * Constants.get_float("speed_stat_meters_per_10s") / 10.0


func set_bump_state(gap_ratio: float, is_winner: bool) -> void:
	_bump_gap_ratio = gap_ratio
	_bump_is_winner = is_winner


func clear_bump_state() -> void:
	_bump_gap_ratio = 0.0
	_bump_is_winner = false


func apply_cohesion_drain(amount: float, edge_name: String = "") -> void:
	if amount <= 0.0 or _state == Unit.State.REMOVED:
		return
	cohesion = maxf(cohesion - amount, 0.0)
	if not edge_name.is_empty() and _edge_cohesion_drain_totals.has(edge_name):
		_edge_cohesion_drain_totals[edge_name] += amount
	_refresh_morale_state()


func update_marching(delta: float, enemies: Array = []) -> void:
	if _state != Unit.State.MARCHING:
		return
	var steps := maxi(1, _ChargeCombat.march_substep_count(self, delta))
	var sub := delta / float(steps)
	for _i in range(steps):
		if _state != Unit.State.MARCHING:
			return
		_update_marching_step(sub, enemies)


func _update_marching_step(delta: float, enemies: Array = []) -> void:
	_update_charge_commit(enemies)
	var to_target := march_target - position
	var top := _ChargeCombat.target_speed_m_s(self)
	var gravity_target = _Magnetism.find_gravity_target(self, enemies)
	var desired_move: Vector2 = Vector2.ZERO
	if gravity_target != null:
		var to_enemy: Vector2 = gravity_target.position - position
		if to_enemy.length_squared() > 0.0001:
			_Magnetism.rotate_toward(self, to_enemy, delta)
			desired_move = to_enemy.normalized()
	elif to_target.length() > 0.001:
		var desired: Vector2 = to_target.normalized()
		var angled: float = facing.angle_to(desired)
		if absf(angled) > 0.15:
			var max_turn: float = _ChargeCombat.turn_rate_rad_s(self) * delta
			if absf(angled) <= max_turn:
				facing = desired
			else:
				facing = facing.rotated(signf(angled) * max_turn)
		desired_move = desired
	var accel: float = _ChargeCombat.accel_m_s2(self)
	var decel: float = _ChargeCombat.decel_m_s2(self)
	if current_speed_m_s < top:
		current_speed_m_s = minf(top, current_speed_m_s + accel * delta)
	elif current_speed_m_s > top:
		current_speed_m_s = maxf(top, current_speed_m_s - decel * delta)
	var speed_px := current_speed_m_s * Constants.get_float("px_per_meter")
	var move_px := speed_px * delta
	if desired_move == Vector2.ZERO:
		desired_move = to_target.normalized() if to_target.length() > 0.001 else facing.normalized()
	if gravity_target == null and to_target.length() <= move_px:
		position = march_target
		current_speed_m_s = maxf(0.0, current_speed_m_s - decel * delta)
		charge_committed = false
		_charge_commit_target_id = ""
		if enemies.is_empty():
			_set_state(Unit.State.HOLD)
		return
	for enemy in enemies:
		if not CombatResolver.could_have_contact(self, enemy):
			continue
		if EdgeContact.units_have_contact(self, enemy) or EdgeContact.units_have_contact(enemy, self):
			return
		move_px = CombatResolver.clamp_march_distance(self, enemy, move_px)
		if move_px <= 0.0:
			return
	position += desired_move * move_px


func begin_disengage() -> void:
	if disengaging:
		return
	disengaging = true
	_disengage_time_left = _Magnetism.disengage_duration_s(self)
	wheeling = false


func complete_disengage() -> void:
	disengaging = false
	_disengage_time_left = 0.0
	_contact_partners.clear()
	_partner_ids.clear()
	clear_bump_state()
	_set_state(Unit.State.MARCHING if current_order == Unit.Order.MARCH_TO else Unit.State.HOLD)


## Called by core after complete_disengage to allow a fresh charge impact.


func tick_disengage(delta: float) -> void:
	if not disengaging:
		return
	_disengage_time_left = maxf(0.0, _disengage_time_left - delta)
	if _disengage_time_left <= 0.0:
		var old_partners: Array = _contact_partners.duplicate()
		complete_disengage()
		# Allow a fresh charge impact after break-off (S32 hit-and-run).
		_pending_charge_latch_clear = true
		_pending_latch_partner_ids.clear()
		for p in old_partners:
			if p != null:
				_pending_latch_partner_ids.append(str(p.unit_id))


func begin_wheel_facing(desired: Vector2) -> void:
	if desired.length_squared() <= 0.0001:
		return
	wheeling = true
	wheel_facing_target = desired.normalized()


func tick_wheel(delta: float) -> void:
	if not wheeling:
		return
	var stepped: float = _Magnetism.rotate_toward(self, wheel_facing_target, delta)
	if stepped > 0.001 and not _contact_partners.is_empty():
		var drain: float = _Magnetism.rotate_under_contact_drain_per_s(self) * delta
		apply_cohesion_drain(drain)
		rotate_under_contact_drain_accum += drain
	if facing.angle_to(wheel_facing_target) <= 0.02:
		facing = wheel_facing_target
		wheeling = false


func is_disengaging() -> bool:
	return disengaging


func can_deal_melee() -> bool:
	return not disengaging


func set_march_to(target: Vector2) -> void:
	march_target = target
	current_order = Unit.Order.MARCH_TO
	if not _contact_partners.is_empty() and not disengaging:
		begin_disengage()
		return
	if disengaging:
		return
	_contact_partners.clear()
	_partner_ids.clear()
	_set_state(Unit.State.MARCHING)


func _update_charge_commit(enemies: Array) -> void:
	## R17: commit to charge gait when marching toward a front-arc enemy in range.
	if current_order != Unit.Order.MARCH_TO:
		charge_committed = false
		_charge_commit_target_id = ""
		return
	var target = _ChargeCombat.find_charge_commit_target(self, enemies)
	if target == null:
		charge_committed = false
		_charge_commit_target_id = ""
		return
	charge_committed = true
	_charge_commit_target_id = str(target.unit_id)


func start_from_rest() -> void:
	current_speed_m_s = 0.0


func is_braced() -> bool:
	return _braced


func begin_charge_amp() -> void:
	charge_amp_factor = Constants.get_float("charge_amp_peak")
	_charge_amp_time_left = Constants.get_float("charge_amp_decay_s")


func tick_charge_amp(delta: float) -> void:
	if _charge_amp_time_left <= 0.0:
		charge_amp_factor = 1.0
		return
	_charge_amp_time_left = maxf(_charge_amp_time_left - delta, 0.0)
	var decay_s := Constants.get_float("charge_amp_decay_s")
	if decay_s <= 0.0:
		charge_amp_factor = 1.0
		return
	var peak := Constants.get_float("charge_amp_peak")
	var t := _charge_amp_time_left / decay_s
	charge_amp_factor = 1.0 + (peak - 1.0) * t


func update_brace(delta: float, enemies: Array = []) -> void:
	if _state == Unit.State.REMOVED or _state == Unit.State.ROUTING or _state == Unit.State.RALLYING:
		_braced = false
		_brace_hold_sec = 0.0
		_threat_front_sec = 0.0
		return

	# R16 Tier 1 threat clock — cheap front-axis only (perf-safe).
	var gallop_threat := false
	for enemy in enemies:
		if enemy == null or enemy.get_state() == Unit.State.REMOVED:
			continue
		if enemy.team_id == team_id:
			continue
		if _ChargeCombat.is_charging_threat(enemy, self):
			gallop_threat = true
			break
	if gallop_threat and _ChargeCombat.own_speed_allows_instinctive(self):
		_threat_front_sec += delta
	else:
		_threat_front_sec = 0.0

	var stationary := current_speed_m_s <= Constants.get_float("brace_stationary_speed")
	var holding := _state == Unit.State.HOLD or (_state == Unit.State.MARCHING and stationary)
	if not holding or not _ChargeCombat.is_pierce(self) or not stationary:
		_brace_hold_sec = 0.0
		_braced = false
		return
	var sees_charger := false
	for enemy in enemies:
		if enemy == null or enemy.get_state() == Unit.State.REMOVED:
			continue
		if enemy.team_id == team_id:
			continue
		if not _ChargeCombat.faces_threat(self, enemy):
			continue
		if _ChargeCombat.closing_speed_into_defender(enemy, self) > 0.05 or enemy.get_state() == Unit.State.MARCHING:
			sees_charger = true
			break
	if sees_charger:
		_brace_hold_sec += delta
	elif not _braced:
		# Keep an already-braced line; don't wipe on one tick of query miss.
		_brace_hold_sec = 0.0
	_braced = _brace_hold_sec >= Constants.get_float("brace_time_s") or _braced


func has_trait(trait_name: String) -> bool:
	for entry in profile.get("traits", []):
		if str(entry).to_upper() == trait_name.to_upper():
			return true
	return false


func get_rallies_remaining() -> int:
	return maxi(0, Constants.get_int("rally_per_battle_limit") - _rallies_this_battle)


func is_defeated_for_victory() -> bool:
	if _state == Unit.State.REMOVED:
		return true
	if _state == Unit.State.ROUTING:
		if has_trait("RALLY") and get_rallies_remaining() > 0:
			return false
		return true
	return false


func is_rallied_hold() -> bool:
	return _rallied_hold and _state == Unit.State.HOLD


func consume_pending_rout_event() -> bool:
	if not _pending_rout_event:
		return false
	_pending_rout_event = false
	return true


func reset_rally_timer() -> void:
	_rally_elapsed_sec = 0.0


func update_routing(delta: float, enemies: Array = []) -> void:
	if _state == Unit.State.RALLYING:
		_rally_reform_remaining_sec -= delta
		if _rally_reform_remaining_sec <= 0.0:
			_set_state(Unit.State.HOLD)
		return
	if _state != Unit.State.ROUTING:
		return
	clear_bump_state()
	position += _flee_direction() * speed_m_per_sec() * Constants.get_float("rout_flee_speed_pct") * Constants.get_float("px_per_meter") * delta
	_check_edge_removal()
	if not has_trait("RALLY") or _rallies_this_battle >= Constants.get_int("rally_per_battle_limit"):
		return
	if _enemy_within_pursuit_radius(enemies):
		_rally_elapsed_sec = 0.0
		return
	_rally_elapsed_sec += delta
	if _rally_elapsed_sec >= Constants.get_float("t_rally_sec"):
		_complete_rally(enemies)


func _enemy_within_pursuit_radius(enemies: Array) -> bool:
	for enemy in enemies:
		if enemy == null or enemy.get_state() == Unit.State.REMOVED:
			continue
		if CombatResolver.enemy_blocks_rally_distance_m(self, enemy):
			return true
	return false


func _complete_rally(enemies: Array) -> void:
	_rallies_this_battle += 1
	_rally_elapsed_sec = 0.0
	cohesion = Constants.get_float("rally_cohesion_reset")
	current_order = Unit.Order.HOLD
	_rallied_hold = true
	_face_nearest_threat(enemies)
	_set_state(Unit.State.RALLYING)
	_rally_reform_remaining_sec = 1.0


func _face_nearest_threat(enemies: Array) -> void:
	var nearest = null
	var nearest_dist := INF
	for enemy in enemies:
		if enemy == null or enemy.get_state() == Unit.State.REMOVED:
			continue
		var dist := CombatResolver.center_distance_m(self, enemy)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	if nearest == null:
		return
	var to_enemy: Vector2 = nearest.position - position
	if to_enemy.length_squared() > 0.0001:
		facing = to_enemy.normalized()


func add_contact_partner(partner) -> void:
	if partner == null or partner == self:
		return
	if partner in _contact_partners:
		return
	_contact_partners.append(partner)
	if partner.unit_id not in _partner_ids:
		_partner_ids.append(partner.unit_id)
	if _state != Unit.State.ROUTING and _state != Unit.State.REMOVED and _state != Unit.State.RALLYING:
		_set_state(Unit.State.ENGAGED)


func remove_contact_partner(partner) -> void:
	if partner == null:
		return
	_contact_partners.erase(partner)
	_partner_ids.erase(partner.unit_id)
	if _contact_partners.is_empty():
		clear_bump_state()
		if _state == Unit.State.ENGAGED or _state == Unit.State.WAVERING:
			_set_state(Unit.State.MARCHING if current_order == Unit.Order.MARCH_TO else Unit.State.HOLD)


func has_contact_with(other) -> bool:
	return other in _contact_partners


func get_contact_partners() -> Array:
	return _contact_partners.duplicate()


func set_active_contact_edges(label: String) -> void:
	_active_contact_edges = label


func get_active_contact_edges() -> String:
	return _active_contact_edges


func get_edge_cohesion_drain_totals() -> Dictionary:
	return _edge_cohesion_drain_totals.duplicate()


func is_ranged_combatant() -> bool:
	return CombatResolver.is_ranged_unit(self)


func ammo_volleys_remaining() -> int:
	return _ammo_remaining


func consume_ammo_volley() -> void:
	if _ammo_remaining > 0:
		_ammo_remaining -= 1


func reset_reload_timer() -> void:
	_reload_timer = float(profile.get("reload_s", 0.0))


func tick_reload(delta: float) -> void:
	if _reload_timer > 0.0:
		_reload_timer = maxf(_reload_timer - delta, 0.0)


func reload_ready() -> bool:
	return _reload_timer <= 0.0


func dead_zone_panic_done() -> bool:
	return _dead_zone_panic_done


func mark_dead_zone_panic_done() -> void:
	_dead_zone_panic_done = true


func set_ammo_volleys(count: int) -> void:
	_ammo_remaining = count


func _init_ranged_state_from_profile() -> void:
	if not CombatResolver.is_ranged_unit(self):
		_ammo_remaining = -1
		_reload_timer = 0.0
		_dead_zone_panic_done = false
		return
	_ammo_remaining = int(profile.get("ammo_volleys", 0))
	_reload_timer = 0.0
	_dead_zone_panic_done = false


func enter_rout() -> void:
	var partners := _contact_partners.duplicate()
	_contact_partners.clear()
	_partner_ids.clear()
	for partner in partners:
		if partner == null:
			continue
		partner.remove_contact_partner(self)
		partner.clear_bump_state()
		if partner.get_state() == Unit.State.ENGAGED or partner.get_state() == Unit.State.WAVERING:
			if partner.get_contact_partners().is_empty():
				partner.current_order = Unit.Order.HOLD
				partner._set_state(Unit.State.HOLD)
	clear_bump_state()
	_rally_elapsed_sec = 0.0
	_pending_rout_event = true
	_set_state(Unit.State.ROUTING)


func mark_removed() -> void:
	_set_state(Unit.State.REMOVED)


func _set_state(new_state: Unit.State) -> void:
	if _state == new_state:
		return
	_state = new_state


func _refresh_morale_state() -> void:
	if _state == Unit.State.ROUTING or _state == Unit.State.REMOVED or _state == Unit.State.RALLYING:
		return
	if cohesion < Constants.get_float("rout_threshold"):
		enter_rout()
		return
	if _state == Unit.State.ENGAGED and cohesion < Constants.get_float("waver_threshold"):
		_set_state(Unit.State.WAVERING)
	elif _state == Unit.State.WAVERING and cohesion >= Constants.get_float("waver_threshold"):
		_set_state(Unit.State.ENGAGED)


func _flee_direction() -> Vector2:
	return -facing.normalized()


func _check_edge_removal() -> void:
	var half_width_px := Constants.get_float("battlefield_width_m") * Constants.get_float("px_per_meter") * 0.5
	var half_height_px := Constants.get_float("battlefield_height_m") * Constants.get_float("px_per_meter") * 0.5
	if absf(position.x) >= half_width_px or absf(position.y) >= half_height_px:
		mark_removed()
