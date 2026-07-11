class_name Scenario01
extends Node2D

const UNIT_SCENE := preload("res://scenes/unit.tscn")
const TRACE_DIR := "res://tests/traces/"

@export var auto_run: bool = true
@export var headless_mode: bool = false

var _units: Array[Unit] = []
var _tick_accumulator: float = 0.0
var _sim_tick_count: int = 0
var _battle_seed: int = 0
var _seed_override: int = -1
var _battle_over: bool = false
var _trace_lines: PackedStringArray = PackedStringArray()
var _trace_header_written: bool = false
var _winner: Unit = null
var _battle_start_time_msec: int = 0

@onready var _camera: Camera2D = $Camera2D
@onready var _ground: ColorRect = $Ground
@onready var _debug_overlay: CanvasLayer = $DebugOverlay


func set_battle_seed(seed_value: int) -> void:
	_seed_override = seed_value


func _ready() -> void:
	_setup_ground()
	_battle_seed = _seed_override if _seed_override >= 0 else Constants.get_int("scenario_01_battle_seed")
	RNG.set_seed(_battle_seed)
	print("[Scenario 01] Battle seed: %d" % _battle_seed)

	_spawn_units()
	_debug_overlay.setup_for_scenario(_units, _camera)

	if auto_run:
		_battle_start_time_msec = Time.get_ticks_msec()
		_write_trace_header()
		_log_trace_row()


func _process(delta: float) -> void:
	if _battle_over:
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
	_update_movement(tick_interval)
	_combat_tick()
	var ticks_per_sec := int(Constants.get_float("tick_rate_per_sec"))
	if _sim_tick_count % ticks_per_sec == 0:
		_log_trace_row()
	_check_battle_end()


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


func _update_movement(delta: float) -> void:
	for unit in _units:
		if unit.get_state() == Unit.State.REMOVED:
			continue
		if unit.get_state() == Unit.State.MARCHING:
			unit.update_marching(delta)
			_try_begin_engagement(unit)
		elif unit.get_state() == Unit.State.ROUTING:
			unit.update_routing(delta)
		elif (
			unit.get_state() == Unit.State.HOLD
			and unit.current_order == Unit.Order.MARCH_TO
		):
			unit.update_marching(delta)
			_try_begin_engagement(unit)


func _try_begin_engagement(unit: Unit) -> void:
	for other in _units:
		if other == unit or other.get_state() == Unit.State.REMOVED:
			continue
		if other.team_id == unit.team_id:
			continue
		if CombatResolver.units_have_front_contact(unit, other):
			unit.begin_engagement(other)
			other.begin_engagement(unit)
			return


func _combat_tick() -> void:
	var processed: Array[String] = []

	for unit in _units:
		if unit.get_state() == Unit.State.REMOVED:
			continue
		if unit.get_state() != Unit.State.ENGAGED and unit.get_state() != Unit.State.WAVERING:
			continue

		var partner := unit.engaged_partner
		if partner == null or partner.get_state() == Unit.State.REMOVED:
			unit.break_engagement()
			continue

		var pair_key := _pair_key(unit, partner)
		if pair_key in processed:
			continue
		processed.append(pair_key)

		if not CombatResolver.units_have_front_contact(unit, partner):
			unit.break_engagement()
			partner.break_engagement()
			continue

		var result := CombatResolver.resolve_engagement(unit, partner)
		CombatResolver.apply_ground_loss(unit, result.shift_a_m)
		CombatResolver.apply_ground_loss(partner, result.shift_b_m)
		CombatResolver.apply_strength_loss(unit, result.damage_a)
		CombatResolver.apply_strength_loss(partner, result.damage_b)


func _pair_key(unit_a: Unit, unit_b: Unit) -> String:
	if unit_a.unit_id < unit_b.unit_id:
		return unit_a.unit_id + ":" + unit_b.unit_id
	return unit_b.unit_id + ":" + unit_a.unit_id


func _check_battle_end() -> void:
	var active_units: Array[Unit] = []
	for unit in _units:
		if unit.get_state() != Unit.State.REMOVED:
			active_units.append(unit)

	if active_units.size() > 1:
		return

	_battle_over = true
	if active_units.size() == 1:
		_winner = active_units[0]
	else:
		_winner = null

	_log_trace_row()
	_write_trace_file()
	_print_summary()


func _write_trace_header() -> void:
	_trace_lines.append(
		"time_sec,unit_id,strength,cohesion,pos_x,pos_y,state"
	)
	_trace_header_written = true


func _log_trace_row() -> void:
	var time_sec := _sim_tick_count * CombatResolver.tick_interval()
	for unit in _units:
		_trace_lines.append(
			"%.1f,%s,%.4f,%.4f,%.2f,%.2f,%s"
			% [
				time_sec,
				unit.unit_id,
				unit.strength,
				unit.cohesion,
				unit.position.x,
				unit.position.y,
				unit.get_state_name(),
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


func _print_summary() -> void:
	var duration_sec := (Time.get_ticks_msec() - _battle_start_time_msec) / 1000.0
	if _winner == null:
		print(
			"[Scenario 01] SUMMARY | winner=none | duration=%.1fs"
			% duration_sec
		)
		return

	print(
		"[Scenario 01] SUMMARY | winner=%s | duration=%.1fs | winner_strength=%.2f | winner_cohesion=%.2f"
		% [
			_winner.unit_id,
			duration_sec,
			_winner.strength,
			_winner.cohesion,
		]
	)

	if headless_mode:
		get_tree().quit(0)


func get_trace_text() -> String:
	return "\n".join(_trace_lines) + "\n"


func get_winner_id() -> String:
	if _winner == null:
		return "none"
	return _winner.unit_id


func is_battle_over() -> bool:
	return _battle_over
