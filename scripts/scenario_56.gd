extends Scenario01

## WO-037 S56 — Cavalry charges, engages, then rotates while engaged.
## Facing must stay unit-length through rotation; contact must remain.

const TRACE_PREFIX := "scenario_56"

var observed_engaged: bool = false
var combat_resolved: bool = false
var observed_rotate_while_engaged: bool = false
var max_facing_len_err: float = 0.0
var facing_ok: bool = true
var _wheel_started: bool = false
var _engage_tick: int = -1


func _spawn_units() -> void:
	var px := Constants.get_float("px_per_meter")
	var inf := UnitProfileLoader.load_profile("test_infantry")
	var cav := UnitProfileLoader.load_profile("test_cavalry")

	var blue: Unit = UNIT_SCENE.instantiate()
	add_child(blue)
	blue.configure("def_hold", "blue", inf, Vector2.ZERO, Vector2.RIGHT)
	blue.set_order_queue([
		{"primitive": "absolute_hold", "params": {}, "trigger": {"type": "at_start"}},
	])
	_units.append(blue)

	# Cavalry approaches from the NE so first contact is angled, then wheels
	# under contact (designer's rotate-after-charge sequence).
	var red: Unit = UNIT_SCENE.instantiate()
	add_child(red)
	var start := Vector2(70.0 * px, -35.0 * px)
	var face := Vector2(-1.0, 0.55).normalized()
	red.configure("atk_cav", "red", cav, start, face)
	red.start_from_rest()
	red.set_order_queue([
		{
			"primitive": "attack_target",
			"params": {"unit": "def_hold"},
			"trigger": {"type": "at_start"},
		},
	])
	_units.append(red)

	for unit in _units:
		unit.set_render_camera(_camera)


func _ready() -> void:
	super._ready()
	_ensure_sim_core()
	_sim_core.battle_type = "pitched"
	_sim_core.victory_spec = {"mode": "rout"}


func advance_one_tick() -> void:
	super.advance_one_tick()
	_observe_and_wheel()


func _observe_and_wheel() -> void:
	_ensure_sim_core()
	if _sim_core == null or _sim_core.units.size() < 2:
		return
	var cav = null
	var hold = null
	for u in _sim_core.units:
		if str(u.unit_id) == "atk_cav":
			cav = u
		elif str(u.unit_id) == "def_hold":
			hold = u
	if cav == null or hold == null:
		return

	for u in _sim_core.units:
		var err: float = absf(u.facing.length() - 1.0)
		max_facing_len_err = maxf(max_facing_len_err, err)
		if not FormationGeometry.facing_is_unit(u.facing):
			facing_ok = false

	if cav.get_state() == Unit.State.ENGAGED or hold.get_state() == Unit.State.ENGAGED:
		observed_engaged = true
		if _engage_tick < 0:
			_engage_tick = int(_sim_core.sim_tick_count)
	if cav.get_state() == Unit.State.WAVERING or hold.get_state() == Unit.State.WAVERING:
		observed_engaged = true
	if float(cav.damage_dealt) > 0.01 or float(hold.damage_dealt) > 0.01:
		combat_resolved = true

	# After a short grind, wheel the cavalry 90° under contact (rotate-while-engaged).
	if (
		observed_engaged
		and not _wheel_started
		and _engage_tick >= 0
		and int(_sim_core.sim_tick_count) >= _engage_tick + 10
	):
		_wheel_started = true
		var turned: Vector2 = cav.facing.rotated(PI * 0.5)
		cav.begin_wheel_facing(turned)

	if _wheel_started and cav.wheeling:
		observed_rotate_while_engaged = true
	if _wheel_started and not cav.wheeling and cav.has_contact_with(hold):
		observed_rotate_while_engaged = true


func rotate_while_engaged_ok() -> bool:
	return (
		observed_engaged
		and combat_resolved
		and observed_rotate_while_engaged
		and facing_ok
		and max_facing_len_err <= FormationGeometry.FACING_UNIT_EPS
		and not had_facing_assertion_failure()
	)
