class_name Scenario01
extends Node2D

const UNIT_SCENE := preload("res://scenes/unit.tscn")
const TRACE_DIR := "res://tests/traces/"
const _TickProfiler := preload("res://scripts/tick_profiler.gd")
const _SimBattleCore := preload("res://scripts/sim/sim_battle_core.gd")
const _SimThreadController := preload("res://scripts/sim/sim_thread_controller.gd")

enum BattlePhase { ACTIVE, VICTORY_PENDING, VICTORY_EPILOGUE, FINISHED }

@export var auto_run: bool = true
@export var headless_mode: bool = false
## When true (with headless_mode), autotest harness drives ticks via SimHarness — no _process loop.
@export var fast_sim_mode: bool = false
## WO-011: worker-thread sim at 10 Hz (realtime only; fast-mode path stays on main thread).
@export var use_sim_thread: bool = false

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
var _current_tick_interval: float = 0.1
var _sim_core = null
var _sim_thread = null
var _threaded_battle_finished: bool = false
var _fast_finish_handled: bool = false

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
		if _sim_thread_enabled():
			_setup_sim_thread()
		else:
			_ensure_sim_core()
			_sim_core.capture_from_units(_units)
			_sim_core.write_trace_header()
			_sim_core.log_trace_row()
			_sync_state_from_core()
	elif _sim_thread_enabled():
		_setup_sim_thread()
	else:
		_ensure_sim_core()
	if headless_mode and not _sim_thread_enabled():
		set_process(false)


func _exit_tree() -> void:
	if _sim_thread != null:
		_sim_thread.stop()
		_sim_thread = null
		_sim_core = null


func _sim_thread_enabled() -> bool:
	return use_sim_thread and not fast_sim_mode


func _sim_thread_active() -> bool:
	return _sim_thread_enabled() and _sim_thread != null


func _setup_sim_thread() -> void:
	_ensure_sim_core()
	if auto_run:
		_sim_core.write_trace_header()
	_sim_core.capture_from_units(_units)
	if auto_run:
		_sim_core.log_trace_row()
	_sim_thread = _SimThreadController.new()
	_sim_thread.start(_sim_core, not headless_mode)


func _ensure_sim_core() -> void:
	if _sim_core != null:
		return
	_sim_core = _SimBattleCore.new()
	_sim_core.configure_rng(_battle_seed)
	_sim_core.headless_mode = headless_mode
	_sim_core.fast_sim_mode = fast_sim_mode
	_sim_core.shock_floater_callback = _spawn_shock_floater_from_proxy


func _dispatch_core_event_hooks() -> void:
	if _sim_core == null:
		return
	if _sim_core.first_contact_tick >= 0 and _first_contact_tick < 0:
		_on_first_contact()
	if _sim_core.first_rout_tick >= 0 and _first_rout_tick < 0:
		_on_first_rout()


func _spawn_shock_floater_from_proxy(proxy, amount: float) -> void:
	if headless_mode or proxy == null:
		return
	for unit in _units:
		if unit.unit_id == proxy.unit_id:
			_spawn_shock_floater(unit, amount)
			return


func _sync_core_from_units() -> void:
	_ensure_sim_core()
	_sim_core.capture_from_units(_units)


func _sync_units_from_core() -> void:
	_sim_core.apply_render_snapshot_to_units(_units)


func _proxy_on_core(unit: Unit):
	for proxy in _sim_core.units:
		if proxy.unit_id == unit.unit_id:
			return proxy
	return null


func _sync_state_from_core() -> void:
	if _sim_core == null:
		return
	_sim_tick_count = _sim_core.sim_tick_count
	_battle_over = _sim_core.battle_over
	_battle_phase = _sim_core.battle_phase as BattlePhase
	_victory_team = _sim_core.victory_team
	if headless_mode:
		_victory_delay_accum = _sim_core.victory_delay_accum
	_watch_epilogue = _sim_core.watch_epilogue
	_trace_lines = _sim_core.trace_lines
	_first_contact_tick = _sim_core.first_contact_tick
	_first_rout_tick = _sim_core.first_rout_tick
	_overlap_assertion_failed = _sim_core.overlap_assertion_failed
	_adhesion_invariant_failed = _sim_core.adhesion_invariant_failed
	_winner = null
	if not _sim_core.winner_id.is_empty():
		for unit in _units:
			if unit.unit_id == _sim_core.winner_id:
				_winner = unit
				break


func wait_for_threaded_completion() -> void:
	if _sim_thread == null:
		return
	_sim_thread.wait_for_completion()
	_sync_state_from_core()
	if auto_run and headless_mode and _battle_over and not _threaded_battle_finished:
		_threaded_battle_finished = true
		_write_trace_file()
		_print_summary()


func run_simulation_threaded_to_completion(extra_ticks: int = 0) -> void:
	wait_for_threaded_completion()
	if extra_ticks > 0:
		push_warning("Scenario01: extra_ticks ignored on threaded sim path")


func _process_threaded_frame(delta: float) -> void:
	var was_over := _battle_over
	_sync_state_from_core()
	if _battle_over:
		if not was_over:
			if auto_run:
				_write_trace_file()
			_print_summary()
			if not headless_mode:
				_show_results_if_needed()
		return

	if not headless_mode and _battle_phase == BattlePhase.VICTORY_PENDING:
		_victory_delay_accum += delta
		if _victory_delay_accum >= Constants.get_float("victory_delay_s"):
			_declare_victory()
		if _sim_thread != null:
			_sim_thread.apply_snapshot_to_units(_units)
		return

	if _sim_thread != null:
		_sim_thread.apply_snapshot_to_units(_units)


func simulate_realtime_step(delta: float = -1.0) -> void:
	var step := delta if delta > 0.0 else CombatResolver.tick_interval()
	if _sim_thread_active():
		_process_threaded_frame(step)
		return
	_process(step)


func run_simulation_fast(extra_ticks: int = 0) -> void:
	var harness: Script = load("res://scripts/sim_harness.gd")
	harness.run_to_completion(self, harness.RunMode.FAST, extra_ticks)


func _process(delta: float) -> void:
	if _sim_thread_active():
		_process_threaded_frame(delta)
		return
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
	if _sim_thread_active():
		return
	if _battle_over:
		return

	_ensure_sim_core()
	_sync_core_from_units()
	if _TickProfiler.enabled:
		_sim_core.advance_one_tick_profiled(CombatResolver.tick_interval())
	else:
		_sim_core.advance_one_tick()
	_sync_units_from_core()
	_dispatch_core_event_hooks()
	_sync_state_from_core()
	_on_core_battle_finished_if_needed()


func _on_core_battle_finished_if_needed() -> void:
	if not _battle_over or _fast_finish_handled:
		return
	_fast_finish_handled = true
	_write_trace_file()
	_print_summary()
	_show_results_if_needed()


func _begin_sim_tick(tick_interval: float) -> void:
	_ensure_sim_core()
	_sim_core.sim_tick_count = _sim_tick_count
	_current_tick_interval = tick_interval
	_sync_core_from_units()
	_sim_core.begin_sim_tick(tick_interval)


func _overlap_assert_enabled() -> bool:
	if _sim_core != null:
		return _sim_core.overlap_assert_enabled()
	return headless_mode and fast_sim_mode


func _capture_tick_start_positions() -> void:
	_ensure_sim_core()
	_sim_core.capture_tick_start_positions()


func _unit_moved_this_tick(unit: Unit) -> bool:
	if _sim_core == null:
		return true
	var proxy = _proxy_on_core(unit)
	if proxy == null:
		return true
	return _sim_core.unit_moved_this_tick(proxy)


func _rebuild_spatial_grid() -> void:
	_sync_core_from_units()
	_sim_core.rebuild_spatial_grid()


func _update_movement(delta: float) -> void:
	_sync_core_from_units()
	_sim_core.update_movement(delta)
	_sync_units_from_core()


func _try_begin_engagement(unit: Unit) -> void:
	_sync_core_from_units()
	var proxy = _proxy_on_core(unit)
	if proxy != null:
		_sim_core.try_begin_engagement(proxy)
	_sync_units_from_core()


func _try_passive_engagement() -> void:
	_sync_core_from_units()
	_sim_core.try_passive_engagement()
	_sync_units_from_core()


func _process_rout_events() -> void:
	_sync_core_from_units()
	_sim_core.process_rout_events()
	_sync_units_from_core()


func _apply_neighbor_rout_shock(routing_unit: Unit) -> void:
	_sync_core_from_units()
	var proxy = _proxy_on_core(routing_unit)
	if proxy != null:
		_sim_core.apply_neighbor_rout_shock(proxy)
	_sync_units_from_core()


func _pursuit_tick() -> void:
	_sync_core_from_units()
	_sim_core.pursuit_tick()
	_sync_units_from_core()


func _on_first_contact() -> void:
	if _first_contact_tick >= 0:
		return
	_first_contact_tick = _sim_core.first_contact_tick if _sim_core != null else _sim_tick_count


func _on_first_rout() -> void:
	if _first_rout_tick >= 0:
		return
	_first_rout_tick = _sim_core.first_rout_tick if _sim_core != null else _sim_tick_count


func _combat_tick() -> void:
	_sync_core_from_units()
	_sim_core.combat_tick()
	_sync_units_from_core()


func _prune_broken_contacts() -> void:
	_sync_core_from_units()
	_sim_core.prune_broken_contacts()
	_sync_units_from_core()


func _track_rout_state() -> void:
	_sync_core_from_units()
	_sim_core.track_rout_state()
	_sync_units_from_core()
	_sync_state_from_core()


func _update_victory_state(tick_interval: float) -> void:
	_sync_core_from_units()
	_sim_core.update_victory_state(tick_interval)
	_sync_units_from_core()
	_sync_state_from_core()


func _apply_contact_adhesion() -> void:
	_sync_core_from_units()
	_sim_core.apply_contact_adhesion()
	_sync_units_from_core()


func _resolve_allied_overlaps() -> void:
	_sync_core_from_units()
	_sim_core.resolve_allied_overlaps()
	_sync_units_from_core()


func _run_overlap_assert_if_enabled() -> void:
	_sync_core_from_units()
	_sim_core.run_overlap_assert_if_enabled()
	_sync_state_from_core()


func _assert_no_overlaps() -> void:
	_sync_core_from_units()
	_sim_core.assert_no_overlaps()
	_sync_state_from_core()


func _check_epilogue_end() -> void:
	_sync_core_from_units()
	_sim_core.check_epilogue_end()
	_sync_units_from_core()
	_dispatch_core_event_hooks()
	_sync_state_from_core()
	_on_core_battle_finished_if_needed()


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


func _spawn_shock_floater(unit: Unit, amount: float) -> void:
	if headless_mode or _shock_floater_layer == null or amount <= 0.0:
		return
	_shock_floater_layer.spawn_for_unit(unit, amount, _camera)


func _declare_victory() -> void:
	_battle_phase = BattlePhase.VICTORY_EPILOGUE
	if _sim_core != null:
		_sim_core.battle_phase = _SimBattleCore.BattlePhase.VICTORY_EPILOGUE
	if headless_mode:
		_watch_epilogue = true
		if _sim_core != null:
			_sim_core.watch_epilogue = true
		return
	_results_overlay.show_victory(_victory_team)


func _on_skip_epilogue() -> void:
	if _sim_core != null:
		_sim_core.finish_battle()
		_sync_units_from_core()
		_sync_state_from_core()
		_fast_finish_handled = false
		_on_core_battle_finished_if_needed()
	else:
		_finish_battle()


func _on_watch_epilogue() -> void:
	_watch_epilogue = true
	if _sim_core != null:
		_sim_core.watch_epilogue = true




func _finish_battle() -> void:
	if _battle_over:
		return
	if _sim_core != null:
		_sim_core.finish_battle()
		_sync_units_from_core()
		_sync_state_from_core()
		_fast_finish_handled = false
		_on_core_battle_finished_if_needed()
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




func _write_trace_header() -> void:
	_ensure_sim_core()
	_sim_core.write_trace_header()
	_trace_lines = _sim_core.trace_lines


func _log_trace_row() -> void:
	_ensure_sim_core()
	_sync_core_from_units()
	_sim_core.log_trace_row()
	_trace_lines = _sim_core.trace_lines


func _log_trace_event(event_type: String, detail: String) -> void:
	_ensure_sim_core()
	_sim_core.log_trace_event(event_type, detail)
	_trace_lines = _sim_core.trace_lines


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
	if _sim_core != null:
		return _sim_core.get_trace_text()
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
	if _sim_thread_active() and _sim_core != null:
		return _sim_core.battle_over
	return _battle_over


func get_sim_thread_tick_stats() -> Dictionary:
	if _sim_thread == null:
		return {}
	var tick_times_usec: Array = _sim_thread.get_tick_times_usec()
	if tick_times_usec.is_empty():
		return {"tick_count": 0}
	var tick_times_ms: Array[float] = []
	for usec in tick_times_usec:
		tick_times_ms.append(float(usec) / 1000.0)
	tick_times_ms.sort()
	var tick_sum := 0.0
	for t in tick_times_ms:
		tick_sum += t
	var p95_idx := int(floor(float(tick_times_ms.size() - 1) * 0.95))
	return {
		"tick_count": tick_times_ms.size(),
		"min_tick_ms": tick_times_ms[0],
		"avg_tick_ms": tick_sum / float(tick_times_ms.size()),
		"max_tick_ms": tick_times_ms[-1],
		"p95_tick_ms": tick_times_ms[p95_idx],
		"last_tick_ms": float(_sim_thread.get_last_tick_usec()) / 1000.0,
	}


func get_unit_kill_totals() -> Dictionary:
	var totals := {}
	for unit in _units:
		totals[unit.unit_id] = unit.soldiers_defeated()
	return totals
