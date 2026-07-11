extends CanvasLayer

@onready var _stats_label: Label = $MarginContainer/VBoxContainer/StatsLabel
@onready var _unit_panel: Label = $MarginContainer/VBoxContainer/UnitPanel
@onready var _rng_result_label: Label = $MarginContainer/VBoxContainer/RngResultLabel

var _camera: Camera2D
var _units: Array[Unit] = []
var _selected_unit: Unit = null


func setup_for_scenario(units: Array[Unit], camera: Camera2D) -> void:
	_units = units
	_camera = camera
	for unit in _units:
		unit.selected.connect(_on_unit_selected)


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
	_update_unit_panel()


func _update_unit_panel() -> void:
	if _selected_unit == null:
		_unit_panel.text = "Unit: (click a block)"
		return

	_unit_panel.text = (
		"Unit: %s (%s)\nStrength: %.1f\nCohesion: %.1f\nState: %s\nPos: %s\nFacing: %s"
		% [
			_selected_unit.unit_id,
			_selected_unit.team_id,
			_selected_unit.strength,
			_selected_unit.cohesion,
			_selected_unit.get_state_name(),
			str(_selected_unit.position.round()),
			str(_selected_unit.facing.round()),
		]
	)


func _on_unit_selected(unit: Unit) -> void:
	_selected_unit = unit


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
	_rng_result_label.text = (
		"RNG test (seed %d): %s"
		% [test_seed, "PASS - sequences match" if matches else "FAIL - sequences differ"]
	)
