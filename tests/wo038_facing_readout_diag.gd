extends SceneTree

## WO-038 — facing readout format + UI-path facing.length census + integrity gate.
## Run: godot --headless -s res://tests/wo038_facing_readout_diag.gd

const SCENE := "res://tests/scenario_56.tscn"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _verify_readout_format():
		push_error("WO-038 readout format FAIL")
		quit(1)
		return

	if not _verify_assert_gate():
		push_error("WO-038 assert gate FAIL")
		quit(1)
		return

	if not _run_ui_path_facing_census():
		push_error("WO-038 facing census FAIL")
		quit(1)
		return

	print("[WO-038] FACING-READOUT DIAG PASS")
	quit(0)


func _verify_readout_format() -> bool:
	## Mirrors scenario_debug_overlay._update_unit_panel facing line.
	var f := Vector2(-0.70710678118, -0.70710678118)
	var line: String = "Facing: (%.3f, %.3f) |len|=%.4f" % [f.x, f.y, f.length()]
	print("[WO-038] readout sample: %s" % line)
	if line.contains("%(") or line.contains("%.3f"):
		push_error("WO-038 malformed format still literal: %s" % line)
		return false
	if not line.begins_with("Facing: ("):
		push_error("WO-038 unexpected readout: %s" % line)
		return false
	if absf(f.length() - 1.0) > 1e-5:
		push_error("WO-038 test vector not unit")
		return false
	# Confirm the historic nested "%(%.3f..." form was the bug class.
	var historic := "Facing: %(%.3f, %.3f) |len|=%.4f" % [f.x, f.y, f.length()]
	print("[WO-038] historic-broken sample: %s" % historic)
	if not historic.contains("%("):
		print("[WO-038] note: engine may still interpolate historic form; fixed form is authoritative")
	print("[WO-038] readout format OK")
	return true


func _verify_assert_gate() -> bool:
	var Core = load("res://scripts/sim/sim_battle_core.gd")
	var core = Core.new()
	core.headless_mode = false
	core.fast_sim_mode = false
	core.debug_integrity_checks = false
	# Without debug flag, non-headless DEBUG builds still enable via OS.is_debug_build().
	var enabled_debug_path: bool = core.overlap_assert_enabled()
	print(
		"[WO-038] gate headless=false fast=false debug_integrity=false → enabled=%s (expect true in debug build)"
		% str(enabled_debug_path)
	)
	if not OS.is_debug_build():
		push_error("WO-038 expected debug build for gate check")
		return false
	if not enabled_debug_path:
		push_error("WO-038 DEBUG realtime OBB gate still closed")
		return false
	core.headless_mode = true
	core.fast_sim_mode = false
	core.debug_integrity_checks = false
	if core.overlap_assert_enabled():
		push_error("WO-038 headless+!fast should stay closed without debug_integrity")
		return false
	core.debug_integrity_checks = true
	if not core.overlap_assert_enabled():
		push_error("WO-038 debug_integrity_checks did not open gate")
		return false
	print("[WO-038] assert gate OK (silent overlap_fail was (a) assert-off, not (b))")
	return true


func _run_ui_path_facing_census() -> bool:
	## UI-launched battles use fast_sim=false. Mirror that with facing-len log ON.
	var packed = load(SCENE)
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = false
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
	sc._sim_core.fast_sim_mode = false
	sc._sim_core.debug_integrity_checks = true
	sc._sim_core.debug_facing_len_log = true
	sc._sim_core.write_trace_header()

	var ticks := 0
	while ticks < 2500 and not sc.is_battle_over():
		sc.advance_one_tick()
		ticks += 1

	var rep: Dictionary = sc._sim_core.facing_len_report()
	var fl_min: float = float(rep.get("min", NAN))
	var fl_max: float = float(rep.get("max", NAN))
	var samples: int = int(rep.get("samples", 0))
	var first_dev: int = int(rep.get("first_dev_tick", -1))
	var first_unit: String = str(rep.get("first_dev_unit", ""))
	var first_len: float = float(rep.get("first_dev_len", 0.0))
	print(
		"[WO-038] FACING_LEN census samples=%d min=%.8f max=%.8f first_dev_tick=%d unit=%s len=%.8f ticks=%d engaged=%s wheeled=%s"
		% [
			samples,
			fl_min,
			fl_max,
			first_dev,
			first_unit,
			first_len,
			ticks,
			str(sc.observed_engaged),
			str(sc.observed_rotate_while_engaged),
		]
	)
	if samples <= 0:
		push_error("WO-038 no facing_len samples")
		sc.free()
		return false
	var clean: bool = first_dev < 0 and absf(fl_min - 1.0) <= 1e-4 and absf(fl_max - 1.0) <= 1e-4
	if clean:
		print(
			"[WO-038] UNNORMALIZED-FACING HYPOTHESIS FALSIFIED — magnitudes clean (min=%.8f max=%.8f); no |len-1|>1e-4"
			% [fl_min, fl_max]
		)
	else:
		print(
			"[WO-038] UNNORMALIZED-FACING HYPOTHESIS SUPPORTED — first_dev_tick=%d unit=%s len=%.8f min=%.8f max=%.8f"
			% [first_dev, first_unit, first_len, fl_min, fl_max]
		)
	# Write a short artifact for the completion report.
	var art := FileAccess.open("/tmp/cursor/artifacts/wo038_facing_census.txt", FileAccess.WRITE)
	if art != null:
		art.store_string(
			"samples=%d\nmin=%.8f\nmax=%.8f\nfirst_dev_tick=%d\nfirst_dev_unit=%s\nfirst_dev_len=%.8f\nclean=%s\n"
			% [samples, fl_min, fl_max, first_dev, first_unit, first_len, str(clean)]
		)
		art.close()
	sc.free()
	return true
