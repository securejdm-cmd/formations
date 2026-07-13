class_name VolleyArc
extends Node2D

const DOT_COUNT := 14
const FLIGHT_S := 0.55

var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _elapsed: float = 0.0
var _dots: Array[ColorRect] = []


func setup(from_world: Vector2, to_world: Vector2) -> void:
	_from = from_world
	_to = to_world
	_elapsed = 0.0
	_build_dots()


func _build_dots() -> void:
	for child in _dots:
		if is_instance_valid(child):
			child.queue_free()
	_dots.clear()
	for i in DOT_COUNT:
		var dot := ColorRect.new()
		dot.size = Vector2(4.0, 4.0)
		dot.color = Color(0.95, 0.88, 0.45, 0.9)
		dot.position = -dot.size * 0.5
		add_child(dot)
		_dots.append(dot)


func _process(delta: float) -> void:
	_elapsed += delta
	var t: float = clampf(_elapsed / FLIGHT_S, 0.0, 1.0)
	for i in _dots.size():
		var phase: float = clampf(t * 1.15 - float(i) / float(_dots.size()), 0.0, 1.0)
		var pos: Vector2 = _arc_point(phase)
		_dots[i].global_position = pos - _dots[i].size * 0.5
		_dots[i].modulate.a = 1.0 - phase * 0.85
	if _elapsed >= FLIGHT_S + 0.05:
		queue_free()


func _arc_point(t: float) -> Vector2:
	var mid: Vector2 = (_from + _to) * 0.5
	var lift_px: float = _from.distance_to(_to) * 0.18
	mid.y -= lift_px
	var a: Vector2 = _from.lerp(mid, t)
	var b: Vector2 = mid.lerp(_to, t)
	return a.lerp(b, t)
