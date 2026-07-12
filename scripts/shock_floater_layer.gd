class_name ShockFloaterLayer
extends CanvasLayer

const FLOATER_SCRIPT := preload("res://scripts/shock_floater.gd")


func spawn_for_unit(unit: Unit, amount: float, camera: Camera2D) -> void:
	if unit == null or camera == null or amount <= 0.0:
		return
	var px_per_meter := Constants.get_float("px_per_meter")
	var half_frontage_px := unit.effective_frontage_m() * 0.5 * px_per_meter
	var world_above := unit.position + Vector2(0.0, -(half_frontage_px + 12.0))
	var screen_pos := camera.get_canvas_transform() * world_above
	var floater: Label = FLOATER_SCRIPT.new()
	add_child(floater)
	floater.setup(screen_pos, amount)
