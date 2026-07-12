extends SceneTree

const APPROACHES := {
	"N": Vector2(0, -1), "NE": Vector2(1, -1), "E": Vector2(1, 0), "SE": Vector2(1, 1),
	"S": Vector2(0, 1), "SW": Vector2(-1, 1), "W": Vector2(-1, 0), "NW": Vector2(-1, -1),
}

const FACINGS := {
	"N": Vector2.UP, "E": Vector2.RIGHT, "S": Vector2.DOWN, "W": Vector2.LEFT,
}

const EXPECTED := {
	"N|N": "front", "N|NE": "front+right", "N|E": "right", "N|SE": "rear+right",
	"N|S": "rear", "N|SW": "rear+left", "N|W": "left", "N|NW": "front+left",
	"E|N": "left", "E|NE": "front+left", "E|E": "front", "E|SE": "front+right",
	"E|S": "right", "E|SW": "rear+right", "E|W": "rear", "E|NW": "rear+left",
	"S|N": "rear", "S|NE": "rear+left", "S|E": "left", "S|SE": "front+left",
	"S|S": "front", "S|SW": "front+right", "S|W": "right", "S|NW": "rear+right",
	"W|N": "right", "W|NE": "rear+right", "W|E": "rear", "W|SE": "rear+left",
	"W|S": "left", "W|SW": "front+left", "W|W": "front", "W|NW": "front+right",
}

var _host = null
var _unit_scene: PackedScene = null
var _profile: Dictionary = {}
var _px_per_meter: float = 2.0
var _cases: Array[String] = []
var _case_idx := 0
var _exit_code := 0
var _primed := false


func _initialize() -> void:
	var constants: Node = root.get_node("Constants")
	_px_per_meter = constants.get_float("px_per_meter")
	_profile = UnitProfileLoader.load_profile("test_infantry")
	_unit_scene = load("res://scenes/unit.tscn")
	for facing_name in FACINGS.keys():
		for approach_name in APPROACHES.keys():
			_cases.append("%s|%s" % [facing_name, approach_name])
	_host = load("res://tests/scenario_04.tscn").instantiate()
	root.add_child(_host)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	if not _host.is_node_ready():
		return
	if not _primed:
		_primed = true
		return
	if _case_idx >= _cases.size():
		process_frame.disconnect(_on_frame)
		_host.queue_free()
		quit(_exit_code)
		return
	var parts := _cases[_case_idx].split("|")
	var key := _cases[_case_idx]
	var expected: String = EXPECTED[key]
	var got := _classify_approach(FACINGS[parts[0]], APPROACHES[parts[1]])
	if got != expected:
		push_error("Compass mismatch %s: expected %s got %s" % [key, expected, got])
		_exit_code = 1
	else:
		print("[Compass] %s PASS (%s)" % [key, got])
	_case_idx += 1


func _classify_approach(defender_facing: Vector2, approach: Vector2) -> String:
	var defender = _unit_scene.instantiate()
	var attacker = _unit_scene.instantiate()
	_host.add_child(defender)
	_host.add_child(attacker)
	defender.configure("def", "blue", _profile, Vector2.ZERO, defender_facing)
	_place_attacker(defender, attacker, approach)
	var contact := EdgeContact.classify_contact(attacker, defender)
	var label: String = contact.get("edge_label", "")
	defender.queue_free()
	attacker.queue_free()
	return label


func _place_attacker(defender, attacker, approach: Vector2) -> void:
	var approach_dir := approach.normalized()
	var half_depth_m := float(_profile.get("formation_depth_m", 15.0)) * 0.5
	var half_frontage_m := float(_profile.get("formation_frontage_m", 40.0)) * 0.5
	var forward: Vector2 = defender.facing.normalized()
	var left: Vector2 = FormationGeometry.left_vector(forward)
	var along: float = approach_dir.dot(forward)
	var across: float = approach_dir.dot(left)
	var offset_m := Vector2.ZERO
	var pen_cardinal := 0.2
	var pen_corner := 0.35
	if absf(along) > 0.4 and absf(across) > 0.4:
		offset_m += forward * signf(along) * (half_depth_m * 2.0 - pen_corner)
		offset_m += left * signf(across) * (half_frontage_m + half_depth_m - pen_corner)
	elif absf(across) > absf(along):
		offset_m += left * signf(across) * (half_frontage_m + half_depth_m - pen_cardinal)
	else:
		offset_m += forward * signf(along) * (half_depth_m * 2.0 - pen_cardinal)
	var spawn_pos: Vector2 = defender.position + offset_m * _px_per_meter
	attacker.configure("atk", "red", _profile, spawn_pos, -approach_dir)
	attacker.rotation = attacker.facing.angle()
	defender.rotation = defender.facing.angle()
	if CombatResolver.is_head_on_pair(attacker, defender):
		CombatResolver.snap_pair_to_contact(attacker, defender)
