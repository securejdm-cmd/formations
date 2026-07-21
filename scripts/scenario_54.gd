class_name Scenario54
extends Scenario01

## S54 — Deception window (WO-033): enemy-visible ROUTING for ~2s; unit_routs never fires.

const TRACE_PREFIX := "scenario_54"

var window_samples: Array = []
var enemy_routs_fired: bool = false
var window_s: float = 2.0


func _spawn_units() -> void:
	var px := Constants.get_float("px_per_meter")
	var high := UnitProfileLoader.load_profile("test_infantry").duplicate(true)
	high["retreating_skill"] = 95.0
	var feint := UNIT_SCENE.instantiate()
	add_child(feint)
	feint.configure("decoy", "blue", high, Vector2(0.0, 0.0), Vector2.RIGHT)
	feint.set_order_queue([
		{
			"primitive": "feign_retreat",
			"params": {"dist": 60.0},
			"trigger": {"type": "at_start"},
		},
	])
	_units.append(feint)

	var enemy := UNIT_SCENE.instantiate()
	add_child(enemy)
	enemy.configure("observer", "red", UnitProfileLoader.load_profile("test_infantry"), Vector2(90.0 * px, 0.0), Vector2.LEFT)
	# Enemy waits on unit_routs(enemy) — must NOT fire on feign.
	enemy.set_order_queue([
		{
			"primitive": "hold",
			"params": {},
			"trigger": {"type": "at_start"},
		},
		{
			"primitive": "attack_nearest",
			"params": {},
			"trigger": {"type": "unit_routs", "scope": "enemy"},
		},
	])
	_units.append(enemy)

	for unit in _units:
		unit.set_render_camera(_camera)


func _ready() -> void:
	super._ready()
	_ensure_sim_core()
	window_s = Constants.get_float("feign_deception_window_s")


func advance_one_tick() -> void:
	super.advance_one_tick()
	_ensure_sim_core()
	var t: float = _sim_core.sim_tick_count * (1.0 / Constants.get_float("tick_rate_per_sec"))
	var decoy = null
	var observer = null
	for u in _sim_core.units:
		if str(u.unit_id) == "decoy":
			decoy = u
		elif str(u.unit_id) == "observer":
			observer = u
	if decoy == null:
		return
	var sample := {
		"t": t,
		"true_state": decoy.get_state_name(),
		"enemy_visible": decoy.get_enemy_visible_state_name(),
		"feign_active": decoy.feign_active,
		"deception_left": decoy.feign_deception_remaining_s,
	}
	window_samples.append(sample)
	# Detect if observer's unit_routs trigger released attack_nearest.
	if observer != null:
		if (
			str(observer.order_primitive) == "attack_nearest"
			and str(observer.order_phase) in ["executing", "terminal"]
			and int(observer.order_step_index) >= 1
		):
			enemy_routs_fired = true


func deception_ok() -> bool:
	## While deception_left > 0: enemy_visible == routing; true_state != routing.
	## After window while still feigning: enemy_visible is ordered (not routing).
	if window_samples.is_empty():
		return false
	var saw_window := false
	var saw_after := false
	for s in window_samples:
		var vis: String = str(s.get("enemy_visible", ""))
		var true_st: String = str(s.get("true_state", ""))
		var left: float = float(s.get("deception_left", 0.0))
		var feign: bool = bool(s.get("feign_active", false))
		if true_st == "routing":
			return false
		if left > 0.0:
			saw_window = true
			if vis != "routing":
				return false
		elif feign:
			saw_after = true
			if vis == "routing":
				return false
	return saw_window and saw_after and not enemy_routs_fired


func _write_trace_file() -> void:
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
