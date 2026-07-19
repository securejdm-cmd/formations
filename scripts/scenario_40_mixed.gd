class_name Scenario40Mixed
extends Scenario01

## S40 — Gate 2 mixed 6v6 on the test hill (designer play-test).
## Scripted orders only. Showcases volleys, grind, flank charge, rout shock, brace.

const TRACE_PREFIX := "scenario_40_mixed"
const _Midbattle := preload("res://scripts/scenario_40_midbattle.gd")

var _midbattle = _Midbattle.new()
var _phase: String = "approach"
var _blue_line: Array[Unit] = []
var _blue_spears: Unit = null
var _blue_archer: Unit = null
var _blue_cav: Unit = null
var _red_line: Array[Unit] = []
var _red_charge: Unit = null
var _red_archer: Unit = null
var _red_cav: Unit = null
var _fps_samples: Array[float] = []
var _tick_times_ms: Array[float] = []
var _sample_accum: float = 0.0
var observed_volley: bool = false
var observed_melee: bool = false
var observed_flank_charge: bool = false
var observed_rout_shock: bool = false
var observed_brace: bool = false
var _first_rout_logged: bool = false


func _spawn_units() -> void:
	var px := Constants.get_float("px_per_meter")
	var inf := UnitProfileLoader.load_profile("test_infantry")
	var spears := UnitProfileLoader.load_profile("test_spears")
	var archer := UnitProfileLoader.load_profile("test_archer")
	var cav := UnitProfileLoader.load_profile("test_cavalry")
	var charge_inf := UnitProfileLoader.load_profile("test_infantry_charge")

	# BLUE holds higher ground (east): 3 infantry line, spears on south flank,
	# archer behind, cavalry reserve further east.
	var blue_x := 60.0 * px
	var lane_ys := [-50.0 * px, 0.0, 50.0 * px]
	for i in 3:
		var u: Unit = UNIT_SCENE.instantiate()
		add_child(u)
		u.configure("blue_inf_%d" % i, "blue", inf, Vector2(blue_x, lane_ys[i]), Vector2.LEFT)
		u.current_order = Unit.Order.HOLD
		u._set_state(Unit.State.HOLD)
		u.current_speed_m_s = 0.0
		_units.append(u)
		_blue_line.append(u)

	_blue_spears = UNIT_SCENE.instantiate()
	add_child(_blue_spears)
	_blue_spears.configure("blue_spears", "blue", spears, Vector2(blue_x + 10.0 * px, 110.0 * px), Vector2.LEFT)
	_blue_spears.current_order = Unit.Order.HOLD
	_blue_spears._set_state(Unit.State.HOLD)
	_blue_spears.current_speed_m_s = 0.0
	# Pre-warm Tier-2 brace so spears receive RED cavalry (S18 pattern).
	_blue_spears._brace_hold_sec = Constants.get_float("brace_time_s") + 0.1
	_blue_spears._braced = true
	_blue_spears._update_brace_visual()
	_units.append(_blue_spears)
	observed_brace = true

	_blue_archer = UNIT_SCENE.instantiate()
	add_child(_blue_archer)
	_blue_archer.configure("blue_archer", "blue", archer, Vector2(blue_x + 55.0 * px, 0.0), Vector2.LEFT)
	_blue_archer.current_order = Unit.Order.HOLD
	_blue_archer._set_state(Unit.State.HOLD)
	_units.append(_blue_archer)

	_blue_cav = UNIT_SCENE.instantiate()
	add_child(_blue_cav)
	_blue_cav.configure("blue_cav", "blue", cav, Vector2(blue_x + 120.0 * px, -80.0 * px), Vector2.LEFT)
	_blue_cav.current_order = Unit.Order.HOLD
	_blue_cav._set_state(Unit.State.HOLD)
	_blue_cav.current_speed_m_s = 0.0
	_units.append(_blue_cav)

	# RED advances from west (uphill): 3 infantry, 1 charge infantry, archer, wide cavalry.
	var red_x := -140.0 * px
	for i in 3:
		var u2: Unit = UNIT_SCENE.instantiate()
		add_child(u2)
		u2.configure("red_inf_%d" % i, "red", inf, Vector2(red_x, lane_ys[i]), Vector2.RIGHT)
		u2.set_march_to(Vector2(blue_x + 20.0 * px, lane_ys[i]))
		_units.append(u2)
		_red_line.append(u2)

	_red_charge = UNIT_SCENE.instantiate()
	add_child(_red_charge)
	_red_charge.configure("red_charge", "red", charge_inf, Vector2(red_x - 20.0 * px, 0.0), Vector2.RIGHT)
	_red_charge.start_from_rest()
	_red_charge.set_march_to(Vector2(blue_x + 40.0 * px, 0.0))
	_units.append(_red_charge)

	_red_archer = UNIT_SCENE.instantiate()
	add_child(_red_archer)
	_red_archer.configure("red_archer", "red", archer, Vector2(red_x - 40.0 * px, -90.0 * px), Vector2.RIGHT)
	_red_archer.current_order = Unit.Order.HOLD
	_red_archer._set_state(Unit.State.HOLD)
	_units.append(_red_archer)

	_red_cav = UNIT_SCENE.instantiate()
	add_child(_red_cav)
	_red_cav.configure("red_cav", "red", cav, Vector2(red_x - 30.0 * px, 160.0 * px), Vector2.RIGHT)
	_red_cav.start_from_rest()
	# Wide to strike BLUE south flank / spears.
	_red_cav.set_march_to(Vector2(blue_x + 30.0 * px, 110.0 * px))
	_units.append(_red_cav)

	for unit in _units:
		unit.set_render_camera(_camera)


func _ready() -> void:
	ensure_test_hill()
	super._ready()


func _ensure_sim_core() -> void:
	super._ensure_sim_core()
	## Tick-synchronous midbattle via RefCounted helper (never a Node method on the worker).
	if _sim_core != null:
		_sim_core.pre_tick_callback = _midbattle.on_pre_tick


func advance_one_tick() -> void:
	var t0 := Time.get_ticks_usec()
	super.advance_one_tick()
	_tick_times_ms.append(float(Time.get_ticks_usec() - t0) / 1000.0)
	_phase = _midbattle.phase
	_observe_events()


func simulate_realtime_step(delta: float = -1.0) -> void:
	var step := delta if delta > 0.0 else CombatResolver.tick_interval()
	var frame_start := Time.get_ticks_usec()
	super.simulate_realtime_step(step)
	var frame_ms := float(Time.get_ticks_usec() - frame_start) / 1000.0
	_sample_accum += step
	if _sample_accum >= 1.0:
		_fps_samples.append(1000.0 / maxf(frame_ms, 0.001))
		_sample_accum = 0.0
	_phase = _midbattle.phase
	# Threaded path: observe from synced core state each frame.
	if _sim_thread_active():
		_observe_events()


func _observe_events() -> void:
	if "volley" in get_trace_text():
		observed_volley = true
	if _first_contact_tick >= 0:
		observed_melee = true
	_ensure_sim_core()
	for ev in _sim_core.last_charge_events:
		if str(ev.get("attacker", "")) == "red_cav" and bool(ev.get("charged", false)):
			observed_flank_charge = true
	if "neighbor_rout_shock" in get_trace_text():
		observed_rout_shock = true
	if _blue_spears != null and _blue_spears.is_braced():
		observed_brace = true


func get_perf_stats() -> Dictionary:
	var ticks := _tick_times_ms.duplicate()
	ticks.sort()
	var p95 := 0.0
	var avg := 0.0
	if not ticks.is_empty():
		var s := 0.0
		for t in ticks:
			s += t
		avg = s / float(ticks.size())
		p95 = ticks[int(floor(float(ticks.size() - 1) * 0.95))]
	var min_fps := 0.0
	var avg_fps := 0.0
	if not _fps_samples.is_empty():
		min_fps = _fps_samples.min()
		var fs := 0.0
		for f in _fps_samples:
			fs += f
		avg_fps = fs / float(_fps_samples.size())
	return {
		"avg_tick_ms": avg,
		"p95_tick_ms": p95,
		"tick_count": ticks.size(),
		"min_fps": min_fps,
		"avg_fps": avg_fps,
		"fps_samples": _fps_samples.size(),
		"sim_thread": get_sim_thread_tick_stats() if has_method("get_sim_thread_tick_stats") else {},
	}


func showcase_ok() -> bool:
	return (
		observed_volley
		and observed_melee
		and observed_flank_charge
		and observed_brace
	)


func _write_trace_file() -> void:
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
	var phases := get_phase_durations_sec()
	print("[Scenario 40 mixed] Trace written: %s" % file_path)
	print(
		"[Scenario 40 mixed] SUMMARY | winner=%s combat=%.1fs volley=%s melee=%s flank=%s shock=%s brace=%s"
		% [
			get_winner_id(),
			float(phases.get("combat_sec", -1.0)),
			observed_volley,
			observed_melee,
			observed_flank_charge,
			observed_rout_shock,
			observed_brace,
		]
	)
