extends Node2D

## Designer hand-confirm gallery — forced visual states, no simulation.

const UNIT_SCENE := preload("res://scenes/unit.tscn")
const FLOATER_SCRIPT := preload("res://scripts/shock_floater.gd")
const GALLERY_FRONTAGE_M := 60.0
const EXHIBIT_SPACING_PX := 180.0
const ROW_SPACING_PX := 220.0
const CAPTION_MARGIN_PX := 36.0
const CAPTION_WIDTH_PX := 110.0

@onready var _camera: Camera2D = $Camera2D
@onready var _shock_layer: CanvasLayer = $ShockFloaterLayer
@onready var _stat_card = $StatCardLayer/UnitStatCard

var _caption_layer: Node2D
var _floater_timer: float = 0.0


func _ready() -> void:
	_caption_layer = Node2D.new()
	_caption_layer.name = "CaptionLayer"
	add_child(_caption_layer)
	_stat_card.setup(_camera)
	_build_exhibits()


func _process(delta: float) -> void:
	_floater_timer += delta
	if _floater_timer >= 3.0:
		_floater_timer = 0.0
		_fire_demo_floater()


func _gallery_profile() -> Dictionary:
	var profile := UnitProfileLoader.load_profile("test_infantry").duplicate()
	profile["formation_frontage_m"] = GALLERY_FRONTAGE_M
	return profile


func _build_exhibits() -> void:
	var profile := _gallery_profile()
	var px: float = Constants.get_float("px_per_meter")
	var col_w: float = EXHIBIT_SPACING_PX
	var origin := Vector2(-2.0 * col_w, -ROW_SPACING_PX)

	_spawn_crack_progression_row(profile, origin, px)
	_spawn_engaged_pair(profile, origin + Vector2(0.0, ROW_SPACING_PX), px)
	_spawn_state_row(profile, origin + Vector2(0.0, ROW_SPACING_PX * 2.0), px)
	_spawn_volley_arc_exhibit(origin + Vector2(0.0, ROW_SPACING_PX * 3.0), px)


func _spawn_crack_progression_row(profile: Dictionary, origin: Vector2, px: float) -> void:
	var strengths := [100.0, 90.0, 70.0, 50.0, 30.0]
	for i in strengths.size():
		var pos: Vector2 = origin + Vector2(float(i) * EXHIBIT_SPACING_PX, 0.0)
		var unit: Unit = UNIT_SCENE.instantiate()
		add_child(unit)
		unit.configure("crack_%d" % int(strengths[i]), "red", profile, pos, Vector2.RIGHT)
		unit.strength = strengths[i]
		unit._set_state(Unit.State.ENGAGED)
		unit.set_render_camera(_camera)
		unit._update_dimensions()
		_add_caption_below_unit(unit, "%d%% STR" % int(strengths[i]))


func _spawn_engaged_pair(profile: Dictionary, origin: Vector2, px: float) -> void:
	var half_gap: float = 28.0
	var red: Unit = UNIT_SCENE.instantiate()
	add_child(red)
	red.configure("grind_red", "red", profile, origin + Vector2(-half_gap, 0.0), Vector2.RIGHT)
	red.set_render_camera(_camera)
	red._set_state(Unit.State.ENGAGED)
	red.set_bump_state(1.0, true)
	red.strength = 55.0
	red._update_dimensions()
	_add_caption_below_unit(red, "Grind (red)")

	var blue: Unit = UNIT_SCENE.instantiate()
	add_child(blue)
	blue.configure("grind_blue", "blue", profile, origin + Vector2(half_gap, 0.0), Vector2.LEFT)
	blue.set_render_camera(_camera)
	blue._set_state(Unit.State.ENGAGED)
	blue.set_bump_state(1.0, false)
	blue.strength = 55.0
	blue._update_dimensions()
	_add_caption_below_unit(blue, "Grind (blue)")


func _spawn_state_row(profile: Dictionary, origin: Vector2, px: float) -> void:
	var waver: Unit = UNIT_SCENE.instantiate()
	add_child(waver)
	waver.configure("waver", "red", profile, origin + Vector2(-EXHIBIT_SPACING_PX, 0.0), Vector2.RIGHT)
	waver.cohesion = 25.0
	waver.strength = 80.0
	waver.set_render_camera(_camera)
	waver._set_state(Unit.State.WAVERING)
	waver._update_dimensions()
	_add_caption_below_unit(waver, "Wavering")

	var rout: Unit = UNIT_SCENE.instantiate()
	add_child(rout)
	rout.configure("rout", "red", profile, origin, Vector2.RIGHT)
	rout.set_render_camera(_camera)
	rout._set_state(Unit.State.ROUTING)
	rout._update_dimensions()
	_add_caption_below_unit(rout, "Routing")

	var rallied: Unit = UNIT_SCENE.instantiate()
	add_child(rallied)
	rallied.configure("rallied", "red", profile, origin + Vector2(EXHIBIT_SPACING_PX, 0.0), Vector2.RIGHT)
	rallied.cohesion = 50.0
	rallied.set_render_camera(_camera)
	rallied._rallied_hold = true
	rallied._set_state(Unit.State.HOLD)
	rallied._update_dimensions()
	_add_caption_below_unit(rallied, "Rallied HOLD")

	_stat_card.show_for_unit(waver)


func _spawn_volley_arc_exhibit(origin: Vector2, px: float) -> void:
	var archer_profile := UnitProfileLoader.load_profile("test_archer")
	var shooter: Unit = UNIT_SCENE.instantiate()
	add_child(shooter)
	shooter.configure("volley_shooter", "red", archer_profile, origin + Vector2(-60.0, 0.0), Vector2.RIGHT)
	shooter.set_render_camera(_camera)
	shooter.current_order = Unit.Order.HOLD
	shooter._set_state(Unit.State.ENGAGED)
	shooter._update_dimensions()

	var target: Unit = UNIT_SCENE.instantiate()
	add_child(target)
	target.configure("volley_target", "blue", archer_profile, origin + Vector2(60.0, 0.0), Vector2.LEFT)
	target.set_render_camera(_camera)
	target.current_order = Unit.Order.HOLD
	target._set_state(Unit.State.ENGAGED)
	target._update_dimensions()

	var arc := preload("res://scripts/volley_arc.gd").new()
	add_child(arc)
	arc.setup(shooter.position, target.position)
	_add_caption_below_unit(shooter, "Volley arc")


func _fire_demo_floater() -> void:
	for child in get_children():
		var unit := child as Unit
		if unit == null or unit.unit_id != "waver":
			continue
		var px_per_meter: float = Constants.get_float("px_per_meter")
		var half_frontage_px: float = unit.effective_frontage_m() * 0.5 * px_per_meter
		var world_above: Vector2 = unit.position + Vector2(0.0, -(half_frontage_px + 12.0))
		var screen_pos: Vector2 = _camera.get_canvas_transform() * world_above
		var floater: ShockFloater = FLOATER_SCRIPT.new()
		_shock_layer.add_child(floater)
		floater.setup(screen_pos, Constants.get_float("neighbor_rout_shock"))
		break


func _add_caption_below_unit(unit: Unit, text: String) -> void:
	var px: float = Constants.get_float("px_per_meter")
	var half_frontage_px: float = unit.effective_frontage_m() * 0.5 * px
	var anchor: Vector2 = unit.position + Vector2(0.0, half_frontage_px + CAPTION_MARGIN_PX)
	_add_world_caption(anchor, text)


func _add_world_caption(anchor: Vector2, text: String) -> void:
	var label: Label = Label.new()
	_caption_layer.add_child(label)
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.94, 1.0))
	label.custom_minimum_size = Vector2(CAPTION_WIDTH_PX, 24.0)
	label.position = anchor - Vector2(CAPTION_WIDTH_PX * 0.5, 0.0)
