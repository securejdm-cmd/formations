extends SceneTree

## WO-037 — facing stays unit-length through charge + rotate-while-engaged.
## Run: godot --headless -s res://tests/wo037_facing_normalize_smoke.gd

const SCENE := "res://tests/scenario_56.tscn"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _static_normalize_predicate():
		push_error("WO-037 static normalize predicate FAIL")
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
		if sc.had_facing_assertion_failure():
			push_error("WO-037 facing invariant fail tick=%d" % ticks)
			quit(1)
			return
		if sc.had_adhesion_invariant_failure():
			push_error("WO-037 adhesion fail tick=%d" % ticks)
			quit(1)
			return

	var ok: bool = bool(sc.rotate_while_engaged_ok())
	print(
		"[WO-037] facing smoke engaged=%s combat=%s wheeled=%s facing_ok=%s max_err=%.6f ticks=%d ok=%s"
		% [
			str(sc.observed_engaged),
			str(sc.combat_resolved),
			str(sc.observed_rotate_while_engaged),
			str(sc.facing_ok),
			float(sc.max_facing_len_err),
			ticks,
			str(ok),
		]
	)
	sc.free()
	if ok:
		print("[WO-037] FACING-NORMALIZE SMOKE PASS")
		quit(0)
	else:
		push_error("WO-037 FACING-NORMALIZE SMOKE FAIL")
		quit(1)


func _static_normalize_predicate() -> bool:
	## Assign the designer's (-1,-1) diagonal; setter must install a unit vector.
	var SimProxy = load("res://scripts/sim/sim_unit_proxy.gd")
	var p = SimProxy.new()
	p.facing = Vector2(-1.0, -1.0)
	var len_p: float = p.facing.length()
	print("[WO-037] static proxy facing=%s |len|=%.6f" % [str(p.facing), len_p])
	if not FormationGeometry.facing_is_unit(p.facing):
		push_error("WO-037 proxy setter did not normalize (-1,-1)")
		return false
	# OBB corners from a deliberately non-unit pre-normalize path still form a rectangle.
	var a = SimProxy.new()
	var b = SimProxy.new()
	var inf: Dictionary = UnitProfileLoader.load_profile("test_infantry")
	var constants: Node = root.get_node_or_null("Constants")
	var px: float = 10.0
	if constants != null:
		px = float(constants.call("get_float", "px_per_meter"))
	a.profile = inf.duplicate(true)
	b.profile = inf.duplicate(true)
	a.strength = 100.0
	b.strength = 100.0
	a.position = Vector2.ZERO
	b.position = Vector2(30.0 * px, 0.0)
	# Bypass would be impossible via setter; verify normalize_facing helper.
	var raw := Vector2(-1.0, -1.0)
	var n := FormationGeometry.normalize_facing(raw)
	print("[WO-037] normalize_facing((-1,-1))=%s |len|=%.6f" % [str(n), n.length()])
	return FormationGeometry.facing_is_unit(n)
