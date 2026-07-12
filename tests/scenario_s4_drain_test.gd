extends SceneTree

var _modes := [0, 1, 2]
var _idx := 0
var _host = null
var _ticks := 0


func _initialize() -> void:
	_load()
	process_frame.connect(_on_frame)


func _load() -> void:
	if _host != null:
		_host.free()
	_host = load("res://tests/scenario_04.tscn").instantiate()
	_host.headless_mode = true
	_host.contact_mode = _modes[_idx]
	root.add_child(_host)
	_ticks = 0


func _on_frame() -> void:
	if not _host.is_node_ready():
		return
	if _ticks < 50:
		_host.advance_one_tick()
		_ticks += 1
		return
	var c: Dictionary = _host.get_contact_sample()
	print(
		"%s drain=%.4f edge=%s lengths=%s frontage_pct=%.3f"
		% [
			["FRONT", "SIDE", "CORNER"][_idx],
			_host.get_drain_per_sec(),
			_host.get_edge_label_sample(),
			c.get("edge_lengths_m", {}),
			c.get("attacker_frontage_pct", 0.0),
		]
	)
	_idx += 1
	if _idx >= _modes.size():
		quit(0)
		return
	_load()
