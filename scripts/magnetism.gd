extends RefCounted

## WO-020 full magnetism — engagement gravity, agility rotation, disengage (R19).
## Turn formula (live): rad/s = base_turn_rate_rad × (Agility/50) / mass  (R5).
## Equivalent deg/s = rad/s × 180/π.

const _Charge := preload("res://scripts/charge_combat.gd")


static func agility_of(unit: Variant) -> float:
	return float(unit.profile.get("agility", 50.0))


static func turn_rate_rad_s(unit: Variant) -> float:
	## Same as ChargeCombat.turn_rate_rad_s — Agility live for gravity & wheel.
	return _Charge.turn_rate_rad_s(unit)


static func turn_rate_deg_s(unit: Variant) -> float:
	return turn_rate_rad_s(unit) * 180.0 / PI


static func disengage_duration_s(unit: Variant) -> float:
	var a: float = agility_of(unit)
	return Constants.get_float("disengage_base_s") * (1.0 - a / 150.0)


static func rotate_under_contact_drain_per_s(unit: Variant) -> float:
	var a: float = agility_of(unit)
	return Constants.get_float("rotate_under_contact_drain") * (1.0 - a / 150.0)


static func is_pinned(unit: Variant) -> bool:
	## R19: already in contact → no auto-rotate toward new contacts.
	if unit == null:
		return false
	if unit.has_method("get_contact_partners"):
		return not unit.get_contact_partners().is_empty()
	return false


static func is_disengaging(unit: Variant) -> bool:
	if unit == null:
		return false
	if "disengaging" in unit:
		return bool(unit.disengaging)
	if "_disengaging" in unit:
		return bool(unit._disengaging)
	return false


static func can_deal_melee(unit: Variant) -> bool:
	return not is_disengaging(unit)


static func faces_in_front_arc(unit: Variant, other: Variant) -> bool:
	return _Charge.faces_threat(unit, other)


static func distance_m(a: Variant, b: Variant) -> float:
	return _Charge.distance_m(a, b)


static func find_gravity_target(unit: Variant, enemies: Array) -> Variant:
	## Closest enemy in front arc within engage_radius_m SURFACE GAP (WO-024).
	## DAMAGE_AND_CATEGORIES Sec 5: distance between blocks, not centers.
	if is_pinned(unit) or is_disengaging(unit):
		return null
	var best = null
	var best_gap: float = INF
	var radius: float = Constants.get_float("engage_radius_m")
	for enemy in enemies:
		if enemy == null:
			continue
		var st = enemy.get_state() if enemy.has_method("get_state") else -1
		if st == Unit.State.REMOVED or st == Unit.State.ROUTING:
			continue
		if str(enemy.team_id) == str(unit.team_id):
			continue
		if not faces_in_front_arc(unit, enemy):
			continue
		# Surface gap along unit facing; ≤ radius (incl. overlap ≤0) triggers.
		var gap: float = FormationGeometry.surface_gap_along_facing_m(unit, enemy)
		if gap > radius:
			continue
		if gap < best_gap:
			best_gap = gap
			best = enemy
	return best


static func rotate_toward(unit: Variant, desired: Vector2, delta: float) -> float:
	## Rotate facing toward desired; returns abs angle moved this tick (rad).
	if desired.length_squared() <= 0.0001:
		return 0.0
	var want: Vector2 = desired.normalized()
	var angled: float = unit.facing.angle_to(want)
	if absf(angled) <= 0.001:
		return 0.0
	var max_turn: float = turn_rate_rad_s(unit) * delta
	var stepped: float = 0.0
	if absf(angled) <= max_turn:
		unit.facing = want
		stepped = absf(angled)
	else:
		unit.facing = unit.facing.rotated(signf(angled) * max_turn)
		stepped = max_turn
	if "rotation" in unit:
		unit.rotation = unit.facing.angle()
	return stepped
