class_name Unit
extends Area2D

const _ChargeCombat := preload("res://scripts/charge_combat.gd")

enum Order { HOLD, MARCH_TO }
enum State { MARCHING, ENGAGED, WAVERING, ROUTING, RALLYING, HOLD, REMOVED }

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
var ammo_remaining: int = -1

var _state: State = State.HOLD
var _base_team_color: Color = Color.RED
var _flicker_time: float = 0.0
var _bump_time: float = 0.0
var _bump_phase_offset: float = 0.0
var _bump_gap_ratio: float = 0.0
var _bump_is_winner: bool = false

var _rally_elapsed_sec: float = 0.0
var _rallies_this_battle: int = 0
var _rallied_hold: bool = false
var _rally_reform_remaining_sec: float = 0.0
var _pending_rout_event: bool = false
var _render_camera: Camera2D = null
var _rout_flicker_time: float = 0.0
var _impact_flicker_time: float = 0.0

@onready var _visual_root: Node2D = $VisualRoot
@onready var _body: ColorRect = $VisualRoot/Body
@onready var _border: ColorRect = $VisualRoot/Border
@onready var _collision: CollisionShape2D = $CollisionShape2D

var _crack_band: ColorRect = null
var _grind_band: ColorRect = null
var _crack_shader: Shader = preload("res://shaders/crack_band.gdshader")
var current_speed_m_s: float = 0.0
var charge_amp_factor: float = 1.0
var _charge_amp_time_left: float = 0.0
## R17: charge gait commitment (physical acceleration to gait top).
var charge_committed: bool = false
var _charge_commit_target_id: String = ""
var _brace_hold_sec: float = 0.0
var _braced: bool = false
## Seconds a front-arc gallop threat has been continuously visible (R16 Tier 1).
var _threat_front_sec: float = 0.0
## Distinct brace tier last resolved at charge impact (1/2/3); 0 = none yet.
var brace_tier_last: int = 0
var _brace_indicator: ColorRect = null
var _instinctive_indicator: ColorRect = null


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
	# Default cruise: preserve pre-WO-016 approach timing for regression scenarios.
	# Charge scenarios call start_from_rest() after configure.
	current_speed_m_s = speed_m_per_sec()
	charge_amp_factor = 1.0
	_charge_amp_time_left = 0.0
	_brace_hold_sec = 0.0
	_braced = false
	_threat_front_sec = 0.0
	brace_tier_last = 0
	if float(profile.get("ranged_damage", 0.0)) > 0.0 and float(profile.get("range", 0.0)) > 0.0:
		ammo_remaining = int(profile.get("ammo_volleys", 0))
	else:
		ammo_remaining = -1

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
		State.RALLYING:
			return "rallying"
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


func add_crack_intensity_from_damage(_strength_damage: float) -> void:
	# Superseded: crack band depth is strength%-driven (render-only). Kept for combat API compat.
	pass


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



func start_from_rest() -> void:
	current_speed_m_s = 0.0


func is_braced() -> bool:
	return _braced


func begin_charge_amp() -> void:
	charge_amp_factor = Constants.get_float("charge_amp_peak")
	_charge_amp_time_left = Constants.get_float("charge_amp_decay_s")


func tick_charge_amp(delta: float) -> void:
	if _charge_amp_time_left <= 0.0:
		charge_amp_factor = 1.0
		return
	_charge_amp_time_left = maxf(_charge_amp_time_left - delta, 0.0)
	var decay_s := Constants.get_float("charge_amp_decay_s")
	if decay_s <= 0.0:
		charge_amp_factor = 1.0
		return
	var peak := Constants.get_float("charge_amp_peak")
	var t := _charge_amp_time_left / decay_s
	charge_amp_factor = 1.0 + (peak - 1.0) * t


func _mass() -> float:
	return _ChargeCombat.mass_of(self)

func update_brace(delta: float, enemies: Array = []) -> void:
	if _state == State.REMOVED or _state == State.ROUTING or _state == State.RALLYING:
		_braced = false
		_brace_hold_sec = 0.0
		_threat_front_sec = 0.0
		_update_brace_visual()
		return

	# R16 Tier 1 threat clock — any unit; cheap front-axis + faces_threat only.
	var gallop_threat := false
	for enemy in enemies:
		if enemy == null or enemy.get_state() == State.REMOVED:
			continue
		if enemy.team_id == team_id:
			continue
		if _ChargeCombat.is_charging_threat(enemy, self):
			gallop_threat = true
			break
	if gallop_threat and _ChargeCombat.own_speed_allows_instinctive(self):
		_threat_front_sec += delta
	else:
		_threat_front_sec = 0.0

	# Tier 2 Pierce set-to-receive (unchanged gate).
	var stationary := current_speed_m_s <= Constants.get_float("brace_stationary_speed")
	var holding := _state == State.HOLD or (_state == State.MARCHING and stationary)
	if not holding or not _ChargeCombat.is_pierce(self) or not stationary:
		_brace_hold_sec = 0.0
		_braced = false
		_update_brace_visual()
		return
	var sees_charger := false
	for enemy in enemies:
		if enemy == null or enemy.get_state() == State.REMOVED:
			continue
		if enemy.team_id == team_id:
			continue
		if not _ChargeCombat.faces_threat(self, enemy):
			continue
		# Incoming if enemy is approaching our front.
		if _ChargeCombat.closing_speed_into_defender(enemy, self) > 0.05 or enemy.get_state() == State.MARCHING:
			sees_charger = true
			break
	if sees_charger:
		_brace_hold_sec += delta
	elif not _braced:
		_brace_hold_sec = 0.0
	_braced = _brace_hold_sec >= Constants.get_float("brace_time_s") or _braced
	_update_brace_visual()


func _update_brace_visual() -> void:
	_ensure_nodes()
	if _brace_indicator == null:
		_brace_indicator = ColorRect.new()
		_brace_indicator.name = "BraceIndicator"
		_visual_root.add_child(_brace_indicator)
		_brace_indicator.color = Color(0.95, 0.85, 0.2, 0.9)
		_brace_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _instinctive_indicator == null:
		_instinctive_indicator = ColorRect.new()
		_instinctive_indicator.name = "InstinctiveBraceIndicator"
		_visual_root.add_child(_instinctive_indicator)
		_instinctive_indicator.color = Color(0.45, 0.85, 0.95, 0.75)
		_instinctive_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frontage_px := effective_frontage_m() * Constants.get_float("px_per_meter")
	var depth_px := 3.0
	var y := -effective_depth_m() * Constants.get_float("px_per_meter") * 0.5 - depth_px
	# Tier 2 (set) takes priority visually.
	if _braced:
		_brace_indicator.visible = true
		_brace_indicator.size = Vector2(frontage_px, depth_px)
		_brace_indicator.position = Vector2(-frontage_px * 0.5, y)
		_instinctive_indicator.visible = false
		return
	_brace_indicator.visible = false
	var instinctive_ready := (
		_threat_front_sec + 0.001 >= Constants.get_float("brace_reaction_s")
		and _ChargeCombat.own_speed_allows_instinctive(self)
	)
	if instinctive_ready:
		_instinctive_indicator.visible = true
		_instinctive_indicator.size = Vector2(frontage_px, depth_px)
		_instinctive_indicator.position = Vector2(-frontage_px * 0.5, y)
	else:
		_instinctive_indicator.visible = false


func update_marching(delta: float, enemies: Array[Unit] = []) -> void:
	if _state != State.MARCHING:
		return

	_update_charge_commit(enemies)
	var to_target := march_target - position
	var top := _ChargeCombat.target_speed_m_s(self)
	if to_target.length() > 0.001:
		var desired := to_target.normalized()
		var angled := facing.angle_to(desired)
		if absf(angled) > 0.15:
			var max_turn: float = _ChargeCombat.turn_rate_rad_s(self) * delta
			if absf(angled) <= max_turn:
				facing = desired
			else:
				facing = facing.rotated(signf(angled) * max_turn)
			rotation = facing.angle()
	# Accelerate / decelerate toward target speed (gait or tactical).
	var accel: float = _ChargeCombat.accel_m_s2(self)
	var decel: float = _ChargeCombat.decel_m_s2(self)
	if current_speed_m_s < top:
		current_speed_m_s = minf(top, current_speed_m_s + accel * delta)
	elif current_speed_m_s > top:
		current_speed_m_s = maxf(top, current_speed_m_s - decel * delta)
	var speed_px := current_speed_m_s * Constants.get_float("px_per_meter")
	var move_px := speed_px * delta
	if to_target.length() <= move_px:
		position = march_target
		current_speed_m_s = maxf(0.0, current_speed_m_s - decel * delta)
		charge_committed = false
		_charge_commit_target_id = ""
		if enemies.is_empty():
			_set_state(State.HOLD)
		return

	for enemy in enemies:
		if not CombatResolver.could_have_contact(self, enemy):
			continue
		if (
			EdgeContact.units_have_contact(self, enemy)
			or EdgeContact.units_have_contact(enemy, self)
		):
			return
		move_px = CombatResolver.clamp_march_distance(self, enemy, move_px)
		if move_px <= 0.0:
			return

	position += to_target.normalized() * move_px


func _update_charge_commit(enemies: Array) -> void:
	## R17: commit to charge gait when marching toward a front-arc enemy in range.
	if current_order != Order.MARCH_TO:
		charge_committed = false
		_charge_commit_target_id = ""
		return
	var target = _ChargeCombat.find_charge_commit_target(self, enemies)
	if target == null:
		charge_committed = false
		_charge_commit_target_id = ""
		return
	charge_committed = true
	_charge_commit_target_id = str(target.unit_id)


func has_trait(trait_name: String) -> bool:
	var traits: Array = profile.get("traits", [])
	for entry in traits:
		if str(entry).to_upper() == trait_name.to_upper():
			return true
	return false


func get_rallies_remaining() -> int:
	return maxi(0, Constants.get_int("rally_per_battle_limit") - _rallies_this_battle)


func is_defeated_for_victory() -> bool:
	if _state == State.REMOVED:
		return true
	if _state == State.ROUTING:
		if has_trait("RALLY") and get_rallies_remaining() > 0:
			return false
		return true
	return false


func set_render_camera(camera: Camera2D) -> void:
	_render_camera = camera


func is_rallied_hold() -> bool:
	return _rallied_hold and _state == State.HOLD


func consume_pending_rout_event() -> bool:
	if not _pending_rout_event:
		return false
	_pending_rout_event = false
	return true


func reset_rally_timer() -> void:
	_rally_elapsed_sec = 0.0


func update_routing(delta: float, enemies: Array[Unit] = []) -> void:
	if _state == State.RALLYING:
		_rally_reform_remaining_sec -= delta
		if _rally_reform_remaining_sec <= 0.0:
			_set_state(State.HOLD)
		return

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

	if not has_trait("RALLY"):
		return
	if _rallies_this_battle >= Constants.get_int("rally_per_battle_limit"):
		return

	if _enemy_within_pursuit_radius(enemies):
		_rally_elapsed_sec = 0.0
		return

	_rally_elapsed_sec += delta
	if _rally_elapsed_sec >= Constants.get_float("t_rally_sec"):
		_complete_rally(enemies)


func _enemy_within_pursuit_radius(enemies: Array[Unit]) -> bool:
	for enemy in enemies:
		if enemy == null or enemy.get_state() == State.REMOVED:
			continue
		if CombatResolver.enemy_blocks_rally_distance_m(self, enemy):
			return true
	return false


func _complete_rally(enemies: Array[Unit]) -> void:
	_rallies_this_battle += 1
	_rally_elapsed_sec = 0.0
	cohesion = Constants.get_float("rally_cohesion_reset")
	current_order = Order.HOLD
	_rallied_hold = true
	_face_nearest_threat(enemies)
	_set_state(State.RALLYING)
	_rally_reform_remaining_sec = 1.0


func _face_nearest_threat(enemies: Array[Unit]) -> void:
	var nearest: Unit = null
	var nearest_dist := INF
	for enemy in enemies:
		if enemy == null or enemy.get_state() == State.REMOVED:
			continue
		var dist := CombatResolver.center_distance_m(self, enemy)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	if nearest == null:
		return
	var to_enemy := nearest.position - position
	if to_enemy.length_squared() <= 0.0001:
		return
	facing = to_enemy.normalized()
	rotation = facing.angle()


func begin_engagement(partner: Unit) -> void:
	add_contact_partner(partner)
	if (
		CombatResolver.is_head_on_pair(self, partner)
		and not EdgeContact.has_non_front_segment_contact(self, partner)
	):
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
	if _state != State.ROUTING and _state != State.REMOVED and _state != State.RALLYING:
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
	_rally_elapsed_sec = 0.0
	_pending_rout_event = true
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
	_update_rout_flicker(delta)
	_update_impact_flicker(delta)
	_update_bump_visual(delta)


func trigger_volley_impact() -> void:
	_impact_flicker_time = 0.22


func _set_state(new_state: State) -> void:
	if _state == new_state:
		return

	_state = new_state
	_apply_state_visuals()
	state_changed.emit(self)


func _refresh_morale_state() -> void:
	if _state == State.ROUTING or _state == State.REMOVED or _state == State.RALLYING:
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
		State.RALLYING:
			_body.color = _base_team_color.lerp(Color(0.92, 0.92, 0.92), 0.45)
			_body.modulate = Color(1.0, 1.0, 1.0, 0.75)
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
	var sim_depth_px := effective_depth_m() * px_per_meter
	var depth_px := sim_depth_px
	var frontage_px := effective_frontage_m() * px_per_meter

	if _state == State.ROUTING or _state == State.RALLYING:
		# WO-010: constant frontage; formlessness = pale/transparent/flicker only.
		depth_px = sim_depth_px * 0.55

	# Centered shrink: rendered footprint matches sim footprint (no front-face recession).
	_body.size = Vector2(depth_px, frontage_px)
	_body.position = Vector2(-depth_px * 0.5, -frontage_px * 0.5)

	var border_pad := 4.0
	_border.size = _body.size + Vector2(border_pad, border_pad)
	_border.position = _body.position - Vector2(border_pad * 0.5, border_pad * 0.5)

	rotation = facing.angle()
	_update_collision()
	_update_crack_band()
	_update_grind_band()


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
		_update_grind_band(Vector2.ZERO)
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
	var bump_offset := facing.normalized() * wave * amp_px * direction
	_visual_root.position = bump_offset
	_update_grind_band(bump_offset)


func _update_crack_band() -> void:
	if _crack_band == null:
		return
	if _state == State.REMOVED:
		_crack_band.visible = false
		return

	var depth_px := _body.size.x
	var frontage_px := _body.size.y
	var strength_max := Constants.get_float("strength_max")
	var strength_pct := strength / strength_max
	var gain := Constants.get_float("crack_band_gain")
	var band_depth_px := (1.0 - strength_pct) * depth_px * gain

	if band_depth_px < 0.5 or depth_px <= 0.0:
		_crack_band.visible = false
		return

	_crack_band.visible = true
	# Front edge anchored at engaged face (+X local); band grows rearward (−X).
	var front_x := depth_px * 0.5
	_crack_band.size = Vector2(band_depth_px, frontage_px)
	_crack_band.position = Vector2(front_x - band_depth_px, -frontage_px * 0.5)

	var mat := _crack_band.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("team_color", _base_team_color.darkened(0.15))
		mat.set_shader_parameter("render_seed", float(absi(unit_id.hash() % 100000)))
		mat.set_shader_parameter("edge_wobble_amp", Constants.get_float("crack_band_edge_wobble"))


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
	# Layering (bottom → top): Body → [future unit symbols below crack band] → CrackBand → GrindBand → Border
	if _crack_band == null and _visual_root != null:
		_crack_band = ColorRect.new()
		_crack_band.name = "CrackBand"
		_crack_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var crack_mat := ShaderMaterial.new()
		crack_mat.shader = _crack_shader
		_crack_band.material = crack_mat
		_visual_root.add_child(_crack_band)
	if _grind_band == null and _visual_root != null:
		_grind_band = ColorRect.new()
		_grind_band.name = "GrindBand"
		_grind_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_visual_root.add_child(_grind_band)
	_reorder_visual_layers()
	if _collision == null:
		_collision = $CollisionShape2D


func _reorder_visual_layers() -> void:
	if _visual_root == null:
		return
	if _body != null:
		_visual_root.move_child(_body, 0)
	if _crack_band != null:
		_visual_root.move_child(_crack_band, 1)
	if _grind_band != null:
		_visual_root.move_child(_grind_band, 2)
	if _border != null:
		_visual_root.move_child(_border, 3)


func _min_world_px_for_screen(screen_px: float) -> float:
	var zoom := 1.0
	if _render_camera != null:
		zoom = _render_camera.zoom.x
	return screen_px / maxf(zoom, 0.001)


func _update_grind_band(bump_offset: Vector2 = Vector2.ZERO) -> void:
	if _grind_band == null:
		return
	if _state != State.ENGAGED and _state != State.WAVERING or _bump_gap_ratio <= 0.001:
		_grind_band.visible = false
		return

	_grind_band.visible = true
	var depth_px := _body.size.x
	var frontage_px := _body.size.y
	var front_x := depth_px * 0.5
	var band_depth_px := _min_world_px_for_screen(Constants.get_float("grind_band_min_screen_px"))
	var intensity := clampf(_bump_gap_ratio, 0.0, 1.0)
	_grind_band.size = Vector2(band_depth_px, frontage_px * 0.88)
	_grind_band.position = Vector2(front_x - band_depth_px, -frontage_px * 0.44) + bump_offset
	_grind_band.color = Color(1.0, 0.5 + 0.35 * intensity, 0.1, 0.25 + 0.55 * intensity)


func _update_rout_flicker(delta: float) -> void:
	if _state != State.ROUTING:
		return
	_rout_flicker_time += delta
	var alpha := 0.32 + 0.08 * sin(_rout_flicker_time * 9.0)
	_body.modulate = Color(1.0, 1.0, 1.0, alpha)


func _update_impact_flicker(delta: float) -> void:
	if _impact_flicker_time <= 0.0:
		return
	_impact_flicker_time = maxf(_impact_flicker_time - delta, 0.0)
	var pulse: float = _impact_flicker_time / 0.22
	_body.modulate = Color(1.0, 0.92, 0.75, 1.0).lerp(Color.WHITE, 1.0 - pulse)
