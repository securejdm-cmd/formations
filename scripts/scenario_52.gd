class_name Scenario52
extends Scenario01

## S52 — Classic feint (WO-033): high-skill feign baits pursuer; flanker springs.

const TRACE_PREFIX := "scenario_52"

@export var use_feint: bool = true

var trap_sprung: bool = false
var pursuer_flank_edge: String = ""
var pursuer_cohesion_end: float = -1.0


func _spawn_units() -> void:
	var px := Constants.get_float("px_per_meter")
	var high := UnitProfileLoader.load_profile("test_infantry").duplicate(true)
	high["retreating_skill"] = 90.0
	high["id"] = "feint_high"
	var pursuer_p := UnitProfileLoader.load_profile("test_infantry").duplicate(true)
	var flank_p := UnitProfileLoader.load_profile("test_cavalry")

	var feint := UNIT_SCENE.instantiate()
	add_child(feint)
	feint.configure("feint_unit", "blue", high, Vector2(0.0, 0.0), Vector2.RIGHT)
	if use_feint:
		feint.set_order_queue([
			{
				"primitive": "absolute_hold",
				"params": {},
				"trigger": {"type": "at_start"},
			},
			{
				"primitive": "feign_retreat",
				"params": {"dist": 50.0},
				"trigger": {"type": "enemy_within", "x_m": 25.0},
			},
		])
	else:
		feint.set_order_queue([
			{"primitive": "absolute_hold", "params": {}, "trigger": {"type": "at_start"}},
		])
	_units.append(feint)

	var pursuer := UNIT_SCENE.instantiate()
	add_child(pursuer)
	pursuer.configure("pursuer", "red", pursuer_p, Vector2(80.0 * px, 0.0), Vector2.LEFT)
	pursuer.set_order_queue([
		{
			"primitive": "attack_target",
			"params": {"unit": "feint_unit"},
			"trigger": {"type": "at_start"},
		},
	])
	_units.append(pursuer)

	var flanker := UNIT_SCENE.instantiate()
	add_child(flanker)
	# Long southern run-up so swing_and_charge reaches charge-gait closing speed.
	flanker.configure("flanker", "blue", flank_p, Vector2(20.0 * px, -180.0 * px), Vector2.DOWN)
	flanker.start_from_rest()
	if use_feint:
		flanker.set_order_queue([
			{
				"primitive": "swing_and_charge",
				"params": {"side": "right", "target": "pursuer", "flank_arc_offset_m": 80.0},
				"trigger": {
					"type": "unit_order_started",
					"unit": "feint_unit",
					"primitive": "feign_retreat",
				},
			},
		])
	else:
		# Control: same flanker but never released (holds) — trap should not spring.
		flanker.set_order_queue([
			{"primitive": "hold", "params": {}, "trigger": {"type": "at_start"}},
		])
	_units.append(flanker)

	for unit in _units:
		unit.set_render_camera(_camera)


func _ready() -> void:
	super._ready()
	_ensure_sim_core()
	_sim_core.battle_type = "pitched"


func advance_one_tick() -> void:
	super.advance_one_tick()
	_observe()


func _observe() -> void:
	_ensure_sim_core()
	for ev in _sim_core.last_charge_events:
		if str(ev.get("attacker", "")) != "flanker":
			continue
		if bool(ev.get("charged", false)):
			trap_sprung = true
			pursuer_flank_edge = str(ev.get("edge", ""))
	# Also count flank engagement (edge contact) if charge threshold missed.
	if not trap_sprung:
		var flanker_p = null
		var pursuer_p = null
		for u in _sim_core.units:
			if str(u.unit_id) == "flanker":
				flanker_p = u
			elif str(u.unit_id) == "pursuer":
				pursuer_p = u
		if flanker_p != null and pursuer_p != null and flanker_p.has_contact_with(pursuer_p):
			trap_sprung = true
			if pursuer_flank_edge.is_empty():
				pursuer_flank_edge = "contact"
	for u in _sim_core.units:
		if str(u.unit_id) == "pursuer":
			pursuer_cohesion_end = u.cohesion


func _write_trace_file() -> void:
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
