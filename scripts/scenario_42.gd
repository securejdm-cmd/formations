class_name Scenario42
extends Scenario01

## S42 — Cannae (WO-031): feign center + wing envelopment + rear cavalry.
## Wings trigger via unit_order_started(center, feign_retreat) — coupled to the
## center's enemy_within(30) rather than a brittle after_seconds constant.

const TRACE_PREFIX := "scenario_42"

var _center: Unit = null
var _wing_l: Unit = null
var _wing_r: Unit = null
var _cavalry: Unit = null
var _enemy: Unit = null

var edges_seen: Dictionary = {}  # edge -> count from charge + contact
var enemy_cohesion_min: float = 100.0
var cascade_events: int = 0


func _spawn_units() -> void:
	var px := Constants.get_float("px_per_meter")
	var inf := UnitProfileLoader.load_profile("test_infantry")
	var cav := UnitProfileLoader.load_profile("test_cavalry")

	_center = UNIT_SCENE.instantiate()
	add_child(_center)
	_center.configure("center", "blue", inf, Vector2.ZERO, Vector2.RIGHT)
	_center.set_order_queue([
		{
			"primitive": "feign_retreat",
			"params": {"dist": 40.0},
			"trigger": {"type": "enemy_within", "x": 30.0},
		},
	])
	_units.append(_center)

	_wing_l = UNIT_SCENE.instantiate()
	add_child(_wing_l)
	_wing_l.configure("wing_l", "blue", inf, Vector2(-10.0 * px, -55.0 * px), Vector2.RIGHT)
	_wing_l.set_order_queue([
		{
			"primitive": "advance_to",
			"params": {"point": {"x": 35.0, "y": -25.0}},
			"trigger": {
				"type": "unit_order_started",
				"unit": "center",
				"primitive": "feign_retreat",
			},
		},
	])
	_units.append(_wing_l)

	_wing_r = UNIT_SCENE.instantiate()
	add_child(_wing_r)
	_wing_r.configure("wing_r", "blue", inf, Vector2(-10.0 * px, 55.0 * px), Vector2.RIGHT)
	_wing_r.set_order_queue([
		{
			"primitive": "advance_to",
			"params": {"point": {"x": 35.0, "y": 25.0}},
			"trigger": {
				"type": "unit_order_started",
				"unit": "center",
				"primitive": "feign_retreat",
			},
		},
	])
	_units.append(_wing_r)

	_cavalry = UNIT_SCENE.instantiate()
	add_child(_cavalry)
	_cavalry.configure("seal_cav", "blue", cav, Vector2(-80.0 * px, 0.0), Vector2.RIGHT)
	_cavalry.start_from_rest()
	_cavalry.set_order_queue([
		{
			"primitive": "swing_and_charge",
			"params": {"side": "left", "target": "enemy_center", "flank_arc_offset_m": 100.0},
			"trigger": {"type": "unit_engages", "unit": "wing_l"},
		},
	])
	_units.append(_cavalry)

	_enemy = UNIT_SCENE.instantiate()
	add_child(_enemy)
	_enemy.configure("enemy_center", "red", inf, Vector2(100.0 * px, 0.0), Vector2.LEFT)
	_enemy.set_order_queue([
		{
			"primitive": "advance_to",
			"params": {"point": {"x": -60.0, "y": 0.0}},
			"trigger": {"type": "at_start"},
		},
	])
	_units.append(_enemy)

	for unit in _units:
		unit.set_render_camera(_camera)


func _ready() -> void:
	super._ready()
	_ensure_sim_core()
	_sim_core.battle_type = "pitched"
	_sim_core.victory_spec = {"mode": "rout"}


func advance_one_tick() -> void:
	super.advance_one_tick()
	_observe()


func _observe() -> void:
	if _enemy != null:
		enemy_cohesion_min = minf(enemy_cohesion_min, _enemy.cohesion)
	_ensure_sim_core()
	for ev in _sim_core.last_charge_events:
		var edge: String = str(ev.get("edge", ""))
		if edge.is_empty():
			continue
		edges_seen[edge] = int(edges_seen.get(edge, 0)) + 1
	# Contact edges on enemy
	if _sim_core != null:
		for u in _sim_core.units:
			if str(u.unit_id) != "enemy_center":
				continue
			var edges: String = str(u.get_active_contact_edges())
			for part in edges.split("+"):
				var e: String = str(part).strip_edges()
				if e.is_empty():
					continue
				edges_seen[e] = int(edges_seen.get(e, 0)) + 1
	# Cascade: neighbor rout shock events in trace
	for line in _sim_core.trace_lines:
		if "neighbor_rout_shock" in str(line):
			cascade_events += 1


func _write_trace_file() -> void:
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
	print("[Scenario 42] Trace written: %s" % file_path)


func get_edges_seen() -> Dictionary:
	return edges_seen.duplicate()


func get_enemy_cohesion_min() -> float:
	return enemy_cohesion_min
