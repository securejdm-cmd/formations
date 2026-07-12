class_name CombatResolver
extends RefCounted

const _TickProfiler := preload("res://scripts/tick_profiler.gd")


static func contact_epsilon_m() -> float:
	return EdgeContact.contact_epsilon_m()


static func engage_snap_max_m() -> float:
	return Constants.get_float("engage_snap_max_m")


static func could_have_contact(unit_a: Unit, unit_b: Unit) -> bool:
	var px_per_meter := Constants.get_float("px_per_meter")
	var dist_m := unit_a.position.distance_to(unit_b.position) / px_per_meter
	var reach := (
		unit_a.effective_depth_m()
		+ unit_b.effective_depth_m()
		+ unit_a.effective_frontage_m() * 0.5
		+ unit_b.effective_frontage_m() * 0.5
		+ engage_snap_max_m()
		+ 1.0
	)
	return dist_m <= reach


static func tick_rate() -> float:
	return Constants.get_float("tick_rate_per_sec")


static func tick_interval() -> float:
	return 1.0 / tick_rate()


static func calc_push_score(unit: Unit, contact_frontage_pct: float = 1.0, context_mod: float = 1.0) -> float:
	var strength_max := Constants.get_float("strength_max")
	var strength_pct := unit.strength / strength_max
	var cohesion_factor := 0.5 + unit.cohesion / 200.0
	var effectiveness := 1.0
	if unit.cohesion < Constants.get_float("waver_threshold"):
		effectiveness = Constants.get_float("waver_effect")

	var base := (
		unit.pushing_power
		* strength_pct
		* cohesion_factor
		* effectiveness
		* contact_frontage_pct
		* context_mod
	)
	return base * RNG.randf_wobble(Constants.get_float("wobble_pct"))


static func units_have_front_contact(unit_a: Unit, unit_b: Unit) -> bool:
	var gap_m := _raw_center_gap_m(unit_a, unit_b)
	return gap_m <= contact_epsilon_m() and gap_m >= -contact_epsilon_m()


static func units_penetrating(unit_a: Unit, unit_b: Unit) -> bool:
	return _raw_center_gap_m(unit_a, unit_b) < -contact_epsilon_m()


static func units_overlap(unit_a: Unit, unit_b: Unit) -> bool:
	# Routing units are formless fugitives — no collision volume (WO-008 TD ruling).
	if (
		unit_a.get_state() == Unit.State.ROUTING
		or unit_b.get_state() == Unit.State.ROUTING
	):
		return false
	if not FormationGeometry.bounds_may_overlap(unit_a, unit_b):
		return false
	if not could_have_contact(unit_a, unit_b):
		return false
	if unit_a.team_id == unit_b.team_id:
		return FormationGeometry.rectangles_overlap(unit_a, unit_b)
	if is_head_on_pair(unit_a, unit_b):
		return units_penetrating(unit_a, unit_b)
	if (
		EdgeContact.units_have_contact(unit_a, unit_b)
		or EdgeContact.units_have_contact(unit_b, unit_a)
	):
		return false
	return FormationGeometry.rectangles_overlap(unit_a, unit_b)


static func _raw_center_gap_m(unit_a: Unit, unit_b: Unit) -> float:
	var to_b := unit_b.position - unit_a.position
	var to_a := unit_a.position - unit_b.position
	var a_sees_b := to_b.dot(unit_a.facing) > 0.0
	var b_sees_a := to_a.dot(unit_b.facing) > 0.0
	if not a_sees_b or not b_sees_a:
		return INF

	var px_per_meter := Constants.get_float("px_per_meter")
	var center_distance_m := to_b.length() / px_per_meter
	return (
		center_distance_m
		- unit_a.effective_depth_m() * 0.5
		- unit_b.effective_depth_m() * 0.5
	)


static func _front_contact_distance(unit_a: Unit, unit_b: Unit) -> float:
	return maxf(_raw_center_gap_m(unit_a, unit_b), 0.0)


static func required_center_distance_px(unit_a: Unit, unit_b: Unit) -> float:
	var px_per_meter := Constants.get_float("px_per_meter")
	return (
		(unit_a.effective_depth_m() + unit_b.effective_depth_m())
		* 0.5
		* px_per_meter
	)


static func snap_pair_to_contact(unit_a: Unit, unit_b: Unit) -> void:
	var to_b := unit_b.position - unit_a.position
	if to_b.length_squared() <= 0.0001:
		return

	var dir := to_b.normalized()
	var required_px := required_center_distance_px(unit_a, unit_b)
	var current_px := to_b.length()
	var half_correction_px := (current_px - required_px) * 0.5
	if absf(half_correction_px) <= 0.001:
		return

	unit_a.position += dir * half_correction_px
	unit_b.position -= dir * half_correction_px

	if units_penetrating(unit_a, unit_b):
		var px_per_meter := Constants.get_float("px_per_meter")
		var gap_m := _raw_center_gap_m(unit_a, unit_b)
		var correction_px := absf(gap_m) * 0.5 * px_per_meter
		unit_a.position -= dir * correction_px
		unit_b.position += dir * correction_px


## Classifier truth: segment pairs use pick_segment_orientation contact; head-on uses edge contact.
static func pair_has_classifier_contact(unit_a: Unit, unit_b: Unit) -> bool:
	if (
		unit_a.get_state() == Unit.State.ROUTING
		or unit_b.get_state() == Unit.State.ROUTING
		or unit_a.get_state() == Unit.State.REMOVED
		or unit_b.get_state() == Unit.State.REMOVED
	):
		return false
	if is_head_on_pair(unit_a, unit_b) and not EdgeContact.has_non_front_segment_contact(unit_a, unit_b):
		return units_have_any_contact(unit_a, unit_b)
	var orient := EdgeContact.pick_segment_orientation(unit_a, unit_b)
	return orient.contact.get("has_contact", false)


## Returns true when the partnership must be pruned this tick.
static func apply_contact_adhesion_pair(unit_a: Unit, unit_b: Unit, all_units: Array = []) -> bool:
	_TickProfiler.record_adhesion_pair()
	_TickProfiler.adhesion_context = true
	var result := _apply_contact_adhesion_pair_impl(unit_a, unit_b, all_units)
	_TickProfiler.adhesion_context = false
	return result


static func _apply_contact_adhesion_pair_impl(unit_a: Unit, unit_b: Unit, all_units: Array = []) -> bool:
	if (
		unit_a.get_state() == Unit.State.ROUTING
		or unit_b.get_state() == Unit.State.ROUTING
		or unit_a.get_state() == Unit.State.REMOVED
		or unit_b.get_state() == Unit.State.REMOVED
	):
		return true

	if is_head_on_pair(unit_a, unit_b) and not EdgeContact.has_non_front_segment_contact(unit_a, unit_b):
		return false

	if pair_has_classifier_contact(unit_a, unit_b):
		return false

	var orient := EdgeContact.pick_segment_orientation(unit_a, unit_b)
	var attacker: Unit = orient.attacker
	var defender: Unit = orient.defender
	var dirs := _segment_adhesion_move_dirs(attacker, defender, orient.contact)
	var old_pos := attacker.position
	var px_per_meter := Constants.get_float("px_per_meter")
	for move_dir in dirs:
		var closure_m := _seek_classifier_closure_m(
			attacker, unit_a, unit_b, all_units, move_dir, engage_snap_max_m()
		)
		if closure_m < 0.0:
			continue
		attacker.position = old_pos + move_dir * closure_m * px_per_meter
		if units_penetrating(attacker, defender):
			var correction_dir := (defender.position - attacker.position).normalized()
			var penetration_m := absf(_raw_center_gap_m(attacker, defender))
			attacker.position -= correction_dir * penetration_m * px_per_meter
		if pair_has_classifier_contact(unit_a, unit_b):
			return false
		attacker.position = old_pos
	return true


static func _segment_adhesion_move_dirs(
	attacker: Unit,
	defender: Unit,
	contact: Dictionary
) -> Array[Vector2]:
	var dirs: Array[Vector2] = []
	var seen: Dictionary = {}
	for raw in [
		_segment_adhesion_move_dir(attacker, defender, contact),
		attacker.facing.normalized(),
		(defender.position - attacker.position).normalized(),
	]:
		if raw.length_squared() <= 0.0001:
			continue
		var key := "%.3f,%.3f" % [raw.x, raw.y]
		if seen.has(key):
			continue
		seen[key] = true
		dirs.append(raw.normalized())
	return dirs


static func _segment_adhesion_move_dir(attacker: Unit, defender: Unit, contact: Dictionary) -> Vector2:
	var push_normal: Vector2 = contact.get("push_normal", Vector2.ZERO)
	if contact.get("has_contact", false) and push_normal.length_squared() > 0.0001:
		return -push_normal.normalized()
	var delta := defender.position - attacker.position
	if delta.length_squared() <= 0.0001:
		return Vector2.ZERO
	return delta.normalized()


static func _seek_classifier_closure_m(
	attacker: Unit,
	unit_a: Unit,
	unit_b: Unit,
	all_units: Array,
	move_dir: Vector2,
	max_m: float
) -> float:
	var old_pos := attacker.position
	var px_per_meter := Constants.get_float("px_per_meter")
	var best_m := -1.0
	var low := 0.0
	var high := max_m
	var max_iters := Constants.get_int("adhesion_binary_search_max_iters")
	for _attempt in max_iters:
		_TickProfiler.record_binary_search_step()
		var try_m := (low + high) * 0.5
		attacker.position = old_pos + move_dir * try_m * px_per_meter
		if _adhesion_move_creates_overlap(attacker, unit_a, unit_b, all_units):
			high = try_m
			continue
		if pair_has_classifier_contact(unit_a, unit_b):
			best_m = try_m
			high = try_m
		else:
			low = try_m
	attacker.position = old_pos
	return best_m


static func _adhesion_move_creates_overlap(
	mover: Unit,
	unit_a: Unit,
	unit_b: Unit,
	all_units: Array
) -> bool:
	var partner := unit_b if mover == unit_a else unit_a
	var px_per_meter := Constants.get_float("px_per_meter")
	var reach_px := (
		mover.effective_depth_m()
		+ mover.effective_frontage_m()
		+ partner.effective_depth_m()
		+ partner.effective_frontage_m()
		+ 5.0
	) * px_per_meter
	for other in all_units:
		if other == mover or other == partner:
			continue
		if other.get_state() == Unit.State.REMOVED or other.get_state() == Unit.State.ROUTING:
			continue
		if mover.get_state() == Unit.State.ROUTING:
			continue
		if mover.position.distance_to(other.position) > reach_px:
			continue
		if units_overlap(mover, other):
			return true
	return false


## Push apart allied rectangles that overlap (sim collision, non-routing only).
static func separate_allied_overlap(unit_a: Unit, unit_b: Unit) -> void:
	if unit_a.get_state() == Unit.State.ROUTING or unit_b.get_state() == Unit.State.ROUTING:
		return
	if unit_a.team_id != unit_b.team_id:
		return
	if not FormationGeometry.rectangles_overlap(unit_a, unit_b):
		return

	var delta := unit_b.position - unit_a.position
	if delta.length_squared() <= 0.0001:
		delta = Vector2(0.0, -Constants.get_float("px_per_meter"))
	var dir := delta.normalized()
	var px_per_meter := Constants.get_float("px_per_meter")
	var step_px := maxf(px_per_meter * 0.25, 1.0)
	for _attempt in 24:
		if not FormationGeometry.rectangles_overlap(unit_a, unit_b):
			return
		unit_a.position -= dir * step_px * 0.5
		unit_b.position += dir * step_px * 0.5


static func clamp_march_distance(unit: Unit, enemy: Unit, move_px: float) -> float:
	if move_px <= 0.0:
		return 0.0

	if (
		EdgeContact.units_have_contact(unit, enemy)
		or EdgeContact.units_have_contact(enemy, unit)
	):
		return 0.0

	if not is_head_on_pair(unit, enemy):
		return move_px

	var to_enemy := enemy.position - unit.position
	if to_enemy.dot(unit.facing) <= 0.0:
		return move_px

	var required_px := required_center_distance_px(unit, enemy)
	var gap_px := to_enemy.length() - required_px
	if gap_px <= 0.0:
		return 0.0
	return minf(move_px, gap_px)


static func resolve_engagement(unit_a: Unit, unit_b: Unit) -> Dictionary:
	var push_a := calc_push_score(unit_a)
	var push_b := calc_push_score(unit_b)

	var result := {
		"push_a": push_a,
		"push_b": push_b,
		"shift_a_m": 0.0,
		"shift_b_m": 0.0,
		"damage_a": 0.0,
		"damage_b": 0.0,
		"gap_ratio": 0.0,
		"a_is_winner": false,
	}

	if is_equal_approx(push_a, push_b):
		result.damage_a = _calc_strength_loss(push_b, false)
		result.damage_b = _calc_strength_loss(push_a, false)
		return result

	var a_wins := push_a > push_b
	var winner_push := push_a if a_wins else push_b
	var loser_push := push_b if a_wins else push_a
	var shift_m := _calc_ground_shift_m(winner_push, loser_push)
	result.gap_ratio = clampf((winner_push - loser_push) / winner_push, 0.0, 1.0)
	result.a_is_winner = a_wins

	if a_wins:
		result.shift_b_m = shift_m
		result.damage_a = _calc_strength_loss(push_b, false)
		result.damage_b = _calc_strength_loss(push_a, true)
	else:
		result.shift_a_m = shift_m
		result.damage_a = _calc_strength_loss(push_b, true)
		result.damage_b = _calc_strength_loss(push_a, false)

	return result


static func apply_ground_shift(loser: Unit, shift_m: float) -> void:
	if shift_m <= 0.0:
		return

	var px_per_meter := Constants.get_float("px_per_meter")
	loser.position -= loser.facing.normalized() * shift_m * px_per_meter

	var cohesion_drain := shift_m * Constants.get_float("drain_per_meter_lost")
	loser.apply_cohesion_drain(cohesion_drain)


static func _calc_ground_shift_m(winner_push: float, loser_push: float) -> float:
	if winner_push <= 0.0:
		return 0.0

	var gap_ratio := clampf((winner_push - loser_push) / winner_push, 0.0, 1.0)
	return gap_ratio * Constants.get_float("push_ground_shift_max_m_per_tick")


static func _calc_strength_loss(opponent_push_score: float, is_push_loser: bool) -> float:
	var loss := Constants.get_float("k_dmg") * opponent_push_score
	if is_push_loser:
		loss *= Constants.get_float("push_loser_damage_factor")
	return loss


static func is_head_on_pair(unit_a: Unit, unit_b: Unit) -> bool:
	var to_b := unit_b.position - unit_a.position
	var to_a := unit_a.position - unit_b.position
	return to_b.dot(unit_a.facing) > 0.0 and to_a.dot(unit_b.facing) > 0.0


static func units_have_any_contact(unit_a: Unit, unit_b: Unit) -> bool:
	return (
		EdgeContact.units_have_contact(unit_a, unit_b)
		or EdgeContact.units_have_contact(unit_b, unit_a)
	)


static func resolve_contact_segment(attacker: Unit, defender: Unit, contact: Dictionary) -> Dictionary:
	# Worked per-tick example (SIDE flank, constants from combat_constants.json):
	#   contact left=15m → attacker_frontage_pct=1.0 (depth), defender_edge_pct≈0.375
	#   If attacker wins: shift≈0.06m → shift_drain=0.06×0.8×edge_mult_side_shift(2.0)≈0.096
	#   casualty_drain from k_dmg×push → cohesion × edge_mult_side_casualty(1.5) on left edge.
	var frontage_pct: float = contact.get("attacker_frontage_pct", 1.0)
	var defender_edge_pct: float = contact.get("defender_edge_pct", 1.0)
	var edge_lengths: Dictionary = contact.get("edge_lengths_m", {})
	var push_normal: Vector2 = contact.get("push_normal", defender.facing)

	var push_attacker := calc_push_score(attacker, frontage_pct)
	var push_defender := calc_push_score(defender, defender_edge_pct)

	var result := {
		"attacker_push": push_attacker,
		"defender_push": push_defender,
		"attacker_shift_m": 0.0,
		"defender_shift_m": 0.0,
		"attacker_damage": 0.0,
		"defender_damage": 0.0,
		"gap_ratio": 0.0,
		"attacker_wins": false,
		"edge_lengths_m": edge_lengths,
		"push_normal": push_normal,
	}

	if is_equal_approx(push_attacker, push_defender):
		result.attacker_damage = _calc_strength_loss(push_defender, false)
		result.defender_damage = _calc_strength_loss(push_attacker, false)
		return result

	var attacker_wins := push_attacker > push_defender
	var winner_push := push_attacker if attacker_wins else push_defender
	var loser_push := push_defender if attacker_wins else push_attacker
	var shift_m := _calc_ground_shift_m(winner_push, loser_push)
	result.gap_ratio = clampf((winner_push - loser_push) / winner_push, 0.0, 1.0)
	result.attacker_wins = attacker_wins

	if attacker_wins:
		result.defender_shift_m = shift_m
		result.attacker_damage = _calc_strength_loss(push_defender, false)
		result.defender_damage = _calc_strength_loss(push_attacker, true)
	else:
		result.attacker_shift_m = shift_m
		result.attacker_damage = _calc_strength_loss(push_defender, true)
		result.defender_damage = _calc_strength_loss(push_attacker, false)

	return result


static func apply_directed_ground_shift(
	loser: Unit,
	shift_m: float,
	normal: Vector2,
	edge_lengths: Dictionary = {}
) -> void:
	apply_directed_position_shift(loser, shift_m, normal)
	var cohesion_drain := shift_m * Constants.get_float("drain_per_meter_lost")
	_apply_morale_drain_by_edges(loser, cohesion_drain, edge_lengths)


static func apply_directed_position_shift(loser: Unit, shift_m: float, normal: Vector2) -> void:
	if shift_m <= 0.0:
		return

	var px_per_meter := Constants.get_float("px_per_meter")
	var direction := normal.normalized()
	if direction.length_squared() <= 0.0001:
		direction = loser.facing.normalized()
	loser.position -= direction * shift_m * px_per_meter


static func apply_shift_morale_drain(
	unit: Unit,
	shift_m: float,
	edge_lengths: Dictionary = {}
) -> void:
	var cohesion_drain := shift_m * Constants.get_float("drain_per_meter_lost")
	_apply_morale_drain_by_edges(unit, cohesion_drain, edge_lengths)


static func apply_strength_loss_with_edge(
	unit: Unit,
	loss: float,
	edge_lengths: Dictionary = {}
) -> float:
	if loss <= 0.0:
		return 0.0

	var strength_max := Constants.get_float("strength_max")
	var old_strength := unit.strength
	unit.strength = maxf(unit.strength - loss, 0.0)
	var applied := old_strength - unit.strength

	if applied > 0.0:
		unit.add_crack_intensity_from_damage(applied)
		var pct_lost := applied / strength_max * 100.0
		var cohesion_drain := pct_lost * Constants.get_float("drain_per_strength_pct_lost")
		_apply_casualty_drain_by_edges(unit, cohesion_drain, edge_lengths)

	return applied


## Length-weighted casualty cohesion drain with per-edge casualty multiplier.
static func _apply_casualty_drain_by_edges(unit: Unit, amount: float, edge_lengths: Dictionary) -> void:
	if amount <= 0.0:
		return
	if edge_lengths.is_empty():
		unit.apply_cohesion_drain(amount)
		return

	var total_length := 0.0
	for length_m in edge_lengths.values():
		total_length += length_m
	if total_length <= 0.0:
		unit.apply_cohesion_drain(amount)
		return

	for edge_name in edge_lengths.keys():
		var length_m: float = edge_lengths[edge_name]
		var portion := amount * length_m / total_length
		var edge_mult := _edge_casualty_multiplier_for_name(edge_name)
		unit.apply_cohesion_drain(portion * edge_mult, edge_name)


## Length-weighted shift morale drain with per-edge shift multiplier (ground-lost only).
static func _apply_morale_drain_by_edges(unit: Unit, amount: float, edge_lengths: Dictionary) -> void:
	if amount <= 0.0:
		return
	if edge_lengths.is_empty():
		unit.apply_cohesion_drain(amount)
		return

	var total_length := 0.0
	for length_m in edge_lengths.values():
		total_length += length_m
	if total_length <= 0.0:
		unit.apply_cohesion_drain(amount)
		return

	for edge_name in edge_lengths.keys():
		var length_m: float = edge_lengths[edge_name]
		var portion := amount * length_m / total_length
		var edge_mult := _edge_shift_multiplier_for_name(edge_name)
		unit.apply_cohesion_drain(portion * edge_mult, edge_name)


static func _edge_shift_multiplier_for_name(edge_name: String) -> float:
	match edge_name:
		EdgeContact.EDGE_FRONT:
			return Constants.get_float("edge_mult_front")
		EdgeContact.EDGE_LEFT, EdgeContact.EDGE_RIGHT:
			return Constants.get_float("edge_mult_side_shift")
		EdgeContact.EDGE_REAR:
			return Constants.get_float("edge_mult_rear_shift")
	return Constants.get_float("edge_mult_front")


static func _edge_casualty_multiplier_for_name(edge_name: String) -> float:
	match edge_name:
		EdgeContact.EDGE_FRONT:
			return Constants.get_float("edge_mult_front")
		EdgeContact.EDGE_LEFT, EdgeContact.EDGE_RIGHT:
			return Constants.get_float("edge_mult_side_casualty")
		EdgeContact.EDGE_REAR:
			return Constants.get_float("edge_mult_rear_casualty")
	return Constants.get_float("edge_mult_front")


static func apply_strength_loss(unit: Unit, loss: float) -> float:
	if loss <= 0.0:
		return 0.0

	var strength_max := Constants.get_float("strength_max")
	var old_strength := unit.strength
	unit.strength = maxf(unit.strength - loss, 0.0)
	var applied := old_strength - unit.strength

	if applied > 0.0:
		unit.add_crack_intensity_from_damage(applied)
		var pct_lost := applied / strength_max * 100.0
		var cohesion_drain := pct_lost * Constants.get_float("drain_per_strength_pct_lost")
		unit.apply_cohesion_drain(cohesion_drain)

	return applied


static func center_distance_m(unit_a: Unit, unit_b: Unit) -> float:
	var px_per_meter := Constants.get_float("px_per_meter")
	return unit_a.position.distance_to(unit_b.position) / px_per_meter


static func pursuit_gap_m(pursuer: Unit, routing_unit: Unit) -> float:
	var center_gap_m := center_distance_m(pursuer, routing_unit)
	return (
		center_gap_m
		- pursuer.effective_depth_m() * 0.5
		- routing_unit.effective_depth_m() * 0.5
	)


static func is_within_pursuit_contact(pursuer: Unit, routing_unit: Unit) -> bool:
	if routing_unit.get_state() != Unit.State.ROUTING:
		return false
	return pursuit_gap_m(pursuer, routing_unit) <= Constants.get_float("pursuit_contact_m")


static func can_apply_pursuit(pursuer: Unit) -> bool:
	# Phase 1: only marching enemies on the flee path apply pursuit (S6 scripted pursuer).
	return pursuer.get_state() == Unit.State.MARCHING and pursuer.current_order == Unit.Order.MARCH_TO


static func enemy_blocks_rally(enemy: Unit) -> bool:
	if enemy.get_state() == Unit.State.REMOVED:
		return false
	# Phase 1: only marching threats on the flee path block rally (stationary winners do not).
	if enemy.get_state() != Unit.State.MARCHING:
		return false
	return true


static func enemy_blocks_rally_distance_m(unit: Unit, enemy: Unit) -> bool:
	if enemy.get_state() == Unit.State.REMOVED:
		return false
	if center_distance_m(unit, enemy) > Constants.get_float("pursuit_radius_m"):
		return false
	if enemy_blocks_rally(enemy):
		return true
	if is_within_pursuit_contact(enemy, unit):
		return true
	return false


static func calc_pursuit_damage(pursuer: Unit) -> float:
	var close_damage := float(pursuer.profile.get("close_damage", 0.0))
	return (
		close_damage
		* Constants.get_float("pursuit_damage_multiplier")
		* Constants.get_float("k_dmg")
	)

