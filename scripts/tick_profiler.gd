class_name TickProfiler
extends RefCounted

## Optional tick instrumentation for WO-010b performance work.

static var enabled: bool = false
static var _section_usec: Dictionary = {}
static var _tick_count: int = 0
static var classifier_calls: int = 0
static var adhesion_classifier_calls: int = 0
static var binary_search_iterations: int = 0
static var adhesion_pairs_processed: int = 0
static var _classification_usec: int = 0
static var adhesion_context: bool = false


static func reset() -> void:
	_section_usec.clear()
	_tick_count = 0
	classifier_calls = 0
	adhesion_classifier_calls = 0
	binary_search_iterations = 0
	adhesion_pairs_processed = 0
	_classification_usec = 0


static func begin_section(name: String) -> int:
	if not enabled:
		return -1
	return Time.get_ticks_usec()


static func end_section(name: String, start_usec: int) -> void:
	if not enabled or start_usec < 0:
		return
	var elapsed := Time.get_ticks_usec() - start_usec
	_section_usec[name] = int(_section_usec.get(name, 0)) + elapsed


static func on_tick_complete() -> void:
	if not enabled:
		return
	_tick_count += 1


static func record_classifier(from_adhesion: bool = false) -> void:
	if not enabled:
		return
	classifier_calls += 1
	if from_adhesion or adhesion_context:
		adhesion_classifier_calls += 1


static func record_binary_search_step() -> void:
	if not enabled:
		return
	binary_search_iterations += 1


static func record_adhesion_pair() -> void:
	if not enabled:
		return
	adhesion_pairs_processed += 1


static func begin_classification() -> int:
	if not enabled:
		return 0
	return Time.get_ticks_usec()


static func end_classification(start_usec: int) -> void:
	if not enabled:
		return
	_classification_usec += Time.get_ticks_usec() - start_usec


static func get_report(unit_count: int) -> Dictionary:
	var ticks := maxi(_tick_count, 1)
	var sections_ms: Dictionary = {}
	var total_usec := 0
	for key in _section_usec.keys():
		var usec: int = int(_section_usec[key])
		total_usec += usec
		sections_ms[key] = float(usec) / float(ticks) / 1000.0
	sections_ms["total"] = float(total_usec) / float(ticks) / 1000.0
	sections_ms["contact_classification"] = float(_classification_usec) / float(ticks) / 1000.0
	return {
		"unit_count": unit_count,
		"tick_samples": ticks,
		"sections_ms": sections_ms,
		"classifier_calls_per_tick": float(classifier_calls) / float(ticks),
		"adhesion_classifier_calls_per_tick": float(adhesion_classifier_calls) / float(ticks),
		"binary_search_iterations_per_tick": float(binary_search_iterations) / float(ticks),
		"adhesion_pairs_per_tick": float(adhesion_pairs_processed) / float(ticks),
	}
