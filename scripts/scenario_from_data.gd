class_name ScenarioFromData
extends Scenario01

## WO-034/035 — spawn a battle from BattleScenarioData JSON / merged deployment.
## WO-035: UI handoff MUST start the certified tick only after metadata is applied
## (identical SimBattleCore.advance_one_tick path as scenario_01..54).

const _BattleData := preload("res://scripts/battle_scenario_data.gd")

var battle_data: Dictionary = {}
var trace_prefix_override: String = "scenario_from_data"
## When true (UI designer battles), track overlap/coherence failures for the results strip.
var ui_integrity_watch: bool = true


func set_battle_data(data: Dictionary) -> void:
	battle_data = data.duplicate(true)


func _spawn_units() -> void:
	_units.clear()
	if battle_data.is_empty() and not _BattleData.pending_battle.is_empty():
		battle_data = _BattleData.pending_battle.duplicate(true)
	var units_src: Array = battle_data.get("units", [])
	if units_src.is_empty():
		push_error("ScenarioFromData: no units in battle_data")
		return
	for rec in units_src:
		if typeof(rec) != TYPE_DICTIONARY:
			continue
		var unit: Unit = _BattleData.spawn_unit_node(self, rec, UNIT_SCENE)
		_units.append(unit)
	for unit in _units:
		unit.set_render_camera(_camera)


func _ready() -> void:
	if battle_data.is_empty() and not _BattleData.pending_battle.is_empty():
		battle_data = _BattleData.pending_battle.duplicate(true)
		_BattleData.pending_battle = {}
	if not battle_data.is_empty():
		set_height_field(_BattleData.build_height_field(battle_data))
		set_terrain_patches(battle_data.get("terrain_patches", []))
		if battle_data.has("battle_seed"):
			set_battle_seed(int(battle_data.get("battle_seed")))

	# WO-035 unification: Scenario01._ready starts the sim thread when
	# use_sim_thread && !fast_sim_mode — even before subclass post-work.
	# Defer thread/auto start until battle metadata is on the core so the first
	# tick matches scenario_01..54 (no partial-init window).
	var saved_auto: bool = auto_run
	var saved_thread: bool = use_sim_thread
	auto_run = false
	use_sim_thread = false
	super._ready()
	_apply_battle_metadata_to_core()
	auto_run = saved_auto
	use_sim_thread = saved_thread
	_battle_start_time_msec = Time.get_ticks_msec()
	if auto_run:
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


func _apply_battle_metadata_to_core() -> void:
	_ensure_sim_core()
	if battle_data.is_empty():
		return
	_sim_core.battle_type = str(battle_data.get("battle_type", "pitched"))
	_sim_core.deployment_zones = battle_data.get("deployment_zones", {}).duplicate(true)
	_sim_core.victory_spec = battle_data.get("victory", {"mode": "rout"}).duplicate(true)
	_sim_core.terrain_patches = battle_data.get("terrain_patches", []).duplicate(true)
	_sim_core.height_field = _height_field
	# Integrity watch uses the same assert_no_overlaps / adhesion invariant the
	# cert path records — enabled under headless+fast in smoke; flag reserved
	# for designer builds that opt into continuous watch without changing the
	# GAMEPLAY_TICK gate (overlap_assert_enabled stays WO-024 rules).
	if ui_integrity_watch and not headless_mode:
		print(
			"[WO-035] UI battle on certified tick path (substep+adhesion+allied_sep+coherence); sim_thread=%s"
			% str(_sim_thread_enabled())
		)


func get_initial_core_fingerprint() -> String:
	_ensure_sim_core()
	if _sim_core.units.is_empty():
		_sim_core.capture_from_units(_units)
	return _BattleData.initial_trace_fingerprint_from_core(_sim_core)


func _process(delta: float) -> void:
	super._process(delta)
	if headless_mode:
		return
	if Engine.get_frames_drawn() % 120 == 0:
		var ov := had_overlap_failure()
		var ad := had_adhesion_invariant_failure()
		print(
			"[WO-035] Battle FPS=%.1f sim_thread=%s overlap_fail=%s coherence_fail=%s"
			% [Engine.get_frames_per_second(), str(use_sim_thread), str(ov), str(ad)]
		)
