class_name Scenario33
extends Scenario01

## S33 — Gravity square-up: approach ~20° off-axis; expect FRONT/FRONT at contact.

const TRACE_PREFIX := "scenario_33"

var _red: Unit = null
var _blue: Unit = null
var contact_edge_red: String = ""
var contact_edge_blue: String = ""
var red_facing_dot_at_contact: float = -2.0
var blue_facing_dot_at_contact: float = -2.0
## Squared-up rotation achieved (degrees from spawn facing toward contact vector).
var red_rotation_deg: float = 0.0
var blue_rotation_deg: float = 0.0
var _logged: bool = false
var _red_spawn_facing: Vector2 = Vector2.RIGHT
var _blue_spawn_facing: Vector2 = Vector2.LEFT


func _spawn_units() -> void:
	var inf_p := UnitProfileLoader.load_profile("test_infantry")
	var px := Constants.get_float("px_per_meter")
	var half := 50.0 * px
	# ~20° off square: blue offset on Y so approaches are angled.
	var offset_y := tan(deg_to_rad(20.0)) * 50.0 * px

	_red = UNIT_SCENE.instantiate()
	add_child(_red)
	_red.configure("red_1", "red", inf_p, Vector2(-half, 0.0), Vector2.RIGHT)
	_red_spawn_facing = Vector2.RIGHT
	_red.set_march_to(Vector2(half + 20.0 * px, offset_y))
	_units.append(_red)

	_blue = UNIT_SCENE.instantiate()
	add_child(_blue)
	_blue.configure("blue_1", "blue", inf_p, Vector2(half, offset_y), Vector2.LEFT)
	_blue_spawn_facing = Vector2.LEFT
	_blue.set_march_to(Vector2(-half - 20.0 * px, 0.0))
	_units.append(_blue)

	for unit in _units:
		unit.set_render_camera(_camera)


func advance_one_tick() -> void:
	super.advance_one_tick()
	if _logged or _red == null or _blue == null:
		return
	if not _red.has_contact_with(_blue):
		return
	_logged = true
	var contact: Dictionary = EdgeContact.classify_contact(_red, _blue)
	var edges: Dictionary = contact.get("edge_lengths_m", {})
	contact_edge_red = str(edges.keys()[0]) if not edges.is_empty() else ""
	# Dominant edges for each as defender.
	var info_r: Dictionary = ChargeCombat.charge_edge_morale_mult(_blue, _red, {})
	var info_b: Dictionary = ChargeCombat.charge_edge_morale_mult(_red, _blue, {})
	contact_edge_red = str(info_r.get("edge", ""))
	contact_edge_blue = str(info_b.get("edge", ""))
	var to_blue: Vector2 = (_blue.position - _red.position).normalized()
	var to_red: Vector2 = (_red.position - _blue.position).normalized()
	red_facing_dot_at_contact = _red.facing.normalized().dot(to_blue)
	blue_facing_dot_at_contact = _blue.facing.normalized().dot(to_red)
	red_rotation_deg = rad_to_deg(absf(_red_spawn_facing.angle_to(_red.facing)))
	blue_rotation_deg = rad_to_deg(absf(_blue_spawn_facing.angle_to(_blue.facing)))
	_sim_core.battle_over = true
	_battle_over = true


func _write_trace_file() -> void:
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
	print("[Scenario 33] Trace written: %s" % file_path)
