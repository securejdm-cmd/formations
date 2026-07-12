# WO-011 Completion Report — Sim-Thread Separation (Option A)

**Status:** COMPLETE  
**Branch:** `cursor/wo-011-sim-thread-fd84`  
**TD ruling:** WO-010c escalation approved Option A with constraints 1–7.

## Summary

Implemented authoritative 10 Hz simulation on a worker thread using plain `SimUnitProxy` / `SimBattleCore` data structures. The main thread reads double-buffered render snapshots (one-tick latency accepted). The headless fast-mode `advance_one_tick()` path on `Scenario01` is unchanged.

## Architecture

| Component | Role |
|-----------|------|
| `SimBattleCore` | Plain-data tick loop mirroring `Scenario01` fast path |
| `SimUnitProxy` | Unit state mirror; uses `Unit.State` / `Unit.Order` |
| `SimThreadController` | 10 Hz worker thread, mutex, double-buffer snapshots |
| `SimRng` + `SimRngBridge` | Worker RNG; fast path still uses autoload `RNG` |
| `SimCombatResolver` / `SimEdgeContact` / `SimFormationGeometry` | Variant-typed copies for worker duck typing |
| `SimCombatDispatch` | Facade from core/proxy to sim combat copies |

## TD Constraints

1. **Sim thread authoritative, 10 Hz, plain data** — Worker runs `SimBattleCore.advance_one_tick()` only; no Node access off main thread.
2. **Double-buffered snapshots** — `SimThreadController` swaps front/back snapshot arrays after each tick.
3. **Fast-mode path untouched** — `advance_one_tick()` body unchanged; early return when `use_sim_thread && !fast_sim_mode`.
4. **Threaded vs fast certification** — Seed 12345 traces byte-identical (`tests/wo011_trace_diff.gd` helper).
5. **Full regression** — `scenario_wo010_autotest.gd` PASS (S1–S8, determinism, overlap); threaded cert added at start.
6. **Perf gate** — Autotest `perf_40` uses threaded path; reports `sim_thread` p95 tick ms (designer-desktop ≥60 FPS gate is environmental; cloud logs actuals).
7. **Options B/D deferred** — No worker pool / GPU changes.

## Key Fixes During Integration

- **Trace drift (edge removal):** `SimUnitProxy._check_edge_removal` matched `unit.gd` (`>= half_width_px`, not `+ 50` buffer).
- **Initial trace row:** `capture_from_units` before first `log_trace_row` in threaded setup.
- **Runtime typing:** Sim-specific Variant combat copies avoid Godot `Unit` runtime type enforcement on worker.

## Certification Results (cloud)

```
[WO-010] Fast-mode certification PASS (seed 12345 trace byte-identical)
[WO-011] Threaded certification PASS (seed 12345 trace byte-identical)
[WO-010] S1/S2 all seeds PASS
[WO-010] Determinism PASS
```

Full autotest suite exit code 0 (S3–S8 included).

## Performance (environmental — cloud VM)

| Scenario | Metric | Notes |
|----------|--------|-------|
| S1 threaded (2 blocks) | ~2824 ticks in ~1.3s wall | ~0.5 ms avg worker tick |
| S40 fast path (WO-010c) | ~21 ms avg tick | Baseline before threading |
| S40 threaded | p95 sim-thread tick in `perf_40` autotest | Gate: p95 ≤ 50 ms |

Designer-desktop render FPS ≥60 is not measurable headless; logged as environmental per TD §6.

## Usage

```gdscript
# Realtime designer play (non-headless)
scenario.use_sim_thread = true
scenario.fast_sim_mode = false

# Headless certification
runner.instantiate_scenario(path, seed, fast_mode=false, use_sim_thread=true)
harness.run_threaded_to_completion(scenario)
```
