class_name Scenario34
extends Scenario01

## S34 — Pinning (R19): A engaged frontally by B; C hits A's LEFT — A must not reface.

const TRACE_PREFIX := "scenario_34"

var _a: Unit = null
var _b: Unit = null
var _c: Unit = null
var _phase: String = "front_engage"
var edge_samples: Array = []  # {t, edge, mult, a_facing_dot_to_c}
var flank_persisted: bool = false
var a_did_not_reface: bool = false


func _spawn_units() -> void:
	var inf_p := UnitProfileLoader.load_profile("test_infantry")
	var px := Constants.get_float("px_per_meter")
	var half := 50.0 * px

	_a = UNIT_SCENE.instantiate()
	add_child(_a)
	_a.configure("blue_a", "blue", inf_p, Vector2.ZERO, Vector2.LEFT)
	_a.current_order = Unit.Order.HOLD
	_a._set_state(Unit.State.HOLD)
	_units.append(_a)

	_b = UNIT_SCENE.instantiate()
	add_child(_b)
	_b.configure("red_b", "red", inf_p, Vector2(-half, 0.0), Vector2.RIGHT)
	_b.set_march_to(Vector2(20.0 * px, 0.0))
	_units.append(_b)

	_c = UNIT_SCENE.instantiate()
	add_child(_c)
	# A faces LEFT (-X). FormationGeometry.left_vector((-1,0)) = (0, +1) → LEFT edge is +Y.
	_c.configure("red_c", "red", inf_p, Vector2(0.0, half), Vector2.UP)
	_c.current_order = Unit.Order.HOLD
	_c._set_state(Unit.State.HOLD)
	_c.current_speed_m_s = 0.0
	_units.append(_c)

	for unit in _units:
		unit.set_render_camera(_camera)


func advance_one_tick() -> void:
	super.advance_one_tick()
	if _a == null:
		return
	match _phase:
		"front_engage":
			if _a.has_contact_with(_b):
				_c.set_march_to(_a.position + Vector2(0.0, -10.0 * Constants.get_float("px_per_meter")))
				_phase = "flank"
		"flank":
			if _a.has_contact_with(_c):
				_phase = "sample"
		"sample":
			var info: Dictionary = EdgeContact.classify_contact(_c, _a)
			var edges: Dictionary = info.get("edge_lengths_m", {})
			var morale: Dictionary = ChargeCombat.charge_edge_morale_mult(_c, _a, edges)
			var edge := str(morale.get("edge", ""))
			var mult := float(morale.get("mult", 0.0))
			var to_c: Vector2 = (_c.position - _a.position).normalized()
			var dot := _a.facing.normalized().dot(to_c)
			edge_samples.append({
				"t": _sim_tick_count * CombatResolver.tick_interval(),
				"edge": edge,
				"mult": mult,
				"a_facing_dot_to_c": dot,
			})
			if edge_samples.size() >= 20:
				var leftish := 0
				var max_dot := -2.0
				for row in edge_samples:
					if str(row.get("edge", "")) == EdgeContact.EDGE_LEFT or float(row.get("mult", 0.0)) >= 1.4:
						leftish += 1
					max_dot = maxf(max_dot, float(row.get("a_facing_dot_to_c", -2.0)))
				flank_persisted = leftish >= 15
				# If A refaced toward C, facing·to_c would approach +1.
				a_did_not_reface = max_dot < 0.5
				_phase = "done"
				_sim_core.battle_over = true
				_battle_over = true


func _write_trace_file() -> void:
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
	print("[Scenario 34] Trace written: %s" % file_path)
