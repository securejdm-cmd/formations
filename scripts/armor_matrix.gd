class_name ArmorMatrix
extends RefCounted

const MATRIX_PATH := "res://data/armor_matrix.json"

static var _multipliers: Dictionary = {}
static var _loaded: bool = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open(MATRIX_PATH, FileAccess.READ)
	if file == null:
		push_error("ArmorMatrix: failed to open %s" % MATRIX_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("ArmorMatrix: invalid JSON in %s" % MATRIX_PATH)
		return
	_multipliers = parsed.get("multipliers", {})


static func class_vs_type(armor_class: String, damage_type: String) -> float:
	_ensure_loaded()
	var row: Variant = _multipliers.get(armor_class, null)
	if row == null:
		push_error("ArmorMatrix: unknown armor_class '%s'" % armor_class)
		return 1.0
	var mult: Variant = row.get(damage_type, null)
	if mult == null:
		push_error("ArmorMatrix: unknown damage_type '%s' for class '%s'" % [damage_type, armor_class])
		return 1.0
	return float(mult)


static func reload() -> void:
	_loaded = false
	_multipliers = {}
	_ensure_loaded()
