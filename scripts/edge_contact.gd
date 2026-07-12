class_name EdgeContact
extends RefCounted

## Oriented edge contact classification per COMBAT_CORE §3.6.
## Basis: FRONT = facing; LEFT = +90° CCW (soldier's left); RIGHT = −90°; REAR = −facing.

const CONTACT_EPSILON_M := 0.01

const EDGE_FRONT := "front"
const EDGE_LEFT := "left"
const EDGE_RIGHT := "right"
const EDGE_REAR := "rear"


static func classify_contact(attacker: Unit, defender: Unit) -> Dictionary:
	# Head-on pairs defer to legacy center-gap contact until aligned.
	if (
		CombatResolver.is_head_on_pair(attacker, defender)
		and not CombatResolver.units_have_front_contact(attacker, defender)
	):
		return _empty_contact()

	var px_per_meter := Constants.get_float("px_per_meter")
	var forward := defender.facing.normalized()
	var left := FormationGeometry.left_vector(forward)
	var half_depth_m := defender.effective_depth_m() * 0.5
	var half_frontage_m := defender.effective_frontage_m() * 0.5

	var attacker_corners := FormationGeometry.get_corners(attacker)
	var eps := CONTACT_EPSILON_M
	var along_min := INF
	var along_max := -INF
	var across_min := INF
	var across_max := -INF

	for corner in attacker_corners:
		var local := corner - defender.position
		var along := local.dot(forward) / px_per_meter
		var across := local.dot(left) / px_per_meter
		along_min = minf(along_min, along)
		along_max = maxf(along_max, along)
		across_min = minf(across_min, across)
		across_max = maxf(across_max, across)

	var center_local := attacker.position - defender.position
	var center_along := center_local.dot(forward) / px_per_meter
	var center_across := center_local.dot(left) / px_per_meter

	along_min -= eps
	along_max += eps
	across_min -= eps
	across_max += eps

	var edge_lengths := {}

	if center_along > 0.0:
		var front_len := _edge_contact_span(
			along_max, along_min, half_depth_m - eps, half_depth_m + eps,
			across_max, across_min, half_frontage_m
		)
		if front_len > eps:
			edge_lengths[EDGE_FRONT] = front_len

	if center_along < 0.0:
		var rear_len := _edge_contact_span(
			along_max, along_min, -half_depth_m - eps, -half_depth_m + eps,
			across_max, across_min, half_frontage_m
		)
		if rear_len > eps:
			edge_lengths[EDGE_REAR] = rear_len

	if center_across > 0.0:
		var left_len := _edge_contact_span(
			across_max, across_min, half_frontage_m - eps, half_frontage_m + eps,
			along_max, along_min, half_depth_m
		)
		if left_len > eps:
			edge_lengths[EDGE_LEFT] = left_len

	if center_across < 0.0:
		var right_len := _edge_contact_span(
			across_max, across_min, -half_frontage_m - eps, -half_frontage_m + eps,
			along_max, along_min, half_depth_m
		)
		if right_len > eps:
			edge_lengths[EDGE_RIGHT] = right_len

	if edge_lengths.is_empty():
		return _empty_contact()

	var total_contact_m := 0.0
	for length_m in edge_lengths.values():
		total_contact_m += length_m

	var weighted_shift_mult := 0.0
	var weighted_casualty_mult := 0.0
	for edge_name in edge_lengths.keys():
		var length_m: float = edge_lengths[edge_name]
		weighted_shift_mult += length_m * _edge_shift_multiplier(edge_name)
		weighted_casualty_mult += length_m * _edge_casualty_multiplier(edge_name)
	weighted_shift_mult /= total_contact_m
	weighted_casualty_mult /= total_contact_m

	var attacker_frontage_pct := _attacker_contact_frontage_pct(
		attacker, defender, edge_lengths, total_contact_m, px_per_meter
	)
	var defender_edge_pct := _defender_engagement_pct(edge_lengths, total_contact_m, half_depth_m, half_frontage_m)
	var push_normal := _dominant_push_normal(edge_lengths, forward, left)

	return {
		"has_contact": true,
		"edge_lengths_m": edge_lengths,
		"edge_multiplier": weighted_shift_mult,
		"edge_shift_multiplier": weighted_shift_mult,
		"edge_casualty_multiplier": weighted_casualty_mult,
		"attacker_frontage_pct": attacker_frontage_pct,
		"defender_edge_pct": defender_edge_pct,
		"push_normal": push_normal,
		"edge_label": _edge_label(edge_lengths),
	}


static func units_have_contact(attacker: Unit, defender: Unit) -> bool:
	return classify_contact(attacker, defender).get("has_contact", false)


static func is_front_only_contact(contact: Dictionary) -> bool:
	var edges: Dictionary = contact.get("edge_lengths_m", {})
	return edges.size() == 1 and edges.has(EDGE_FRONT)


## Pick one segment orientation per pair (flank/rear contact beats spurious reverse front).
static func pick_segment_orientation(unit_a: Unit, unit_b: Unit) -> Dictionary:
	var contact_ab := classify_contact(unit_a, unit_b)
	var contact_ba := classify_contact(unit_b, unit_a)
	var priority_ab := _segment_orientation_priority(contact_ab)
	var priority_ba := _segment_orientation_priority(contact_ba)
	if priority_ba > priority_ab:
		return {"attacker": unit_b, "defender": unit_a, "contact": contact_ba}
	if priority_ab > priority_ba:
		return {"attacker": unit_a, "defender": unit_b, "contact": contact_ab}
	if unit_b.unit_id < unit_a.unit_id:
		return {"attacker": unit_b, "defender": unit_a, "contact": contact_ba}
	return {"attacker": unit_a, "defender": unit_b, "contact": contact_ab}


static func has_non_front_segment_contact(unit_a: Unit, unit_b: Unit) -> bool:
	const MIN_FLANK_EDGE_M := 5.0
	for contact in [classify_contact(unit_a, unit_b), classify_contact(unit_b, unit_a)]:
		if not contact.get("has_contact", false):
			continue
		if is_front_only_contact(contact):
			continue
		var edges: Dictionary = contact.get("edge_lengths_m", {})
		for edge_name in [EDGE_LEFT, EDGE_RIGHT, EDGE_REAR]:
			if edges.get(edge_name, 0.0) >= MIN_FLANK_EDGE_M:
				return true
	return false


static func _empty_contact() -> Dictionary:
	return {
		"has_contact": false,
		"edge_lengths_m": {},
		"edge_multiplier": 1.0,
		"edge_shift_multiplier": 1.0,
		"edge_casualty_multiplier": 1.0,
		"attacker_frontage_pct": 0.0,
		"defender_edge_pct": 0.0,
		"push_normal": Vector2.ZERO,
		"edge_label": "",
	}


static func _edge_contact_span(
	primary_max: float,
	primary_min: float,
	edge_low: float,
	edge_high: float,
	secondary_max: float,
	secondary_min: float,
	secondary_limit: float
) -> float:
	if primary_max < edge_low or primary_min > edge_high:
		return 0.0
	var sec_lo := maxf(secondary_min, -secondary_limit)
	var sec_hi := minf(secondary_max, secondary_limit)
	return maxf(0.0, sec_hi - sec_lo)


static func _edge_overlap_length(
	primary_max: float, primary_min: float, edge_low: float, edge_high: float,
	secondary_max: float, secondary_min: float
) -> float:
	return _edge_contact_span(
		primary_max, primary_min, edge_low, edge_high,
		secondary_max, secondary_min, INF
	)


static func _edge_shift_multiplier(edge_name: String) -> float:
	match edge_name:
		EDGE_FRONT:
			return Constants.get_float("edge_mult_front")
		EDGE_LEFT, EDGE_RIGHT:
			return Constants.get_float("edge_mult_side_shift")
		EDGE_REAR:
			return Constants.get_float("edge_mult_rear_shift")
	return Constants.get_float("edge_mult_front")


static func _edge_casualty_multiplier(edge_name: String) -> float:
	match edge_name:
		EDGE_FRONT:
			return Constants.get_float("edge_mult_front")
		EDGE_LEFT, EDGE_RIGHT:
			return Constants.get_float("edge_mult_side_casualty")
		EDGE_REAR:
			return Constants.get_float("edge_mult_rear_casualty")
	return Constants.get_float("edge_mult_front")


static func _max_defender_edge_span(edge_lengths: Dictionary, half_depth_m: float, half_frontage_m: float) -> float:
	var max_span := 0.0
	for edge_name in edge_lengths.keys():
		match edge_name:
			EDGE_FRONT, EDGE_REAR:
				max_span = maxf(max_span, half_frontage_m * 2.0)
			EDGE_LEFT, EDGE_RIGHT:
				max_span = maxf(max_span, half_depth_m * 2.0)
	return maxf(max_span, 0.001)


static func _segment_orientation_priority(contact: Dictionary) -> float:
	if not contact.get("has_contact", false):
		return -1.0
	var edges: Dictionary = contact.get("edge_lengths_m", {})
	if edges.is_empty():
		return -1.0
	var score := 0.0
	for length_m in edges.values():
		score += length_m
	if edges.has(EDGE_LEFT) or edges.has(EDGE_RIGHT):
		score += 1000.0
	if edges.has(EDGE_REAR):
		score += 500.0
	if is_front_only_contact(contact):
		score -= 100.0
	return score


static func _attacker_contact_frontage_pct(
	attacker: Unit,
	defender: Unit,
	edge_lengths: Dictionary,
	total_contact_m: float,
	px_per_meter: float
) -> float:
	var front_pct := _attacker_front_face_contact_pct(attacker, defender, px_per_meter)
	if front_pct > 0.001 and edge_lengths.has(EDGE_FRONT) and edge_lengths.size() == 1:
		return front_pct
	if edge_lengths.is_empty() or total_contact_m <= 0.0:
		return 0.0
	var flank_only := (
		not edge_lengths.has(EDGE_FRONT)
		and not edge_lengths.has(EDGE_REAR)
		and (edge_lengths.has(EDGE_LEFT) or edge_lengths.has(EDGE_RIGHT))
	)
	if flank_only:
		# Side approach: full depth ranks engage along the contact line.
		return clampf(total_contact_m / maxf(attacker.effective_depth_m(), 0.001), 0.0, 1.0)
	if edge_lengths.size() > 1:
		# Corner / multi-edge: at least one full-rank push can press the weak corner.
		return clampf(
			maxf(front_pct, total_contact_m / maxf(attacker.effective_depth_m(), 0.001)),
			0.0,
			1.0,
		)
	# Front/rear fallback: contact span along the attacker's front edge.
	return clampf(total_contact_m / maxf(attacker.effective_frontage_m(), 0.001), 0.0, 1.0)


static func _defender_engagement_pct(
	edge_lengths: Dictionary,
	total_contact_m: float,
	half_depth_m: float,
	half_frontage_m: float
) -> float:
	if total_contact_m <= 0.0:
		return 0.0
	var frontage_span := maxf(half_frontage_m * 2.0, 0.001)
	var weighted := 0.0
	var min_engagement := 1.0
	for edge_name in edge_lengths.keys():
		var length_m: float = edge_lengths[edge_name]
		var edge_engagement := clampf(length_m / frontage_span, 0.0, 1.0)
		min_engagement = minf(min_engagement, edge_engagement)
		weighted += length_m * edge_engagement
	var blended := clampf(weighted / total_contact_m, 0.0, 1.0)
	var flank_only := (
		not edge_lengths.has(EDGE_FRONT)
		and not edge_lengths.has(EDGE_REAR)
		and (edge_lengths.has(EDGE_LEFT) or edge_lengths.has(EDGE_RIGHT))
	)
	if flank_only:
		return clampf(blended * 0.9, 0.0, 1.0)
	if edge_lengths.size() > 1:
		return min_engagement
	return blended


static func _attacker_front_face_contact_pct(attacker: Unit, defender: Unit, px_per_meter: float) -> float:
	var forward := attacker.facing.normalized()
	var right := FormationGeometry.right_vector(forward)
	var half_depth_m := attacker.effective_depth_m() * 0.5
	var half_frontage_m := attacker.effective_frontage_m() * 0.5

	var defender_corners := FormationGeometry.get_corners(defender)
	var along_min := INF
	var along_max := -INF
	var across_min := INF
	var across_max := -INF

	for corner in defender_corners:
		var local := corner - attacker.position
		var along := local.dot(forward) / px_per_meter
		var across := local.dot(right) / px_per_meter
		along_min = minf(along_min, along)
		along_max = maxf(along_max, along)
		across_min = minf(across_min, across)
		across_max = maxf(across_max, across)

	var overlap_across_min := maxf(across_min, -half_frontage_m)
	var overlap_across_max := minf(across_max, half_frontage_m)
	var front_touch := along_max >= half_depth_m - CONTACT_EPSILON_M and along_min <= half_depth_m + CONTACT_EPSILON_M
	if not front_touch:
		return 0.0

	var contact_span := maxf(0.0, overlap_across_max - overlap_across_min)
	return clampf(contact_span / maxf(half_frontage_m * 2.0, 0.001), 0.0, 1.0)


static func _dominant_push_normal(edge_lengths: Dictionary, forward: Vector2, left: Vector2) -> Vector2:
	var best_edge := EDGE_FRONT
	var best_len := -1.0
	for edge_name in edge_lengths.keys():
		var length_m: float = edge_lengths[edge_name]
		if length_m > best_len:
			best_len = length_m
			best_edge = edge_name

	match best_edge:
		EDGE_FRONT:
			return forward
		EDGE_REAR:
			return -forward
		EDGE_LEFT:
			return left
		EDGE_RIGHT:
			return -left
	return forward


static func _edge_label(edge_lengths: Dictionary) -> String:
	if edge_lengths.is_empty():
		return ""
	var parts: Array[String] = []
	for edge_name in [EDGE_FRONT, EDGE_REAR, EDGE_LEFT, EDGE_RIGHT]:
		if edge_lengths.has(edge_name):
			parts.append(edge_name)
	if parts.size() == 1:
		return parts[0]
	return "+".join(parts)
