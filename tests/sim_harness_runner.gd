class_name SimHarnessRunner
extends RefCounted

## Spawn helpers for SceneTree autotest drivers.


static func instantiate_scenario(scene_path: String, seed_value: int, fast_mode: bool = true) -> Scenario01:
	var packed: PackedScene = load(scene_path)
	var scenario: Scenario01 = packed.instantiate()
	scenario.headless_mode = true
	scenario.fast_sim_mode = fast_mode
	scenario.set_battle_seed(seed_value)
	return scenario


static func attach_and_wait_ready(tree: SceneTree, scenario: Scenario01) -> void:
	tree.root.add_child(scenario)
	var spins := 0
	while not scenario.is_node_ready() and spins < 256:
		tree.idle_frame.emit()
		spins += 1
