class_name Scenario46
extends Scenario01

## S46 — Detection matrix (WO-032): base × profile × movement; Massive rejected.
## Autotest calls run_full_matrix() — does not rely on a long battle sim.
## Detection AND assertions use center-to-center meters (same reference as the mechanic).

const TRACE_PREFIX := "scenario_46"
const _Concealment := preload("res://scripts/concealment.gd")
const _Proxy := preload("res://scripts/sim/sim_unit_proxy.gd")

var matrix_results: Array = []
var massive_rejected: bool = false


func _spawn_units() -> void:
	var px := Constants.get_float("px_per_meter")
	var inf := UnitProfileLoader.load_profile("test_infantry")
	var u := UNIT_SCENE.instantiate()
	add_child(u)
	u.configure("placeholder", "blue", inf, Vector2.ZERO, Vector2.RIGHT)
	_units.append(u)
	u.set_render_camera(_camera)


func _ready() -> void:
	super._ready()
	_ensure_sim_core()
	_sim_core.battle_type = "ambush"


func run_full_matrix() -> Dictionary:
	matrix_results.clear()
	massive_rejected = false
	var profiles: Array = ["Low", "Medium", "High"]
	var patches: Array = ["FOREST", "SHRUB"]
	for patch_type in patches:
		for prof in profiles:
			for moving in [false, true]:
				var got: float = _measure_detect_m(str(prof), str(patch_type), bool(moving))
				var base: float = (
					Constants.get_float("forest_detect_radius_m")
					if patch_type == "FOREST"
					else Constants.get_float("shrub_detect_radius_m")
				)
				var pmult: float = _profile_mult(str(prof))
				var mm: float = Constants.get_float("concealment_moving_detect_mult") if moving else 1.0
				var expected: float = base * pmult * mm
				# Stepping 0.5m: reveal when distance <= expected ⇒ got in (expected-0.5, expected].
				var ok := got > 0.0 and got <= expected + 0.05 and got > expected - 0.55
				matrix_results.append({
					"profile": prof,
					"patch": patch_type,
					"moving": moving,
					"expected_m": expected,
					"got_m": got,
					"ok": ok,
				})
	massive_rejected = _assert_massive_cannot_conceal()
	return {
		"rows": matrix_results,
		"massive_rejected": massive_rejected,
		"all_ok": _all_rows_ok() and massive_rejected,
	}


func _all_rows_ok() -> bool:
	for row in matrix_results:
		if not bool(row.get("ok", false)):
			return false
	return matrix_results.size() == 12


func _profile_mult(prof: String) -> float:
	match prof:
		"Low":
			return Constants.get_float("concealment_profile_mult_low")
		"High":
			return Constants.get_float("concealment_profile_mult_high")
		_:
			return Constants.get_float("concealment_profile_mult_medium")


func _measure_detect_m(prof: String, patch_type: String, moving: bool) -> float:
	## Returns center-to-center distance at the reveal tick.
	var core = _SimBattleCore.new()
	core.configure_rng(1000)
	core.headless_mode = true
	core.fast_sim_mode = true
	core.force_trace_logging = true
	var patch := {"type": patch_type, "x": -80.0, "y": -80.0, "w": 160.0, "h": 160.0}
	core.terrain_patches = [patch]

	var base_prof: Dictionary
	if prof == "Low":
		base_prof = UnitProfileLoader.load_profile("test_skirmisher").duplicate(true)
	elif prof == "High":
		base_prof = UnitProfileLoader.load_profile("test_cavalry").duplicate(true)
	else:
		base_prof = UnitProfileLoader.load_profile("test_infantry").duplicate(true)
	base_prof["profile"] = prof
	base_prof["formation_frontage_m"] = 10.0
	base_prof["formation_depth_m"] = 8.0

	var hid = _Proxy.from_unit(_make_temp_unit("hidden", "blue", base_prof, Vector2.ZERO, Vector2.RIGHT))
	hid.starting_posture = "concealed"
	var probe_prof := UnitProfileLoader.load_profile("test_infantry").duplicate(true)
	probe_prof["formation_frontage_m"] = 8.0
	probe_prof["formation_depth_m"] = 8.0
	var start_d: float = 80.0
	var px := Constants.get_float("px_per_meter")
	var probe = _Proxy.from_unit(
		_make_temp_unit("probe", "red", probe_prof, Vector2(start_d * px, 0.0), Vector2.LEFT)
	)
	core.units = [hid, probe]
	core.apply_starting_concealment_if_needed()
	if not hid.concealed:
		return -1.0

	var tick_interval := 1.0 / Constants.get_float("tick_rate_per_sec")
	if moving:
		hid.current_order = Unit.Order.MARCH_TO
		hid.march_target = probe.position
		hid._set_state(Unit.State.MARCHING)
	else:
		hid.current_order = Unit.Order.HOLD
		hid._set_state(Unit.State.HOLD)
		hid.current_speed_m_s = 0.0

	for _i in 2000:
		if not hid.concealed:
			break
		if moving:
			var dir: Vector2 = (probe.position - hid.position).normalized()
			var step_m: float = 0.5
			hid.position += dir * step_m * px
			hid.current_speed_m_s = step_m / tick_interval
		else:
			var dir2: Vector2 = (hid.position - probe.position).normalized()
			var step_m2: float = 0.5
			probe.position += dir2 * step_m2 * px
			hid.current_speed_m_s = 0.0
		core.sim_tick_count += 1
		core.tick_concealment(tick_interval)
	if hid.concealed:
		return -2.0
	return _Concealment.distance_m(hid, probe)


func _assert_massive_cannot_conceal() -> bool:
	var core = _SimBattleCore.new()
	core.configure_rng(1000)
	core.headless_mode = true
	core.fast_sim_mode = true
	core.terrain_patches = [{"type": "FOREST", "x": -80.0, "y": -80.0, "w": 160.0, "h": 160.0}]
	var prof := UnitProfileLoader.load_profile("test_infantry").duplicate(true)
	prof["profile"] = "Massive"
	prof["id"] = "test_massive"
	prof["formation_frontage_m"] = 10.0
	prof["formation_depth_m"] = 8.0
	var u = _Proxy.from_unit(
		_make_temp_unit("elephant", "blue", prof, Vector2.ZERO, Vector2.RIGHT)
	)
	u.starting_posture = "concealed"
	core.units = [u]
	core.apply_starting_concealment_if_needed()
	return not u.concealed


func _make_temp_unit(uid: String, team: String, profile: Dictionary, pos: Vector2, facing: Vector2) -> Unit:
	var u: Unit = UNIT_SCENE.instantiate()
	add_child(u)
	u.configure(uid, team, profile, pos, facing)
	u.visible = false
	return u


func _write_trace_file() -> void:
	pass
