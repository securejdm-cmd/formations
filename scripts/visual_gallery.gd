extends Node2D

## WO-010 designer hand-confirm gallery — forced visual states, no simulation.

const UNIT_SCENE := preload("res://scenes/unit.tscn")
const FLOATER_SCRIPT := preload("res://scripts/shock_floater.gd")

@onready var _camera: Camera2D = $Camera2D
@onready var _shock_layer: CanvasLayer = $ShockFloaterLayer
@onready var _stat_card = $StatCardLayer/UnitStatCard

var _floater_timer: float = 0.0


func _ready() -> void:
	_stat_card.setup(_camera)
	_build_exhibits()


func _process(delta: float) -> void:
	_floater_timer += delta
	if _floater_timer >= 3.0:
		_floater_timer = 0.0
		_fire_demo_floater()


func _build_exhibits() -> void:
	var profile := UnitProfileLoader.load_profile("test_infantry")
	var px := Constants.get_float("px_per_meter")
	var spacing := 120.0 * px
	var y0 := -2.5 * spacing

	_spawn_strength_row(profile, Vector2(-3.5 * spacing, y0), px)
	_spawn_engaged_pair(profile, Vector2(0.0, y0), px)
	_spawn_state_row(profile, Vector2(3.5 * spacing, y0), px)


func _spawn_strength_row(profile: Dictionary, origin: Vector2, px: float) -> void:
	var strengths := [100.0, 75.0, 50.0, 25.0]
	for i in strengths.size():
		var unit: Unit = UNIT_SCENE.instantiate()
		add_child(unit)
		var pos := origin + Vector2(float(i) * 70.0 * px, 0.0)
		unit.configure("str_%d" % int(strengths[i]), "red", profile, pos, Vector2.RIGHT)
		unit.strength = strengths[i]
		unit.set_render_camera(_camera)
		_add_caption(pos + Vector2(0.0, 55.0 * px), "%d%% STR" % int(strengths[i]))


func _spawn_engaged_pair(profile: Dictionary, origin: Vector2, px: float) -> void:
	var red: Unit = UNIT_SCENE.instantiate()
	add_child(red)
	red.configure("grind_red", "red", profile, origin + Vector2(-20.0 * px, 0.0), Vector2.RIGHT)
	red.set_render_camera(_camera)
	red._set_state(Unit.State.ENGAGED)
	red.set_bump_state(1.0, true)
	red.add_crack_intensity_from_damage(80.0)

	var blue: Unit = UNIT_SCENE.instantiate()
	add_child(blue)
	blue.configure("grind_blue", "blue", profile, origin + Vector2(20.0 * px, 0.0), Vector2.LEFT)
	blue.set_render_camera(_camera)
	blue._set_state(Unit.State.ENGAGED)
	blue.set_bump_state(1.0, false)
	blue.add_crack_intensity_from_damage(80.0)

	_add_caption(origin + Vector2(0.0, 55.0 * px), "Max grind + fissures")


func _spawn_state_row(profile: Dictionary, origin: Vector2, px: float) -> void:
	var waver: Unit = UNIT_SCENE.instantiate()
	add_child(waver)
	waver.configure("waver", "red", profile, origin, Vector2.RIGHT)
	waver.cohesion = 25.0
	waver.set_render_camera(_camera)
	waver._set_state(Unit.State.WAVERING)
	_add_caption(origin + Vector2(0.0, 55.0 * px), "Wavering")

	var rout: Unit = UNIT_SCENE.instantiate()
	add_child(rout)
	var rout_pos := origin + Vector2(0.0, 90.0 * px)
	rout.configure("rout", "red", profile, rout_pos, Vector2.RIGHT)
	rout.set_render_camera(_camera)
	rout._set_state(Unit.State.ROUTING)
	_add_caption(rout_pos + Vector2(0.0, 55.0 * px), "Routing (constant width)")

	var rallied: Unit = UNIT_SCENE.instantiate()
	add_child(rallied)
	var hold_pos := origin + Vector2(0.0, 180.0 * px)
	rallied.configure("rallied", "red", profile, hold_pos, Vector2.RIGHT)
	rallied.cohesion = 50.0
	rallied.set_render_camera(_camera)
	rallied._rallied_hold = true
	rallied._set_state(Unit.State.HOLD)
	_add_caption(hold_pos + Vector2(0.0, 55.0 * px), "Rallied HOLD")

	_stat_card.show_for_unit(waver)


func _fire_demo_floater() -> void:
	for child in get_children():
		if child is Unit and child.unit_id == "waver":
			var px_per_meter := Constants.get_float("px_per_meter")
			var half_frontage_px := child.effective_frontage_m() * 0.5 * px_per_meter
			var world_above := child.position + Vector2(0.0, -(half_frontage_px + 12.0))
			var screen_pos := _camera.get_canvas_transform() * world_above
			var floater: Label = FLOATER_SCRIPT.new()
			_shock_layer.add_child(floater)
			floater.setup(screen_pos, Constants.get_float("neighbor_rout_shock"))
			break


func _add_caption(world_pos: Vector2, text: String) -> void:
	var label := Label.new()
	_shock_layer.add_child(label)
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	label.position = _camera.get_canvas_transform() * world_pos
