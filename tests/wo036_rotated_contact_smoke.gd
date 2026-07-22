extends SceneTree

## WO-036 — angled/rotated OBB contact must engage; never MARCHING+merged.
## Run: godot --headless -s res://tests/wo036_rotated_contact_smoke.gd

const SCENE := "res://tests/scenario_55.tscn"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# Static predicate: known angled OBB clip must report contact.
	if not _static_obb_contact_predicate():
		push_error("WO-036 static OBB contact predicate FAIL")
		quit(1)
		return
	var packed = load(SCENE)
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.auto_run = false
	sc.use_sim_thread = false
	sc.suppress_io = true
	sc.set_battle_seed(1000)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(1000)
		spins += 1
	if sc.has_method("stop_sim_thread_for_harness"):
		sc.stop_sim_thread_for_harness()
	sc._ensure_sim_core()
	sc._sim_core.capture_from_units(sc._units)
	sc._sim_core.headless_mode = true
	sc._sim_core.fast_sim_mode = true

	var ticks := 0
	while ticks < 2500 and not sc.is_battle_over():
		sc.advance_one_tick()
		ticks += 1
		if sc.had_adhesion_invariant_failure():
			push_error("WO-036 coherence fail tick=%d" % ticks)
			quit(1)
			return

	var ok: bool = bool(sc.angled_contact_ok())
	print(
		"[WO-036] rotated smoke engaged=%s combat=%s obb_march=%s streak=%d off_x=%.1f° ticks=%d ok=%s"
		% [
			str(sc.observed_engaged),
			str(sc.combat_resolved),
			str(sc.observed_left_marching_while_obb),
			sc.max_obb_marching_ticks,
			float(sc.first_contact_facing_off_x_deg),
			ticks,
			str(ok),
		]
	)
	sc.free()
	if ok:
		print("[WO-036] ROTATED-CONTACT SMOKE PASS")
		quit(0)
	else:
		push_error("WO-036 ROTATED-CONTACT SMOKE FAIL")
		quit(1)


func _static_obb_contact_predicate() -> bool:
	## Build two proxies with ~45° relative facing whose OBBs overlap while
	## center-gap head-on band would still be open on axis-aligned depths.
	var SimProxy = load("res://scripts/sim/sim_unit_proxy.gd")
	var inf: Dictionary = UnitProfileLoader.load_profile("test_infantry")
	var px: float = float(Engine.get_main_loop().root.get_node("/root/Constants").get_float("px_per_meter"))
	var a = SimProxy.new()
	var b = SimProxy.new()
	a.unit_id = "a"
	b.unit_id = "b"
	a.team_id = "red"
	b.team_id = "blue"
	a.profile = inf.duplicate(true)
	b.profile = inf.duplicate(true)
	a.strength = 100.0
	b.strength = 100.0
	a.position = Vector2(18.0 * px, -14.0 * px)
	b.position = Vector2.ZERO
	a.facing = Vector2(-1.0, 0.65).normalized()
	b.facing = Vector2.RIGHT
	a._state = Unit.State.MARCHING
	b._state = Unit.State.HOLD
	var obb: bool = FormationGeometry.rectangles_overlap(a, b)
	var contact: bool = CombatResolver.units_have_any_contact(a, b)
	print("[WO-036] static obb=%s contact=%s gap=%.3f" % [
		str(obb), str(contact), CombatResolver.center_gap_m(a, b)
	])
	if not obb:
		# Tune positions until OBB overlaps for the predicate.
		push_error("WO-036 static setup does not OBB-overlap — adjust fixture")
		return false
	return contact
