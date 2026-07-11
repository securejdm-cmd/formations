extends Node

## Loads all tunable gameplay constants from data/combat_constants.json at startup.

const CONSTANTS_PATH := "res://data/combat_constants.json"

var _constants: Dictionary = {}


func _init() -> void:
	_load_constants()


func _ready() -> void:
	if _constants.is_empty():
		_load_constants()


func _load_constants() -> void:
	var file := FileAccess.open(CONSTANTS_PATH, FileAccess.READ)
	if file == null:
		push_error("Constants: failed to open %s" % CONSTANTS_PATH)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Constants: %s is not a valid JSON object" % CONSTANTS_PATH)
		return

	_constants = parsed


func get_constant(key: StringName, default_value: Variant = null) -> Variant:
	return _constants.get(key, default_value)


func get_float(key: StringName, default_value: float = 0.0) -> float:
	return float(_constants.get(key, default_value))


func get_int(key: StringName, default_value: int = 0) -> int:
	return int(_constants.get(key, default_value))


func has_constant(key: StringName) -> bool:
	return _constants.has(key)


func get_all_constants() -> Dictionary:
	return _constants.duplicate(true)
