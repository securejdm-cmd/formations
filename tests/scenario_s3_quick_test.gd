extends SceneTree

var _scenario = null
var _ticks := 0

func _initialize() -> void:
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	if _scenario == null:
		var packed: PackedScene = load("res://tests/scenario_03.tscn")
		_scenario = packed.instantiate()
		_scenario.headless_mode = true
		_scenario.set_battle_seed(1000)
		root.add_child(_scenario)
		return
	if not _scenario.is_node_ready():
		return
	if _scenario.is_battle_over() or _ticks >= 5000:
		var p: Dictionary = _scenario.get_phase_durations_sec()
		print(
			"S3 combat=%.1fs rout=%.2f drains=%s overlap=%s winner=%s"
			% [
				p.combat_sec,
				_scenario.get_blue_a_strength_at_rout(),
				_scenario.get_blue_a_edge_drains(),
				_scenario.had_overlap_failure(),
				_scenario.get_winner_id(),
			]
		)
		quit(0)
	_scenario.advance_one_tick()
	_ticks += 1
