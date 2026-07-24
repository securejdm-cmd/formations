extends SceneTree

## WO-038 — running-build eye check of debug Facing readout (DISPLAY=:99).
## Run: DISPLAY=:99 godot -s res://tests/wo038_readout_visual.gd

const SCENE := "res://tests/scenario_56.tscn"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed = load(SCENE)
	var sc = packed.instantiate()
	sc.headless_mode = false
	sc.fast_sim_mode = false
	sc.auto_run = true
	sc.use_sim_thread = true
	sc.suppress_io = true
	sc.set_battle_seed(1000)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		await process_frame
		spins += 1

	# Advance a few frames so overlay _process runs and units exist.
	for _i in 30:
		await process_frame

	var overlay = sc.get_node_or_null("DebugOverlay")
	if overlay == null:
		push_error("WO-038 no DebugOverlay")
		quit(1)
		return

	var unit: Unit = null
	for u in sc._units:
		if u != null and str(u.unit_id) == "atk_cav":
			unit = u
			break
	if unit == null and sc._units.size() > 0:
		unit = sc._units[0]
	if unit == null:
		push_error("WO-038 no unit to select")
		quit(1)
		return

	# Select and force panel refresh.
	overlay._on_unit_selected(unit)
	overlay._update_unit_panel()
	var text: String = str(overlay._unit_panel.text)
	print("[WO-038] PANEL TEXT:\n%s" % text)
	if text.contains("%(") or text.contains("%.3f") or text.contains("%.4f"):
		push_error("WO-038 panel still shows format literals")
		quit(1)
		return
	if not text.contains("Facing: ("):
		push_error("WO-038 panel missing Facing line")
		quit(1)
		return
	if not text.contains("|len|="):
		push_error("WO-038 panel missing |len|=")
		quit(1)
		return

	# Capture a screenshot of the running build for attestation.
	await process_frame
	var img: Image = get_root().get_viewport().get_texture().get_image()
	if img != null:
		DirAccess.make_dir_recursive_absolute("/tmp/cursor/artifacts")
		var path := "/tmp/cursor/artifacts/wo038_facing_readout.png"
		img.save_png(path)
		print("[WO-038] screenshot saved %s" % path)

	print("[WO-038] READOUT VISUAL PASS")
	quit(0)
