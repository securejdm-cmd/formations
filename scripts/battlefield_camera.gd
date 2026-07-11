extends Camera2D

const MIN_ZOOM := 0.5
const MAX_ZOOM := 3.0
const ZOOM_STEP := 0.1

var _drag_active := false
var _drag_touch_index := -1
var _last_pointer := Vector2.ZERO
var _touch_positions: Dictionary = {}
var _pinch_active := false
var _pinch_last_distance := 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	elif event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		_drag_active = event.pressed
		_last_pointer = event.position
		return

	if not event.pressed:
		return

	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom_at_screen_point(1.0 + ZOOM_STEP, event.position)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom_at_screen_point(1.0 / (1.0 + ZOOM_STEP), event.position)


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if not _drag_active:
		return

	_pan_by_screen_delta(event.position - _last_pointer)
	_last_pointer = event.position


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touch_positions[event.index] = event.position
	else:
		_touch_positions.erase(event.index)

	if _touch_positions.size() == 1:
		var only_index: int = _touch_positions.keys()[0]
		_drag_touch_index = only_index
		_last_pointer = _touch_positions[only_index]
		_pinch_active = false
	elif _touch_positions.size() >= 2:
		_drag_touch_index = -1
		_pinch_active = true
		_pinch_last_distance = _get_pinch_distance()
	else:
		_drag_touch_index = -1
		_pinch_active = false


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	_touch_positions[event.index] = event.position

	if _touch_positions.size() >= 2:
		_update_pinch_zoom()
	elif event.index == _drag_touch_index:
		_pan_by_screen_delta(event.position - _last_pointer)
		_last_pointer = event.position


func _pan_by_screen_delta(screen_delta: Vector2) -> void:
	position -= screen_delta / zoom


func _zoom_at_screen_point(factor: float, screen_point: Vector2) -> void:
	var old_zoom := zoom.x
	var new_zoom := clampf(old_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(old_zoom, new_zoom):
		return

	var world_before := get_canvas_transform().affine_inverse() * screen_point
	zoom = Vector2(new_zoom, new_zoom)
	var world_after := get_canvas_transform().affine_inverse() * screen_point
	position += world_before - world_after


func _get_pinch_distance() -> float:
	var indices: Array = _touch_positions.keys()
	if indices.size() < 2:
		return 0.0

	var point_a: Vector2 = _touch_positions[indices[0]]
	var point_b: Vector2 = _touch_positions[indices[1]]
	return point_a.distance_to(point_b)


func _update_pinch_zoom() -> void:
	if not _pinch_active:
		return

	var distance := _get_pinch_distance()
	if _pinch_last_distance <= 0.0:
		_pinch_last_distance = distance
		return

	if distance > 0.0 and _pinch_last_distance > 0.0:
		var indices: Array = _touch_positions.keys()
		var midpoint: Vector2 = (
			_touch_positions[indices[0]] + _touch_positions[indices[1]]
		) * 0.5
		_zoom_at_screen_point(distance / _pinch_last_distance, midpoint)

	_pinch_last_distance = distance
