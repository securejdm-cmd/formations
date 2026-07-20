class_name Scenario47
extends Scenario01

## S47 — Fit rule + reveal permanence (WO-032).

const TRACE_PREFIX := "scenario_47"
const _Concealment := preload("res://scripts/concealment.gd")

var fit_half_out_rejected: bool = false
var reveal_permanence_ok: bool = false


func _spawn_units() -> void:
	var px := Constants.get_float("px_per_meter")
	var inf := UnitProfileLoader.load_profile("test_infantry").duplicate(true)
	inf["formation_frontage_m"] = 20.0
	inf["formation_depth_m"] = 15.0

	# Forest patch: small enough that a unit centered on the edge is half-out.
	var forest := {"type": "FOREST", "x": 0.0, "y": -40.0, "w": 40.0, "h": 80.0}
	set_terrain_patches([forest])

	# Unit A: fully inside → can conceal.
	var inside := UNIT_SCENE.instantiate()
	add_child(inside)
	inside.configure("inside", "blue", inf, Vector2(20.0 * px, 0.0), Vector2.RIGHT)
	inside.starting_posture = "concealed"
	inside.set_order_queue([
		{"primitive": "hold", "params": {}, "trigger": {"type": "at_start"}},
	])
	_units.append(inside)

	# Unit B: center on the left edge so footprint straddles — fit rule fails.
	var half := UNIT_SCENE.instantiate()
	add_child(half)
	half.configure("half_out", "blue", inf, Vector2(0.0, 0.0), Vector2.RIGHT)
	half.starting_posture = "concealed"
	half.set_order_queue([
		{"primitive": "hold", "params": {}, "trigger": {"type": "at_start"}},
	])
	_units.append(half)

	# Enemy that will walk into detection of `inside`, then leave; `inside` re-enters forest.
	var probe := UNIT_SCENE.instantiate()
	add_child(probe)
	probe.configure("probe", "red", inf, Vector2(20.0 * px, 80.0 * px), Vector2.UP)
	probe.set_order_queue([
		{
			"primitive": "advance_to",
			"params": {"point": {"x": 20.0, "y": 0.0}},
			"trigger": {"type": "at_start"},
		},
		{
			"primitive": "advance_to",
			"params": {"point": {"x": 20.0, "y": 80.0}},
			"trigger": {"type": "after_seconds", "seconds": 8.0},
		},
	])
	_units.append(probe)

	for unit in _units:
		unit.set_render_camera(_camera)


func _ready() -> void:
	super._ready()
	_ensure_sim_core()
	_sim_core.battle_type = "ambush"
	_render_terrain_patches()


func evaluate_after_ticks() -> void:
	_ensure_sim_core()
	var half_proxy = null
	var inside_proxy = null
	for u in _sim_core.units:
		if u.unit_id == "half_out":
			half_proxy = u
		elif u.unit_id == "inside":
			inside_proxy = u
	fit_half_out_rejected = half_proxy != null and not half_proxy.concealed and not half_proxy.ever_revealed
	# Permanence: inside must have been revealed and must stay un-concealed even if back in patch.
	reveal_permanence_ok = (
		inside_proxy != null
		and inside_proxy.ever_revealed
		and not inside_proxy.concealed
	)


func _write_trace_file() -> void:
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
