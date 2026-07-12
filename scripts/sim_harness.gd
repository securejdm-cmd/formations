class_name SimHarness
extends RefCounted

## Headless simulation drivers — fixed 10 Hz tick math, decoupled from wall clock.

enum RunMode { FAST, REALTIME }


static func tick_interval() -> float:
	return CombatResolver.tick_interval()


static func run_ticks(scenario: Scenario01, tick_count: int) -> void:
	for _i in tick_count:
		scenario.advance_one_tick()


static func run_to_completion(scenario: Scenario01, mode: RunMode, extra_ticks: int = 0) -> void:
	match mode:
		RunMode.FAST:
			_run_fast(scenario, extra_ticks)
		RunMode.REALTIME:
			_run_realtime(scenario, extra_ticks)


static func _run_fast(scenario: Scenario01, extra_ticks: int) -> void:
	while not scenario.is_battle_over():
		scenario.advance_one_tick()
	for _i in extra_ticks:
		scenario.advance_one_tick()


static func _run_realtime(scenario: Scenario01, extra_ticks: int) -> void:
	var interval := tick_interval()
	while not scenario.is_battle_over():
		scenario.simulate_realtime_step(interval)
	for _i in extra_ticks:
		scenario.simulate_realtime_step(interval)


static func trace_bytes(scenario: Scenario01) -> PackedByteArray:
	return scenario.get_trace_text().to_utf8_buffer()


static func traces_match(a: Scenario01, b: Scenario01) -> bool:
	return trace_bytes(a) == trace_bytes(b)
