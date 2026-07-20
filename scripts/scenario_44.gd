class_name Scenario44
extends Scenario01

## S44 — Absolute hold vs hold (WO-031): routers stream past; enemy follows.
## Hold unit uses attack_nearest (may leave post). Absolute_hold must not.

const TRACE_PREFIX := "scenario_44"

var _hold: Unit = null
var _abs: Unit = null
var _router: Unit = null
var _pursuer: Unit = null

var hold_start: Vector2 = Vector2.ZERO
var abs_start: Vector2 = Vector2.ZERO
var hold_max_disp_m: float = 0.0
var abs_max_disp_m: float = 0.0


func _spawn_units() -> void:
	var px := Constants.get_float("px_per_meter")
	var inf := UnitProfileLoader.load_profile("test_infantry")
	var cav := UnitProfileLoader.load_profile("test_cavalry")

	_hold = UNIT_SCENE.instantiate()
	add_child(_hold)
	_hold.configure("hold_unit", "blue", inf, Vector2(0.0, -40.0 * px), Vector2.RIGHT)
	_hold.set_order_queue([
		{"primitive": "hold", "params": {}, "trigger": {"type": "at_start"}},
		{
			"primitive": "attack_nearest",
			"params": {},
			"trigger": {"type": "enemy_within", "x": 50.0},
		},
	])
	_units.append(_hold)
	hold_start = _hold.position

	_abs = UNIT_SCENE.instantiate()
	add_child(_abs)
	_abs.configure("abs_unit", "blue", inf, Vector2(0.0, 40.0 * px), Vector2.RIGHT)
	_abs.set_order_queue([
		{"primitive": "absolute_hold", "params": {}, "trigger": {"type": "at_start"}},
	])
	_units.append(_abs)
	abs_start = _abs.position

	# Pre-routed unit streaming past (will be forced to ROUTING after configure).
	_router = UNIT_SCENE.instantiate()
	add_child(_router)
	_router.configure("router", "red", inf, Vector2(80.0 * px, 0.0), Vector2.LEFT)
	_units.append(_router)

	_pursuer = UNIT_SCENE.instantiate()
	add_child(_pursuer)
	_pursuer.configure("pursuer", "red", cav, Vector2(140.0 * px, 0.0), Vector2.LEFT)
	_pursuer.start_from_rest()
	_pursuer.set_order_queue([
		{
			"primitive": "advance_to",
			"params": {"point": {"x": -120.0, "y": 0.0}},
			"trigger": {"type": "at_start"},
		},
	])
	_units.append(_pursuer)

	for unit in _units:
		unit.set_render_camera(_camera)


func _ready() -> void:
	super._ready()
	# Force router into ROUTING after sim capture starts — use pre_tick once.
	_ensure_sim_core()
	_sim_core.pre_tick_callback = Callable(self, "_force_router_once")


var _router_forced: bool = false


func _force_router_once(core) -> void:
	if _router_forced:
		return
	_router_forced = true
	for u in core.units:
		if str(u.unit_id) != "router":
			continue
		u.cohesion = 0.0
		u._set_state(Unit.State.ROUTING)
		u.current_order = Unit.Order.HOLD
		# Flee toward left edge past both posts.
		var px := Constants.get_float("px_per_meter")
		u.facing = Vector2.LEFT
		break


func advance_one_tick() -> void:
	super.advance_one_tick()
	_observe_disp()


func _observe_disp() -> void:
	var px := Constants.get_float("px_per_meter")
	if _hold != null:
		hold_max_disp_m = maxf(hold_max_disp_m, hold_start.distance_to(_hold.position) / px)
	if _abs != null:
		abs_max_disp_m = maxf(abs_max_disp_m, abs_start.distance_to(_abs.position) / px)


func _write_trace_file() -> void:
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d.csv" % _battle_seed
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
	print("[Scenario 44] Trace written: %s" % file_path)
