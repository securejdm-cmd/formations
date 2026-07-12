class_name SimContactCache
extends RefCounted

## Per-tick directed contact classification cache (WO-010b).

static var _entries: Dictionary = {}
static var _tick_id: int = -1


static func begin_tick(tick_id: int) -> void:
	if _tick_id != tick_id:
		_entries.clear()
		_tick_id = tick_id


static func pose_hash(unit: Variant) -> int:
	var p: Vector2 = unit.position
	var f: Vector2 = unit.facing
	return hash([p.x, p.y, f.x, f.y])


static func lookup(attacker: Variant, defender: Variant):
	var key: String = attacker.unit_id + ">" + defender.unit_id
	if not _entries.has(key):
		return null
	var entry: Dictionary = _entries[key]
	if (
		int(entry.pose_a) == pose_hash(attacker)
		and int(entry.pose_b) == pose_hash(defender)
	):
		return entry.contact
	return null


static func store(attacker: Variant, defender: Variant, contact: Dictionary) -> void:
	var key: String = attacker.unit_id + ">" + defender.unit_id
	_entries[key] = {
		"pose_a": pose_hash(attacker),
		"pose_b": pose_hash(defender),
		"contact": contact,
	}
