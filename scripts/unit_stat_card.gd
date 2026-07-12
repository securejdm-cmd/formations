class_name UnitStatCard
extends PanelContainer

const OFFSET_ABOVE_PX := 28.0

var _unit: Unit = null
var _camera: Camera2D = null

@onready var _label: Label = $MarginContainer/Label


func setup(camera: Camera2D) -> void:
	_camera = camera
	scale = Vector2.ONE
	visible = false


func show_for_unit(unit: Unit) -> void:
	_unit = unit
	visible = true
	_refresh_text()
	_update_position()


func dismiss() -> void:
	_unit = null
	visible = false


func get_tracked_unit() -> Unit:
	return _unit


func _process(_delta: float) -> void:
	if _unit == null:
		return
	if _unit.get_state() == Unit.State.REMOVED:
		dismiss()
		return
	_refresh_text()
	_update_position()


func _refresh_text() -> void:
	if _unit == null:
		return
	_label.text = "STR %d%% · COH %d%% · ⚔ %d" % [
		int(round(_unit.strength_percent())),
		int(round(_unit.cohesion_percent())),
		_unit.soldiers_defeated(),
	]


func _update_position() -> void:
	if _unit == null or _camera == null:
		return

	# Screen-space card: constant pixel size regardless of zoom.
	scale = Vector2.ONE
	var px_per_meter := Constants.get_float("px_per_meter")
	var half_frontage_px := _unit.effective_frontage_m() * 0.5 * px_per_meter
	var world_above := _unit.position + Vector2(0.0, -(half_frontage_px + OFFSET_ABOVE_PX))
	var screen_pos: Vector2 = _camera.get_canvas_transform() * world_above

	var viewport_size := get_viewport().get_visible_rect().size
	var margin := Constants.get_float("stat_card_edge_margin_px")
	var half := size * 0.5
	screen_pos.x = clampf(screen_pos.x, margin + half.x, viewport_size.x - margin - half.x)
	screen_pos.y = clampf(screen_pos.y, margin + half.y, viewport_size.y - margin - half.y)

	position = screen_pos - half
