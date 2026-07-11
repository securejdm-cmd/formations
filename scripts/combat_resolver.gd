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
	return _front_contact_distance(unit_a, unit_b) <= CONTACT_EPSILON_M


static func _front_contact_distance(unit_a: Unit, unit_b: Unit) -> float:
	var to_b := unit_b.position - unit_a.position
	var to_a := unit_a.position - unit_b.position
	var a_sees_b := to_b.dot(unit_a.facing) > 0.0
	var b_sees_a := to_a.dot(unit_b.facing) > 0.0
	if not a_sees_b or not b_sees_a:
		return INF

	var px_per_meter := Constants.get_float("px_per_meter")
	var center_distance_m := to_b.length() / px_per_meter
	var gap_m := (
		center_distance_m
		- unit_a.effective_depth_m() * 0.5
		- unit_b.effective_depth_m() * 0.5
	)
	return maxf(gap_m, 0.0)


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
	}

	if is_equal_approx(push_a, push_b):
		result.damage_a = _calc_strength_loss(push_b, false)
		result.damage_b = _calc_strength_loss(push_a, false)
		return result

	var a_wins := push_a > push_b
	var winner_push := push_a if a_wins else push_b
	var loser_push := push_b if a_wins else push_a
	var shift_m := _calc_ground_shift_m(winner_push, loser_push)

	if a_wins:
		result.shift_b_m = shift_m
		result.damage_a = _calc_strength_loss(push_b, false)
		result.damage_b = _calc_strength_loss(push_a, true)
	else:
		result.shift_a_m = shift_m
		result.damage_a = _calc_strength_loss(push_b, true)
		result.damage_b = _calc_strength_loss(push_a, false)

	return result


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


static func apply_strength_loss(unit: Unit, loss: float) -> void:
	if loss <= 0.0:
		return

	var strength_max := Constants.get_float("strength_max")
	var old_strength := unit.strength
	unit.strength = maxf(unit.strength - loss, 0.0)

	var pct_lost := (old_strength - unit.strength) / strength_max * 100.0
	if pct_lost > 0.0:
		var cohesion_drain := pct_lost * Constants.get_float("drain_per_strength_pct_lost")
		unit.apply_cohesion_drain(cohesion_drain)


static func apply_ground_loss(unit: Unit, shift_m: float) -> void:
	if shift_m <= 0.0:
		return

	unit.position -= unit.facing * shift_m * Constants.get_float("px_per_meter")
	var cohesion_drain := shift_m * Constants.get_float("drain_per_meter_lost")
	unit.apply_cohesion_drain(cohesion_drain)
