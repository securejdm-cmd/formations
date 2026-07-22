extends Scenario01

## WO-036 S55 — Rotated / angled contact must engage (not MARCHING+merged).
## Stages the case S40 never hits: ~45° approach with OBB corner clip.

const TRACE_PREFIX := "scenario_55"

var observed_engaged: bool = false
var observed_left_marching_while_obb: bool = false
var max_obb_marching_ticks: int = 0
var _obb_marching_streak: int = 0
var combat_resolved: bool = false
## Diagnostic: attacker |facing.angle| from world ±X at first ENGAGED (degrees).
var first_contact_facing_off_x_deg: float = 0.0
var _logged_first_contact_angle: bool = false


func _spawn_units() -> void:
	var px := Constants.get_float("px_per_meter")
	var inf := UnitProfileLoader.load_profile("test_infantry")

	# Defender holds facing +X.
	var blue: Unit = UNIT_SCENE.instantiate()
	add_child(blue)
	blue.configure("def_hold", "blue", inf, Vector2.ZERO, Vector2.RIGHT)
	blue.set_order_queue([
		{"primitive": "absolute_hold", "params": {}, "trigger": {"type": "at_start"}},
	])
	_units.append(blue)

	# Attacker approaches from NE at ~45° so facings are off-square and the
	# true OBB corners clip before the center-gap head-on band closes.
	var red: Unit = UNIT_SCENE.instantiate()
	add_child(red)
	var start := Vector2(55.0 * px, -45.0 * px)
	var face := Vector2(-1.0, 0.7).normalized()
	red.configure("atk_angle", "red", inf, start, face)
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
	_observe()


func _observe() -> void:
	_ensure_sim_core()
	if _sim_core == null or _sim_core.units.size() < 2:
		return
	var a = null
	var b = null
	for u in _sim_core.units:
		if str(u.unit_id) == "atk_angle":
			a = u
		elif str(u.unit_id) == "def_hold":
			b = u
	if a == null or b == null:
		return
	if a.get_state() == Unit.State.ENGAGED or b.get_state() == Unit.State.ENGAGED:
		observed_engaged = true
		if not _logged_first_contact_angle:
			_logged_first_contact_angle = true
			# Spawn is ~45° NE; gravity rotates toward the holder. Log residual
			# off-axis facing at first engage (proves non-head-on-square staging).
			var f: Vector2 = a.facing.normalized()
			first_contact_facing_off_x_deg = rad_to_deg(absf(atan2(f.y, f.x)))
			# Fold into [0, 90]: distance from nearest world ±X axis.
			var fold: float = first_contact_facing_off_x_deg
			if fold > 90.0:
				fold = 180.0 - fold
			first_contact_facing_off_x_deg = fold
	if a.get_state() == Unit.State.WAVERING or b.get_state() == Unit.State.WAVERING:
		observed_engaged = true
	if float(a.damage_dealt) > 0.01 or float(b.damage_dealt) > 0.01:
		combat_resolved = true
	# Forbidden: OBB interpenetration while either is still MARCHING without partners.
	var obb: bool = FormationGeometry.rectangles_overlap(a, b)
	var partners: bool = a.has_contact_with(b)
	var marching: bool = (
		a.get_state() == Unit.State.MARCHING or b.get_state() == Unit.State.MARCHING
	)
	if obb and marching and not partners:
		_obb_marching_streak += 1
		max_obb_marching_ticks = maxi(max_obb_marching_ticks, _obb_marching_streak)
		observed_left_marching_while_obb = true
	else:
		_obb_marching_streak = 0


func angled_contact_ok() -> bool:
	## Staging is ~45° with gravity rotation (S40 never hits this). Pass =
	## engage + combat + never OBB-merged while still MARCHING.
	return observed_engaged and combat_resolved and not observed_left_marching_while_obb
