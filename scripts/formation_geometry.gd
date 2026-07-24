class_name FormationGeometry
extends RefCounted

## Oriented formation rectangles: depth along facing, frontage perpendicular.

## Facing must always be a unit vector. Zero / near-zero → +X fallback.
const FACING_UNIT_EPS := 0.01


static func normalize_facing(facing: Vector2) -> Vector2:
	if facing.length_squared() <= 0.0001:
		return Vector2.RIGHT
	return facing.normalized()


static func facing_is_unit(facing: Vector2) -> bool:
	return absf(facing.length() - 1.0) <= FACING_UNIT_EPS


static func left_vector(facing: Vector2) -> Vector2:
	# Soldier's left: facing rotated +90° counterclockwise (Godot Y-down).
	var f: Vector2 = normalize_facing(facing)
	return Vector2(f.y, -f.x)


static func right_vector(facing: Vector2) -> Vector2:
	# Soldier's right: facing rotated -90° clockwise.
	var f: Vector2 = normalize_facing(facing)
	return Vector2(-f.y, f.x)


static func get_corners(unit: Variant) -> PackedVector2Array:
	var px_per_meter: float = Constants.get_float("px_per_meter")
	var half_depth_px: float = unit.effective_depth_m() * 0.5 * px_per_meter
	var half_frontage_px: float = unit.effective_frontage_m() * 0.5 * px_per_meter
	var forward: Vector2 = normalize_facing(unit.facing)
	var right: Variant = right_vector(forward)

	return PackedVector2Array([
		unit.position + forward * half_depth_px + right * half_frontage_px,
		unit.position + forward * half_depth_px - right * half_frontage_px,
		unit.position - forward * half_depth_px - right * half_frontage_px,
		unit.position - forward * half_depth_px + right * half_frontage_px,
	])


## Minimum surface gap (m) from `unit`'s front face to `other`'s OBB along
## `unit`'s facing (arc-of-travel). Positive = separation ahead; ≤0 = overlap
## along the approach axis (contact / penetration). Used by engagement gravity
## (WO-024 — Sec 5 is block surface gap, not center distance).
static func surface_gap_along_facing_m(unit: Variant, other: Variant) -> float:
	var px_per_meter: float = Constants.get_float("px_per_meter")
	var forward: Vector2 = normalize_facing(unit.facing)
	if forward.length_squared() <= 0.0001:
		return INF
	var half_depth_m: float = unit.effective_depth_m() * 0.5
	var unit_front_m: float = (unit.position / px_per_meter).dot(forward) + half_depth_m
	var other_near_m: float = INF
	for corner in get_corners(other):
		other_near_m = minf(other_near_m, (corner / px_per_meter).dot(forward))
	return other_near_m - unit_front_m


static func contains_world_point(unit: Variant, world_point: Vector2) -> bool:
	var px_per_meter: float = Constants.get_float("px_per_meter")
	var half_depth_px: float = unit.effective_depth_m() * 0.5 * px_per_meter
	var half_frontage_px: float = unit.effective_frontage_m() * 0.5 * px_per_meter
	var local: Vector2 = world_point - unit.position
	var forward: Vector2 = normalize_facing(unit.facing)
	var right: Variant = right_vector(forward)
	var along: float = local.dot(forward)
	var across: float = local.dot(right)
	return absf(along) <= half_depth_px and absf(across) <= half_frontage_px


static func bounds_may_overlap(unit_a: Variant, unit_b: Variant) -> bool:
	var px_per_meter: float = Constants.get_float("px_per_meter")
	var dist: float = unit_a.position.distance_to(unit_b.position)
	var half_diag_a: Variant = sqrt(
		pow(unit_a.effective_depth_m() * 0.5 * px_per_meter, 2.0)
		+ pow(unit_a.effective_frontage_m() * 0.5 * px_per_meter, 2.0)
	)
	var half_diag_b: Variant = sqrt(
		pow(unit_b.effective_depth_m() * 0.5 * px_per_meter, 2.0)
		+ pow(unit_b.effective_frontage_m() * 0.5 * px_per_meter, 2.0)
	)
	return dist <= half_diag_a + half_diag_b + px_per_meter * 0.25


static func rectangles_overlap(unit_a: Variant, unit_b: Variant) -> bool:
	if not bounds_may_overlap(unit_a, unit_b):
		return false
	return _obb_overlap(get_corners(unit_a), get_corners(unit_b))


static func _obb_overlap(corners_a: PackedVector2Array, corners_b: PackedVector2Array) -> bool:
	## WO-037: SAT axes are always normalized (orthonormal projection).
	var axes: Array[Vector2] = []
	axes.append(_edge_normal(corners_a[0], corners_a[1]))
	axes.append(_edge_normal(corners_a[1], corners_a[2]))
	axes.append(_edge_normal(corners_b[0], corners_b[1]))
	axes.append(_edge_normal(corners_b[1], corners_b[2]))

	for axis in axes:
		if axis.length_squared() <= 0.0001:
			continue
		axis = axis.normalized()
		var a_proj: Variant = _project_corners(corners_a, axis)
		var b_proj: Variant = _project_corners(corners_b, axis)
		if a_proj.y < b_proj.x or b_proj.y < a_proj.x:
			return false

	return true


static func _edge_normal(a: Vector2, b: Vector2) -> Vector2:
	var edge: Variant = b - a
	return Vector2(-edge.y, edge.x)


static func _project_corners(corners: PackedVector2Array, axis: Vector2) -> Vector2:
	var min_v: Variant = axis.dot(corners[0])
	var max_v: Variant = min_v
	for i in range(1, corners.size()):
		var value: Variant = axis.dot(corners[i])
		min_v = minf(min_v, value)
		max_v = maxf(max_v, value)
	return Vector2(min_v, max_v)
