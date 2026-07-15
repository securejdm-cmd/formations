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
	## Tactical top speed (march / trot). Charge gait uses target_speed_m_s().
	return (
		float(unit.profile.get("speed", 0.0))
		* Constants.get_float("speed_stat_meters_per_10s")
		/ 10.0
	)


static func charge_gait_mult(unit: Variant) -> float:
	return maxf(1.0, float(unit.profile.get("charge_gait_mult", 1.0)))


static func gait_top_speed_m_s(unit: Variant) -> float:
	return top_speed_m_s(unit) * charge_gait_mult(unit)


static func target_speed_m_s(unit: Variant) -> float:
	## Movement ceiling this tick: gait top when charge-committed, else tactical.
	## WO-021: slope_speed_mult emerges from HeightField (identity at grade 0).
	var base: float
	if unit != null and "charge_committed" in unit and bool(unit.charge_committed):
		base = gait_top_speed_m_s(unit)
	else:
		base = top_speed_m_s(unit)
	return base * _slope_speed_mult(unit)


static func _slope_speed_mult(unit: Variant) -> float:
	if unit != null and "slope_speed_mult" in unit:
		return maxf(0.05, float(unit.slope_speed_mult))
	return 1.0


static func accel_m_s2(unit: Variant) -> float:
	## WO-021: same slope mult as top speed — downhill accelerates faster (R6), no charge-specific path.
	return (
		Constants.get_float("base_accel")
		/ maxf(mass_of(unit), 0.01)
		* _slope_speed_mult(unit)
	)


static func decel_m_s2(unit: Variant) -> float:
	return (
		Constants.get_float("base_decel")
		/ maxf(mass_of(unit), 0.01)
		* _slope_speed_mult(unit)
	)


static func charge_min_closing_m_s(attacker: Variant) -> float:
	## R18: relative threshold — own tactical Speed × charge_min_speed_pct.
	## gait_mult=1.0 units can never exceed their Speed, so they never charge.
	return top_speed_m_s(attacker) * Constants.get_float("charge_min_speed_pct")


static func march_substep_count(unit: Variant, delta: float) -> int:
	## Keep per-substep displacement < engage_snap_max_m at gait speeds (R18 Task 3).
	var snap := Constants.get_float("engage_snap_max_m")
	if snap <= 0.0 or delta <= 0.0:
		return 1
	var top := target_speed_m_s(unit)
	var speed_now: float = float(unit.current_speed_m_s) if "current_speed_m_s" in unit else 0.0
	var peak := minf(top, speed_now + accel_m_s2(unit) * delta)
	peak = maxf(peak, speed_now)
	var disp := peak * delta
	if disp < snap:
		return 1
	return int(floor(disp / snap)) + 1


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


static func contact_inward_normal(attacker: Variant, defender: Variant, edges: Dictionary = {}) -> Vector2:
	## Length-weighted inward contact normal (WO-016: closing along contact normal).
	## Falls back to approach direction, then front inward, when edges are empty.
	var edge_lengths: Dictionary = edges
	if edge_lengths.is_empty():
		var contact: Dictionary = EdgeContact.classify_contact(attacker, defender)
		edge_lengths = contact.get("edge_lengths_m", {})
	if not edge_lengths.is_empty():
		var weighted := Vector2.ZERO
		var total_len := 0.0
		for edge_name in edge_lengths.keys():
			var length_m: float = float(edge_lengths[edge_name])
			total_len += length_m
			weighted += _edge_inward_normal(defender, str(edge_name)) * length_m
		if total_len > 0.0 and weighted.length_squared() > 0.0001:
			return weighted.normalized()
	var to_def: Vector2 = defender.position - attacker.position
	if to_def.length_squared() > 0.0001:
		return to_def.normalized()
	return -defender.facing.normalized()


static func closing_speed_into_defender(attacker: Variant, defender: Variant) -> float:
	# Cheap front-axis closing used by brace threat detection (sim m/s).
	# Charge Impact uses closing_speed_along_contact() (contact normal).
	var into_def: Vector2 = -defender.facing.normalized()
	return maxf(0.0, velocity_world(attacker).dot(into_def))


static func closing_speed_along_contact(attacker: Variant, defender: Variant, edges: Dictionary = {}) -> float:
	# Attacker's real speed along the contact inward normal (sim m/s). R17: no SI conversion.
	return maxf(0.0, velocity_world(attacker).dot(contact_inward_normal(attacker, defender, edges)))


static func calc_impact(attacker: Variant, defender: Variant, closing_speed_m_s: float) -> float:
	## Impact from real sim-m/s closing (R17). No hidden conversion.
	var strength_pct: float = attacker.strength / Constants.get_float("strength_max")
	return (
		mass_of(attacker)
		* closing_speed_m_s
		* strength_pct
		* Constants.get_float("charge_impact_scale")
	)


static func distance_m(a: Variant, b: Variant) -> float:
	var px := Constants.get_float("px_per_meter")
	return a.position.distance_to(b.position) / px


static func find_charge_commit_target(unit: Variant, enemies: Array) -> Variant:
	## Closest enemy in front arc within charge_commit_range_m (or null).
	if charge_gait_mult(unit) <= 1.0 + 0.001:
		return null
	var best = null
	var best_dist := INF
	var range_m := Constants.get_float("charge_commit_range_m")
	for enemy in enemies:
		if enemy == null:
			continue
		var st = enemy.get_state() if enemy.has_method("get_state") else -1
		if st == Unit.State.REMOVED or st == Unit.State.ROUTING:
			continue
		if str(enemy.team_id) == str(unit.team_id):
			continue
		if not faces_threat(unit, enemy):
			continue
		var d := distance_m(unit, enemy)
		if d > range_m:
			continue
		if d < best_dist:
			best_dist = d
			best = enemy
	return best


## Length-weighted casualty (morale) multiplier of the defender edges under charge contact.
## Front ×1, side ×edge_mult_side_casualty, rear ×edge_mult_rear_casualty (R15 extension).
static func charge_edge_morale_mult(attacker: Variant, defender: Variant, edges_override: Dictionary = {}) -> Dictionary:
	var edges: Dictionary = edges_override
	if edges.is_empty():
		var contact: Dictionary = EdgeContact.classify_contact(attacker, defender)
		edges = contact.get("edge_lengths_m", {})
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


static func is_charging_threat(attacker: Variant, defender: Variant) -> bool:
	## Cheap front-arc charge threat (no full classification). Closing in sim m/s.
	if attacker == null or defender == null:
		return false
	if not faces_threat(defender, attacker):
		return false
	var closing := closing_speed_into_defender(attacker, defender)
	return closing >= charge_min_closing_m_s(attacker)


static func own_speed_allows_instinctive(defender: Variant) -> bool:
	var top := top_speed_m_s(defender)
	var cap := top * Constants.get_float("brace_max_own_speed_pct")
	var spd: float = float(defender.current_speed_m_s) if "current_speed_m_s" in defender else 0.0
	return spd <= cap + 0.001


static func is_engaged_with_other(defender: Variant, exclude_attacker: Variant) -> bool:
	if defender == null or not defender.has_method("get_contact_partners"):
		return false
	for partner in defender.get_contact_partners():
		if partner == null:
			continue
		if exclude_attacker != null and partner == exclude_attacker:
			continue
		if str(partner.team_id) == str(defender.team_id):
			continue
		var st = partner.get_state() if partner.has_method("get_state") else -1
		if st == Unit.State.REMOVED:
			continue
		return true
	return false


static func threat_front_sec_of(defender: Variant) -> float:
	if defender == null:
		return 0.0
	if "threat_front_sec" in defender:
		return float(defender.threat_front_sec)
	if "_threat_front_sec" in defender:
		return float(defender._threat_front_sec)
	return 0.0


## R16 brace tier at impact. Returns {tier, mult, name}.
static func resolve_brace_tier(attacker: Variant, defender: Variant, edge_name: String) -> Dictionary:
	# Tier 2 — Pierce set-to-receive.
	if is_pierce(defender) and defender.has_method("is_braced") and defender.is_braced():
		return {"tier": 2, "mult": 0.0, "name": "set_to_receive"}
	# Tier 1 — Instinctive (frontal only).
	var front := str(edge_name) == EdgeContact.EDGE_FRONT
	if (
		front
		and threat_front_sec_of(defender) + 0.001 >= Constants.get_float("brace_reaction_s")
		and not is_engaged_with_other(defender, attacker)
		and own_speed_allows_instinctive(defender)
	):
		return {
			"tier": 1,
			"mult": Constants.get_float("instinctive_brace_mult"),
			"name": "instinctive",
		}
	return {"tier": 3, "mult": 1.0, "name": "unaware"}


static func charge_amp_of(unit: Variant) -> float:
	if unit == null:
		return 1.0
	return maxf(1.0, float(unit.charge_amp_factor))
