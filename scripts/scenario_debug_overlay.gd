extends CanvasLayer

@onready var _stats_label: Label = $MarginContainer/VBoxContainer/StatsLabel
@onready var _unit_panel: Label = $MarginContainer/VBoxContainer/UnitPanel
@onready var _rng_result_label: Label = $MarginContainer/VBoxContainer/RngResultLabel

var _camera: Camera2D
var _units: Array[Unit] = []
var _selected_unit: Unit = null
var _stat_card = null


func setup_for_scenario(units: Array[Unit], camera: Camera2D, stat_card) -> void:
	_units = units
	_camera = camera
	_stat_card = stat_card
	for unit in _units:
		if not unit.selected.is_connected(_on_unit_selected):
			unit.selected.connect(_on_unit_selected)


func _input(event: InputEvent) -> void:
	var screen_pos: Vector2 = Vector2.ZERO
	var is_press := false

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		screen_pos = event.position
		is_press = true
	elif event is InputEventScreenTouch and event.pressed:
		screen_pos = event.position
		is_press = true

	if not is_press:
		return

	var world_pos := _screen_to_world(screen_pos)
	for unit in _units:
		if unit.get_state() == Unit.State.REMOVED:
			continue
		if unit.contains_world_point(world_pos):
			_on_unit_selected(unit)
			get_viewport().set_input_as_handled()
			return

	_dismiss_selection()
	get_viewport().set_input_as_handled()


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var canvas_transform := get_viewport().get_canvas_transform()
	return canvas_transform.affine_inverse() * screen_pos


func _process(_delta: float) -> void:
	_stats_label.text = (
		"FPS: %d\nCamera: %s\nZoom: %.2f\nRNG Seed: %d\nClick a block to inspect"
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
		"Unit: %s (%s)\nStrength: %.1f (%.0f%%)\nCohesion: %.1f (%.0f%%)\nSoldiers defeated: %d\nState: %s\nPos: %s\nFacing: %s"
		% [
			_selected_unit.unit_id,
			_selected_unit.team_id,
			_selected_unit.strength,
			_selected_unit.strength_percent(),
			_selected_unit.cohesion,
			_selected_unit.cohesion_percent(),
			_selected_unit.soldiers_defeated(),
			_selected_unit.get_state_name(),
			str(_selected_unit.position.round()),
			"%(%.3f, %.3f) |len|=%.4f"
			% [
				_selected_unit.facing.x,
				_selected_unit.facing.y,
				_selected_unit.facing.length(),
			],
		]
	)


func _on_unit_selected(unit: Unit) -> void:
	_selected_unit = unit
	if _stat_card != null:
		_stat_card.show_for_unit(unit)


func _dismiss_selection() -> void:
	_selected_unit = null
	if _stat_card != null:
		_stat_card.dismiss()


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
