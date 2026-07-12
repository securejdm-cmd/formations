class_name Unit
extends Area2D

enum Order { HOLD, MARCH_TO }
enum State { MARCHING, ENGAGED, WAVERING, ROUTING, HOLD, REMOVED }

signal state_changed(unit: Unit)
signal selected(unit: Unit)

var unit_id: String = ""
var team_id: String = ""
var profile: Dictionary = {}

var strength: float = 100.0
var cohesion: float = 100.0
var facing: Vector2 = Vector2.RIGHT
var current_order: Order = Order.HOLD
var march_target: Vector2 = Vector2.ZERO
var engaged_partner: Unit = null

var pushing_power: float = 0.0
var speed_stat: float = 0.0

var _state: State = State.HOLD
var _base_team_color: Color = Color.RED
var _flicker_time: float = 0.0
var _bump_time: float = 0.0
var _bump_gap_ratio: float = 0.0
var _bump_is_winner: bool = false

@onready var _visual_root: Node2D = $VisualRoot
@onready var _body: ColorRect = $VisualRoot/Body
@onready var _border: ColorRect = $VisualRoot/Border
@onready var _collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	input_pickable = true
	monitorable = true
	input_event.connect(_on_input_event)


func configure(id: String, team: String, profile_data: Dictionary, spawn_position: Vector2, face_direction: Vector2) -> void:
	_ensure_nodes()
	unit_id = id
	team_id = team
	profile = profile_data
	position = spawn_position
	facing = face_direction.normalized()

	strength = Constants.get_float("strength_max")
	cohesion = Constants.get_float("cohesion_max")
	pushing_power = float(profile.get("pushing_power", 0.0))
	speed_stat = float(profile.get("speed", 0.0))

	_base_team_color = Color(0.85, 0.2, 0.2) if team_id == "red" else Color(0.2, 0.35, 0.85)
	_body.color = _base_team_color
	_update_dimensions()
	_update_collision()
	_set_state(State.HOLD)


func set_march_to(target: Vector2) -> void:
	march_target = target
	current_order = Order.MARCH_TO
	engaged_partner = null
	_set_state(State.MARCHING)


func get_state() -> State:
	return _state


func get_state_name() -> String:
	match _state:
		State.MARCHING:
			return "marching"
		State.ENGAGED:
			return "engaged"
		State.WAVERING:
			return "wavering"
		State.ROUTING:
			return "routing"
		State.HOLD:
			return "hold"
		State.REMOVED:
			return "removed"
	return "unknown"


func effective_depth_m() -> float:
	var depth_m := float(profile.get("formation_depth_m", Constants.get_float("default_infantry_block_depth_m")))
	return depth_m * (strength / Constants.get_float("strength_max"))


func effective_frontage_m() -> float:
	return float(profile.get("formation_frontage_m", Constants.get_float("default_infantry_block_frontage_m")))


func speed_m_per_sec() -> float:
	return (
		speed_stat
		* Constants.get_float("speed_stat_meters_per_10s")
		/ 10.0
	)


func contains_world_point(world_point: Vector2) -> bool:
	return FormationGeometry.contains_world_point(self, world_point)


func set_bump_state(gap_ratio: float, is_winner: bool) -> void:
	_bump_gap_ratio = gap_ratio
	_bump_is_winner = is_winner


func clear_bump_state() -> void:
	_bump_gap_ratio = 0.0
	_bump_is_winner = false
	if _visual_root != null:
		_visual_root.position = Vector2.ZERO


func apply_cohesion_drain(amount: float) -> void:
	if amount <= 0.0 or _state == State.REMOVED:
		return

	cohesion = maxf(cohesion - amount, 0.0)
	_refresh_morale_state()


func update_marching(delta: float, enemies: Array[Unit] = []) -> void:
	if _state != State.MARCHING:
		return

	var speed_px := speed_m_per_sec() * Constants.get_float("px_per_meter")
	var to_target := march_target - position
	var move_px := speed_px * delta
	if to_target.length() <= move_px:
		position = march_target
		_set_state(State.HOLD)
		return

	for enemy in enemies:
		move_px = CombatResolver.clamp_march_distance(self, enemy, move_px)
		if move_px <= 0.0:
			return

	position += to_target.normalized() * move_px


func update_routing(delta: float) -> void:
	if _state != State.ROUTING:
		return

	clear_bump_state()
	var flee_direction := _flee_direction()
	var speed_px := (
		speed_m_per_sec()
		* Constants.get_float("rout_flee_speed_pct")
		* Constants.get_float("px_per_meter")
	)
	position += flee_direction * speed_px * delta
	_check_edge_removal()


func begin_engagement(partner: Unit) -> void:
	engaged_partner = partner
	CombatResolver.snap_pair_to_contact(self, partner)
	_set_state(State.ENGAGED)


func break_engagement() -> void:
	engaged_partner = null
	clear_bump_state()
	if _state == State.ENGAGED or _state == State.WAVERING:
		if current_order == Order.MARCH_TO:
			_set_state(State.MARCHING)
		else:
			_set_state(State.HOLD)


func enter_rout() -> void:
	if engaged_partner != null:
		var partner := engaged_partner
		engaged_partner = null
		partner.engaged_partner = null
		partner.clear_bump_state()
		if partner.get_state() == State.ENGAGED or partner.get_state() == State.WAVERING:
			partner.current_order = Order.HOLD
			partner._set_state(State.HOLD)

	clear_bump_state()
	_set_state(State.ROUTING)


func mark_removed() -> void:
	_set_state(State.REMOVED)
	visible = false
	monitoring = false
	monitorable = false
	input_pickable = false


func _process(delta: float) -> void:
	_update_dimensions()
	_update_waver_flicker(delta)
	_update_bump_visual(delta)


func _set_state(new_state: State) -> void:
	if _state == new_state:
		return

	_state = new_state
	_apply_state_visuals()
	state_changed.emit(self)


func _refresh_morale_state() -> void:
	if _state == State.ROUTING or _state == State.REMOVED:
		return

	if cohesion < Constants.get_float("rout_threshold"):
		enter_rout()
		return

	if _state == State.ENGAGED and cohesion < Constants.get_float("waver_threshold"):
		_set_state(State.WAVERING)
	elif _state == State.WAVERING and cohesion >= Constants.get_float("waver_threshold"):
		_set_state(State.ENGAGED)


func _apply_state_visuals() -> void:
	match _state:
		State.ROUTING:
			_body.color = _base_team_color.lerp(Color(0.85, 0.85, 0.85), 0.65)
			_border.visible = false
		State.REMOVED:
			_body.color = _base_team_color
			_border.visible = false
		_:
			_body.color = _base_team_color
			_border.visible = cohesion < Constants.get_float("waver_threshold")


func _update_dimensions() -> void:
	var px_per_meter := Constants.get_float("px_per_meter")
	var depth_px := effective_depth_m() * px_per_meter
	var frontage_px := effective_frontage_m() * px_per_meter

	# Local X = depth (short axis, along facing). Local Y = frontage (long front edge).
	_body.size = Vector2(depth_px, frontage_px)
	_body.position = Vector2(-depth_px * 0.5, -frontage_px * 0.5)

	var border_pad := 4.0
	_border.size = _body.size + Vector2(border_pad, border_pad)
	_border.position = _body.position - Vector2(border_pad * 0.5, border_pad * 0.5)

	rotation = facing.angle()


func _update_collision() -> void:
	var shape := _collision.shape as RectangleShape2D
	if shape == null:
		shape = RectangleShape2D.new()
		_collision.shape = shape

	var px_per_meter := Constants.get_float("px_per_meter")
	shape.size = Vector2(
		effective_depth_m() * px_per_meter,
		effective_frontage_m() * px_per_meter,
	)


func _update_bump_visual(delta: float) -> void:
	if _visual_root == null:
		return

	if _state != State.ENGAGED and _state != State.WAVERING:
		_visual_root.position = Vector2.ZERO
		return

	_bump_time += delta
	var period := Constants.get_float("bump_period_sec")
	var wave := sin((_bump_time / period) * TAU)
	var amp_px := (
		Constants.get_float("bump_amplitude_max_m")
		* _bump_gap_ratio
		* Constants.get_float("px_per_meter")
	)
	var direction := 1.0 if _bump_is_winner else -1.0
	_visual_root.position = facing.normalized() * wave * amp_px * direction


func _update_waver_flicker(delta: float) -> void:
	if not _border.visible:
		return

	_flicker_time += delta
	var flicker := 0.55 + 0.45 * sin(_flicker_time * 24.0)
	_border.modulate = Color(1.0, 1.0, 1.0, flicker)
	var jitter := Vector2(sin(_flicker_time * 31.0), cos(_flicker_time * 27.0)) * 0.35
	_border.position = _body.position - Vector2(2.0, 2.0) + jitter


func _flee_direction() -> Vector2:
	# Each team flees toward its own map edge; avoids flip-flop at the boundary.
	return Vector2.LEFT if team_id == "red" else Vector2.RIGHT


func _check_edge_removal() -> void:
	var half_width_px := Constants.get_float("battlefield_width_m") * Constants.get_float("px_per_meter") * 0.5
	var half_height_px := Constants.get_float("battlefield_height_m") * Constants.get_float("px_per_meter") * 0.5

	if absf(position.x) >= half_width_px or absf(position.y) >= half_height_px:
		mark_removed()


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected.emit(self)
		get_viewport().set_input_as_handled()


func _ensure_nodes() -> void:
	if _visual_root == null:
		_visual_root = get_node_or_null("VisualRoot")
	if _body == null and _visual_root != null:
		_body = _visual_root.get_node("Body")
	if _border == null and _visual_root != null:
		_border = _visual_root.get_node("Border")
	if _collision == null:
		_collision = $CollisionShape2D
