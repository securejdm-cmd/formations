extends Node2D

@onready var _ground: ColorRect = $Ground


func _ready() -> void:
	var width_px := (
		Constants.get_float("battlefield_width_m")
		* Constants.get_float("px_per_meter")
	)
	var height_px := (
		Constants.get_float("battlefield_height_m")
		* Constants.get_float("px_per_meter")
	)
	_ground.size = Vector2(width_px, height_px)
	_ground.position = Vector2(-width_px * 0.5, -height_px * 0.5)

	RNG.set_seed(12345)
