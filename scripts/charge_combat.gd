class_name ChargeCombat
extends RefCounted

## WO-016 momentum charge + brace helpers (R4 / R5). No knockback.

const MASS_BY_PROFILE_PATH := "res://data/mass_by_profile.json"
static var _mass_table: Dictionary = {}


static func _ensure_mass_table() -> void:
	if not _mass_table.is_empty():
		return
	if not FileAccess.file_exists(MASS_BY_PROFILE_PATH):
		_mass_table = {
			"Low": Constants.get_float("mass_low"),
			"Medium": Constants.get_float("mass_medium"),
			"High": Constants.get_float("mass_high"),
			"Massive": Constants.get_float("mass_massive"),
		}
		return
	var text := FileAccess.get_file_as_string(MASS_BY_PROFILE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		_mass_table = parsed
	else:
		_mass_table = {
			"Low": Constants.get_float("mass_low"),
			"Medium": Constants.get_float("mass_medium"),
			"High": Constants.get_float("mass_high"),
			"Massive": Constants.get_float("mass_massive"),
		}


static func mass_of(unit: Variant) -> float:
	_ensure_mass_table()
	var label := str(unit.profile.get("profile", "Medium"))
	if _mass_table.has(label):
		return float(_mass_table[label])
	return float(_mass_table.get("Medium", Constants.get_float("mass_medium")))


static func top_speed_m_s(unit: Variant) -> float:
	return (
		float(unit.profile.get("speed", 0.0))
		* Constants.get_float("speed_stat_meters_per_10s")
		/ 10.0
	)


static func accel_m_s2(unit: Variant) -> float:
	return Constants.get_float("base_accel") / maxf(mass_of(unit), 0.01)


static func decel_m_s2(unit: Variant) -> float:
	return Constants.get_float("base_decel") / maxf(mass_of(unit), 0.01)


static func turn_rate_rad_s(unit: Variant) -> float:
	var agility := float(unit.profile.get("agility", 50.0))
	var agility_factor := clampf(agility / 50.0, 0.25, 2.0)
	return Constants.get_float("base_turn_rate_rad") * agility_factor / maxf(mass_of(unit), 0.01)


static func velocity_world(unit: Variant) -> Vector2:
	var speed: float = float(unit.current_speed_m_s) if "current_speed_m_s" in unit else 0.0
	return unit.facing.normalized() * speed


static func _edge_inward_normal(defender: Variant, edge_name: String) -> Vector2:
	# Inward = into the block through that edge (opposite the edge outward axis).
	var forward: Vector2 = defender.facing.normalized()
	var left: Vector2 = FormationGeometry.left_vector(forward)
	match edge_name:
		EdgeContact.EDGE_FRONT:
			return -forward
		EdgeContact.EDGE_REAR:
			return forward
		EdgeContact.EDGE_LEFT:
			return -left
		EdgeContact.EDGE_RIGHT:
			return left
	return -forward


static func contact_inward_normal(attacker: Variant, defender: Variant) -> Vector2:
	## Length-weighted inward contact normal (WO-016: closing along contact normal).
	## Falls back to approach direction, then front inward, when edges are empty.
	var contact: Dictionary = EdgeContact.classify_contact(attacker, defender)
	var edges: Dictionary = contact.get("edge_lengths_m", {})
	if not edges.is_empty():
		var weighted := Vector2.ZERO
		var total_len := 0.0
		for edge_name in edges.keys():
			var length_m: float = float(edges[edge_name])
			total_len += length_m
			weighted += _edge_inward_normal(defender, str(edge_name)) * length_m
		if total_len > 0.0 and weighted.length_squared() > 0.0001:
			return weighted.normalized()
	var to_def: Vector2 = defender.position - attacker.position
	if to_def.length_squared() > 0.0001:
		return to_def.normalized()
	return -defender.facing.normalized()


static func closing_speed_into_defender(attacker: Variant, defender: Variant) -> float:
	# Attacker's speed along the contact inward normal (sim m/s).
	# Frontal = prior -facing projection; flank/rear use the struck edge normal.
	return maxf(0.0, velocity_world(attacker).dot(contact_inward_normal(attacker, defender)))


static func si_scale() -> float:
	## Maps underscaled sim m/s → design SI m/s (WO-016b). Movement stays on
	## speed_stat_meters_per_10s=1.0 so S1/S12 approach timing is preserved.
	return Constants.get_float("charge_speed_si_scale")


static func closing_speed_si(attacker: Variant, defender: Variant) -> float:
	return closing_speed_into_defender(attacker, defender) * si_scale()


static func calc_impact(attacker: Variant, defender: Variant, closing_speed_si_m_s: float) -> float:
	var strength_pct: float = attacker.strength / Constants.get_float("strength_max")
	return (
		mass_of(attacker)
		* closing_speed_si_m_s
		* strength_pct
		* Constants.get_float("charge_impact_scale")
	)


## Length-weighted casualty (morale) multiplier of the defender edges under charge contact.
## Front ×1, side ×edge_mult_side_casualty, rear ×edge_mult_rear_casualty (R15 extension).
static func charge_edge_morale_mult(attacker: Variant, defender: Variant) -> Dictionary:
	var contact: Dictionary = EdgeContact.classify_contact(attacker, defender)
	var edges: Dictionary = contact.get("edge_lengths_m", {})
	if edges.is_empty() and CombatResolver.is_head_on_pair(attacker, defender):
		return {
			"edge": EdgeContact.EDGE_FRONT,
			"mult": Constants.get_float("edge_mult_front"),
			"edge_lengths_m": {EdgeContact.EDGE_FRONT: 1.0},
		}
	if edges.is_empty():
		return {
			"edge": EdgeContact.EDGE_FRONT,
			"mult": Constants.get_float("edge_mult_front"),
			"edge_lengths_m": {},
		}
	var total_len := 0.0
	var weighted := 0.0
	var dominant := EdgeContact.EDGE_FRONT
	var dominant_len := -1.0
	for edge_name in edges.keys():
		var length_m: float = float(edges[edge_name])
		total_len += length_m
		var m: float = EdgeContact._edge_casualty_multiplier(str(edge_name))
		weighted += length_m * m
		if length_m > dominant_len:
			dominant_len = length_m
			dominant = str(edge_name)
	var mult := Constants.get_float("edge_mult_front")
	if total_len > 0.0:
		mult = weighted / total_len
	return {"edge": dominant, "mult": mult, "edge_lengths_m": edges.duplicate()}


static func base_charge_shock(impact: float) -> float:
	return impact * Constants.get_float("charge_cohesion_coeff")


static func is_pierce(unit: Variant) -> bool:
	return str(unit.profile.get("melee_damage_type", "")).to_upper() == "PIERCE"


static func faces_threat(defender: Variant, attacker: Variant) -> bool:
	var to_attacker: Vector2 = attacker.position - defender.position
	if to_attacker.length_squared() <= 0.0001:
		return false
	return defender.facing.normalized().dot(to_attacker.normalized()) > 0.5


static func charge_amp_of(unit: Variant) -> float:
	if unit == null:
		return 1.0
	return maxf(1.0, float(unit.charge_amp_factor))
