class_name ScenarioFromData
extends Scenario01

## WO-034 — spawn a battle from BattleScenarioData JSON / merged deployment dict.
## Headless + realtime; uses existing SimBattleCore / sim-thread seam.

const _BattleData := preload("res://scripts/battle_scenario_data.gd")

var battle_data: Dictionary = {}
var trace_prefix_override: String = "scenario_from_data"


func set_battle_data(data: Dictionary) -> void:
	battle_data = data.duplicate(true)


func _spawn_units() -> void:
	_units.clear()
	if battle_data.is_empty() and not _BattleData.pending_battle.is_empty():
		battle_data = _BattleData.pending_battle.duplicate(true)
	var units_src: Array = battle_data.get("units", [])
	if units_src.is_empty():
		# Allow roster+placements merge if caller only set placements path.
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
	# Apply map metadata before Scenario01._ready spawns / starts sim.
	if not battle_data.is_empty():
		set_height_field(_BattleData.build_height_field(battle_data))
		set_terrain_patches(battle_data.get("terrain_patches", []))
		if battle_data.has("battle_seed"):
			set_battle_seed(int(battle_data.get("battle_seed")))
	super._ready()
	_ensure_sim_core()
	if not battle_data.is_empty():
		_sim_core.battle_type = str(battle_data.get("battle_type", "pitched"))
		_sim_core.deployment_zones = battle_data.get("deployment_zones", {}).duplicate(true)
		_sim_core.victory_spec = battle_data.get("victory", {"mode": "rout"}).duplicate(true)
		_sim_core.terrain_patches = battle_data.get("terrain_patches", []).duplicate(true)
		_sim_core.height_field = _height_field


func get_initial_core_fingerprint() -> String:
	_ensure_sim_core()
	if _sim_core.units.is_empty():
		_sim_core.capture_from_units(_units)
	return _BattleData.initial_trace_fingerprint_from_core(_sim_core)


func _process(delta: float) -> void:
	super._process(delta)
	if headless_mode:
		return
	# Report battle FPS after deploy handoff (render thread; sim on worker).
	if Engine.get_frames_drawn() % 120 == 0:
		print("[WO-034] Battle FPS=%.1f (sim_thread=%s)" % [Engine.get_frames_per_second(), str(use_sim_thread)])
