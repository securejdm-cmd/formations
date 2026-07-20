class_name Scenario48
extends Scenario01

## S48 — Forest penalties (WO-032): cav −40% speed, over-wide drain, missile −25% both ways.

const TRACE_PREFIX := "scenario_48"
const _Charge := preload("res://scripts/charge_combat.gd")
const _Concealment := preload("res://scripts/concealment.gd")

var cav_speed_in_forest: float = -1.0
var cav_speed_on_flat: float = -1.0
var overwide_cohesion_start: float = -1.0
var overwide_cohesion_end: float = -1.0
var narrow_cohesion_end: float = -1.0
var volley_out_damage: float = -1.0
var volley_into_damage: float = -1.0
var volley_flat_damage: float = -1.0


func _spawn_units() -> void:
	# Units are created in probe helpers; keep a placeholder for Scenario01.
	var px := Constants.get_float("px_per_meter")
	var inf := UnitProfileLoader.load_profile("test_infantry")
	var u := UNIT_SCENE.instantiate()
	add_child(u)
	u.configure("placeholder", "blue", inf, Vector2.ZERO, Vector2.RIGHT)
	_units.append(u)
	u.set_render_camera(_camera)
	set_terrain_patches([
		{"type": "FOREST", "x": -50.0, "y": -50.0, "w": 100.0, "h": 100.0},
	])


func _ready() -> void:
	super._ready()
	_ensure_sim_core()
	_sim_core.battle_type = "pitched"
	_render_terrain_patches()


func run_penalty_probes() -> Dictionary:
	_probe_cav_speed()
	_probe_overwide_drain()
	_probe_missile()
	var speed_ok := cav_speed_on_flat > 0.0 and absf(cav_speed_in_forest / cav_speed_on_flat - 0.6) <= 0.02
	var drain_ok := (
		overwide_cohesion_end >= 0.0
		and overwide_cohesion_end < overwide_cohesion_start - 1.0
		and narrow_cohesion_end > overwide_cohesion_end + 0.5
	)
	var missile_ok := (
		volley_flat_damage > 0.0
		and absf(volley_out_damage / volley_flat_damage - 0.75) <= 0.03
		and absf(volley_into_damage / volley_flat_damage - 0.75) <= 0.03
	)
	return {
		"cav_speed_in_forest": cav_speed_in_forest,
		"cav_speed_on_flat": cav_speed_on_flat,
		"speed_ok": speed_ok,
		"overwide_start": overwide_cohesion_start,
		"overwide_end": overwide_cohesion_end,
		"narrow_end": narrow_cohesion_end,
		"drain_ok": drain_ok,
		"volley_flat": volley_flat_damage,
		"volley_out": volley_out_damage,
		"volley_into": volley_into_damage,
		"missile_ok": missile_ok,
		"all_ok": speed_ok and drain_ok and missile_ok,
	}


func _probe_cav_speed() -> void:
	var px := Constants.get_float("px_per_meter")
	var cav := UnitProfileLoader.load_profile("test_cavalry").duplicate(true)
	# Forest core
	var core_f = _SimBattleCore.new()
	core_f.configure_rng(1000)
	core_f.headless_mode = true
	core_f.fast_sim_mode = true
	core_f.terrain_patches = [{"type": "FOREST", "x": -50.0, "y": -50.0, "w": 100.0, "h": 100.0}]
	var u_f = preload("res://scripts/sim/sim_unit_proxy.gd").from_unit(
		_temp("cav_f", "blue", cav, Vector2.ZERO, Vector2.RIGHT)
	)
	core_f.units = [u_f]
	core_f.refresh_slope_mods()
	cav_speed_in_forest = _Charge.target_speed_m_s(u_f)

	var core_flat = _SimBattleCore.new()
	core_flat.configure_rng(1000)
	core_flat.headless_mode = true
	core_flat.fast_sim_mode = true
	core_flat.terrain_patches = []
	var u_flat = preload("res://scripts/sim/sim_unit_proxy.gd").from_unit(
		_temp("cav_flat", "blue", cav, Vector2(200.0 * px, 0.0), Vector2.RIGHT)
	)
	core_flat.units = [u_flat]
	core_flat.refresh_slope_mods()
	cav_speed_on_flat = _Charge.target_speed_m_s(u_flat)


func _probe_overwide_drain() -> void:
	var tick_interval := 1.0 / Constants.get_float("tick_rate_per_sec")
	var wide := UnitProfileLoader.load_profile("test_infantry").duplicate(true)
	wide["formation_frontage_m"] = 60.0
	wide["formation_depth_m"] = 10.0
	var narrow := UnitProfileLoader.load_profile("test_infantry").duplicate(true)
	narrow["formation_frontage_m"] = 30.0
	narrow["formation_depth_m"] = 10.0
	var Proxy = preload("res://scripts/sim/sim_unit_proxy.gd")

	var core_w = _SimBattleCore.new()
	core_w.configure_rng(1000)
	core_w.headless_mode = true
	core_w.fast_sim_mode = true
	core_w.terrain_patches = [{"type": "FOREST", "x": -80.0, "y": -80.0, "w": 160.0, "h": 160.0}]
	var u_w = Proxy.from_unit(_temp("wide", "blue", wide, Vector2.ZERO, Vector2.RIGHT))
	core_w.units = [u_w]
	overwide_cohesion_start = u_w.cohesion
	for _i in 50:
		core_w.tick_concealment(tick_interval)
	overwide_cohesion_end = u_w.cohesion

	var core_n = _SimBattleCore.new()
	core_n.configure_rng(1000)
	core_n.headless_mode = true
	core_n.fast_sim_mode = true
	core_n.terrain_patches = [{"type": "FOREST", "x": -80.0, "y": -80.0, "w": 160.0, "h": 160.0}]
	var u_n = Proxy.from_unit(_temp("narrow", "blue", narrow, Vector2.ZERO, Vector2.RIGHT))
	core_n.units = [u_n]
	for _i in 50:
		core_n.tick_concealment(tick_interval)
	narrow_cohesion_end = u_n.cohesion


func _probe_missile() -> void:
	var Proxy = preload("res://scripts/sim/sim_unit_proxy.gd")
	var px := Constants.get_float("px_per_meter")
	var archer := UnitProfileLoader.load_profile("test_archer").duplicate(true)
	var target_p := UnitProfileLoader.load_profile("test_infantry").duplicate(true)
	archer["formation_frontage_m"] = 20.0
	archer["formation_depth_m"] = 10.0
	target_p["formation_frontage_m"] = 20.0
	target_p["formation_depth_m"] = 10.0

	# Flat control: both outside forest.
	volley_flat_damage = _one_volley_damage(
		Proxy, archer, target_p,
		Vector2(120.0 * px, 0.0), Vector2(200.0 * px, 0.0),
		[{"type": "FOREST", "x": -40.0, "y": -40.0, "w": 80.0, "h": 80.0}]
	)
	# OUT of forest: shooter in forest, target outside.
	volley_out_damage = _one_volley_damage(
		Proxy, archer, target_p,
		Vector2.ZERO, Vector2(80.0 * px, 0.0),
		[{"type": "FOREST", "x": -40.0, "y": -40.0, "w": 80.0, "h": 80.0}]
	)
	# INTO forest: shooter outside, target in forest.
	volley_into_damage = _one_volley_damage(
		Proxy, archer, target_p,
		Vector2(80.0 * px, 0.0), Vector2.ZERO,
		[{"type": "FOREST", "x": -40.0, "y": -40.0, "w": 80.0, "h": 80.0}]
	)


func _one_volley_damage(Proxy, archer_prof: Dictionary, tgt_prof: Dictionary, shoot_pos: Vector2, tgt_pos: Vector2, patches: Array) -> float:
	var core = _SimBattleCore.new()
	core.configure_rng(1000)
	core.headless_mode = true
	core.fast_sim_mode = true
	core.force_trace_logging = true
	core.terrain_patches = patches
	var shooter = Proxy.from_unit(_temp("archer", "blue", archer_prof, shoot_pos, Vector2.RIGHT))
	var target = Proxy.from_unit(_temp("target", "red", tgt_prof, tgt_pos, Vector2.LEFT))
	shooter._set_state(Unit.State.HOLD)
	shooter.current_order = Unit.Order.HOLD
	shooter.current_speed_m_s = 0.0
	target._set_state(Unit.State.HOLD)
	core.units = [shooter, target]
	core.capture_tick_start_positions()
	# Force reload ready.
	shooter._reload_timer = 0.0
	var before: float = target.strength
	core.try_fire_volley(shooter)
	return before - target.strength


func _temp(uid: String, team: String, profile: Dictionary, pos: Vector2, facing: Vector2) -> Unit:
	var u: Unit = UNIT_SCENE.instantiate()
	add_child(u)
	u.configure(uid, team, profile, pos, facing)
	u.visible = false
	return u


func _write_trace_file() -> void:
	pass
