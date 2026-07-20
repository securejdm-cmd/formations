class_name Scenario43
extends Scenario01

## S43 — The Horn (WO-031): losing engagement; horn at T saves men vs no-horn control.
## Layout matches team-edge convention: red left / blue right.

const TRACE_PREFIX := "scenario_43"

@export var horn_at_sec: float = 35.0
@export var use_horn: bool = true

var _blue_a: Unit = null
var _blue_b: Unit = null
var _red_a: Unit = null
var _red_b: Unit = null
## Strength at removal / end for fair "men saved" accounting.
var _blue_final_str: Dictionary = {}


func _spawn_units() -> void:
	var px := Constants.get_float("px_per_meter")
	var weak := UnitProfileLoader.load_profile("test_infantry_push40")
	var strong := UnitProfileLoader.load_profile("test_infantry_push60")

	# Blue (right) — losing side; retreats toward +x own edge on horn.
	_blue_a = UNIT_SCENE.instantiate()
	add_child(_blue_a)
	_blue_a.configure("blue_a", "blue", weak, Vector2(50.0 * px, -20.0 * px), Vector2.LEFT)
	_blue_a.set_order_queue([
		{
			"primitive": "advance_to",
			"params": {"point": {"x": -40.0, "y": -20.0}},
			"trigger": {"type": "at_start"},
		},
	])
	_units.append(_blue_a)

	_blue_b = UNIT_SCENE.instantiate()
	add_child(_blue_b)
	_blue_b.configure("blue_b", "blue", weak, Vector2(50.0 * px, 20.0 * px), Vector2.LEFT)
	_blue_b.set_order_queue([
		{
			"primitive": "advance_to",
			"params": {"point": {"x": -40.0, "y": 20.0}},
			"trigger": {"type": "at_start"},
		},
	])
	_units.append(_blue_b)

	# Red (left) — winning push.
	_red_a = UNIT_SCENE.instantiate()
	add_child(_red_a)
	_red_a.configure("red_a", "red", strong, Vector2(-50.0 * px, -20.0 * px), Vector2.RIGHT)
	_red_a.set_order_queue([
		{
			"primitive": "advance_to",
			"params": {"point": {"x": 40.0, "y": -20.0}},
			"trigger": {"type": "at_start"},
		},
	])
	_units.append(_red_a)

	_red_b = UNIT_SCENE.instantiate()
	add_child(_red_b)
	_red_b.configure("red_b", "red", strong, Vector2(-50.0 * px, 20.0 * px), Vector2.RIGHT)
	_red_b.set_order_queue([
		{
			"primitive": "advance_to",
			"params": {"point": {"x": 40.0, "y": 20.0}},
			"trigger": {"type": "at_start"},
		},
	])
	_units.append(_red_b)

	for unit in _units:
		unit.set_render_camera(_camera)


func _ready() -> void:
	super._ready()
	_ensure_sim_core()
	_sim_core.battle_type = "pitched"
	if use_horn:
		_sim_core.schedule_horn("blue", horn_at_sec)


func advance_one_tick() -> void:
	super.advance_one_tick()
	for u in [_blue_a, _blue_b]:
		if u == null:
			continue
		_blue_final_str[str(u.unit_id)] = float(u.strength)


func _write_trace_file() -> void:
	var tag := "horn" if use_horn else "control"
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%s_%d.csv" % [tag, _battle_seed]
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
	print("[Scenario 43] Trace written: %s" % file_path)


func blue_surviving_strength() -> float:
	## Men remaining: live units' strength, else last known strength before removal.
	var total := 0.0
	for u in [_blue_a, _blue_b]:
		if u == null:
			continue
		if u.get_state() == Unit.State.REMOVED:
			total += float(_blue_final_str.get(str(u.unit_id), 0.0))
		else:
			total += maxf(u.strength, 0.0)
	return total


func get_horn_disengage_costs() -> Dictionary:
	_ensure_sim_core()
	return _sim_core.horn_disengage_cost.duplicate()
