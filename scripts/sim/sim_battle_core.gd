class_name SimBattleCore
extends RefCounted

const _TickProfiler := preload("res://scripts/tick_profiler.gd")
const SimUnitProxy := preload("res://scripts/sim/sim_unit_proxy.gd")
const SimRngBridge := preload("res://scripts/sim/sim_rng_bridge.gd")
const SimRng := preload("res://scripts/sim/sim_rng.gd")
const _Charge := preload("res://scripts/charge_combat.gd")

## Last charge-impact telemetry for scenario probes.
var last_charge_events: Array = []
## Pair keys "attacker>defender" already evaluated for charge (first contact only).
var _charge_pair_done: Dictionary = {}

enum BattlePhase { ACTIVE, VICTORY_PENDING, VICTORY_EPILOGUE, FINISHED }

var units: Array = []
var sim_tick_count: int = 0
var battle_over: bool = false
var battle_phase: BattlePhase = BattlePhase.ACTIVE
var victory_team: String = ""
var victory_delay_accum: float = 0.0
var watch_epilogue: bool = false
var trace_lines: PackedStringArray = PackedStringArray()
var winner_id: String = ""
var first_contact_tick: int = -1
var first_rout_tick: int = -1
var overlap_assertion_failed: bool = false
var adhesion_invariant_failed: bool = false
var grid_cell_size_px: float = 1.0
var grid_cells: Dictionary = {}
var current_tick_interval: float = 0.1
var tick_start_positions: Dictionary = {}
var headless_mode: bool = true
var fast_sim_mode: bool = false
var battle_seed: int = 0
var _rng: SimRng = SimRng.new()
var shock_floater_callback: Callable = Callable()
var volley_visual_callback: Callable = Callable()
## WO-021: optional coarse height grid (null = absent; flat grid = identity modifiers).
var height_field = null


func configure_rng(seed_value: int) -> void:
	_rng.set_seed(seed_value)
	battle_seed = seed_value

func advance_one_tick() -> void:
	if battle_over:
		return
	var tick_interval := 1.0 / Constants.get_float("tick_rate_per_sec")
	sim_tick_count += 1
	begin_sim_tick(tick_interval)
	advance_one_tick_fast(tick_interval)

func begin_sim_tick(tick_interval: float) -> void:
	current_tick_interval = tick_interval
	SimRngBridge.set_worker_rng(_rng)
	EdgeContact.begin_tick(sim_tick_count)
	capture_tick_start_positions()


func overlap_assert_enabled() -> bool:
	# Verification equipment: autotest and fast-mode only — not realtime gameplay.
	return headless_mode and fast_sim_mode


func capture_tick_start_positions() -> void:
	tick_start_positions.clear()
	for unit in units:
		if unit == null:
			continue
		tick_start_positions[unit.unit_id] = unit.position


func unit_moved_this_tick(unit: SimUnitProxy) -> bool:
	if unit == null or not tick_start_positions.has(unit.unit_id):
		return true
	var start: Vector2 = tick_start_positions[unit.unit_id]
	return start.distance_squared_to(unit.position) > 0.0001


func advance_one_tick_fast(tick_interval: float) -> void:
	rebuild_spatial_grid()
	refresh_slope_mods()
	update_movement(tick_interval)
	process_rout_events()
	ranged_volley_tick(tick_interval)
	resolve_allied_overlaps()
	try_passive_engagement()
	apply_contact_adhesion()
	run_overlap_assert_if_enabled()
	combat_tick()
	pursuit_tick()
	apply_contact_adhesion()
	track_rout_state()
	update_victory_state(tick_interval)
	var ticks_per_sec := int(Constants.get_float("tick_rate_per_sec"))
	if sim_tick_count % ticks_per_sec == 0:
		log_trace_row()
	check_epilogue_end()


func refresh_slope_mods() -> void:
	## Sample height/gradient once per unit per tick; identical in fast/threaded/realtime.
	for unit in units:
		if unit == null or unit.get_state() == Unit.State.REMOVED:
			continue
		if height_field == null:
			unit.slope_speed_mult = 1.0
			unit.slope_push_mod = 1.0
			continue
		unit.slope_speed_mult = height_field.speed_mult_at(unit.position, unit.facing)
		unit.slope_push_mod = height_field.push_mod_at(unit.position, unit.facing)


func slope_range_mult(shooter: SimUnitProxy, target: SimUnitProxy) -> float:
	if height_field == null or shooter == null or target == null:
		return 1.0
	return height_field.range_mult_toward(shooter.position, target.position)


func advance_one_tick_profiled(tick_interval: float) -> void:
	var t0 := _TickProfiler.begin_section("grid_overhead")
	rebuild_spatial_grid()
	refresh_slope_mods()
	_TickProfiler.end_section("grid_overhead", t0)

	t0 = _TickProfiler.begin_section("movement")
	update_movement(tick_interval)
	process_rout_events()
	ranged_volley_tick(tick_interval)
	_TickProfiler.end_section("movement", t0)

	t0 = _TickProfiler.begin_section("allied_separation")
	resolve_allied_overlaps()
	try_passive_engagement()
	_TickProfiler.end_section("allied_separation", t0)

	t0 = _TickProfiler.begin_section("adhesion")
	apply_contact_adhesion()
	_TickProfiler.end_section("adhesion", t0)

	t0 = _TickProfiler.begin_section("overlap_assert")
	run_overlap_assert_if_enabled()
	_TickProfiler.end_section("overlap_assert", t0)

	t0 = _TickProfiler.begin_section("combat")
	combat_tick()
	pursuit_tick()
	_TickProfiler.end_section("combat", t0)

	t0 = _TickProfiler.begin_section("adhesion_post")
	apply_contact_adhesion()
	_TickProfiler.end_section("adhesion_post", t0)

	t0 = _TickProfiler.begin_section("victory_epilogue")
	track_rout_state()
	update_victory_state(tick_interval)
	var ticks_per_sec := int(Constants.get_float("tick_rate_per_sec"))
	if sim_tick_count % ticks_per_sec == 0:
		var t_log := _TickProfiler.begin_section("trace_logging")
		log_trace_row()
		_TickProfiler.end_section("trace_logging", t_log)
	check_epilogue_end()
	_TickProfiler.end_section("victory_epilogue", t0)

	_TickProfiler.on_tick_complete()


func spatial_cell_size_m() -> float:
	return Constants.get_float("spatial_grid_cell_m")


func rebuild_spatial_grid() -> void:
	var px_per_meter := Constants.get_float("px_per_meter")
	grid_cell_size_px = maxf(spatial_cell_size_m() * px_per_meter, 1.0)
	grid_cells.clear()
	for unit in units:
		if unit == null or grid_unit_inactive(unit):
			continue
		var cell: Vector2i = grid_cell_key(unit.position)
		if not grid_cells.has(cell):
			grid_cells[cell] = []
		(grid_cells[cell] as Array).append(unit)


func grid_unit_inactive(unit: SimUnitProxy) -> bool:
	var state_name: String = unit.get_state_name()
	return state_name == "removed" or state_name == "routing"


func grid_cell_key(pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(pos.x / grid_cell_size_px)),
		int(floor(pos.y / grid_cell_size_px)),
	)


func grid_neighbor_units(unit: SimUnitProxy) -> Array:
	var origin: Vector2i = grid_cell_key(unit.position)
	var found: Array = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var key := Vector2i(origin.x + dx, origin.y + dy)
			if not grid_cells.has(key):
				continue
			for other in grid_cells[key]:
				if other != unit:
					found.append(other)
	return found


func grid_sorted_pair_candidates() -> Array:
	if grid_cells.is_empty():
		rebuild_spatial_grid()
	var seen: Dictionary = {}
	var pairs: Array = []
	for unit in units:
		if unit == null or grid_unit_inactive(unit):
			continue
		for other in grid_neighbor_units(unit):
			if other == null or grid_unit_inactive(other):
				continue
			var key := pair_key(unit, other)
			if seen.has(key):
				continue
			seen[key] = true
			pairs.append([unit, other])
	pairs.sort_custom(func(a, b) -> bool:
		return pair_key(a[0], a[1]) < pair_key(b[0], b[1])
	)
	return pairs


func spatial_neighbors_sorted(unit: SimUnitProxy) -> Array:
	if grid_cells.is_empty():
		rebuild_spatial_grid()
	var neighbors: Array = grid_neighbor_units(unit)
	neighbors.sort_custom(func(a: SimUnitProxy, b: SimUnitProxy) -> bool:
		return a.unit_id < b.unit_id
	)
	return neighbors


func max_closing_speed_m() -> float:
	var max_speed := 0.0
	for unit in units:
		if unit == null or unit.get_state() == Unit.State.REMOVED:
			continue
		max_speed = maxf(max_speed, _Charge.gait_top_speed_m_s(unit))
	return max_speed * 2.0


func max_unit_dimension_m() -> float:
	var max_dim := 0.0
	for unit in units:
		if unit == null or unit.get_state() == Unit.State.REMOVED:
			continue
		var dim: float = unit.effective_depth_m() + unit.effective_frontage_m()
		max_dim = maxf(max_dim, dim)
	return max_dim


func march_enemy_query_radius_px() -> float:
	## Contact-scale radius for collision clamping, plus charge_commit_range so
	## R17 gait commitment can see targets before the final 50m (WO-019/R18).
	var px_per_meter := Constants.get_float("px_per_meter")
	var contact_radius_m := (
		max_closing_speed_m() * current_tick_interval
		+ max_unit_dimension_m()
	)
	var commit_radius_m := (
		Constants.get_float("charge_commit_range_m")
		+ max_unit_dimension_m()
	)
	return maxf(contact_radius_m, commit_radius_m) * px_per_meter


func grid_units_within_radius_sorted(unit: SimUnitProxy, radius_px: float) -> Array:
	if grid_cells.is_empty():
		rebuild_spatial_grid()
	var origin: Vector2i = grid_cell_key(unit.position)
	var ring := maxi(int(ceil(radius_px / grid_cell_size_px)), 1)
	var found: Array = []
	var seen: Dictionary = {}
	for dx in range(-ring, ring + 1):
		for dy in range(-ring, ring + 1):
			var key := Vector2i(origin.x + dx, origin.y + dy)
			if not grid_cells.has(key):
				continue
			for other in grid_cells[key]:
				if other == unit or other == null or seen.has(other.unit_id):
					continue
				if unit.position.distance_to(other.position) > radius_px:
					continue
				seen[other.unit_id] = true
				found.append(other)
	found.sort_custom(func(a: SimUnitProxy, b: SimUnitProxy) -> bool:
		return a.unit_id < b.unit_id
	)
	return found


func uses_march_grid_enemies(unit: SimUnitProxy) -> bool:
	if unit.get_state() == Unit.State.MARCHING:
		return true
	return (
		unit.get_state() == Unit.State.HOLD
		and unit.current_order == Unit.Order.MARCH_TO
		and not unit.is_rallied_hold()
	)


func _clear_charge_latch_if_requested(unit: SimUnitProxy) -> void:
	if not unit._pending_charge_latch_clear:
		return
	for pid in unit._pending_latch_partner_ids:
		var key := "%s>%s" % [unit.unit_id, pid]
		_charge_pair_done.erase(key)
	unit._pending_charge_latch_clear = false
	unit._pending_latch_partner_ids.clear()


func clear_charge_pair_latch(attacker_id: String, defender_id: String) -> void:
	_charge_pair_done.erase("%s>%s" % [attacker_id, defender_id])


func enemies_for(unit: SimUnitProxy) -> Array:
	var enemies: Array = []
	var candidates: Array = units
	if uses_march_grid_enemies(unit):
		candidates = grid_units_within_radius_sorted(unit, march_enemy_query_radius_px())
	elif unit.get_state() in [Unit.State.ENGAGED, Unit.State.WAVERING, Unit.State.ROUTING, Unit.State.RALLYING]:
		candidates = spatial_neighbors_sorted(unit)
	for other in candidates:
		if other == unit or other.get_state() == Unit.State.REMOVED:
			continue
		if other.team_id == unit.team_id:
			continue
		enemies.append(other)
	return enemies


func update_movement(delta: float) -> void:
	for unit in units:
		if unit.get_state() == Unit.State.REMOVED:
			continue
		unit.tick_charge_amp(delta)
		unit.update_brace(delta, enemies_for(unit))
		unit.tick_disengage(delta)
		_clear_charge_latch_if_requested(unit)
		unit.tick_wheel(delta)
		# Decelerate only when deliberately holding / bracing — never while ENGAGED.
		# Mid-fight partner flicker returns units to MARCHING briefly; decelerating in
		# combat made those gaps crawl and drifted S1/S2/S8 grind timing.
		if (
			unit.get_state() == Unit.State.HOLD
			and unit.current_order == Unit.Order.HOLD
		):
			var decel: float = _Charge.decel_m_s2(unit)
			unit.current_speed_m_s = maxf(0.0, unit.current_speed_m_s - decel * delta)
		if unit.get_state() == Unit.State.MARCHING:
			unit.update_marching(delta, enemies_for(unit))
			try_begin_engagement(unit)
		elif unit.get_state() == Unit.State.ROUTING or unit.get_state() == Unit.State.RALLYING:
			unit.update_routing(delta, enemies_for(unit))
		elif (
			unit.get_state() == Unit.State.HOLD
			and unit.current_order == Unit.Order.MARCH_TO
			and not unit.is_rallied_hold()
		):
			unit.update_marching(delta, enemies_for(unit))
			try_begin_engagement(unit)


func try_begin_engagement(unit: SimUnitProxy) -> void:
	if unit.get_state() == Unit.State.ROUTING or unit.get_state() == Unit.State.RALLYING:
		return
	if unit.profile.get("skip_auto_engage", false):
		return
	if unit.auto_engage_locked or unit.disengaging:
		return

	for other in spatial_neighbors_sorted(unit):
		if other.get_state() == Unit.State.REMOVED:
			continue
		if other.get_state() == Unit.State.ROUTING or other.get_state() == Unit.State.RALLYING:
			continue
		if other.team_id == unit.team_id:
			continue
		if other.profile.get("skip_auto_engage", false):
			continue
		if other.auto_engage_locked or other.disengaging:
			continue
		if not CombatResolver.units_have_any_contact(unit, other):
			continue

		var already: bool = unit.has_contact_with(other)
		if not already:
			apply_charge_impacts(unit, other)
		unit.add_contact_partner(other)
		other.add_contact_partner(unit)
		if (
			CombatResolver.is_head_on_pair(unit, other)
			and not EdgeContact.has_non_front_segment_contact(unit, other)
		):
			CombatResolver.snap_pair_to_contact(unit, other)
		on_first_contact()


func try_passive_engagement() -> void:
	for unit in units:
		if unit.get_state() != Unit.State.HOLD or not unit.is_rallied_hold():
			continue
		for other in spatial_neighbors_sorted(unit):
			if other.get_state() == Unit.State.REMOVED:
				continue
			if other.team_id == unit.team_id:
				continue
			if other.get_state() == Unit.State.ROUTING or other.get_state() == Unit.State.RALLYING:
				continue
			if not CombatResolver.units_have_any_contact(unit, other):
				continue
			var already: bool = unit.has_contact_with(other)
			if not already:
				apply_charge_impacts(other, unit)
				apply_charge_impacts(unit, other)
			unit.add_contact_partner(other)
			other.add_contact_partner(unit)
			if (
				CombatResolver.is_head_on_pair(unit, other)
				and not EdgeContact.has_non_front_segment_contact(unit, other)
			):
				CombatResolver.snap_pair_to_contact(unit, other)
			on_first_contact()


func apply_charge_impacts(attacker: SimUnitProxy, defender: SimUnitProxy) -> void:
	var pair_key := "%s>%s" % [attacker.unit_id, defender.unit_id]
	if _charge_pair_done.has(pair_key):
		return
	_charge_pair_done[pair_key] = true
	# One classify for contact-normal closing + edge morale weight.
	var contact: Dictionary = EdgeContact.classify_contact(attacker, defender)
	var edges: Dictionary = contact.get("edge_lengths_m", {})
	var closing := _Charge.closing_speed_along_contact(attacker, defender, edges)
	# R18: relative charge threshold (own Speed × charge_min_speed_pct), sim m/s.
	var min_speed := _Charge.charge_min_closing_m_s(attacker)
	if closing < min_speed:
		last_charge_events.append({
			"attacker": attacker.unit_id,
			"defender": defender.unit_id,
			"closing_speed": closing,
			"impact": 0.0,
			"charged": false,
			"braced": defender.is_braced(),
		})
		return
	var impact := _Charge.calc_impact(attacker, defender, closing)
	var edge_info: Dictionary = _Charge.charge_edge_morale_mult(attacker, defender, edges)
	var edge_mult: float = float(edge_info.get("mult", 1.0))
	var edge_name: String = str(edge_info.get("edge", "front"))
	var brace: Dictionary = _Charge.resolve_brace_tier(attacker, defender, edge_name)
	var brace_tier: int = int(brace.get("tier", 3))
	var brace_mult: float = float(brace.get("mult", 1.0))
	var brace_name: String = str(brace.get("name", "unaware"))
	defender.brace_tier_last = brace_tier
	var base_shock := _Charge.base_charge_shock(impact)
	var shock := base_shock * edge_mult * brace_mult
	var reflected := 0.0
	var braced_set := brace_tier == 2
	# Contact ends the charge gait commitment.
	attacker.charge_committed = false
	attacker._charge_commit_target_id = ""
	if braced_set:
		reflected = impact * Constants.get_float("brace_reflect_pct")
		# Impact is already in strength/cohesion-adjacent units; reflect without k_melee.
		CombatResolver.apply_strength_loss(attacker, reflected)
		var reflected_shock := reflected * Constants.get_float("charge_cohesion_coeff") * 0.5
		attacker.apply_cohesion_drain(reflected_shock)
		spawn_shock_floater(attacker, reflected_shock)
		log_trace_event(
			"brace_reflect",
			"attacker=%s,defender=%s,impact=%.3f,closing=%.3f,reflected=%.3f,edge=%s,brace_tier=%d"
			% [attacker.unit_id, defender.unit_id, impact, closing, reflected, edge_name, brace_tier]
		)
	else:
		defender.apply_cohesion_drain(shock)
		spawn_shock_floater(defender, shock)
		attacker.begin_charge_amp()
		log_trace_event(
			"charge_impact",
			"attacker=%s,defender=%s,impact=%.3f,closing=%.3f,base_shock=%.3f,edge=%s,edge_mult=%.3f,brace_tier=%d,brace=%s,brace_mult=%.3f,shock=%.3f,mass=%.3f,cohesion_after=%.2f,speed=%.3f"
			% [
				attacker.unit_id,
				defender.unit_id,
				impact,
				closing,
				base_shock,
				edge_name,
				edge_mult,
				brace_tier,
				brace_name,
				brace_mult,
				shock,
				_Charge.mass_of(attacker),
				defender.cohesion,
				float(attacker.current_speed_m_s),
			]
		)
	last_charge_events.append({
		"attacker": attacker.unit_id,
		"defender": defender.unit_id,
		"closing_speed": closing,
		"impact_closing_speed": closing,
		"unit_speed": float(attacker.current_speed_m_s),
		"impact": impact,
		"base_shock": base_shock,
		"edge": edge_name,
		"edge_mult": edge_mult,
		"brace_tier": brace_tier,
		"brace": brace_name,
		"brace_mult": brace_mult,
		"shock": 0.0 if braced_set else shock,
		"defender_cohesion_after": defender.cohesion,
		"charged": true,
		"braced": braced_set,
		"reflected": reflected,
	})


func process_rout_events() -> void:
	for unit in units:
		if unit.get_state() == Unit.State.REMOVED:
			continue
		if not unit.consume_pending_rout_event():
			continue
		apply_neighbor_rout_shock(unit)


func apply_neighbor_rout_shock(routing_unit: SimUnitProxy) -> void:
	var radius_m := Constants.get_float("neighbor_rout_shock_radius_m")
	var shock := Constants.get_float("neighbor_rout_shock")
	for ally in units:
		if ally == routing_unit or ally.team_id != routing_unit.team_id:
			continue
		if ally.get_state() == Unit.State.REMOVED:
			continue
		if CombatResolver.center_distance_m(ally, routing_unit) > radius_m:
			continue
		ally.apply_cohesion_drain(shock)
		spawn_shock_floater(ally, shock)
		log_trace_event(
			"neighbor_rout_shock",
			"victim=%s,source=%s,drain=%.1f" % [ally.unit_id, routing_unit.unit_id, shock]
		)


func spawn_shock_floater(unit: SimUnitProxy, amount: float) -> void:
	if shock_floater_callback.is_valid():
		shock_floater_callback.call(unit, amount)


func spawn_volley_visual(shooter: SimUnitProxy, target: SimUnitProxy) -> void:
	if volley_visual_callback.is_valid():
		volley_visual_callback.call(shooter, target)


func ranged_volley_tick(delta: float) -> void:
	var shooters: Array = []
	for unit in units:
		if unit == null or unit.get_state() == Unit.State.REMOVED:
			continue
		if not unit.is_ranged_combatant():
			continue
		shooters.append(unit)
	shooters.sort_custom(func(a: SimUnitProxy, b: SimUnitProxy) -> bool:
		return a.unit_id < b.unit_id
	)

	for shooter in shooters:
		shooter.tick_reload(delta)
		check_dead_zone_panic(shooter)
		try_fire_volley(shooter)


func check_dead_zone_panic(shooter: SimUnitProxy) -> void:
	if shooter.dead_zone_panic_done():
		return
	if shooter.get_state() in [Unit.State.ENGAGED, Unit.State.WAVERING]:
		return
	var min_range_m := float(shooter.profile.get("min_range_m", 0.0))
	if min_range_m <= 0.0:
		return
	for enemy in units:
		if enemy == shooter or enemy.get_state() == Unit.State.REMOVED:
			continue
		if enemy.team_id == shooter.team_id:
			continue
		if CombatResolver.center_distance_m(shooter, enemy) >= min_range_m:
			continue
		var shock := Constants.get_float("dead_zone_panic_shock")
		shooter.apply_cohesion_drain(shock, "front")
		spawn_shock_floater(shooter, shock)
		shooter.mark_dead_zone_panic_done()
		log_trace_event(
			"dead_zone_panic",
			"unit=%s,enemy=%s,drain=%.1f" % [shooter.unit_id, enemy.unit_id, shock]
		)
		return


func try_fire_volley(shooter: SimUnitProxy) -> void:
	if shooter.ammo_volleys_remaining() <= 0:
		return
	if not shooter.reload_ready():
		return
	if unit_moved_this_tick(shooter):
		return
	if shooter.get_state() in [
		Unit.State.MARCHING, Unit.State.ROUTING, Unit.State.RALLYING, Unit.State.REMOVED,
	]:
		return

	var target: SimUnitProxy = pick_volley_target(shooter)
	if target == null:
		return

	var distance_m := CombatResolver.center_distance_m(shooter, target)
	var damage := CombatResolver.calc_ranged_volley_damage(
		shooter, target, distance_m, slope_range_mult(shooter, target)
	)
	var applied := CombatResolver.apply_strength_loss(target, damage)
	shooter.record_damage_dealt(applied)
	shooter.consume_ammo_volley()
	shooter.reset_reload_timer()
	spawn_volley_visual(shooter, target)
	if target.get_state() == Unit.State.ROUTING:
		on_first_rout()
		try_start_victory_delay(target)

	log_trace_event(
		"volley",
		"shooter=%s,target=%s,dist_m=%.1f,damage=%.4f,ammo=%d"
		% [shooter.unit_id, target.unit_id, distance_m, applied, shooter.ammo_volleys_remaining()]
	)
	if shooter.ammo_volleys_remaining() <= 0:
		log_trace_event("ammo_empty", "unit=%s" % shooter.unit_id)

	apply_volley_friendly_fire(shooter, target, damage)


func pick_volley_target(shooter: SimUnitProxy) -> SimUnitProxy:
	var best: SimUnitProxy = null
	var best_dist := INF
	for enemy in units:
		if enemy == shooter or enemy.get_state() == Unit.State.REMOVED:
			continue
		if enemy.team_id == shooter.team_id:
			continue
		if not volley_target_permitted(shooter, enemy):
			continue
		var dist := CombatResolver.center_distance_m(shooter, enemy)
		if best == null:
			best = enemy
			best_dist = dist
			continue
		if dist < best_dist - 0.0001:
			best = enemy
			best_dist = dist
		elif is_equal_approx(dist, best_dist) and enemy.unit_id < best.unit_id:
			best = enemy
	return best


func volley_target_permitted(shooter: SimUnitProxy, target: SimUnitProxy) -> bool:
	var max_range_m := float(shooter.profile.get("range", 0.0)) * slope_range_mult(shooter, target)
	var min_range_m := float(shooter.profile.get("min_range_m", 0.0))
	var dist_m := CombatResolver.center_distance_m(shooter, target)
	if dist_m < min_range_m or dist_m > max_range_m:
		return false
	var doctrine := str(shooter.profile.get("fire_doctrine", "FIRE_ON_SIGHT")).to_upper()
	match doctrine:
		"FIRE_AT_70":
			if dist_m > max_range_m * Constants.get_float("fire_at_range_pct"):
				return false
		"FIRE_ON_ENGAGED":
			if target.get_state() not in [Unit.State.ENGAGED, Unit.State.WAVERING]:
				return false
			if not enemy_engaged_with_friendly(shooter, target):
				return false
	return true


func enemy_engaged_with_friendly(shooter: SimUnitProxy, enemy: SimUnitProxy) -> bool:
	for partner in enemy.get_contact_partners():
		if partner == null or partner.get_state() == Unit.State.REMOVED:
			continue
		if partner.team_id == shooter.team_id:
			return true
	return false


func apply_volley_friendly_fire(
	shooter: SimUnitProxy,
	target: SimUnitProxy,
	rolled_damage: float
) -> void:
	if target.get_state() not in [Unit.State.ENGAGED, Unit.State.WAVERING]:
		return
	for partner in target.get_contact_partners():
		if partner == null or partner.get_state() == Unit.State.REMOVED:
			continue
		if partner.team_id != shooter.team_id:
			continue
		var ff_damage := CombatResolver.calc_friendly_fire_damage(shooter, partner, rolled_damage)
		if ff_damage <= 0.0:
			continue
		var applied := CombatResolver.apply_strength_loss(partner, ff_damage)
		shooter.record_damage_dealt(applied)
		log_trace_event(
			"friendly_fire",
			"shooter=%s,victim=%s,target=%s,damage=%.4f"
			% [shooter.unit_id, partner.unit_id, target.unit_id, applied]
		)
		if partner.get_state() == Unit.State.ROUTING:
			on_first_rout()
			try_start_victory_delay(partner)



func pursuit_tick() -> void:
	for routing_unit in units:
		if routing_unit.get_state() != Unit.State.ROUTING:
			continue
		for enemy in enemies_for(routing_unit):
			if not CombatResolver.can_apply_pursuit(enemy):
				continue
			if not CombatResolver.is_within_pursuit_contact(enemy, routing_unit):
				continue
			var damage := CombatResolver.calc_pursuit_damage(enemy, routing_unit)
			var applied := CombatResolver.apply_strength_loss(routing_unit, damage)
			routing_unit.reset_rally_timer()
			enemy.record_damage_dealt(applied)
			log_trace_event(
				"pursuit_damage",
				"victim=%s,pursuer=%s,damage=%.4f" % [routing_unit.unit_id, enemy.unit_id, applied]
			)
			if routing_unit.strength <= 0.0:
				routing_unit.mark_removed()


func on_first_contact() -> void:
	if first_contact_tick >= 0:
		return
	first_contact_tick = sim_tick_count


func on_first_rout() -> void:
	if first_rout_tick >= 0:
		return
	first_rout_tick = sim_tick_count


func combat_tick() -> void:
	prune_broken_contacts()
	_apply_disengage_free_hits()

	var processed_head_on: Array[String] = []
	var processed_segments: Array[String] = []
	var defender_shifts: Dictionary = {}
	var bump_winners: Dictionary = {}
	var contact_edge_labels: Dictionary = {}  # Unit -> Array[String]

	for unit in units:
		if unit.get_state() == Unit.State.REMOVED:
			continue
		if unit.get_state() != Unit.State.ENGAGED and unit.get_state() != Unit.State.WAVERING:
			continue
		# Disengagers are handled exclusively by _apply_disengage_free_hits.
		if unit.disengaging:
			continue

		for partner in unit.get_contact_partners():
			if partner == null or partner.get_state() == Unit.State.REMOVED:
				continue
			if partner.get_state() == Unit.State.ROUTING:
				continue
			if partner.disengaging:
				continue

			if not CombatResolver.is_head_on_pair(unit, partner):
				continue
			if not CombatResolver.units_have_front_contact(unit, partner):
				continue
			if EdgeContact.has_non_front_segment_contact(unit, partner):
				continue

			var pk := pair_key(unit, partner)
			if pk in processed_head_on:
				continue
			processed_head_on.append(pk)

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
				on_first_rout()
				try_start_victory_delay(unit if unit.get_state() == Unit.State.ROUTING else partner)

	for defender in units:
		if defender.get_state() == Unit.State.REMOVED:
			continue
		if defender.get_state() != Unit.State.ENGAGED and defender.get_state() != Unit.State.WAVERING:
			continue
		if defender.disengaging:
			continue

		for attacker in defender.get_contact_partners():
			if attacker == null or attacker.get_state() == Unit.State.REMOVED:
				continue
			if attacker.get_state() == Unit.State.ROUTING:
				continue
			if attacker.disengaging:
				continue
			if CombatResolver.is_head_on_pair(attacker, defender):
				if not EdgeContact.has_non_front_segment_contact(attacker, defender):
					continue

			var pk := pair_key(attacker, defender)
			if pk in processed_segments:
				continue
			processed_segments.append(pk)

			var orientation := EdgeContact.pick_segment_orientation(attacker, defender)
			var seg_attacker: SimUnitProxy = orientation.get("attacker")
			var seg_defender: SimUnitProxy = orientation.get("defender")
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
				accumulate_directed_shift(defender_shifts, seg_defender, push_normal, segment.defender_shift_m)
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
				accumulate_directed_shift(defender_shifts, seg_attacker, -push_normal, segment.attacker_shift_m)
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
				on_first_rout()
				try_start_victory_delay(
					seg_attacker if seg_attacker.get_state() == Unit.State.ROUTING else seg_defender
				)

		defender.set_active_contact_edges("")

	for unit in units:
		if unit.get_state() == Unit.State.REMOVED:
			continue
		var labels: Array[String] = contact_edge_labels.get(unit, [] as Array[String])
		unit.set_active_contact_edges(join_edge_labels(labels))

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


func _apply_disengage_free_hits() -> void:
	## Fighting withdrawal (WO-020b): remain in contact for the full timer; no
	## translation, no counter-attack. Free hits use melee against a turning-
	## back target (push-loser factor) × disengage_damage_mult, plus ordered
	## retreat cohesion drain every tick per partner.
	var processed: Array[String] = []
	var dt: float = current_tick_interval
	var dmg_mult: float = Constants.get_float("disengage_damage_mult")
	for unit in units:
		if not unit.disengaging:
			continue
		if unit.get_state() == Unit.State.REMOVED or unit.get_state() == Unit.State.ROUTING:
			continue
		# Stay put while the timer runs — no marching / gravity translation.
		unit.current_speed_m_s = 0.0
		for partner in unit.get_contact_partners():
			if partner == null or partner.get_state() == Unit.State.REMOVED:
				continue
			if partner.get_state() == Unit.State.ROUTING:
				continue
			var pk := pair_key(unit, partner)
			if pk in processed:
				continue
			processed.append(pk)
			if CombatResolver.is_head_on_pair(unit, partner):
				CombatResolver.snap_pair_to_contact(unit, partner)
			# Turning your back: always resolve as push-loser for free-hit lethality.
			# Do NOT use bidirectional resolve_engagement (push-winner asymmetry
			# made Agility-blind exposure under WO-020).
			var incoming: float = (
				CombatResolver.calc_melee_strength_loss(partner, unit, 1.0, true) * dmg_mult
			)
			var applied := CombatResolver.apply_strength_loss(unit, incoming)
			partner.record_damage_dealt(applied)
			var coh_drain: float = Constants.get_float("ordered_retreat_drain_per_sec") * dt
			unit.apply_cohesion_drain(coh_drain)
			if unit.get_state() == Unit.State.ROUTING:
				on_first_rout()
				try_start_victory_delay(unit)


func prune_broken_contacts() -> void:
	for unit in units:
		if unit.get_state() == Unit.State.REMOVED or unit.get_state() == Unit.State.ROUTING:
			continue
		# Fighting withdrawal / wheel-under-contact: keep partners locked.
		if unit.disengaging or unit.wheeling:
			continue
		for partner in unit.get_contact_partners().duplicate():
			if partner == null or partner.get_state() == Unit.State.REMOVED:
				unit.remove_contact_partner(partner)
				continue
			if partner.get_state() == Unit.State.ROUTING:
				unit.remove_contact_partner(partner)
				continue
			if partner.disengaging:
				continue
			if (
				CombatResolver.is_head_on_pair(unit, partner)
				and not EdgeContact.has_non_front_segment_contact(unit, partner)
			):
				if not CombatResolver.units_have_any_contact(unit, partner):
					unit.remove_contact_partner(partner)


func accumulate_directed_shift(
	shift_map: Dictionary,
	unit: SimUnitProxy,
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


func join_edge_labels(labels: Array[String]) -> String:
	if labels.is_empty():
		return ""
	var unique: Array[String] = []
	for label in labels:
		if label not in unique:
			unique.append(label)
	return ";".join(unique)


func track_rout_state() -> void:
	for unit in units:
		if unit.get_state() == Unit.State.ROUTING:
			on_first_rout()
			try_start_victory_delay(unit)
			return


func try_start_victory_delay(routing_unit: SimUnitProxy) -> void:
	if battle_phase != BattlePhase.ACTIVE:
		return
	if not team_fully_defeated(routing_unit.team_id):
		return

	victory_team = opponent_team(routing_unit.team_id)
	battle_phase = BattlePhase.VICTORY_PENDING
	victory_delay_accum = 0.0
	for unit in units:
		if unit.team_id == victory_team:
			winner_id = unit.unit_id


func team_fully_defeated(team_id: String) -> bool:
	var has_active := false
	for unit in units:
		if unit.team_id != team_id:
			continue
		if unit.get_state() == Unit.State.REMOVED:
			continue
		has_active = true
		if not unit.is_defeated_for_victory():
			return false
	return has_active


func opponent_team(team_id: String) -> String:
	return "blue" if team_id == "red" else "red"


func update_victory_state(tick_interval: float) -> void:
	if not headless_mode or battle_phase != BattlePhase.VICTORY_PENDING:
		return

	victory_delay_accum += tick_interval
	if victory_delay_accum >= Constants.get_float("victory_delay_s"):
		battle_phase = BattlePhase.VICTORY_EPILOGUE
		watch_epilogue = true


func declare_victory() -> void:
	battle_phase = BattlePhase.VICTORY_EPILOGUE
	watch_epilogue = true




func check_epilogue_end() -> void:
	if battle_phase == BattlePhase.ACTIVE:
		check_legacy_battle_end()
		return
	if battle_phase != BattlePhase.VICTORY_EPILOGUE or not watch_epilogue:
		return
	if any_routing_units():
		return
	finish_battle()


func any_routing_units() -> bool:
	for unit in units:
		if unit.get_state() == Unit.State.ROUTING:
			return true
	return false


func check_legacy_battle_end() -> void:
	var active_units: Array = []
	for unit in units:
		if unit.get_state() != Unit.State.REMOVED:
			active_units.append(unit)
	if active_units.size() > 1:
		return
	if active_units.size() == 1:
		winner_id = active_units[0].unit_id
	finish_battle()



func finish_battle() -> void:
	if battle_over:
		return
	battle_phase = BattlePhase.FINISHED
	battle_over = true
	if winner_id.is_empty():
		for unit in units:
			if unit.get_state() != Unit.State.REMOVED and unit.get_state() != Unit.State.ROUTING:
				winner_id = unit.unit_id
				break
	log_trace_row()

func log_trace_row() -> void:
	var time_sec := sim_tick_count * (1.0 / Constants.get_float("tick_rate_per_sec"))
	for unit in units:
		var ammo_field := ""
		if unit.is_ranged_combatant():
			ammo_field = ",ammo=%d" % unit.ammo_volleys_remaining()
		trace_lines.append(
			"%.1f,%s,%.4f,%.4f,%d,%.2f,%.2f,%s,%s%s"
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
				ammo_field,
			]
		)

func log_trace_event(event_type: String, detail: String) -> void:
	var time_sec := sim_tick_count * (1.0 / Constants.get_float("tick_rate_per_sec"))
	trace_lines.append("%.1f,EVENT,%s,%s" % [time_sec, event_type, detail])

func write_trace_header() -> void:
	trace_lines.append("time_sec,unit_id,strength,cohesion,kills,pos_x,pos_y,state,contact_edges")




func apply_contact_adhesion() -> void:
	var processed: Array[String] = []
	var prune_keys: Array[String] = []
	for unit in units:
		if unit.get_state() == Unit.State.REMOVED or unit.get_state() == Unit.State.ROUTING:
			continue
		for partner in unit.get_contact_partners():
			if partner == null or partner.get_state() == Unit.State.REMOVED:
				continue
			if partner.get_state() == Unit.State.ROUTING:
				continue
			var pk := pair_key(unit, partner)
			if pk in processed:
				continue
			processed.append(pk)
			# Disengaging pairs: keep trying to hold classifier contact for free hits,
			# but never prune the partnership on failure.
			var should_prune: bool = CombatResolver.apply_contact_adhesion_pair(unit, partner, units)
			if should_prune and not unit.disengaging and not partner.disengaging:
				prune_keys.append(pk)
	for unit in units:
		if unit.get_state() == Unit.State.REMOVED or unit.get_state() == Unit.State.ROUTING:
			continue
		if unit.disengaging:
			continue
		for partner in unit.get_contact_partners().duplicate():
			if partner == null:
				continue
			if partner.disengaging:
				continue
			var pk2 := pair_key(unit, partner)
			if pk2 in prune_keys:
				unit.remove_contact_partner(partner)
	assert_partner_classifier_contact_invariant()


func assert_partner_classifier_contact_invariant() -> void:
	for unit in units:
		if unit.get_state() == Unit.State.REMOVED or unit.get_state() == Unit.State.ROUTING:
			continue
		if unit.disengaging:
			continue
		for partner in unit.get_contact_partners():
			if partner == null or partner.get_state() == Unit.State.REMOVED:
				continue
			if partner.get_state() == Unit.State.ROUTING:
				continue
			if partner.disengaging:
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
			if not adhesion_invariant_failed:
				push_error(
					"Adhesion invariant failed at tick %d: %s/%s partner-linked without classifier contact"
					% [sim_tick_count, unit.unit_id, partner.unit_id]
				)
			adhesion_invariant_failed = true


func resolve_allied_overlaps() -> void:
	for pair in grid_sorted_pair_candidates():
		var unit_a: SimUnitProxy = pair[0]
		var unit_b: SimUnitProxy = pair[1]
		if unit_a.team_id != unit_b.team_id:
			continue
		if not unit_moved_this_tick(unit_a) and not unit_moved_this_tick(unit_b):
			continue
		if not FormationGeometry.bounds_may_overlap(unit_a, unit_b):
			continue
		CombatResolver.separate_allied_overlap(unit_a, unit_b)


func pair_key(unit_a: SimUnitProxy, unit_b: SimUnitProxy) -> String:
	if unit_a.unit_id < unit_b.unit_id:
		return unit_a.unit_id + ":" + unit_b.unit_id
	return unit_b.unit_id + ":" + unit_a.unit_id


func run_overlap_assert_if_enabled() -> void:
	if not overlap_assert_enabled():
		return
	assert_no_overlaps()


func assert_no_overlaps() -> void:
	# Non-routing pairs only (allied and enemy). Routing units are formless fugitives.
	for pair in grid_sorted_pair_candidates():
		var unit_a: SimUnitProxy = pair[0]
		var unit_b: SimUnitProxy = pair[1]
		if not FormationGeometry.bounds_may_overlap(unit_a, unit_b):
			continue
		if not CombatResolver.units_overlap(unit_a, unit_b):
			continue
		overlap_assertion_failed = true
		var relation := "allied" if unit_a.team_id == unit_b.team_id else "enemy"
		push_error(
			"Overlap detected at tick %d between %s and %s (%s)"
			% [sim_tick_count, unit_a.unit_id, unit_b.unit_id, relation]
		)



func get_trace_text() -> String:
	return "\n".join(trace_lines) + "\n"

func capture_from_units(unit_nodes: Array) -> void:
	var existing: Dictionary = {}
	for proxy in units:
		existing[proxy.unit_id] = proxy
	var next: Array = []
	for node in unit_nodes:
		if node == null:
			continue
		if existing.has(node.unit_id):
			var proxy: SimUnitProxy = existing[node.unit_id]
			proxy.refresh_from_unit(node)
			next.append(proxy)
		else:
			next.append(SimUnitProxy.from_unit(node))
	units = next
	resolve_partner_links()

func resolve_partner_links() -> void:
	var by_id: Dictionary = {}
	for u in units:
		by_id[u.unit_id] = u
	for u in units:
		u.resolve_partners(by_id)

func apply_render_snapshot_to_units(unit_nodes: Array) -> void:
	var by_id: Dictionary = {}
	for node in unit_nodes:
		by_id[node.unit_id] = node
	for proxy in units:
		if by_id.has(proxy.unit_id):
			proxy.apply_to_unit(by_id[proxy.unit_id], unit_nodes)


func build_render_snapshot() -> Array:
	var snap: Array = []
	for proxy in units:
		snap.append(proxy.duplicate_render_state())
	return snap


func apply_render_snapshot(snap: Array, unit_nodes: Array) -> void:
	var by_id: Dictionary = {}
	for node in unit_nodes:
		by_id[node.unit_id] = node
	for proxy in snap:
		if by_id.has(proxy.unit_id):
			proxy.apply_to_unit(by_id[proxy.unit_id], unit_nodes)

func is_battle_over() -> bool:
	return battle_over
