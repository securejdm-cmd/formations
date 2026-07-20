class_name Concealment
extends RefCounted

## WO-032 Sec 10 — terrain patches, fit rule, detection radii, forest penalties.

const PATCH_FOREST := "FOREST"
const PATCH_SHRUB := "SHRUB"
const PROFILE_LOW := "Low"
const PROFILE_MEDIUM := "Medium"
const PROFILE_HIGH := "High"
const PROFILE_MASSIVE := "Massive"

const _FormationGeometry := preload("res://scripts/formation_geometry.gd")
const _Charge := preload("res://scripts/charge_combat.gd")


static func profile_label(unit: Variant) -> String:
	return str(unit.profile.get("profile", PROFILE_MEDIUM))


static func can_conceal_profile(unit: Variant) -> bool:
	return profile_label(unit) != PROFILE_MASSIVE


static func profile_detect_mult(unit: Variant) -> float:
	match profile_label(unit):
		PROFILE_LOW:
			return Constants.get_float("concealment_profile_mult_low")
		PROFILE_HIGH:
			return Constants.get_float("concealment_profile_mult_high")
		PROFILE_MASSIVE:
			return 0.0
		_:
			return Constants.get_float("concealment_profile_mult_medium")


static func base_detect_radius_m(patch_type: String) -> float:
	if patch_type == PATCH_SHRUB:
		return Constants.get_float("shrub_detect_radius_m")
	return Constants.get_float("forest_detect_radius_m")


static func is_moving_for_detection(unit: Variant) -> bool:
	## TD-confirmed: current_speed_m_s > brace_stationary_speed.
	return float(unit.current_speed_m_s) > Constants.get_float("brace_stationary_speed")


static func effective_detect_radius_m(unit: Variant, patch_type: String) -> float:
	var base: float = base_detect_radius_m(patch_type)
	var prof: float = profile_detect_mult(unit)
	var move_mult: float = 1.0
	if is_moving_for_detection(unit):
		move_mult = Constants.get_float("concealment_moving_detect_mult")
	return base * prof * move_mult


static func patch_type_of(patch: Dictionary) -> String:
	return str(patch.get("type", PATCH_FOREST)).to_upper()


static func point_in_patch_m(pos_m: Vector2, patch: Dictionary) -> bool:
	var x: float = float(patch.get("x", 0.0))
	var y: float = float(patch.get("y", 0.0))
	var w: float = float(patch.get("w", 0.0))
	var h: float = float(patch.get("h", 0.0))
	return pos_m.x >= x and pos_m.x <= x + w and pos_m.y >= y and pos_m.y <= y + h


static func world_px_to_m(pos_px: Vector2) -> Vector2:
	var px: float = Constants.get_float("px_per_meter")
	return Vector2(pos_px.x / px, pos_px.y / px)


static func unit_center_in_patch(unit: Variant, patch: Dictionary) -> bool:
	return point_in_patch_m(world_px_to_m(unit.position), patch)


static func footprint_fully_in_patch(unit: Variant, patch: Dictionary) -> bool:
	var corners: PackedVector2Array = _FormationGeometry.get_corners(unit)
	for i in corners.size():
		if not point_in_patch_m(world_px_to_m(corners[i]), patch):
			return false
	return true


static func find_covering_patch(unit: Variant, patches: Array) -> Dictionary:
	## Prefer a patch that fully contains the footprint (fit rule).
	for patch in patches:
		if typeof(patch) != TYPE_DICTIONARY:
			continue
		if footprint_fully_in_patch(unit, patch):
			return patch
	return {}


static func find_center_patch(unit: Variant, patches: Array) -> Dictionary:
	for patch in patches:
		if typeof(patch) != TYPE_DICTIONARY:
			continue
		if unit_center_in_patch(unit, patch):
			return patch
	return {}


static func is_in_forest(unit: Variant, patches: Array) -> bool:
	var p: Dictionary = find_center_patch(unit, patches)
	return not p.is_empty() and patch_type_of(p) == PATCH_FOREST


static func forest_speed_mult(unit: Variant, patches: Array) -> float:
	## Sec 10 / TD: High profile (= all mounted) ×0.6 inside FOREST.
	if patches.is_empty():
		return 1.0
	if profile_label(unit) != PROFILE_HIGH:
		return 1.0
	if not is_in_forest(unit, patches):
		return 1.0
	return Constants.get_float("forest_cavalry_speed_mult")


static func forest_missile_mult(shooter: Variant, target: Variant, patches: Array) -> float:
	## −25% when shooter OR target center is in FOREST (symmetric). Shrub: no penalty.
	if patches.is_empty():
		return 1.0
	var penalty: float = Constants.get_float("forest_missile_penalty")
	var mult: float = 1.0
	if is_in_forest(shooter, patches) or is_in_forest(target, patches):
		mult = 1.0 - penalty
	return mult


static func try_begin_concealed(unit: Variant, patches: Array) -> bool:
	## Fit rule + Massive rejection. Sets unit.concealed / concealment_patch_type.
	if unit == null:
		return false
	unit.concealed = false
	unit.concealment_patch_type = ""
	if str(unit.starting_posture) != "concealed":
		return false
	if not can_conceal_profile(unit):
		return false
	var patch: Dictionary = find_covering_patch(unit, patches)
	if patch.is_empty():
		return false
	unit.concealed = true
	unit.concealment_patch_type = patch_type_of(patch)
	unit.ever_revealed = false
	return true


static func is_concealed_from(viewer: Variant, other: Variant) -> bool:
	## Asymmetric: concealed units are invisible to the enemy side only.
	if other == null or viewer == null:
		return false
	if not bool(other.concealed):
		return false
	return str(other.team_id) != str(viewer.team_id)


static func distance_m(a: Variant, b: Variant) -> float:
	return _Charge.distance_m(a, b)
