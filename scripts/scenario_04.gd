class_name Scenario04
extends Scenario01

enum ContactMode { FRONT, SIDE, CORNER }

@export var contact_mode: ContactMode = ContactMode.FRONT

var _defender: Unit = null
var _attacker: Unit = null
var _cohesion_start: float = 0.0
var _combat_start_tick: int = -1
var _drain_total: float = 0.0


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

	var attacker_pos := Vector2(half_depth_px * 2.0, 0.0)
	var attacker_facing := Vector2.LEFT
	match contact_mode:
		ContactMode.FRONT:
			attacker_pos = Vector2(half_depth_px * 2.0, 0.0)
			attacker_facing = Vector2.LEFT
		ContactMode.SIDE:
			attacker_pos = Vector2(half_depth_px * 1.05, half_frontage_px * 0.30)
			attacker_facing = Vector2.LEFT
		ContactMode.CORNER:
			attacker_pos = Vector2(half_depth_px * 0.08, -(half_frontage_px * 0.58))
			attacker_facing = Vector2.DOWN

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


func _update_movement(_delta: float) -> void:
	pass


func _track_rout_state() -> void:
	pass


func _update_victory_state(_tick_interval: float) -> void:
	pass


func _check_epilogue_end() -> void:
	pass


func advance_one_tick() -> void:
	super.advance_one_tick()
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
	if _defender == null:
		return ""
	var contact := EdgeContact.classify_contact(_attacker, _defender)
	return contact.get("edge_label", _defender.get_active_contact_edges())
