class_name EdgeContact
extends RefCounted

const _TickProfiler := preload("res://scripts/tick_profiler.gd")
const _ContactCache := preload("res://scripts/contact_cache.gd")

## Oriented edge contact classification per COMBAT_CORE §3.6.
## Basis: FRONT = facing; LEFT = +90° CCW (soldier's left); RIGHT = −90°; REAR = −facing.

const EDGE_FRONT := "front"
const EDGE_LEFT := "left"
const EDGE_RIGHT := "right"
const EDGE_REAR := "rear"


static func contact_epsilon_m() -> float:
	return Constants.get_float("contact_epsilon_m")


static func begin_tick(tick_id: int) -> void:
	_ContactCache.begin_tick(tick_id)


static func classify_contact(attacker: Variant, defender: Variant) -> Dictionary:
	var prof_start: Variant = _TickProfiler.begin_classification()
	var result: Dictionary
	var cached = _ContactCache.lookup(attacker, defender)
	if cached != null:
		result = cached
	else:
		result = _classify_contact_impl(attacker, defender)
		_ContactCache.store(attacker, defender, result)
	_TickProfiler.end_classification(prof_start)
	_TickProfiler.record_classifier()
	return result


static func _classify_contact_impl(attacker: Variant, defender: Variant) -> Dictionary:
	# Head-on pairs defer to legacy center-gap contact until aligned.
	if (
		CombatResolver.is_head_on_pair(attacker, defender)
		and not CombatResolver.units_have_front_contact(attacker, defender)
	):
		return _empty_contact()

	var px_per_meter: float = Constants.get_float("px_per_meter")
	var forward: Vector2 = defender.facing.normalized()
	var left: Vector2 = FormationGeometry.left_vector(forward)
	var half_depth_m: float = defender.effective_depth_m() * 0.5
	var half_frontage_m: float = defender.effective_frontage_m() * 0.5

	var attacker_corners: Variant = FormationGeometry.get_corners(attacker)
	var eps: Variant = contact_epsilon_m()
	var along_min: Variant = INF
	var along_max: Variant = -INF
	var across_min: Variant = INF
	var across_max: Variant = -INF

	for corner in attacker_corners:
		var local: Vector2 = corner - defender.position
		var along: float = local.dot(forward) / px_per_meter
		var across: float = local.dot(left) / px_per_meter
		along_min = minf(along_min, along)
		along_max = maxf(along_max, along)
		across_min = minf(across_min, across)
		across_max = maxf(across_max, across)

	var center_local: Vector2 = attacker.position - defender.position
	var center_along: float = center_local.dot(forward) / px_per_meter
	var center_across: float = center_local.dot(left) / px_per_meter

	along_min -= eps
	along_max += eps
	across_min -= eps
	across_max += eps

	var edge_lengths: Variant = {}

	if center_along > 0.0:
		var front_len: Variant = _edge_contact_span(
			along_max, along_min, half_depth_m - eps, half_depth_m + eps,
			across_max, across_min, half_frontage_m
		)
		if front_len > eps:
			edge_lengths[EDGE_FRONT] = front_len

	if center_along < 0.0:
		var rear_len: Variant = _edge_contact_span(
			along_max, along_min, -half_depth_m - eps, -half_depth_m + eps,
			across_max, across_min, half_frontage_m
		)
		if rear_len > eps:
			edge_lengths[EDGE_REAR] = rear_len

	if center_across > 0.0:
		var left_len: Variant = _edge_contact_span(
			across_max, across_min, half_frontage_m - eps, half_frontage_m + eps,
			along_max, along_min, half_depth_m
		)
		if left_len > eps:
			edge_lengths[EDGE_LEFT] = left_len

	if center_across < 0.0:
		var right_len: Variant = _edge_contact_span(
			across_max, across_min, -half_frontage_m - eps, -half_frontage_m + eps,
			along_max, along_min, half_depth_m
		)
		if right_len > eps:
			edge_lengths[EDGE_RIGHT] = right_len

	if edge_lengths.is_empty():
		return _empty_contact()

	var total_contact_m: float = 0.0
	for length_m in edge_lengths.values():
		total_contact_m += length_m

	var weighted_shift_mult: Variant = 0.0
	var weighted_casualty_mult: Variant = 0.0
	for edge_name in edge_lengths.keys():
		var length_m: float = edge_lengths[edge_name]
		weighted_shift_mult += length_m * _edge_shift_multiplier(edge_name)
		weighted_casualty_mult += length_m * _edge_casualty_multiplier(edge_name)
	weighted_shift_mult /= total_contact_m
	weighted_casualty_mult /= total_contact_m

	var attacker_frontage_pct: float = _attacker_contact_frontage_pct(
		attacker, defender, edge_lengths, total_contact_m, px_per_meter
	)
	var defender_edge_pct: float = _defender_engagement_pct(edge_lengths, total_contact_m, half_depth_m, half_frontage_m)
	var push_normal: Vector2 = _dominant_push_normal(edge_lengths, forward, left)

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


static func units_have_contact(attacker: Variant, defender: Variant) -> bool:
	return classify_contact(attacker, defender).get("has_contact", false)


static func is_front_only_contact(contact: Dictionary) -> bool:
	var edges: Dictionary = contact.get("edge_lengths_m", {})
	return edges.size() == 1 and edges.has(EDGE_FRONT)


## Pick one segment orientation per pair (flank/rear contact beats spurious reverse front).
static func pick_segment_orientation(unit_a: Variant, unit_b: Variant) -> Dictionary:
	var contact_ab: Variant = classify_contact(unit_a, unit_b)
	var contact_ba: Variant = classify_contact(unit_b, unit_a)
	var priority_ab: Variant = _segment_orientation_priority(contact_ab)
	var priority_ba: Variant = _segment_orientation_priority(contact_ba)
	if priority_ba > priority_ab:
		return {"attacker": unit_b, "defender": unit_a, "contact": contact_ba}
	if priority_ab > priority_ba:
		return {"attacker": unit_a, "defender": unit_b, "contact": contact_ab}
	if unit_b.unit_id < unit_a.unit_id:
		return {"attacker": unit_b, "defender": unit_a, "contact": contact_ba}
	return {"attacker": unit_a, "defender": unit_b, "contact": contact_ab}


static func has_non_front_segment_contact(unit_a: Variant, unit_b: Variant) -> bool:
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
	var sec_lo: Variant = maxf(secondary_min, -secondary_limit)
	var sec_hi: Variant = minf(secondary_max, secondary_limit)
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
	var max_span: Variant = 0.0
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
	var score: Variant = 0.0
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
	attacker: Variant,
	defender: Variant,
	edge_lengths: Dictionary,
	total_contact_m: float,
	px_per_meter: float
) -> float:
	var front_pct: float = _attacker_front_face_contact_pct(attacker, defender, px_per_meter)
	if front_pct > 0.001 and edge_lengths.has(EDGE_FRONT) and edge_lengths.size() == 1:
		return front_pct
	if edge_lengths.is_empty() or total_contact_m <= 0.0:
		return 0.0
	var flank_only: Variant = (
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
	var frontage_span: Variant = maxf(half_frontage_m * 2.0, 0.001)
	var weighted: Variant = 0.0
	var min_engagement: Variant = 1.0
	for edge_name in edge_lengths.keys():
		var length_m: float = edge_lengths[edge_name]
		var edge_engagement: Variant = clampf(length_m / frontage_span, 0.0, 1.0)
		min_engagement = minf(min_engagement, edge_engagement)
		weighted += length_m * edge_engagement
	var blended: Variant = clampf(weighted / total_contact_m, 0.0, 1.0)
	var flank_only: Variant = (
		not edge_lengths.has(EDGE_FRONT)
		and not edge_lengths.has(EDGE_REAR)
		and (edge_lengths.has(EDGE_LEFT) or edge_lengths.has(EDGE_RIGHT))
	)
	if flank_only:
		return clampf(blended * 0.9, 0.0, 1.0)
	if edge_lengths.size() > 1:
		return min_engagement
	return blended


static func _attacker_front_face_contact_pct(attacker: Variant, defender: Variant, px_per_meter: float) -> float:
	var forward: Vector2 = attacker.facing.normalized()
	var right: Variant = FormationGeometry.right_vector(forward)
	var half_depth_m: float = attacker.effective_depth_m() * 0.5
	var half_frontage_m: float = attacker.effective_frontage_m() * 0.5

	var defender_corners: Variant = FormationGeometry.get_corners(defender)
	var along_min: Variant = INF
	var along_max: Variant = -INF
	var across_min: Variant = INF
	var across_max: Variant = -INF

	for corner in defender_corners:
		var local: Vector2 = corner - attacker.position
		var along: float = local.dot(forward) / px_per_meter
		var across: float = local.dot(right) / px_per_meter
		along_min = minf(along_min, along)
		along_max = maxf(along_max, along)
		across_min = minf(across_min, across)
		across_max = maxf(across_max, across)

	var overlap_across_min: Variant = maxf(across_min, -half_frontage_m)
	var overlap_across_max: Variant = minf(across_max, half_frontage_m)
	var front_touch: float = along_max >= half_depth_m - contact_epsilon_m() and along_min <= half_depth_m + contact_epsilon_m()
	if not front_touch:
		return 0.0

	var contact_span: Variant = maxf(0.0, overlap_across_max - overlap_across_min)
	return clampf(contact_span / maxf(half_frontage_m * 2.0, 0.001), 0.0, 1.0)


## WO-030: interval of attacker's claim on the defender's FRONT edge, meters along
## the defender's left-axis (soldier-left positive), clamped to the defender front.
## Returns {lo, hi, length}. Empty/invalid → length 0.
## Head-on pairs use center-gap contact (CombatResolver.units_have_front_contact);
## for those, lateral AABB overlap on the front line is the claim even when the
## geometric front-face slab test would miss (penetration / depth mismatch).
static func front_edge_interval_m(attacker: Variant, defender: Variant) -> Dictionary:
	var px_per_meter: float = Constants.get_float("px_per_meter")
	var forward: Vector2 = defender.facing.normalized()
	var left: Vector2 = FormationGeometry.left_vector(forward)
	var half_depth_m: float = defender.effective_depth_m() * 0.5
	var half_frontage_m: float = defender.effective_frontage_m() * 0.5
	var eps: float = contact_epsilon_m()

	var along_min: float = INF
	var along_max: float = -INF
	var across_min: float = INF
	var across_max: float = -INF
	for corner in FormationGeometry.get_corners(attacker):
		var local: Vector2 = corner - defender.position
		var along: float = local.dot(forward) / px_per_meter
		var across: float = local.dot(left) / px_per_meter
		along_min = minf(along_min, along)
		along_max = maxf(along_max, along)
		across_min = minf(across_min, across)
		across_max = maxf(across_max, across)

	var head_on_front: bool = _is_head_on_front_contact(attacker, defender)
	# Geometric front-face touch (positive along = in front of defender).
	var touches_front: bool = (
		along_max >= half_depth_m - eps
		and along_min <= half_depth_m + eps
		and along_max > 0.0
	)
	if not head_on_front and not touches_front:
		return {"lo": 0.0, "hi": 0.0, "length": 0.0}

	var lo: float = maxf(across_min, -half_frontage_m)
	var hi: float = minf(across_max, half_frontage_m)
	var length: float = maxf(0.0, hi - lo)
	return {"lo": lo, "hi": hi, "length": length}


## Head-on center-gap contact (mirrors CombatResolver without circular preload).
static func _is_head_on_front_contact(unit_a: Variant, unit_b: Variant) -> bool:
	var to_b: Vector2 = unit_b.position - unit_a.position
	var to_a: Vector2 = unit_a.position - unit_b.position
	if to_b.dot(unit_a.facing) <= 0.0 or to_a.dot(unit_b.facing) <= 0.0:
		return false
	var px_per_meter: float = Constants.get_float("px_per_meter")
	var center_distance_m: float = to_b.length() / px_per_meter
	var gap_m: float = (
		center_distance_m
		- unit_a.effective_depth_m() * 0.5
		- unit_b.effective_depth_m() * 0.5
	)
	return gap_m <= contact_epsilon_m()


## WO-030: partition the defender FRONT edge among concurrent attackers so
## Σ allocated length ≤ defender front width (no double-counted meters).
## Returns Dictionary unit_id -> ContactFrontage% (= allocated_m / attacker.frontage_m).
## Deterministic: claimants sorted by unit_id; overlapping slices split equally.
static func allocate_front_edge_frontage(defender: Variant, attackers: Array) -> Dictionary:
	var out: Dictionary = {}
	if defender == null or attackers.is_empty():
		return out

	var claims: Array = []
	for atk in attackers:
		if atk == null:
			continue
		var iv: Dictionary = front_edge_interval_m(atk, defender)
		var length: float = float(iv.get("length", 0.0))
		if length <= 0.0:
			out[str(atk.unit_id)] = 0.0
			continue
		claims.append(
			{
				"id": str(atk.unit_id),
				"atk": atk,
				"lo": float(iv.lo),
				"hi": float(iv.hi),
			}
		)
	if claims.is_empty():
		return out

	claims.sort_custom(func(a, b): return str(a.id) < str(b.id))

	# Sweep endpoints.
	var points: Array = []
	for c in claims:
		points.append(float(c.lo))
		points.append(float(c.hi))
	points.sort()

	var allocated_m: Dictionary = {}
	for c2 in claims:
		allocated_m[str(c2.id)] = 0.0

	for i in range(points.size() - 1):
		var a: float = float(points[i])
		var b: float = float(points[i + 1])
		var seg: float = b - a
		if seg <= 1e-9:
			continue
		var mid: float = (a + b) * 0.5
		var owners: Array = []
		for c3 in claims:
			if float(c3.lo) <= mid and mid <= float(c3.hi):
				owners.append(str(c3.id))
		if owners.is_empty():
			continue
		var share: float = seg / float(owners.size())
		for oid in owners:
			allocated_m[oid] = float(allocated_m.get(oid, 0.0)) + share

	for c4 in claims:
		var id4: String = str(c4.id)
		var front_m: float = maxf(float(c4.atk.effective_frontage_m()), 0.001)
		out[id4] = clampf(float(allocated_m.get(id4, 0.0)) / front_m, 0.0, 1.0)
	return out


static func _dominant_push_normal(edge_lengths: Dictionary, forward: Vector2, left: Vector2) -> Vector2:
	var best_edge: Variant = EDGE_FRONT
	var best_len: Variant = -1.0
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
