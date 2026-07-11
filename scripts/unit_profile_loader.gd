class_name UnitProfileLoader
extends RefCounted

const UNITS_DIR := "res://data/units/"


static func load_profile(profile_id: String) -> Dictionary:
	var path := UNITS_DIR + profile_id + ".json"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("UnitProfileLoader: failed to open %s" % path)
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("UnitProfileLoader: %s is not a valid JSON object" % path)
		return {}

	return parsed
