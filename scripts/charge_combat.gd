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


static func closing_speed_into_defender(attacker: Variant, defender: Variant) -> float:
	# Speed of attacker along the direction into the defender's front face.
	var into_def: Vector2 = -defender.facing.normalized()
	return maxf(0.0, velocity_world(attacker).dot(into_def))


static func calc_impact(attacker: Variant, defender: Variant, closing_speed: float) -> float:
	var strength_pct: float = attacker.strength / Constants.get_float("strength_max")
	return (
		mass_of(attacker)
		* closing_speed
		* strength_pct
		* Constants.get_float("charge_impact_scale")
	)


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
