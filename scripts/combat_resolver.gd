class_name CombatResolver
extends RefCounted

const CONTACT_EPSILON_M := 0.01


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
	return gap_m <= CONTACT_EPSILON_M and gap_m >= -CONTACT_EPSILON_M


static func units_penetrating(unit_a: Unit, unit_b: Unit) -> bool:
	return _raw_center_gap_m(unit_a, unit_b) < -CONTACT_EPSILON_M


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


static func clamp_march_distance(unit: Unit, enemy: Unit, move_px: float) -> float:
	if move_px <= 0.0:
		return 0.0

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


static func apply_strength_loss(unit: Unit, loss: float) -> float:
	if loss <= 0.0:
		return 0.0

	var strength_max := Constants.get_float("strength_max")
	var old_strength := unit.strength
	unit.strength = maxf(unit.strength - loss, 0.0)
	var applied := old_strength - unit.strength

	if applied > 0.0:
		unit.apply_rear_anchored_depth_from_strength(old_strength, unit.strength)
		var pct_lost := applied / strength_max * 100.0
		var cohesion_drain := pct_lost * Constants.get_float("drain_per_strength_pct_lost")
		unit.apply_cohesion_drain(cohesion_drain)

	return applied

