extends SceneTree

var _host = null


func _initialize() -> void:
	_host = load("res://tests/scenario_04.tscn").instantiate()
	_host.headless_mode = true
	_host.contact_mode = 2
	root.add_child(_host)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	if not _host.is_node_ready():
		return
	var atk = _host._attacker
	var def = _host._defender
	var c: Dictionary = EdgeContact.classify_contact(atk, def)
	var edges: Dictionary = c.get("edge_lengths_m", {})
	print("CORNER spawn contact=", c)
	for _i in 50:
		_host.advance_one_tick()
	print("drain/s=", _host.get_drain_per_sec())
	print("post contact ab=", EdgeContact.classify_contact(atk, def))
	print("post contact ba=", EdgeContact.classify_contact(def, atk))
	print("head_on=", CombatResolver.is_head_on_pair(atk, def))
	print("non_front_seg=", EdgeContact.has_non_front_segment_contact(atk, def))
	quit(0)
