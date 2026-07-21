class_name Scenario53
extends Scenario01

## S53 — Feint backfire (WO-033): low Retreating Skill bleeds into real rout.

const TRACE_PREFIX := "scenario_53"

var cohesion_samples: Array = []
var did_rout: bool = false
var rout_time_sec: float = -1.0


func _spawn_units() -> void:
	var px := Constants.get_float("px_per_meter")
	var low := UnitProfileLoader.load_profile("test_infantry").duplicate(true)
	low["retreating_skill"] = 5.0
	low["id"] = "feint_low"
	# Start already shaken so ordered-retreat drain can tip into rout.
	var feint := UNIT_SCENE.instantiate()
	add_child(feint)
	feint.configure("low_feint", "blue", low, Vector2(0.0, 0.0), Vector2.RIGHT)
	feint.cohesion = 18.0
	feint.set_order_queue([
		{
			"primitive": "feign_retreat",
			"params": {"dist": 80.0},
			"trigger": {"type": "at_start"},
		},
	])
	_units.append(feint)

	# Dummy enemy so the unit has a facing reference / battlefield context.
	var enemy := UNIT_SCENE.instantiate()
	add_child(enemy)
	enemy.configure("watcher", "red", UnitProfileLoader.load_profile("test_infantry"), Vector2(100.0 * px, 0.0), Vector2.LEFT)
	enemy.set_order_queue([
		{"primitive": "hold", "params": {}, "trigger": {"type": "at_start"}},
	])
	_units.append(enemy)

	for unit in _units:
		unit.set_render_camera(_camera)


func _ready() -> void:
	super._ready()
	_ensure_sim_core()


func advance_one_tick() -> void:
	super.advance_one_tick()
	_ensure_sim_core()
	for u in _sim_core.units:
		if str(u.unit_id) != "low_feint":
			continue
		var t: float = _sim_core.sim_tick_count * (1.0 / Constants.get_float("tick_rate_per_sec"))
		cohesion_samples.append({"t": t, "coh": u.cohesion, "state": u.get_state_name()})
		if u.get_state() == Unit.State.ROUTING and not did_rout:
			did_rout = true
			rout_time_sec = t


func _write_trace_file() -> void:
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
