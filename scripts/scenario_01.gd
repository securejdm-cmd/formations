class_name Scenario01
extends Node2D

const UNIT_SCENE := preload("res://scenes/unit.tscn")
const TRACE_DIR := "res://tests/traces/"

enum BattlePhase { ACTIVE, VICTORY_PENDING, VICTORY_EPILOGUE, FINISHED }

@export var auto_run: bool = true
@export var headless_mode: bool = false

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

@onready var _camera: Camera2D = $Camera2D
@onready var _ground: ColorRect = $Ground
@onready var _debug_overlay: CanvasLayer = $DebugOverlay
@onready var _stat_card = $StatCardLayer/UnitStatCard
@onready var _results_overlay = $ResultsOverlay


func set_battle_seed(seed_value: int) -> void:
	_seed_override = seed_value


func _ready() -> void:
	_setup_ground()
	_battle_seed = _seed_override if _seed_override >= 0 else Constants.get_int("scenario_01_battle_seed")
	RNG.set_seed(_battle_seed)
	print("[Scenario 01] Battle seed: %d" % _battle_seed)

	_spawn_units()
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


func _process(delta: float) -> void:
	if _battle_over:
		return

	if not headless_mode and _battle_phase == BattlePhase.VICTORY_PENDING:
		_victory_delay_accum += delta
		if _victory_delay_accum >= Constants.get_float("victory_delay_s"):
			_declare_victory()

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
	_update_movement(tick_interval)
	_assert_no_overlaps()
	_combat_tick()
	_track_rout_state()
	_update_victory_state(tick_interval)
	var ticks_per_sec := int(Constants.get_float("tick_rate_per_sec"))
	if _sim_tick_count % ticks_per_sec == 0:
		_log_trace_row()
	_check_epilogue_end()


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


func _enemies_for(unit: Unit) -> Array[Unit]:
	var enemies: Array[Unit] = []
	for other in _units:
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
		elif unit.get_state() == Unit.State.ROUTING:
			unit.update_routing(delta)
		elif (
			unit.get_state() == Unit.State.HOLD
			and unit.current_order == Unit.Order.MARCH_TO
		):
			unit.update_marching(delta, _enemies_for(unit))
			_try_begin_engagement(unit)


func _try_begin_engagement(unit: Unit) -> void:
	if unit.get_state() == Unit.State.ROUTING:
		return

	for other in _units:
		if other == unit or other.get_state() == Unit.State.REMOVED:
			continue
		if other.get_state() == Unit.State.ROUTING:
			continue
		if other.team_id == unit.team_id:
			continue
		if not CombatResolver.units_have_any_contact(unit, other):
			continue

		unit.add_contact_partner(other)
		other.add_contact_partner(unit)
		if CombatResolver.is_head_on_pair(unit, other):
			CombatResolver.snap_pair_to_contact(unit, other)
		_on_first_contact()


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

		var edge_labels: Array[String] = []

		for attacker in defender.get_contact_partners():
			if attacker == null or attacker.get_state() == Unit.State.REMOVED:
				continue
			if attacker.get_state() == Unit.State.ROUTING:
				continue
			if (
				CombatResolver.is_head_on_pair(attacker, defender)
				and CombatResolver.units_have_front_contact(attacker, defender)
			):
				continue

			var contact := EdgeContact.classify_contact(attacker, defender)
			if not contact.get("has_contact", false):
				continue

			var segment_key := attacker.unit_id + ">" + defender.unit_id
			if segment_key in processed_segments:
				continue
			processed_segments.append(segment_key)

			var edge_label: String = contact.get("edge_label", "")
			if not edge_label.is_empty():
				edge_labels.append(edge_label)

			var segment := CombatResolver.resolve_contact_segment(attacker, defender, contact)
			var edge_lengths: Dictionary = segment.get("edge_lengths_m", {})
			var push_normal: Vector2 = segment.get("push_normal", defender.facing)

			if segment.attacker_wins:
				_accumulate_directed_shift(defender_shifts, defender, push_normal, segment.defender_shift_m)
				CombatResolver.apply_shift_morale_drain(defender, segment.defender_shift_m, edge_lengths)
				var applied := CombatResolver.apply_strength_loss_with_edge(
					defender, segment.defender_damage, edge_lengths
				)
				attacker.record_damage_dealt(applied)
			else:
				_accumulate_directed_shift(defender_shifts, attacker, -push_normal, segment.attacker_shift_m)
				CombatResolver.apply_shift_morale_drain(attacker, segment.attacker_shift_m, edge_lengths)
				var applied := CombatResolver.apply_strength_loss_with_edge(
					attacker, segment.attacker_damage, edge_lengths
				)
				defender.record_damage_dealt(applied)

			var gap_ratio: float = segment.get("gap_ratio", 0.0)
			bump_winners[attacker] = segment.attacker_wins
			attacker.set_bump_state(gap_ratio, segment.attacker_wins)
			defender.set_bump_state(gap_ratio, not segment.attacker_wins)

			if attacker.get_state() == Unit.State.ROUTING or defender.get_state() == Unit.State.ROUTING:
				_on_first_rout()
				_try_start_victory_delay(
					attacker if attacker.get_state() == Unit.State.ROUTING else defender
				)

		defender.set_active_contact_edges(_join_edge_labels(edge_labels))

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
	if not _team_fully_routing(routing_unit.team_id):
		return

	_victory_team = _opponent_team(routing_unit.team_id)
	_battle_phase = BattlePhase.VICTORY_PENDING
	_victory_delay_accum = 0.0
	for unit in _units:
		if unit.team_id == _victory_team:
			_winner = unit


func _team_fully_routing(team_id: String) -> bool:
	var has_active := false
	for unit in _units:
		if unit.team_id != team_id:
			continue
		if unit.get_state() == Unit.State.REMOVED:
			continue
		if unit.get_state() != Unit.State.ROUTING:
			return false
		has_active = true
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


func _pair_key(unit_a: Unit, unit_b: Unit) -> String:
	if unit_a.unit_id < unit_b.unit_id:
		return unit_a.unit_id + ":" + unit_b.unit_id
	return unit_b.unit_id + ":" + unit_a.unit_id


func _assert_no_overlaps() -> void:
	# All unit pairs including allies — enemy head-on uses center-gap penetration;
	# all other pairs (allied or angled) use oriented-box overlap.
	for i in _units.size():
		var unit_a := _units[i]
		if unit_a.get_state() == Unit.State.REMOVED:
			continue
		for j in range(i + 1, _units.size()):
			var unit_b := _units[j]
			if unit_b.get_state() == Unit.State.REMOVED:
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


func is_battle_over() -> bool:
	return _battle_over


func get_unit_kill_totals() -> Dictionary:
	var totals := {}
	for unit in _units:
		totals[unit.unit_id] = unit.soldiers_defeated()
	return totals
