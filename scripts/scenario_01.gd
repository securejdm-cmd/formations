class_name Scenario01
extends Node2D

const UNIT_SCENE := preload("res://scenes/unit.tscn")
const TRACE_DIR := "res://tests/traces/"
const _TickProfiler := preload("res://scripts/tick_profiler.gd")

enum BattlePhase { ACTIVE, VICTORY_PENDING, VICTORY_EPILOGUE, FINISHED }

@export var auto_run: bool = true
@export var headless_mode: bool = false
## When true (with headless_mode), autotest harness drives ticks via SimHarness — no _process loop.
@export var fast_sim_mode: bool = false

var _units: Array[Unit] = []
var _tick_accumulator: float = 0.0
var _sim_tick_count: int = 0
var _battle_seed: int = 0
var _seed_override: int = -1
var _battle_over: bool = false
var _battle_phase: BattlePhase = BattlePhase.ACTIVE
var _victory_team: String = ""
var _victory_delay_accum: float = 0.0
var _watch_epilogue: bool = false
var _trace_lines: PackedStringArray = PackedStringArray()
var _winner: Unit = null
var _battle_start_time_msec: int = 0
var _first_contact_tick: int = -1
var _first_rout_tick: int = -1
var _overlap_assertion_failed: bool = false
var _adhesion_invariant_failed: bool = false
var _grid_cell_size_px: float = 1.0
var _grid_cells: Dictionary = {}
var _current_tick_interval: float = 0.1
var _tick_start_positions: Dictionary = {}

@onready var _camera: Camera2D = $Camera2D
@onready var _ground: ColorRect = $Ground
@onready var _debug_overlay: CanvasLayer = $DebugOverlay
@onready var _stat_card = $StatCardLayer/UnitStatCard
var _shock_floater_layer: CanvasLayer = null
@onready var _results_overlay = $ResultsOverlay


func set_battle_seed(seed_value: int) -> void:
	_seed_override = seed_value


func _ready() -> void:
	_setup_ground()
	_battle_seed = _seed_override if _seed_override >= 0 else Constants.get_int("scenario_01_battle_seed")
	RNG.set_seed(_battle_seed)
	print("[Scenario 01] Battle seed: %d" % _battle_seed)

	_spawn_units()
	_shock_floater_layer = get_node_or_null("ShockFloaterLayer") as CanvasLayer
	_debug_overlay.setup_for_scenario(_units, _camera, _stat_card)
	_stat_card.setup(_camera)
	if not headless_mode:
		_results_overlay.skip_pressed.connect(_on_skip_epilogue)
		_results_overlay.watch_pressed.connect(_on_watch_epilogue)
	else:
		_results_overlay.hide_all()

	if auto_run:
		_battle_start_time_msec = Time.get_ticks_msec()
		_write_trace_header()
		_log_trace_row()
	if headless_mode:
		set_process(false)


func simulate_realtime_step(delta: float = -1.0) -> void:
	var step := delta if delta > 0.0 else CombatResolver.tick_interval()
	_process(step)


func run_simulation_fast(extra_ticks: int = 0) -> void:
	var harness: Script = load("res://scripts/sim_harness.gd")
	harness.run_to_completion(self, harness.RunMode.FAST, extra_ticks)


func _process(delta: float) -> void:
	if _battle_over:
		return
	if not headless_mode and _battle_phase == BattlePhase.VICTORY_PENDING:
		_victory_delay_accum += delta
		if _victory_delay_accum >= Constants.get_float("victory_delay_s"):
			_declare_victory()
		return

	_tick_accumulator += delta
	var tick_interval := CombatResolver.tick_interval()
	while _tick_accumulator >= tick_interval:
		_tick_accumulator -= tick_interval
		advance_one_tick()
		if _battle_over:
			return


func advance_one_tick() -> void:
	if _battle_over:
		return

	var tick_interval := CombatResolver.tick_interval()
	_sim_tick_count += 1
	_begin_sim_tick(tick_interval)

	if _TickProfiler.enabled:
		_advance_one_tick_profiled(tick_interval)
	else:
		_advance_one_tick_fast(tick_interval)


func _begin_sim_tick(tick_interval: float) -> void:
	_current_tick_interval = tick_interval
	EdgeContact.begin_tick(_sim_tick_count)
	_capture_tick_start_positions()


func _overlap_assert_enabled() -> bool:
	# Verification equipment: autotest and fast-mode only — not realtime gameplay.
	return headless_mode and fast_sim_mode


func _capture_tick_start_positions() -> void:
	_tick_start_positions.clear()
	for unit in _units:
		if unit == null:
			continue
		_tick_start_positions[unit.unit_id] = unit.position


func _unit_moved_this_tick(unit: Unit) -> bool:
	if unit == null or not _tick_start_positions.has(unit.unit_id):
		return true
	var start: Vector2 = _tick_start_positions[unit.unit_id]
	return start.distance_squared_to(unit.position) > 0.0001


func _advance_one_tick_fast(tick_interval: float) -> void:
	_rebuild_spatial_grid()
	_update_movement(tick_interval)
	_process_rout_events()
	_resolve_allied_overlaps()
	_try_passive_engagement()
	_apply_contact_adhesion()
	_run_overlap_assert_if_enabled()
	_combat_tick()
	_pursuit_tick()
	_apply_contact_adhesion()
	_track_rout_state()
	_update_victory_state(tick_interval)
	var ticks_per_sec := int(Constants.get_float("tick_rate_per_sec"))
	if _sim_tick_count % ticks_per_sec == 0:
		_log_trace_row()
	_check_epilogue_end()


func _advance_one_tick_profiled(tick_interval: float) -> void:
	var t0 := _TickProfiler.begin_section("grid_overhead")
	_rebuild_spatial_grid()
	_TickProfiler.end_section("grid_overhead", t0)

	t0 = _TickProfiler.begin_section("movement")
	_update_movement(tick_interval)
	_process_rout_events()
	_TickProfiler.end_section("movement", t0)

	t0 = _TickProfiler.begin_section("allied_separation")
	_resolve_allied_overlaps()
	_try_passive_engagement()
	_TickProfiler.end_section("allied_separation", t0)

	t0 = _TickProfiler.begin_section("adhesion")
	_apply_contact_adhesion()
	_TickProfiler.end_section("adhesion", t0)

	t0 = _TickProfiler.begin_section("overlap_assert")
	_run_overlap_assert_if_enabled()
	_TickProfiler.end_section("overlap_assert", t0)

	t0 = _TickProfiler.begin_section("combat")
	_combat_tick()
	_pursuit_tick()
	_TickProfiler.end_section("combat", t0)

	t0 = _TickProfiler.begin_section("adhesion_post")
	_apply_contact_adhesion()
	_TickProfiler.end_section("adhesion_post", t0)

	t0 = _TickProfiler.begin_section("victory_epilogue")
	_track_rout_state()
	_update_victory_state(tick_interval)
	var ticks_per_sec := int(Constants.get_float("tick_rate_per_sec"))
	if _sim_tick_count % ticks_per_sec == 0:
		var t_log := _TickProfiler.begin_section("trace_logging")
		_log_trace_row()
		_TickProfiler.end_section("trace_logging", t_log)
	_check_epilogue_end()
	_TickProfiler.end_section("victory_epilogue", t0)

	_TickProfiler.on_tick_complete()


func _setup_ground() -> void:
	var width_px := Constants.get_float("battlefield_width_m") * Constants.get_float("px_per_meter")
	var height_px := Constants.get_float("battlefield_height_m") * Constants.get_float("px_per_meter")
	_ground.size = Vector2(width_px, height_px)
	_ground.position = Vector2(-width_px * 0.5, -height_px * 0.5)


func _spawn_units() -> void:
	var profile := UnitProfileLoader.load_profile("test_infantry")
	var start_distance_m := Constants.get_float("scenario_01_start_distance_m")
	var half_distance_px := start_distance_m * 0.5 * Constants.get_float("px_per_meter")

	var red: Unit = UNIT_SCENE.instantiate()
	add_child(red)
	red.configure("red_1", "red", profile, Vector2(-half_distance_px, 0.0), Vector2.RIGHT)
	red.set_march_to(Vector2(half_distance_px, 0.0))
	_units.append(red)

	var blue: Unit = UNIT_SCENE.instantiate()
	add_child(blue)
	blue.configure("blue_1", "blue", profile, Vector2(half_distance_px, 0.0), Vector2.LEFT)
	blue.set_march_to(Vector2(-half_distance_px, 0.0))
	_units.append(blue)

	for unit in _units:
		unit.set_render_camera(_camera)


func _spatial_cell_size_m() -> float:
	return Constants.get_float("spatial_grid_cell_m")


func _rebuild_spatial_grid() -> void:
	var px_per_meter := Constants.get_float("px_per_meter")
	_grid_cell_size_px = maxf(_spatial_cell_size_m() * px_per_meter, 1.0)
	_grid_cells.clear()
	for unit in _units:
		if unit == null or _grid_unit_inactive(unit):
			continue
		var cell: Vector2i = _grid_cell_key(unit.position)
		if not _grid_cells.has(cell):
			_grid_cells[cell] = []
		(_grid_cells[cell] as Array).append(unit)


func _grid_unit_inactive(unit: Unit) -> bool:
	var state_name: String = unit.get_state_name()
	return state_name == "removed" or state_name == "routing"


func _grid_cell_key(pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(pos.x / _grid_cell_size_px)),
		int(floor(pos.y / _grid_cell_size_px)),
	)


func _grid_neighbor_units(unit: Unit) -> Array:
	var origin: Vector2i = _grid_cell_key(unit.position)
	var found: Array = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var key := Vector2i(origin.x + dx, origin.y + dy)
			if not _grid_cells.has(key):
				continue
			for other in _grid_cells[key]:
				if other != unit:
					found.append(other)
	return found


func _grid_sorted_pair_candidates() -> Array:
	if _grid_cells.is_empty():
		_rebuild_spatial_grid()
	var seen: Dictionary = {}
	var pairs: Array = []
	for unit in _units:
		if unit == null or _grid_unit_inactive(unit):
			continue
		for other in _grid_neighbor_units(unit):
			if other == null or _grid_unit_inactive(other):
				continue
			var key := _pair_key(unit, other)
			if seen.has(key):
				continue
			seen[key] = true
			pairs.append([unit, other])
	pairs.sort_custom(func(a, b) -> bool:
		return _pair_key(a[0], a[1]) < _pair_key(b[0], b[1])
	)
	return pairs


func _spatial_neighbors_sorted(unit: Unit) -> Array:
	if _grid_cells.is_empty():
		_rebuild_spatial_grid()
	var neighbors: Array = _grid_neighbor_units(unit)
	neighbors.sort_custom(func(a: Unit, b: Unit) -> bool:
		return a.unit_id < b.unit_id
	)
	return neighbors


func _max_closing_speed_m() -> float:
	var max_speed := 0.0
	for unit in _units:
		if unit == null or unit.get_state() == Unit.State.REMOVED:
			continue
		max_speed = maxf(max_speed, unit.speed_m_per_sec())
	return max_speed * 2.0


func _max_unit_dimension_m() -> float:
	var max_dim := 0.0
	for unit in _units:
		if unit == null or unit.get_state() == Unit.State.REMOVED:
			continue
		var dim := unit.effective_depth_m() + unit.effective_frontage_m()
		max_dim = maxf(max_dim, dim)
	return max_dim


func _march_enemy_query_radius_px() -> float:
	var px_per_meter := Constants.get_float("px_per_meter")
	var radius_m := (
		_max_closing_speed_m() * _current_tick_interval
		+ _max_unit_dimension_m()
	)
	return radius_m * px_per_meter


func _grid_units_within_radius_sorted(unit: Unit, radius_px: float) -> Array:
	if _grid_cells.is_empty():
		_rebuild_spatial_grid()
	var origin: Vector2i = _grid_cell_key(unit.position)
	var ring := maxi(int(ceil(radius_px / _grid_cell_size_px)), 1)
	var found: Array = []
	var seen: Dictionary = {}
	for dx in range(-ring, ring + 1):
		for dy in range(-ring, ring + 1):
			var key := Vector2i(origin.x + dx, origin.y + dy)
			if not _grid_cells.has(key):
				continue
			for other in _grid_cells[key]:
				if other == unit or other == null or seen.has(other.unit_id):
					continue
				if unit.position.distance_to(other.position) > radius_px:
					continue
				seen[other.unit_id] = true
				found.append(other)
	found.sort_custom(func(a: Unit, b: Unit) -> bool:
		return a.unit_id < b.unit_id
	)
	return found


func _uses_march_grid_enemies(unit: Unit) -> bool:
	if unit.get_state() == Unit.State.MARCHING:
		return true
	return (
		unit.get_state() == Unit.State.HOLD
		and unit.current_order == Unit.Order.MARCH_TO
		and not unit.is_rallied_hold()
	)


func _enemies_for(unit: Unit) -> Array[Unit]:
	var enemies: Array[Unit] = []
	var candidates: Array = _units
	if _uses_march_grid_enemies(unit):
		candidates = _grid_units_within_radius_sorted(unit, _march_enemy_query_radius_px())
	elif unit.get_state() in [Unit.State.ENGAGED, Unit.State.WAVERING, Unit.State.ROUTING, Unit.State.RALLYING]:
		candidates = _spatial_neighbors_sorted(unit)
	for other in candidates:
		if other == unit or other.get_state() == Unit.State.REMOVED:
			continue
		if other.team_id == unit.team_id:
			continue
		enemies.append(other)
	return enemies


func _update_movement(delta: float) -> void:
	for unit in _units:
		if unit.get_state() == Unit.State.REMOVED:
			continue
		if unit.get_state() == Unit.State.MARCHING:
			unit.update_marching(delta, _enemies_for(unit))
			_try_begin_engagement(unit)
		elif unit.get_state() == Unit.State.ROUTING or unit.get_state() == Unit.State.RALLYING:
			unit.update_routing(delta, _enemies_for(unit))
		elif (
			unit.get_state() == Unit.State.HOLD
			and unit.current_order == Unit.Order.MARCH_TO
			and not unit.is_rallied_hold()
		):
			unit.update_marching(delta, _enemies_for(unit))
			_try_begin_engagement(unit)


func _try_begin_engagement(unit: Unit) -> void:
	if unit.get_state() == Unit.State.ROUTING or unit.get_state() == Unit.State.RALLYING:
		return

	for other in _spatial_neighbors_sorted(unit):
		if other.get_state() == Unit.State.REMOVED:
			continue
		if other.get_state() == Unit.State.ROUTING or other.get_state() == Unit.State.RALLYING:
			continue
		if other.team_id == unit.team_id:
			continue
		if not CombatResolver.units_have_any_contact(unit, other):
			continue

		unit.add_contact_partner(other)
		other.add_contact_partner(unit)
		if (
			CombatResolver.is_head_on_pair(unit, other)
			and not EdgeContact.has_non_front_segment_contact(unit, other)
		):
			CombatResolver.snap_pair_to_contact(unit, other)
		_on_first_contact()


func _try_passive_engagement() -> void:
	for unit in _units:
		if unit.get_state() != Unit.State.HOLD or not unit.is_rallied_hold():
			continue
		for other in _spatial_neighbors_sorted(unit):
			if other.get_state() == Unit.State.REMOVED:
				continue
			if other.team_id == unit.team_id:
				continue
			if other.get_state() == Unit.State.ROUTING or other.get_state() == Unit.State.RALLYING:
				continue
			if not CombatResolver.units_have_any_contact(unit, other):
				continue
			unit.add_contact_partner(other)
			other.add_contact_partner(unit)
			if (
				CombatResolver.is_head_on_pair(unit, other)
				and not EdgeContact.has_non_front_segment_contact(unit, other)
			):
				CombatResolver.snap_pair_to_contact(unit, other)
			_on_first_contact()


func _process_rout_events() -> void:
	for unit in _units:
		if unit.get_state() == Unit.State.REMOVED:
			continue
		if not unit.consume_pending_rout_event():
			continue
		_apply_neighbor_rout_shock(unit)


func _apply_neighbor_rout_shock(routing_unit: Unit) -> void:
	var radius_m := Constants.get_float("neighbor_rout_shock_radius_m")
	var shock := Constants.get_float("neighbor_rout_shock")
	for ally in _units:
		if ally == routing_unit or ally.team_id != routing_unit.team_id:
			continue
		if ally.get_state() == Unit.State.REMOVED:
			continue
		if CombatResolver.center_distance_m(ally, routing_unit) > radius_m:
			continue
		ally.apply_cohesion_drain(shock)
		_spawn_shock_floater(ally, shock)
		_log_trace_event(
			"neighbor_rout_shock",
			"victim=%s,source=%s,drain=%.1f" % [ally.unit_id, routing_unit.unit_id, shock]
		)


func _spawn_shock_floater(unit: Unit, amount: float) -> void:
	if headless_mode or _shock_floater_layer == null or amount <= 0.0:
		return
	_shock_floater_layer.spawn_for_unit(unit, amount, _camera)


func _pursuit_tick() -> void:
	for routing_unit in _units:
		if routing_unit.get_state() != Unit.State.ROUTING:
			continue
		for enemy in _enemies_for(routing_unit):
			if not CombatResolver.can_apply_pursuit(enemy):
				continue
			if not CombatResolver.is_within_pursuit_contact(enemy, routing_unit):
				continue
			var damage := CombatResolver.calc_pursuit_damage(enemy)
			var applied := CombatResolver.apply_strength_loss(routing_unit, damage)
			routing_unit.reset_rally_timer()
			enemy.record_damage_dealt(applied)
			_log_trace_event(
				"pursuit_damage",
				"victim=%s,pursuer=%s,damage=%.4f" % [routing_unit.unit_id, enemy.unit_id, applied]
			)
			if routing_unit.strength <= 0.0:
				routing_unit.mark_removed()


func _on_first_contact() -> void:
	if _first_contact_tick >= 0:
		return
	_first_contact_tick = _sim_tick_count


func _on_first_rout() -> void:
	if _first_rout_tick >= 0:
		return
	_first_rout_tick = _sim_tick_count


func _combat_tick() -> void:
	_prune_broken_contacts()

	var processed_head_on: Array[String] = []
	var processed_segments: Array[String] = []
	var defender_shifts: Dictionary = {}
	var bump_winners: Dictionary = {}
	var contact_edge_labels: Dictionary = {}  # Unit -> Array[String]

	for unit in _units:
		if unit.get_state() == Unit.State.REMOVED:
			continue
		if unit.get_state() != Unit.State.ENGAGED and unit.get_state() != Unit.State.WAVERING:
			continue

		for partner in unit.get_contact_partners():
			if partner == null or partner.get_state() == Unit.State.REMOVED:
				continue
			if partner.get_state() == Unit.State.ROUTING:
				continue

			if not CombatResolver.is_head_on_pair(unit, partner):
				continue
			if not CombatResolver.units_have_front_contact(unit, partner):
				continue
			if EdgeContact.has_non_front_segment_contact(unit, partner):
				continue

			var pair_key := _pair_key(unit, partner)
			if pair_key in processed_head_on:
				continue
			processed_head_on.append(pair_key)

			var result := CombatResolver.resolve_engagement(unit, partner)
			CombatResolver.apply_ground_shift(unit, result.shift_a_m)
			CombatResolver.apply_ground_shift(partner, result.shift_b_m)

			var applied_to_unit := CombatResolver.apply_strength_loss(unit, result.damage_a)
			partner.record_damage_dealt(applied_to_unit)
			var applied_to_partner := CombatResolver.apply_strength_loss(partner, result.damage_b)
			unit.record_damage_dealt(applied_to_partner)

			unit.set_bump_state(result.gap_ratio, result.a_is_winner)
			partner.set_bump_state(result.gap_ratio, not result.a_is_winner)

			if unit.get_state() == Unit.State.ROUTING or partner.get_state() == Unit.State.ROUTING:
				_on_first_rout()
				_try_start_victory_delay(unit if unit.get_state() == Unit.State.ROUTING else partner)

	for defender in _units:
		if defender.get_state() == Unit.State.REMOVED:
			continue
		if defender.get_state() != Unit.State.ENGAGED and defender.get_state() != Unit.State.WAVERING:
			continue

		for attacker in defender.get_contact_partners():
			if attacker == null or attacker.get_state() == Unit.State.REMOVED:
				continue
			if attacker.get_state() == Unit.State.ROUTING:
				continue
			if CombatResolver.is_head_on_pair(attacker, defender):
				if not EdgeContact.has_non_front_segment_contact(attacker, defender):
					continue

			var pair_key := _pair_key(attacker, defender)
			if pair_key in processed_segments:
				continue
			processed_segments.append(pair_key)

			var orientation := EdgeContact.pick_segment_orientation(attacker, defender)
			var seg_attacker: Unit = orientation.get("attacker")
			var seg_defender: Unit = orientation.get("defender")
			var contact: Dictionary = orientation.get("contact", {})
			if not contact.get("has_contact", false):
				continue

			var edge_label: String = contact.get("edge_label", "")
			if not edge_label.is_empty():
				if not contact_edge_labels.has(seg_defender):
					contact_edge_labels[seg_defender] = [] as Array[String]
				(contact_edge_labels[seg_defender] as Array[String]).append(edge_label)

			var segment := CombatResolver.resolve_contact_segment(seg_attacker, seg_defender, contact)
			var edge_lengths: Dictionary = segment.get("edge_lengths_m", {})
			var push_normal: Vector2 = segment.get("push_normal", seg_defender.facing)

			if is_equal_approx(segment.attacker_push, segment.defender_push):
				var dmg_attacker := CombatResolver.apply_strength_loss_with_edge(
					seg_attacker, segment.attacker_damage, edge_lengths
				)
				var dmg_defender := CombatResolver.apply_strength_loss_with_edge(
					seg_defender, segment.defender_damage, edge_lengths
				)
				seg_defender.record_damage_dealt(dmg_attacker)
				seg_attacker.record_damage_dealt(dmg_defender)
			elif segment.attacker_wins:
				_accumulate_directed_shift(defender_shifts, seg_defender, push_normal, segment.defender_shift_m)
				CombatResolver.apply_shift_morale_drain(seg_defender, segment.defender_shift_m, edge_lengths)
				var applied_defender := CombatResolver.apply_strength_loss_with_edge(
					seg_defender, segment.defender_damage, edge_lengths
				)
				var applied_attacker := CombatResolver.apply_strength_loss_with_edge(
					seg_attacker, segment.attacker_damage, edge_lengths
				)
				seg_attacker.record_damage_dealt(applied_defender)
				seg_defender.record_damage_dealt(applied_attacker)
			else:
				_accumulate_directed_shift(defender_shifts, seg_attacker, -push_normal, segment.attacker_shift_m)
				CombatResolver.apply_shift_morale_drain(seg_attacker, segment.attacker_shift_m, edge_lengths)
				var applied_attacker := CombatResolver.apply_strength_loss_with_edge(
					seg_attacker, segment.attacker_damage, edge_lengths
				)
				var applied_defender := CombatResolver.apply_strength_loss_with_edge(
					seg_defender, segment.defender_damage, edge_lengths
				)
				seg_defender.record_damage_dealt(applied_attacker)
				seg_attacker.record_damage_dealt(applied_defender)

			var gap_ratio: float = segment.get("gap_ratio", 0.0)
			bump_winners[seg_attacker] = segment.attacker_wins
			seg_attacker.set_bump_state(gap_ratio, segment.attacker_wins)
			seg_defender.set_bump_state(gap_ratio, not segment.attacker_wins)

			if seg_attacker.get_state() == Unit.State.ROUTING or seg_defender.get_state() == Unit.State.ROUTING:
				_on_first_rout()
				_try_start_victory_delay(
					seg_attacker if seg_attacker.get_state() == Unit.State.ROUTING else seg_defender
				)

		defender.set_active_contact_edges("")

	for unit in _units:
		if unit.get_state() == Unit.State.REMOVED:
			continue
		var labels: Array[String] = contact_edge_labels.get(unit, [] as Array[String])
		unit.set_active_contact_edges(_join_edge_labels(labels))

	for defender in defender_shifts.keys():
		var shift_info: Dictionary = defender_shifts[defender]
		var shift_vector: Vector2 = shift_info.vector
		var shift_m := shift_vector.length() / Constants.get_float("px_per_meter")
		if shift_m > 0.0:
			CombatResolver.apply_directed_position_shift(
				defender,
				shift_m,
				shift_vector.normalized(),
			)

	for unit in bump_winners.keys():
		if unit.get_state() == Unit.State.ROUTING:
			unit.clear_bump_state()


func _prune_broken_contacts() -> void:
	for unit in _units:
		if unit.get_state() == Unit.State.REMOVED or unit.get_state() == Unit.State.ROUTING:
			continue
		for partner in unit.get_contact_partners().duplicate():
			if partner == null or partner.get_state() == Unit.State.REMOVED:
				unit.remove_contact_partner(partner)
				continue
			if partner.get_state() == Unit.State.ROUTING:
				unit.remove_contact_partner(partner)
				continue
			if (
				CombatResolver.is_head_on_pair(unit, partner)
				and not EdgeContact.has_non_front_segment_contact(unit, partner)
			):
				if not CombatResolver.units_have_any_contact(unit, partner):
					unit.remove_contact_partner(partner)


func _accumulate_directed_shift(
	shift_map: Dictionary,
	unit: Unit,
	normal: Vector2,
	shift_m: float
) -> void:
	if shift_m <= 0.0:
		return
	var px_per_meter := Constants.get_float("px_per_meter")
	if not shift_map.has(unit):
		shift_map[unit] = {"vector": Vector2.ZERO, "edge_lengths": {}}
	var entry: Dictionary = shift_map[unit]
	entry.vector += normal.normalized() * shift_m * px_per_meter


func _join_edge_labels(labels: Array[String]) -> String:
	if labels.is_empty():
		return ""
	var unique: Array[String] = []
	for label in labels:
		if label not in unique:
			unique.append(label)
	return ";".join(unique)


func _track_rout_state() -> void:
	for unit in _units:
		if unit.get_state() == Unit.State.ROUTING:
			_on_first_rout()
			_try_start_victory_delay(unit)
			return


func _try_start_victory_delay(routing_unit: Unit) -> void:
	if _battle_phase != BattlePhase.ACTIVE:
		return
	if not _team_fully_defeated(routing_unit.team_id):
		return

	_victory_team = _opponent_team(routing_unit.team_id)
	_battle_phase = BattlePhase.VICTORY_PENDING
	_victory_delay_accum = 0.0
	for unit in _units:
		if unit.team_id == _victory_team:
			_winner = unit


func _team_fully_defeated(team_id: String) -> bool:
	var has_active := false
	for unit in _units:
		if unit.team_id != team_id:
			continue
		if unit.get_state() == Unit.State.REMOVED:
			continue
		has_active = true
		if not unit.is_defeated_for_victory():
			return false
	return has_active


func _opponent_team(team_id: String) -> String:
	return "blue" if team_id == "red" else "red"


func _update_victory_state(tick_interval: float) -> void:
	if not headless_mode or _battle_phase != BattlePhase.VICTORY_PENDING:
		return

	_victory_delay_accum += tick_interval
	if _victory_delay_accum >= Constants.get_float("victory_delay_s"):
		_battle_phase = BattlePhase.VICTORY_EPILOGUE
		_watch_epilogue = true


func _declare_victory() -> void:
	_battle_phase = BattlePhase.VICTORY_EPILOGUE
	if headless_mode:
		_watch_epilogue = true
		return
	_results_overlay.show_victory(_victory_team)


func _on_skip_epilogue() -> void:
	_finish_battle()


func _on_watch_epilogue() -> void:
	_watch_epilogue = true


func _check_epilogue_end() -> void:
	if _battle_phase == BattlePhase.ACTIVE:
		_check_legacy_battle_end()
		return
	if _battle_phase != BattlePhase.VICTORY_EPILOGUE or not _watch_epilogue:
		return
	if _any_routing_units():
		return
	_finish_battle()


func _any_routing_units() -> bool:
	for unit in _units:
		if unit.get_state() == Unit.State.ROUTING:
			return true
	return false


func _check_legacy_battle_end() -> void:
	var active_units: Array[Unit] = []
	for unit in _units:
		if unit.get_state() != Unit.State.REMOVED:
			active_units.append(unit)
	if active_units.size() > 1:
		return
	if active_units.size() == 1:
		_winner = active_units[0]
	_finish_battle()


func _finish_battle() -> void:
	if _battle_over:
		return

	_battle_phase = BattlePhase.FINISHED
	_battle_over = true
	if _winner == null:
		for unit in _units:
			if unit.get_state() != Unit.State.REMOVED and unit.get_state() != Unit.State.ROUTING:
				_winner = unit
				break

	_log_trace_row()
	_write_trace_file()
	_print_summary()
	_show_results_if_needed()


func _show_results_if_needed() -> void:
	if headless_mode:
		return

	var rows := _build_results_rows()
	var phases := _phase_durations_sec()
	var summary := "march %.1fs · combat %.1fs · flee %.1fs" % [
		phases.march_sec,
		phases.combat_sec,
		phases.flee_sec,
	]
	_results_overlay.show_results(rows, summary)


func _build_results_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for unit in _units:
		rows.append({
			"name": unit.get_display_name(),
			"side": unit.team_id,
			"state": unit.get_results_state_label(),
			"kills": unit.soldiers_defeated(),
			"top": false,
		})

	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.kills) > int(b.kills)
	)
	if not rows.is_empty():
		rows[0].top = true
	return rows


func _apply_contact_adhesion() -> void:
	var processed: Array[String] = []
	var prune_keys: Array[String] = []
	for unit in _units:
		if unit.get_state() == Unit.State.REMOVED or unit.get_state() == Unit.State.ROUTING:
			continue
		for partner in unit.get_contact_partners():
			if partner == null or partner.get_state() == Unit.State.REMOVED:
				continue
			if partner.get_state() == Unit.State.ROUTING:
				continue
			var pair_key := _pair_key(unit, partner)
			if pair_key in processed:
				continue
			processed.append(pair_key)
			if CombatResolver.apply_contact_adhesion_pair(unit, partner, _units):
				prune_keys.append(pair_key)
	for unit in _units:
		if unit.get_state() == Unit.State.REMOVED or unit.get_state() == Unit.State.ROUTING:
			continue
		for partner in unit.get_contact_partners().duplicate():
			if partner == null:
				continue
			var pair_key := _pair_key(unit, partner)
			if pair_key in prune_keys:
				unit.remove_contact_partner(partner)
	_assert_partner_classifier_contact_invariant()


func _assert_partner_classifier_contact_invariant() -> void:
	for unit in _units:
		if unit.get_state() == Unit.State.REMOVED or unit.get_state() == Unit.State.ROUTING:
			continue
		for partner in unit.get_contact_partners():
			if partner == null or partner.get_state() == Unit.State.REMOVED:
				continue
			if partner.get_state() == Unit.State.ROUTING:
				continue
			if partner.get_state() != Unit.State.ENGAGED and partner.get_state() != Unit.State.WAVERING:
				continue
			if (
				CombatResolver.is_head_on_pair(unit, partner)
				and not EdgeContact.has_non_front_segment_contact(unit, partner)
			):
				continue
			if CombatResolver.pair_has_classifier_contact(unit, partner):
				continue
			if not _adhesion_invariant_failed:
				push_error(
					"Adhesion invariant failed at tick %d: %s/%s partner-linked without classifier contact"
					% [_sim_tick_count, unit.unit_id, partner.unit_id]
				)
			_adhesion_invariant_failed = true


func _resolve_allied_overlaps() -> void:
	for pair in _grid_sorted_pair_candidates():
		var unit_a: Unit = pair[0]
		var unit_b: Unit = pair[1]
		if unit_a.team_id != unit_b.team_id:
			continue
		if not _unit_moved_this_tick(unit_a) and not _unit_moved_this_tick(unit_b):
			continue
		if not FormationGeometry.bounds_may_overlap(unit_a, unit_b):
			continue
		CombatResolver.separate_allied_overlap(unit_a, unit_b)


func _pair_key(unit_a: Unit, unit_b: Unit) -> String:
	if unit_a.unit_id < unit_b.unit_id:
		return unit_a.unit_id + ":" + unit_b.unit_id
	return unit_b.unit_id + ":" + unit_a.unit_id


func _run_overlap_assert_if_enabled() -> void:
	if not _overlap_assert_enabled():
		return
	_assert_no_overlaps()


func _assert_no_overlaps() -> void:
	# Non-routing pairs only (allied and enemy). Routing units are formless fugitives.
	for pair in _grid_sorted_pair_candidates():
		var unit_a: Unit = pair[0]
		var unit_b: Unit = pair[1]
		if not FormationGeometry.bounds_may_overlap(unit_a, unit_b):
			continue
		if not CombatResolver.units_overlap(unit_a, unit_b):
			continue
		_overlap_assertion_failed = true
		var relation := "allied" if unit_a.team_id == unit_b.team_id else "enemy"
		push_error(
			"Overlap detected at tick %d between %s and %s (%s)"
			% [_sim_tick_count, unit_a.unit_id, unit_b.unit_id, relation]
		)


func _write_trace_header() -> void:
	_trace_lines.append(
		"time_sec,unit_id,strength,cohesion,kills,pos_x,pos_y,state,contact_edges"
	)


func _log_trace_row() -> void:
	var time_sec := _sim_tick_count * CombatResolver.tick_interval()
	for unit in _units:
		_trace_lines.append(
			"%.1f,%s,%.4f,%.4f,%d,%.2f,%.2f,%s,%s"
			% [
				time_sec,
				unit.unit_id,
				unit.strength,
				unit.cohesion,
				unit.soldiers_defeated(),
				unit.position.x,
				unit.position.y,
				unit.get_state_name(),
				unit.get_active_contact_edges(),
			]
		)


func _log_trace_event(event_type: String, detail: String) -> void:
	var time_sec := _sim_tick_count * CombatResolver.tick_interval()
	_trace_lines.append("%.1f,EVENT,%s,%s" % [time_sec, event_type, detail])


func get_trace_events() -> PackedStringArray:
	var events := PackedStringArray()
	for line in _trace_lines:
		if ",EVENT," in line:
			events.append(line)
	return events


func _write_trace_file() -> void:
	var dir := DirAccess.open("res://tests")
	if dir == null:
		push_error("Scenario 01: cannot access tests directory")
		return

	if not dir.dir_exists("traces"):
		dir.make_dir("traces")

	var file_path := TRACE_DIR + "scenario_01_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("Scenario 01: cannot write trace file %s" % file_path)
		return

	for line in _trace_lines:
		file.store_line(line)

	print("[Scenario 01] Trace written: %s" % file_path)


func _phase_durations_sec() -> Dictionary:
	var tick_interval := CombatResolver.tick_interval()
	var contact_tick := _first_contact_tick if _first_contact_tick >= 0 else _sim_tick_count
	var rout_tick := _first_rout_tick if _first_rout_tick >= 0 else _sim_tick_count

	return {
		"march_sec": contact_tick * tick_interval,
		"combat_sec": maxf((rout_tick - contact_tick) * tick_interval, 0.0),
		"flee_sec": maxf((_sim_tick_count - rout_tick) * tick_interval, 0.0),
	}


func _print_summary() -> void:
	var phases := _phase_durations_sec()
	if _winner == null:
		print(
			"[Scenario 01] SUMMARY | winner=none | march=%.1fs | combat=%.1fs | flee=%.1fs"
			% [phases.march_sec, phases.combat_sec, phases.flee_sec]
		)
		return

	print(
		"[Scenario 01] SUMMARY | winner=%s | march=%.1fs | combat=%.1fs | flee=%.1fs | winner_strength=%.2f | winner_cohesion=%.2f"
		% [
			_winner.unit_id,
			phases.march_sec,
			phases.combat_sec,
			phases.flee_sec,
			_winner.strength,
			_winner.cohesion,
		]
	)


func get_trace_text() -> String:
	return "\n".join(_trace_lines) + "\n"


func get_winner_id() -> String:
	if _winner == null:
		return "none"
	return _winner.unit_id


func get_phase_durations_sec() -> Dictionary:
	return _phase_durations_sec()


func had_overlap_failure() -> bool:
	return _overlap_assertion_failed


func had_adhesion_invariant_failure() -> bool:
	return _adhesion_invariant_failed


func is_battle_over() -> bool:
	return _battle_over


func get_unit_kill_totals() -> Dictionary:
	var totals := {}
	for unit in _units:
		totals[unit.unit_id] = unit.soldiers_defeated()
	return totals
