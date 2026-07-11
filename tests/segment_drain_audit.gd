extends SceneTree

func _initialize() -> void:
	RNG.set_seed(1000)
	var profile := UnitProfileLoader.load_profile("test_infantry")
	var unit_scene: PackedScene = load("res://scenes/unit.tscn")
	var defender = unit_scene.instantiate()
	var attacker = unit_scene.instantiate()
	root.add_child(defender)
	root.add_child(attacker)
	defender.configure("def", "blue", profile, Vector2.ZERO, Vector2.RIGHT)
	var px := Constants.get_float("px_per_meter")
	var depth_m := float(profile.get("formation_depth_m", 15.0))
	var frontage_m := float(profile.get("formation_frontage_m", 40.0))
	var touch := (EdgeContact.CONTACT_EPSILON_M + 0.15) * px
	var pos := Vector2(0.0, -(frontage_m * 0.5 + depth_m * 0.5) * px + touch)
	attacker.configure("atk", "red", profile, pos, Vector2.DOWN)
	var contact: Dictionary = EdgeContact.classify_contact(attacker, defender)
	var seg: Dictionary = CombatResolver.resolve_contact_segment(attacker, defender, contact)
	print("SIDE contact=", contact)
	print("SIDE segment=", seg)
	var coh_before: float = defender.cohesion
	CombatResolver.apply_shift_morale_drain(defender, seg.defender_shift_m, contact.edge_lengths_m)
	var coh_after_shift: float = defender.cohesion
	CombatResolver.apply_strength_loss_with_edge(defender, seg.defender_damage, contact.edge_lengths_m)
	print(
		"shift_drain=%.4f casualty_drain=%.4f total=%.4f winner=%s"
		% [
			coh_before - coh_after_shift,
			coh_after_shift - defender.cohesion,
			coh_before - defender.cohesion,
			seg.attacker_wins,
		]
	)
	# FRONT head-on one tick
	defender.cohesion = 100.0
	attacker.position = Vector2(depth_m * px, 0.0)
	attacker.facing = Vector2.LEFT
	CombatResolver.snap_pair_to_contact(attacker, defender)
	var eng: Dictionary = CombatResolver.resolve_engagement(attacker, defender)
	coh_before = defender.cohesion
	CombatResolver.apply_ground_shift(defender, eng.shift_b_m)
	CombatResolver.apply_strength_loss(defender, eng.damage_b)
	print("FRONT eng=", eng)
	print(
		"FRONT shift_drain=%.4f casualty_drain=%.4f"
		% [eng.shift_b_m * Constants.get_float("drain_per_meter_lost"), (coh_before - defender.cohesion) - eng.shift_b_m * Constants.get_float("drain_per_meter_lost")]
	)
	quit(0)
