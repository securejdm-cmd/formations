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
var _contact_partners: Array[Unit] = []
var _active_contact_edges: String = ""
var _edge_cohesion_drain_totals: Dictionary = {
	"front": 0.0,
	"left": 0.0,
	"right": 0.0,
	"rear": 0.0,
}

var pushing_power: float = 0.0
var speed_stat: float = 0.0
var damage_dealt: float = 0.0
var _crack_intensity: float = 0.0
var _crack_flicker_time: float = 0.0

var _state: State = State.HOLD
var _base_team_color: Color = Color.RED
var _flicker_time: float = 0.0
var _bump_time: float = 0.0
var _bump_phase_offset: float = 0.0
var _bump_gap_ratio: float = 0.0
var _bump_is_winner: bool = false

@onready var _visual_root: Node2D = $VisualRoot
@onready var _body: ColorRect = $VisualRoot/Body
@onready var _border: ColorRect = $VisualRoot/Border
@onready var _collision: CollisionShape2D = $CollisionShape2D

var _crack_overlay: Node2D = null


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
	var period := Constants.get_float("bump_period_s")
	_bump_phase_offset = float(absi(unit_id.hash()) % 1000) / 1000.0 * period
	_update_dimensions()
	_update_collision()
	_set_state(State.HOLD)


func set_march_to(target: Vector2) -> void:
	march_target = target
	current_order = Order.MARCH_TO
	_clear_contact_partners()
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


func full_depth_m() -> float:
	return float(profile.get("formation_depth_m", Constants.get_float("default_infantry_block_depth_m")))


func strength_percent() -> float:
	return strength / Constants.get_float("strength_max") * 100.0


func cohesion_percent() -> float:
	return cohesion / Constants.get_float("cohesion_max") * 100.0


func soldiers_defeated() -> int:
	var men_per_strength := (
		Constants.get_float("men_per_full_unit") / Constants.get_float("strength_max")
	)
	return int(round(damage_dealt * men_per_strength))


func record_damage_dealt(strength_damage: float) -> void:
	if strength_damage > 0.0:
		damage_dealt += strength_damage


func get_display_name() -> String:
	return str(profile.get("display_name", unit_id))


func get_results_state_label() -> String:
	match _state:
		State.ROUTING:
			return "routed"
		State.REMOVED:
			if strength <= 0.0:
				return "destroyed"
			return "routed"
		State.ENGAGED, State.WAVERING, State.MARCHING, State.HOLD:
			return "fighting"
	return "fighting"


func add_crack_intensity_from_damage(strength_damage: float) -> void:
	var strength_max := Constants.get_float("strength_max")
	_crack_intensity = clampf(
		_crack_intensity + strength_damage / strength_max,
		0.0,
		1.0,
	)


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


func apply_cohesion_drain(amount: float, edge_name: String = "") -> void:
	if amount <= 0.0 or _state == State.REMOVED:
		return

	cohesion = maxf(cohesion - amount, 0.0)
	if not edge_name.is_empty() and _edge_cohesion_drain_totals.has(edge_name):
		_edge_cohesion_drain_totals[edge_name] += amount
	_refresh_morale_state()


func update_marching(delta: float, enemies: Array[Unit] = []) -> void:
	if _state != State.MARCHING:
		return

	var speed_px := speed_m_per_sec() * Constants.get_float("px_per_meter")
	var to_target := march_target - position
	var move_px := speed_px * delta
	if to_target.length() <= move_px:
		position = march_target
		if enemies.is_empty():
			_set_state(State.HOLD)
		return

	for enemy in enemies:
		if (
			EdgeContact.units_have_contact(self, enemy)
			or EdgeContact.units_have_contact(enemy, self)
		):
			return
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
	add_contact_partner(partner)
	CombatResolver.snap_pair_to_contact(self, partner)
	_set_state(State.ENGAGED)


func add_contact_partner(partner: Unit) -> void:
	if partner == null or partner == self:
		return
	if partner in _contact_partners:
		_sync_primary_partner()
		return
	_contact_partners.append(partner)
	_sync_primary_partner()
	if _state != State.ROUTING and _state != State.REMOVED:
		_set_state(State.ENGAGED)


func remove_contact_partner(partner: Unit) -> void:
	if partner == null:
		return
	_contact_partners.erase(partner)
	_sync_primary_partner()
	if _contact_partners.is_empty():
		clear_bump_state()
		if _state == State.ENGAGED or _state == State.WAVERING:
			if current_order == Order.MARCH_TO:
				_set_state(State.MARCHING)
			else:
				_set_state(State.HOLD)


func break_engagement(partner: Unit = null) -> void:
	if partner == null:
		var partners := _contact_partners.duplicate()
		for contact_partner in partners:
			remove_contact_partner(contact_partner)
		return
	remove_contact_partner(partner)


func has_contact_with(other: Unit) -> bool:
	return other in _contact_partners


func get_contact_partners() -> Array[Unit]:
	return _contact_partners.duplicate()


func set_active_contact_edges(label: String) -> void:
	_active_contact_edges = label


func get_active_contact_edges() -> String:
	return _active_contact_edges


func get_edge_cohesion_drain_totals() -> Dictionary:
	return _edge_cohesion_drain_totals.duplicate()


func _clear_contact_partners() -> void:
	_contact_partners.clear()
	engaged_partner = null
	_active_contact_edges = ""


func _sync_primary_partner() -> void:
	engaged_partner = _contact_partners[0] if not _contact_partners.is_empty() else null


func enter_rout() -> void:
	var partners := _contact_partners.duplicate()
	_clear_contact_partners()
	for partner in partners:
		if partner == null:
			continue
		partner.remove_contact_partner(self)
		partner.clear_bump_state()
		if partner.get_state() == State.ENGAGED or partner.get_state() == State.WAVERING:
			if partner.get_contact_partners().is_empty():
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
	_update_crack_fissures(delta)


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
			_body.color = _base_team_color.lerp(Color(0.92, 0.92, 0.92), 0.8)
			_body.modulate = Color(1.0, 1.0, 1.0, 0.38)
			_border.visible = false
		State.REMOVED:
			_body.color = _base_team_color
			_body.modulate = Color.WHITE
			_border.visible = false
		_:
			_body.color = _base_team_color
			_body.modulate = Color.WHITE
			_border.visible = cohesion < Constants.get_float("waver_threshold")


func _update_dimensions() -> void:
	var px_per_meter := Constants.get_float("px_per_meter")
	var full_depth_px := full_depth_m() * px_per_meter
	var depth_px := effective_depth_m() * px_per_meter
	var frontage_px := effective_frontage_m() * px_per_meter
	var front_face_x := full_depth_px * 0.5

	if _state == State.ROUTING:
		# Formless fugitive: pale, softened footprint (collision already dropped in sim).
		depth_px *= 0.55
		frontage_px *= 1.2
		front_face_x = full_depth_px * 0.5

	# Simulation footprint stays centered on the unit origin (WO-003 geometry).
	# Visual front face anchored at the sim contact edge; depth loss thins toward the rear.
	_body.size = Vector2(depth_px, frontage_px)
	_body.position = Vector2(front_face_x - depth_px, -frontage_px * 0.5)

	var border_pad := 4.0
	_border.size = _body.size + Vector2(border_pad, border_pad)
	_border.position = _body.position - Vector2(border_pad * 0.5, border_pad * 0.5)

	rotation = facing.angle()
	_update_collision()


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
	var period := Constants.get_float("bump_period_s")
	var wave := sin(((_bump_time + _bump_phase_offset) / period) * TAU)
	var amp_px := (
		Constants.get_float("bump_amplitude_m")
		* _bump_gap_ratio
		* Constants.get_float("px_per_meter")
	)
	var direction := 1.0 if _bump_is_winner else -1.0
	_visual_root.position = facing.normalized() * wave * amp_px * direction


func _update_crack_fissures(delta: float) -> void:
	if _crack_overlay == null:
		return

	if _state != State.ENGAGED and _state != State.WAVERING:
		_crack_overlay.queue_redraw()
		return
	_crack_flicker_time += delta
	_crack_overlay.queue_redraw()


func _draw_crack_fissures(canvas: Node2D) -> void:
	if _crack_intensity <= 0.001:
		return
	if _state != State.ENGAGED and _state != State.WAVERING:
		return

	var px_per_meter := Constants.get_float("px_per_meter")
	var full_depth_px := full_depth_m() * px_per_meter
	var depth_px := effective_depth_m() * px_per_meter
	var frontage_px := effective_frontage_m() * px_per_meter
	var front_x := full_depth_px * 0.5
	var max_count := int(Constants.get_float("crack_fissure_max_count"))
	var line_count := int(ceil(_crack_intensity * float(max_count)))
	line_count = clampi(line_count, 0, max_count)
	if line_count <= 0:
		return

	var length_px := Constants.get_float("crack_fissure_length_m") * px_per_meter
	var flicker_hz := Constants.get_float("crack_fissure_flicker_s")
	var flicker := 0.35 + 0.65 * absf(sin(_crack_flicker_time / flicker_hz * TAU + float(unit_id.hash() % 7)))
	var color := Color(0.08, 0.08, 0.1, 0.85 * flicker)

	for i in line_count:
		var seed := absi(unit_id.hash() + i * 131)
		var y := -frontage_px * 0.5 + (float(seed % 1000) / 1000.0) * frontage_px
		var jag := float(seed % 17) / 17.0 * length_px * 0.35
		var p0 := Vector2(front_x, y)
		var p1 := Vector2(front_x + length_px * flicker, y + jag)
		var p2 := Vector2(front_x + length_px * 0.65 * flicker, y - jag * 0.5)
		canvas.draw_line(p0, p1, color, 1.2, true)
		canvas.draw_line(p1, p2, color, 1.0, true)


func _update_waver_flicker(delta: float) -> void:
	if not _border.visible:
		return

	_flicker_time += delta
	var flicker := 0.55 + 0.45 * sin(_flicker_time * 24.0)
	_border.modulate = Color(1.0, 1.0, 1.0, flicker)
	var jitter := Vector2(sin(_flicker_time * 31.0), cos(_flicker_time * 27.0)) * 0.35
	_border.position = _body.position - Vector2(2.0, 2.0) + jitter


func _flee_direction() -> Vector2:
	return -facing.normalized()


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
	if _crack_overlay == null and _visual_root != null:
		_crack_overlay = _visual_root.get_node_or_null("CrackOverlay")
		if _crack_overlay == null:
			_crack_overlay = Node2D.new()
			_crack_overlay.name = "CrackOverlay"
			_visual_root.add_child(_crack_overlay)
			_crack_overlay.draw.connect(_on_crack_overlay_draw)
	if _collision == null:
		_collision = $CollisionShape2D


func _on_crack_overlay_draw() -> void:
	_draw_crack_fissures(_crack_overlay)
