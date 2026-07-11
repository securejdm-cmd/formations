class_name Scenario04
extends Scenario01

enum ContactMode { FRONT, SIDE, CORNER }

@export var contact_mode: ContactMode = ContactMode.FRONT

var _defender: Unit = null
var _attacker: Unit = null
var _cohesion_start: float = 0.0
var _combat_start_tick: int = -1
var _drain_total: float = 0.0
var _spawn_edge_label: String = ""
var _spawn_offset_m: Vector2 = Vector2.ZERO
var _spawn_facing: Vector2 = Vector2.LEFT
var _defender_spawn_pos: Vector2 = Vector2.ZERO
var _defender_spawn_facing: Vector2 = Vector2.RIGHT


func _spawn_units() -> void:
	var profile := UnitProfileLoader.load_profile("test_infantry")
	var px_per_meter := Constants.get_float("px_per_meter")
	var depth_m := float(profile.get("formation_depth_m", Constants.get_float("default_infantry_block_depth_m")))
	var frontage_m := float(profile.get("formation_frontage_m", Constants.get_float("default_infantry_block_frontage_m")))
	var half_depth_px := depth_m * 0.5 * px_per_meter
	var half_frontage_px := frontage_m * 0.5 * px_per_meter

	_defender = UNIT_SCENE.instantiate()
	add_child(_defender)
	_defender.configure("defender", "blue", profile, Vector2.ZERO, Vector2.RIGHT)
	_units.append(_defender)
	_defender_spawn_pos = _defender.position
	_defender_spawn_facing = _defender.facing

	var attacker_pos := Vector2(half_depth_px * 2.0, 0.0)
	var attacker_facing := Vector2.LEFT
	var touch_pen_px := (EdgeContact.CONTACT_EPSILON_M + 0.15) * px_per_meter
	match contact_mode:
		ContactMode.FRONT:
			attacker_pos = Vector2(half_depth_px * 2.0, 0.0)
			attacker_facing = Vector2.LEFT
		ContactMode.SIDE:
			attacker_pos = Vector2(0.0, -(half_frontage_px + half_depth_px - touch_pen_px))
			attacker_facing = Vector2.DOWN
		ContactMode.CORNER:
			var half_depth_m := depth_m * 0.5
			var half_frontage_m := frontage_m * 0.5
			var pen_m := 0.35
			var approach := Vector2(-1, -1).normalized()
			var offset_m := Vector2.ZERO
			offset_m += _defender.facing.normalized() * (half_depth_m * 2.0 - pen_m)
			offset_m += FormationGeometry.left_vector(_defender.facing) * (half_frontage_m + half_depth_m - pen_m)
			attacker_pos = offset_m * px_per_meter
			attacker_facing = -approach

	_attacker = UNIT_SCENE.instantiate()
	add_child(_attacker)
	_attacker.configure("attacker", "red", profile, attacker_pos, attacker_facing)
	_units.append(_attacker)

	if CombatResolver.is_head_on_pair(_attacker, _defender):
		CombatResolver.snap_pair_to_contact(_attacker, _defender)
	_attacker.add_contact_partner(_defender)
	_defender.add_contact_partner(_attacker)
	_on_first_contact()
	_combat_start_tick = _sim_tick_count
	_cohesion_start = _defender.cohesion
	var spawn_contact := EdgeContact.classify_contact(_attacker, _defender)
	_spawn_edge_label = spawn_contact.get("edge_label", "")
	if _spawn_edge_label.is_empty() and contact_mode == ContactMode.FRONT:
		_spawn_edge_label = EdgeContact.EDGE_FRONT
	var forward := _defender.facing.normalized()
	var left := FormationGeometry.left_vector(forward)
	_spawn_offset_m = Vector2(
		(_attacker.position - _defender.position).dot(forward) / px_per_meter,
		(_attacker.position - _defender.position).dot(left) / px_per_meter,
	)
	_spawn_facing = _attacker.facing


func _maintain_spawn_contact() -> void:
	if _defender == null or _attacker == null:
		return
	_defender.position = _defender_spawn_pos
	_defender.facing = _defender_spawn_facing
	_defender.rotation = _defender.facing.angle()
	var px_per_meter := Constants.get_float("px_per_meter")
	var forward := _defender.facing.normalized()
	var left := FormationGeometry.left_vector(forward)
	_attacker.position = _defender.position + (forward * _spawn_offset_m.x + left * _spawn_offset_m.y) * px_per_meter
	_attacker.facing = _spawn_facing
	_attacker.rotation = _attacker.facing.angle()
	if CombatResolver.is_head_on_pair(_attacker, _defender):
		CombatResolver.snap_pair_to_contact(_attacker, _defender)
	if not _attacker.has_contact_with(_defender):
		_attacker.add_contact_partner(_defender)
		_defender.add_contact_partner(_attacker)


func advance_one_tick() -> void:
	if _battle_over:
		return
	var tick_interval := CombatResolver.tick_interval()
	_sim_tick_count += 1
	_maintain_spawn_contact()
	_combat_tick()
	_assert_no_overlaps()
	var ticks_per_sec := int(Constants.get_float("tick_rate_per_sec"))
	if _sim_tick_count % ticks_per_sec == 0:
		_log_trace_row()
	if _combat_start_tick >= 0 and _defender != null:
		_drain_total = _cohesion_start - _defender.cohesion


func get_drain_per_sec() -> float:
	if _combat_start_tick < 0:
		return 0.0
	var elapsed_ticks := _sim_tick_count - _combat_start_tick
	if elapsed_ticks <= 0:
		return 0.0
	return _drain_total / (float(elapsed_ticks) * CombatResolver.tick_interval())


func get_edge_label_sample() -> String:
	return _spawn_edge_label


func get_contact_sample() -> Dictionary:
	if _defender == null or _attacker == null:
		return {}
	return EdgeContact.classify_contact(_attacker, _defender)
