class_name ShockFloater
extends Label

var _elapsed: float = 0.0
var _duration: float = 1.5
var _rise_px: float = 36.0
var _start_screen: Vector2 = Vector2.ZERO


func setup(screen_pos: Vector2, amount: float) -> void:
	_start_screen = screen_pos
	_duration = Constants.get_float("shock_floater_duration_s")
	_rise_px = Constants.get_float("shock_floater_rise_px")
	text = "−%d ⚡" % int(round(amount))
	add_theme_font_size_override("font_size", int(Constants.get_float("shock_floater_font_px")))
	add_theme_color_override("font_color", Color(1.0, 0.35, 0.25, 1.0))
	add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	add_theme_constant_override("shadow_offset_x", 1)
	add_theme_constant_override("shadow_offset_y", 1)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pivot_offset = size * 0.5
	position = screen_pos
	modulate = Color(1, 1, 1, 1)


func _process(delta: float) -> void:
	_elapsed += delta
	var t := clampf(_elapsed / _duration, 0.0, 1.0)
	position = _start_screen + Vector2(0.0, -_rise_px * t)
	modulate.a = 1.0 - t
	if _elapsed >= _duration:
		queue_free()
