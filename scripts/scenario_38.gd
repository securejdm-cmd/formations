class_name Scenario38
extends Scenario01

## S38 — Missile high ground: same archer profile, downhill vs uphill first volley.

const TRACE_PREFIX := "scenario_38"

var _archer_down: Unit = null
var _tgt_down: Unit = null
var _archer_up: Unit = null
var _tgt_up: Unit = null
var first_volley_down_m: float = -1.0
var first_volley_up_m: float = -1.0


func _ready() -> void:
	ensure_test_hill()
	super._ready()


func _spawn_units() -> void:
	var archer_p := UnitProfileLoader.load_profile("test_archer")
	var inf_p := UnitProfileLoader.load_profile("test_infantry")
	var px := Constants.get_float("px_per_meter")
	var start_gap_m := 200.0

	# Downhill shot: archer faces west (downslope), target marches up from west.
	_archer_down = UNIT_SCENE.instantiate()
	add_child(_archer_down)
	_archer_down.configure("red_archer_down", "red", archer_p, Vector2(0.0, -90.0 * px), Vector2.LEFT)
	_archer_down.current_order = Unit.Order.HOLD
	_archer_down._set_state(Unit.State.HOLD)
	_units.append(_archer_down)

	_tgt_down = UNIT_SCENE.instantiate()
	add_child(_tgt_down)
	_tgt_down.configure(
		"blue_tgt_down",
		"blue",
		inf_p,
		Vector2(-start_gap_m * px, -90.0 * px),
		Vector2.RIGHT
	)
	_tgt_down.set_march_to(Vector2(20.0 * px, -90.0 * px))
	_units.append(_tgt_down)

	# Uphill shot: archer faces east (upslope), target marches down from east.
	_archer_up = UNIT_SCENE.instantiate()
	add_child(_archer_up)
	_archer_up.configure("red_archer_up", "red", archer_p, Vector2(0.0, 90.0 * px), Vector2.RIGHT)
	_archer_up.current_order = Unit.Order.HOLD
	_archer_up._set_state(Unit.State.HOLD)
	_units.append(_archer_up)

	_tgt_up = UNIT_SCENE.instantiate()
	add_child(_tgt_up)
	_tgt_up.configure(
		"blue_tgt_up",
		"blue",
		inf_p,
		Vector2(start_gap_m * px, 90.0 * px),
		Vector2.LEFT
	)
	_tgt_up.set_march_to(Vector2(-20.0 * px, 90.0 * px))
	_units.append(_tgt_up)

	for unit in _units:
		unit.set_render_camera(_camera)


func advance_one_tick() -> void:
	super.advance_one_tick()
	_capture_first_volleys()


func _capture_first_volleys() -> void:
	if first_volley_down_m < 0.0 or first_volley_up_m < 0.0:
		for line in _trace_lines:
			if not line.contains("EVENT,volley,"):
				continue
			if first_volley_down_m < 0.0 and line.contains("shooter=red_archer_down,"):
				var idx := line.find("dist_m=")
				if idx >= 0:
					first_volley_down_m = float(line.substr(idx + 7).split(",")[0])
			if first_volley_up_m < 0.0 and line.contains("shooter=red_archer_up,"):
				var idx2 := line.find("dist_m=")
				if idx2 >= 0:
					first_volley_up_m = float(line.substr(idx2 + 7).split(",")[0])
	if first_volley_down_m >= 0.0 and first_volley_up_m >= 0.0 and _sim_core != null:
		if _sim_tick_count > 50:
			_sim_core.battle_over = true
			_battle_over = true


func _write_trace_file() -> void:
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
	print("[Scenario 38] Trace written: %s" % file_path)
	print(
		"[Scenario 38] SUMMARY | down_first=%.1fm up_first=%.1fm"
		% [first_volley_down_m, first_volley_up_m]
	)
