class_name SimThreadController
extends RefCounted

## Worker-thread 10 Hz sim driver (WO-011). Operates on plain SimBattleCore only.

const SimRngBridge := preload("res://scripts/sim/sim_rng_bridge.gd")

var _thread: Thread
var _mutex: Mutex
var _core = null
var _stop: bool = false
var _running: bool = false
var _last_tick_usec: int = 0
var _tick_interval_sec: float = 0.1
var _realtime_pacing: bool = true
var _snapshot_front: Array = []
var _snapshot_back: Array = []
var _tick_times_usec: Array[int] = []
## WO-029b: visual events produced on the worker, drained on the main thread.
var _visual_front: Dictionary = {"shock": [], "volley": []}


func start(core, realtime_pacing: bool = true) -> void:
	_core = core
	_realtime_pacing = realtime_pacing
	_tick_interval_sec = 1.0 / Constants.get_float("tick_rate_per_sec")
	_mutex = Mutex.new()
	_stop = false
	_running = true
	_snapshot_front = core.build_render_snapshot()
	_snapshot_back = _snapshot_front.duplicate()
	_thread = Thread.new()
	_thread.start(_worker_loop)


func stop() -> void:
	_stop = true
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	_running = false
	SimRngBridge.clear_worker_rng()


func is_running() -> bool:
	return _running


func get_last_tick_usec() -> int:
	return _last_tick_usec


func get_tick_times_usec() -> Array[int]:
	return _tick_times_usec.duplicate()


func get_core():
	_mutex.lock()
	var core = _core as SimBattleCore
	_mutex.unlock()
	return core


func wait_for_completion() -> void:
	while _running:
		OS.delay_usec(500)


func apply_snapshot_to_units(unit_nodes: Array) -> void:
	_mutex.lock()
	var snap := _snapshot_front
	_mutex.unlock()
	if _core != null:
		_core.apply_render_snapshot(snap, unit_nodes)


func take_pending_visuals_for_main() -> Dictionary:
	_mutex.lock()
	var visuals: Dictionary = _visual_front
	_visual_front = {"shock": [], "volley": []}
	_mutex.unlock()
	return visuals


func _worker_loop() -> void:
	while not _stop:
		var tick_start := Time.get_ticks_usec()
		# Advance outside the mutex so overlap push_error / logging cannot
		# stall the main thread (which only needs the snapshot briefly).
		var core = _core
		var done := false
		if core != null and not core.battle_over:
			core.advance_one_tick()
			var snap: Array = core.build_render_snapshot()
			var visuals: Dictionary = core.take_pending_visuals()
			_mutex.lock()
			_snapshot_back = snap
			var tmp := _snapshot_front
			_snapshot_front = _snapshot_back
			_snapshot_back = tmp
			# Append — main may not drain every worker tick under load.
			var shock: Array = _visual_front.get("shock", [])
			var volley: Array = _visual_front.get("volley", [])
			shock.append_array(visuals.get("shock", []))
			volley.append_array(visuals.get("volley", []))
			_visual_front = {"shock": shock, "volley": volley}
			done = core.battle_over
			_mutex.unlock()
		else:
			done = core != null and core.battle_over
		_last_tick_usec = Time.get_ticks_usec() - tick_start
		# Cap samples — unpaced headless workers can otherwise grow this array
		# unboundedly and stall later stats sorts (S40→perf_40 cloud hang).
		if _tick_times_usec.size() < 10000:
			_tick_times_usec.append(_last_tick_usec)
		if done:
			break
		if _realtime_pacing:
			var sleep_ms := maxi(int((_tick_interval_sec * 1000000.0 - _last_tick_usec) / 1000.0), 1)
			OS.delay_msec(sleep_ms)
	_running = false
	SimRngBridge.clear_worker_rng()
