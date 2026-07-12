class_name SimCombatDispatch
extends RefCounted

## Sim-thread combat facade (Variant-typed copies; fast path uses originals).

static func units_have_any_contact(unit_a, unit_b) -> bool:
	return SimCombatResolver.units_have_any_contact(unit_a, unit_b)

static func is_head_on_pair(unit_a, unit_b) -> bool:
	return SimCombatResolver.is_head_on_pair(unit_a, unit_b)

static func snap_pair_to_contact(unit_a, unit_b) -> void:
	SimCombatResolver.snap_pair_to_contact(unit_a, unit_b)

static func center_distance_m(unit_a, unit_b) -> float:
	return SimCombatResolver.center_distance_m(unit_a, unit_b)

static func can_apply_pursuit(pursuer) -> bool:
	return SimCombatResolver.can_apply_pursuit(pursuer)

static func is_within_pursuit_contact(pursuer, routing_unit) -> bool:
	return SimCombatResolver.is_within_pursuit_contact(pursuer, routing_unit)

static func calc_pursuit_damage(pursuer) -> float:
	return SimCombatResolver.calc_pursuit_damage(pursuer)

static func apply_strength_loss(unit, loss: float) -> float:
	return SimCombatResolver.apply_strength_loss(unit, loss)

static func units_have_front_contact(unit_a, unit_b) -> bool:
	return SimCombatResolver.units_have_front_contact(unit_a, unit_b)

static func resolve_engagement(unit_a, unit_b) -> Dictionary:
	return SimCombatResolver.resolve_engagement(unit_a, unit_b)

static func apply_ground_shift(loser, shift_m: float) -> void:
	SimCombatResolver.apply_ground_shift(loser, shift_m)

static func resolve_contact_segment(attacker, defender, contact: Dictionary) -> Dictionary:
	return SimCombatResolver.resolve_contact_segment(attacker, defender, contact)

static func apply_strength_loss_with_edge(unit, loss: float, edge_lengths: Dictionary) -> float:
	return SimCombatResolver.apply_strength_loss_with_edge(unit, loss, edge_lengths)

static func apply_shift_morale_drain(unit, shift_m: float, edge_lengths: Dictionary) -> void:
	SimCombatResolver.apply_shift_morale_drain(unit, shift_m, edge_lengths)

static func apply_directed_position_shift(loser, shift_m: float, normal: Vector2) -> void:
	SimCombatResolver.apply_directed_position_shift(loser, shift_m, normal)

static func apply_contact_adhesion_pair(unit_a, unit_b, all_units: Array = []) -> bool:
	return SimCombatResolver.apply_contact_adhesion_pair(unit_a, unit_b, all_units)

static func pair_has_classifier_contact(unit_a, unit_b) -> bool:
	return SimCombatResolver.pair_has_classifier_contact(unit_a, unit_b)

static func separate_allied_overlap(unit_a, unit_b) -> void:
	SimCombatResolver.separate_allied_overlap(unit_a, unit_b)

static func units_overlap(unit_a, unit_b) -> bool:
	return SimCombatResolver.units_overlap(unit_a, unit_b)

static func could_have_contact(unit_a, unit_b) -> bool:
	return SimCombatResolver.could_have_contact(unit_a, unit_b)

static func clamp_march_distance(unit, enemy, move_px: float) -> float:
	return SimCombatResolver.clamp_march_distance(unit, enemy, move_px)

static func enemy_blocks_rally_distance_m(unit, enemy) -> bool:
	return SimCombatResolver.enemy_blocks_rally_distance_m(unit, enemy)

static func bounds_may_overlap(unit_a, unit_b) -> bool:
	return SimFormationGeometry.bounds_may_overlap(unit_a, unit_b)

static func has_non_front_segment_contact(unit_a, unit_b) -> bool:
	return SimEdgeContact.has_non_front_segment_contact(unit_a, unit_b)

static func pick_segment_orientation(unit_a, unit_b) -> Dictionary:
	return SimEdgeContact.pick_segment_orientation(unit_a, unit_b)

static func units_have_contact(attacker, defender) -> bool:
	return SimEdgeContact.units_have_contact(attacker, defender)
