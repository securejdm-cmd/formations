class_name Scenario45
extends Scenario01

## S45 — Teutoburg ambush (WO-032): concealed flank charge vs visible control.
## use_concealment=true → posture concealed; false → identical layout visible.

const TRACE_PREFIX := "scenario_45"

@export var use_concealment: bool = true

var _column: Unit = null
var _ambusher_a: Unit = null
var _ambusher_b: Unit = null

var observed_brace_tier: int = -1
var observed_charge_edge: String = ""
var reveal_time_sec: float = -1.0
var reveal_reason: String = ""


func _spawn_units() -> void:
	var px := Constants.get_float("px_per_meter")
	var inf := UnitProfileLoader.load_profile("test_infantry")
	var cav := UnitProfileLoader.load_profile("test_cavalry")

	# Victim column marches north along the road (x≈0).
	_column = UNIT_SCENE.instantiate()
	add_child(_column)
	_column.configure("column", "red", inf, Vector2(0.0, 120.0 * px), Vector2.UP)
	_column.set_order_queue([
		{
			"primitive": "advance_to",
			"params": {"point": {"x": 0.0, "y": -80.0}},
			"trigger": {"type": "at_start"},
		},
	])
	_units.append(_column)

	# Forest strip east of the road corridor. Ambusher centers deep enough that
	# stationary High detect (15m) does not fire while the column is distant,
	# but leave/detection on the charge keeps reveal inside brace_reaction_s.
	var forest := {
		"type": "FOREST",
		"x": 18.0,
		"y": -100.0,
		"w": 90.0,
		"h": 200.0,
	}
	set_terrain_patches([forest])

	_ambusher_a = UNIT_SCENE.instantiate()
	add_child(_ambusher_a)
	# Just inside the forest edge (x≈22m); facing west toward the road.
	_ambusher_a.configure("ambush_cav_a", "blue", cav, Vector2(28.0 * px, 20.0 * px), Vector2.LEFT)
	_ambusher_a.start_from_rest()
	if use_concealment:
		_ambusher_a.starting_posture = "concealed"
	else:
		_ambusher_a.starting_posture = "normal"
	_ambusher_a.set_order_queue([
		{
			"primitive": "hold",
			"params": {},
			"trigger": {"type": "at_start"},
		},
		{
			"primitive": "swing_and_charge",
			"params": {"side": "left", "target": "column", "flank_arc_offset_m": 55.0},
			"trigger": {"type": "enemy_within", "x_m": 45.0},
		},
	])
	_units.append(_ambusher_a)

	_ambusher_b = UNIT_SCENE.instantiate()
	add_child(_ambusher_b)
	_ambusher_b.configure("ambush_cav_b", "blue", cav, Vector2(32.0 * px, -20.0 * px), Vector2.LEFT)
	_ambusher_b.start_from_rest()
	if use_concealment:
		_ambusher_b.starting_posture = "concealed"
	else:
		_ambusher_b.starting_posture = "normal"
	_ambusher_b.set_order_queue([
		{
			"primitive": "hold",
			"params": {},
			"trigger": {"type": "at_start"},
		},
		{
			"primitive": "swing_and_charge",
			"params": {"side": "right", "target": "column", "flank_arc_offset_m": 55.0},
			"trigger": {"type": "enemy_within", "x_m": 45.0},
		},
	])
	_units.append(_ambusher_b)

	for unit in _units:
		unit.set_render_camera(_camera)


func _ready() -> void:
	super._ready()
	_ensure_sim_core()
	_sim_core.battle_type = "ambush" if use_concealment else "pitched"
	_sim_core.victory_spec = {"mode": "rout"}
	_render_terrain_patches()


func advance_one_tick() -> void:
	super.advance_one_tick()
	_observe()


func _observe() -> void:
	_ensure_sim_core()
	if reveal_time_sec < 0.0:
		for line in _sim_core.trace_lines:
			if "EVENT,reveal," in line and "ambush_cav" in line:
				var parts: PackedStringArray = line.split(",")
				if parts.size() >= 1:
					reveal_time_sec = float(parts[0])
				if "reason=" in line:
					var idx: int = line.find("reason=")
					reveal_reason = line.substr(idx + 7).split(",")[0]
				break
	for ev in _sim_core.last_charge_events:
		var att: String = str(ev.get("attacker", ""))
		if not att.begins_with("ambush_cav"):
			continue
		if not bool(ev.get("charged", false)):
			continue
		observed_brace_tier = int(ev.get("brace_tier", -1))
		observed_charge_edge = str(ev.get("edge", ""))
		break


func _write_trace_file() -> void:
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
	print("[Scenario 45] Trace written: %s" % file_path)


func column_cohesion() -> float:
	if _column == null:
		return -1.0
	return _column.cohesion


func column_strength() -> float:
	if _column == null:
		return -1.0
	return _column.strength


func get_brace_tier() -> int:
	return observed_brace_tier


func get_charge_edge() -> String:
	return observed_charge_edge


func get_reveal_time() -> float:
	return reveal_time_sec


func ambusher_was_concealed_at_start() -> bool:
	_ensure_sim_core()
	# After first tick concealment is applied; check ever_revealed / starting posture path
	# via whether a reveal event exists when use_concealment, or proxy state early.
	for u in _sim_core.units:
		if str(u.unit_id).begins_with("ambush_cav"):
			# If still concealed or was revealed later, start succeeded.
			if u.concealed or u.ever_revealed or str(u.starting_posture) == "concealed":
				return use_concealment
	return false
