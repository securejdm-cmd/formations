class_name FormationGeometry
extends RefCounted

## Oriented formation rectangles: depth along facing, frontage perpendicular.


static func left_vector(facing: Vector2) -> Vector2:
	# Soldier's left: facing rotated +90° counterclockwise (Godot Y-down).
	return Vector2(facing.y, -facing.x)


static func right_vector(facing: Vector2) -> Vector2:
	# Soldier's right: facing rotated -90° clockwise.
	return Vector2(-facing.y, facing.x)


static func get_corners(unit: Unit) -> PackedVector2Array:
	var px_per_meter := Constants.get_float("px_per_meter")
	var half_depth_px := unit.effective_depth_m() * 0.5 * px_per_meter
	var half_frontage_px := unit.effective_frontage_m() * 0.5 * px_per_meter
	var forward := unit.facing.normalized()
	var right := right_vector(forward)

	return PackedVector2Array([
		unit.position + forward * half_depth_px + right * half_frontage_px,
		unit.position + forward * half_depth_px - right * half_frontage_px,
		unit.position - forward * half_depth_px - right * half_frontage_px,
		unit.position - forward * half_depth_px + right * half_frontage_px,
	])


static func contains_world_point(unit: Unit, world_point: Vector2) -> bool:
	var px_per_meter := Constants.get_float("px_per_meter")
	var half_depth_px := unit.effective_depth_m() * 0.5 * px_per_meter
	var half_frontage_px := unit.effective_frontage_m() * 0.5 * px_per_meter
	var local := world_point - unit.position
	var forward := unit.facing.normalized()
	var right := right_vector(forward)
	var along := local.dot(forward)
	var across := local.dot(right)
	return absf(along) <= half_depth_px and absf(across) <= half_frontage_px


static func rectangles_overlap(unit_a: Unit, unit_b: Unit) -> bool:
	return _obb_overlap(get_corners(unit_a), get_corners(unit_b))


static func _obb_overlap(corners_a: PackedVector2Array, corners_b: PackedVector2Array) -> bool:
	var axes: Array[Vector2] = []
	axes.append(_edge_normal(corners_a[0], corners_a[1]))
	axes.append(_edge_normal(corners_a[1], corners_a[2]))
	axes.append(_edge_normal(corners_b[0], corners_b[1]))
	axes.append(_edge_normal(corners_b[1], corners_b[2]))

	for axis in axes:
		if axis.length_squared() <= 0.0001:
			continue
		axis = axis.normalized()
		var a_proj := _project_corners(corners_a, axis)
		var b_proj := _project_corners(corners_b, axis)
		if a_proj.y < b_proj.x or b_proj.y < a_proj.x:
			return false

	return true


static func _edge_normal(a: Vector2, b: Vector2) -> Vector2:
	var edge := b - a
	return Vector2(-edge.y, edge.x)


static func _project_corners(corners: PackedVector2Array, axis: Vector2) -> Vector2:
	var min_v := axis.dot(corners[0])
	var max_v := min_v
	for i in range(1, corners.size()):
		var value := axis.dot(corners[i])
		min_v = minf(min_v, value)
		max_v = maxf(max_v, value)
	return Vector2(min_v, max_v)
