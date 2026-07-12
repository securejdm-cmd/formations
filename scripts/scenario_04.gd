class_name Scenario04
extends Scenario01

enum ContactMode { FRONT, SIDE, CORNER }

const S4_CONTACT_BALANCE_TARGET_M := 1.0

@export var contact_mode: ContactMode = ContactMode.FRONT

var _defender: Unit = null
var _attacker: Unit = null
var _cohesion_start: float = 0.0
var _combat_start_tick: int = -1
var _drain_total: float = 0.0
var _spawn_edge_label: String = ""
var _spawn_contact: Dictionary = {}
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
			var corner_pose := _solve_corner_spawn_pose(profile, _defender, depth_m, frontage_m)
			attacker_pos = corner_pose.position
			attacker_facing = corner_pose.facing

	_attacker = UNIT_SCENE.instantiate()
	add_child(_attacker)
	_attacker.configure("attacker", "red", profile, attacker_pos, attacker_facing)
	_units.append(_attacker)

	if contact_mode == ContactMode.FRONT and CombatResolver.is_head_on_pair(_attacker, _defender):
		CombatResolver.snap_pair_to_contact(_attacker, _defender)
	_attacker.add_contact_partner(_defender)
	_defender.add_contact_partner(_attacker)
	_on_first_contact()
	_combat_start_tick = _sim_tick_count
	_cohesion_start = _defender.cohesion
	var spawn_contact := EdgeContact.classify_contact(_attacker, _defender)
	_spawn_contact = spawn_contact
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
	if contact_mode == ContactMode.FRONT and CombatResolver.is_head_on_pair(_attacker, _defender):
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


func _combat_tick() -> void:
	if contact_mode == ContactMode.FRONT:
		super._combat_tick()
		return
	_prune_broken_contacts()
	if _attacker == null or _defender == null:
		return
	if (
		_defender.get_state() != Unit.State.ENGAGED
		and _defender.get_state() != Unit.State.WAVERING
	):
		return
	if _attacker.get_state() == Unit.State.ROUTING or _attacker.get_state() == Unit.State.REMOVED:
		return
	var contact: Dictionary = _spawn_contact
	if not contact.get("has_contact", false):
		return
	var segment := CombatResolver.resolve_contact_segment(_attacker, _defender, contact)
	var edge_lengths: Dictionary = segment.get("edge_lengths_m", {})
	var push_normal: Vector2 = segment.get("push_normal", _defender.facing)
	if is_equal_approx(segment.attacker_push, segment.defender_push):
		CombatResolver.apply_strength_loss_with_edge(_attacker, segment.attacker_damage, edge_lengths)
		CombatResolver.apply_strength_loss_with_edge(_defender, segment.defender_damage, edge_lengths)
	elif segment.attacker_wins:
		CombatResolver.apply_directed_position_shift(_defender, segment.defender_shift_m, push_normal)
		CombatResolver.apply_shift_morale_drain(_defender, segment.defender_shift_m, edge_lengths)
		CombatResolver.apply_strength_loss_with_edge(_defender, segment.defender_damage, edge_lengths)
		CombatResolver.apply_strength_loss_with_edge(_attacker, segment.attacker_damage, edge_lengths)
	else:
		CombatResolver.apply_directed_position_shift(
			_attacker, segment.attacker_shift_m, -push_normal
		)
		CombatResolver.apply_shift_morale_drain(_attacker, segment.attacker_shift_m, edge_lengths)
		CombatResolver.apply_strength_loss_with_edge(_attacker, segment.attacker_damage, edge_lengths)
		CombatResolver.apply_strength_loss_with_edge(_defender, segment.defender_damage, edge_lengths)
	_defender.set_active_contact_edges(contact.get("edge_label", ""))


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


func get_spawn_contact_sample() -> Dictionary:
	return _spawn_contact.duplicate()


func _solve_corner_spawn_pose(
	profile: Dictionary,
	defender: Unit,
	depth_m: float,
	frontage_m: float
) -> Dictionary:
	var px_per_meter := Constants.get_float("px_per_meter")
	var half_depth_m := depth_m * 0.5
	var half_frontage_m := frontage_m * 0.5
	var forward := defender.facing.normalized()
	var left := FormationGeometry.left_vector(forward)

	var probe: Unit = UNIT_SCENE.instantiate()
	add_child(probe)
	probe.configure("corner_probe", "red", profile, Vector2.ZERO, Vector2.LEFT)

	var best_score := INF
	var best_balance_delta := INF
	var best_pos := defender.position
	var best_facing := Vector2(-1, -1).normalized()
	var best_contact: Dictionary = {}

	for approach_deg in _range_float(200.0, 340.0, 5.0):
		var approach := Vector2.RIGHT.rotated(deg_to_rad(approach_deg))
		var attacker_facing := -approach
		probe.facing = attacker_facing
		probe.rotation = attacker_facing.angle()
		for along_m in _range_float(half_depth_m + 2.0, depth_m * 2.5, 0.25):
			for across_m in _range_float(2.0, half_frontage_m + half_depth_m, 0.25):
				var offset_m := forward * along_m + left * across_m
				probe.position = defender.position + offset_m * px_per_meter
				var contact: Dictionary = EdgeContact.classify_contact(probe, defender)
				if not contact.get("has_contact", false):
					continue
				var edges: Dictionary = contact.get("edge_lengths_m", {})
				if not edges.has(EdgeContact.EDGE_FRONT) or not edges.has(EdgeContact.EDGE_LEFT):
					continue
				var front_l: float = edges.get(EdgeContact.EDGE_FRONT, 0.0)
				var left_l: float = edges.get(EdgeContact.EDGE_LEFT, 0.0)
				if front_l < 5.0 or left_l < 5.0:
					continue
				var balance_delta: float = absf(front_l - left_l)
				var score: float = balance_delta
				if score < best_score:
					best_score = score
					best_balance_delta = balance_delta
					best_pos = probe.position
					best_facing = attacker_facing
					best_contact = contact

	probe.free()

	if best_balance_delta > S4_CONTACT_BALANCE_TARGET_M and not best_contact.is_empty():
		var refine_forward := defender.facing.normalized()
		var refine_left := FormationGeometry.left_vector(refine_forward)
		var best_local := Vector2(
			(best_pos - defender.position).dot(refine_forward) / px_per_meter,
			(best_pos - defender.position).dot(refine_left) / px_per_meter,
		)
		var refine_probe: Unit = UNIT_SCENE.instantiate()
		add_child(refine_probe)
		refine_probe.configure("corner_refine", "red", profile, Vector2.ZERO, best_facing)
		refine_probe.facing = best_facing
		refine_probe.rotation = best_facing.angle()
		for along_m in _range_float(best_local.x - 3.0, best_local.x + 3.0, 0.025):
			for across_m in _range_float(best_local.y - 3.0, best_local.y + 3.0, 0.025):
				refine_probe.position = defender.position + (refine_forward * along_m + refine_left * across_m) * px_per_meter
				var contact: Dictionary = EdgeContact.classify_contact(refine_probe, defender)
				if not contact.get("has_contact", false):
					continue
				var edges: Dictionary = contact.get("edge_lengths_m", {})
				if not edges.has(EdgeContact.EDGE_FRONT) or not edges.has(EdgeContact.EDGE_LEFT):
					continue
				var front_l: float = edges.get(EdgeContact.EDGE_FRONT, 0.0)
				var left_l: float = edges.get(EdgeContact.EDGE_LEFT, 0.0)
				if front_l < 5.0 or left_l < 5.0:
					continue
				var balance_delta: float = absf(front_l - left_l)
				var score: float = balance_delta
				if score < best_score:
					best_score = score
					best_balance_delta = balance_delta
					best_pos = refine_probe.position
					best_contact = contact
		refine_probe.free()

	if best_contact.is_empty():
		var fallback_approach := Vector2(-1, -1).normalized()
		var offset_m := forward * (half_depth_m * 2.0 - 0.35)
		offset_m += left * (half_frontage_m + half_depth_m - 0.35)
		best_pos = defender.position + offset_m * px_per_meter
		best_facing = -fallback_approach

	return {"position": best_pos, "facing": best_facing, "contact": best_contact}


func _range_float(start: float, end: float, step: float) -> Array[float]:
	var values: Array[float] = []
	var value := start
	while value <= end + 0.0001:
		values.append(value)
		value += step
	return values
