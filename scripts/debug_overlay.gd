extends CanvasLayer

@onready var _stats_label: Label = $MarginContainer/VBoxContainer/StatsLabel
@onready var _rng_result_label: Label = $MarginContainer/VBoxContainer/RngResultLabel
@onready var _camera: Camera2D = get_node("../Camera2D")


func _process(_delta: float) -> void:
	_stats_label.text = (
		"FPS: %d\nCamera: %s\nZoom: %.2f\nRNG Seed: %d"
		% [
			Engine.get_frames_per_second(),
			str(_camera.position.round()),
			_camera.zoom.x,
			RNG.get_seed(),
		]
	)


func _on_rng_test_button_pressed() -> void:
	var test_seed := 42
	var sequence_a: Array[float] = []
	var sequence_b: Array[float] = []

	RNG.set_seed(test_seed)
	for _i in 5:
		sequence_a.append(RNG.randf_range(0.0, 1.0))

	RNG.set_seed(test_seed)
	for _i in 5:
		sequence_b.append(RNG.randf_range(0.0, 1.0))

	var matches := sequence_a == sequence_b
	print("[RNG Test] Seed %d sequence A: %s" % [test_seed, str(sequence_a)])
	print("[RNG Test] Seed %d sequence B: %s" % [test_seed, str(sequence_b)])
	print("[RNG Test] Same seed -> same sequence: %s" % str(matches))

	_rng_result_label.text = (
		"RNG test (seed %d): %s"
		% [test_seed, "PASS - sequences match" if matches else "FAIL - sequences differ"]
	)
