class_name Scenario08b
extends Scenario01

## S8b — Sequential depth-column check (WO-030).
## Attackers stack in depth on the approach axis (legacy S8 layout).
## Asserts sequential contact: defender never has 2+ partners at once.

const TRACE_PREFIX := "scenario_08b"

@export var attacker_count: int = 3

var _defender: Unit = null
var _attackers: Array[Unit] = []
var _defender_strength_start: float = 0.0
var max_defender_partners: int = 0
var multi_partner_ticks: int = 0


func _spawn_units() -> void:
	var profile := UnitProfileLoader.load_profile("test_infantry")
	var px_per_meter := Constants.get_float("px_per_meter")
	var depth_m := float(profile.get("formation_depth_m", Constants.get_float("default_infantry_block_depth_m")))
	var half_depth_px := depth_m * 0.5 * px_per_meter
	var stack_gap_px := depth_m * px_per_meter * 2.5

	_defender = UNIT_SCENE.instantiate()
	add_child(_defender)
	_defender.configure("defender", "blue", profile, Vector2.ZERO, Vector2.RIGHT)
	_defender.current_order = Unit.Order.HOLD
	_units.append(_defender)
	_defender_strength_start = _defender.strength

	for i in attacker_count:
		var attacker: Unit = UNIT_SCENE.instantiate()
		add_child(attacker)
		var attacker_id := "attacker_%d" % (i + 1)
		var spawn_x := half_depth_px * 2.0 + float(i) * stack_gap_px
		attacker.configure(attacker_id, "red", profile, Vector2(spawn_x, 0.0), Vector2.LEFT)
		attacker.set_march_to(Vector2(-half_depth_px, 0.0))
		_units.append(attacker)
		_attackers.append(attacker)


func advance_one_tick() -> void:
	super.advance_one_tick()
	_observe_partner_peak()


func _observe_partner_peak() -> void:
	if _defender == null:
		return
	var n := 0
	if _sim_core != null:
		for u in _sim_core.units:
			if str(u.unit_id) == "defender":
				n = u.get_contact_partners().size()
				break
	else:
		n = _defender.get_contact_partners().size()
	max_defender_partners = maxi(max_defender_partners, n)
	if n >= 2:
		multi_partner_ticks += 1


func _write_trace_file() -> void:
	var dir := DirAccess.open("res://tests")
	if dir == null:
		return
	if not dir.dir_exists("traces"):
		dir.make_dir("traces")
	var file_path := TRACE_DIR + TRACE_PREFIX + "_%d_%d.csv" % [_battle_seed, attacker_count]
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	for line in _trace_lines:
		file.store_line(line)
	print("[Scenario 08b] Trace written: %s" % file_path)


func get_defender_damage_taken() -> float:
	if _defender == null:
		return 0.0
	return maxf(_defender_strength_start - _defender.strength, 0.0)


func get_attacker_count() -> int:
	return attacker_count
