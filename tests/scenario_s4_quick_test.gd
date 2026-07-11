extends SceneTree

var _scenario = null
var _ticks := 0

func _initialize() -> void:
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	if _scenario == null:
		var packed: PackedScene = load("res://tests/scenario_04.tscn")
		_scenario = packed.instantiate()
		_scenario.headless_mode = true
		for mode_name in ["front", "side", "corner"]:
			_run_mode(mode_name)
		quit(0)
		return

func _run_mode(mode_name: String) -> void:
	if _scenario != null:
		_scenario.free()
	var packed: PackedScene = load("res://tests/scenario_04.tscn")
	_scenario = packed.instantiate()
	_scenario.headless_mode = true
	match mode_name:
		"front":
			_scenario.contact_mode = _scenario.ContactMode.FRONT
		"side":
			_scenario.contact_mode = _scenario.ContactMode.SIDE
		"corner":
			_scenario.contact_mode = _scenario.ContactMode.CORNER
	root.add_child(_scenario)
	while not _scenario.is_node_ready():
		await process_frame
	for _i in 50:
		_scenario.advance_one_tick()
	print(
		"%s drain/s=%.3f edge=%s"
		% [mode_name, _scenario.get_drain_per_sec(), _scenario.get_edge_label_sample()]
	)
