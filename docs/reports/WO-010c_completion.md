# WO-010c Completion Report

**Branch:** `cursor/wo-010c-testmode-perf-fd84`  
**Regression:** Full `scenario_wo010_autotest.gd` — **PASS** (byte-identical traces)

---

## Changes implemented

### 1. Overlap assertion → test-mode only

- `_overlap_assert_enabled()` returns `headless_mode && fast_sim_mode`
- `_run_overlap_assert_if_enabled()` gates all overlap checks
- Realtime gameplay (`headless_mode=false`) and gameplay-path perf harnesses (`fast_sim_mode=false`) skip overlap entirely
- Autotest / fast-mode runs retain mandatory overlap verification

### 2. MARCHING grid neighbor queries

- `_march_enemy_query_radius_px()` = `(2 × max_speed × tick_interval + max(depth+frontage)) × px_per_meter`
- `_grid_units_within_radius_sorted()` with deterministic `unit_id` ordering
- MARCHING and HOLD+MARCH_TO units use radius query; close-combat states keep spatial neighbors

### 3. Allied separation movement dirty flags

- `_capture_tick_start_positions()` at tick start
- `_resolve_allied_overlaps()` skips pairs where **neither** unit moved this tick
- Missing position record → keep check (correctness doubt rule)

---

## Performance results (gameplay path, warmup 600, profile 800)

### Wall-clock (`fast_sim_mode=false`, profiler off)

| Units | WO-010b | WO-010c | Δ |
|-------|---------|---------|---|
| 4 | 0.572 ms | **0.403 ms** | −30% |
| 20 | 7.011 ms | **4.861 ms** | −31% |
| **40** | **27.858 ms** | **21.003 ms** | **−25%** |

### Profiler breakdown (40 units)

| Subsystem | WO-010b | WO-010c | Δ |
|-----------|---------|---------|---|
| **total** | **28.3 ms** | **20.0 ms** | **−29%** |
| movement | 11.0 ms | 10.2 ms | −7% |
| allied_separation | 7.4 ms | 7.7 ms | +4% |
| contact_classification | 6.4 ms | 5.3 ms | −17% |
| **overlap_assert** | **8.0 ms** | **0.006 ms** | **−99.9%** |
| grid_overhead | 0.07 ms | 0.06 ms | — |
| classifier_calls/tick | 856 | 611 | −29% |

**Scaling (wall-clock):** 4 → 20 → 40 = 0.40 → 4.86 → 21.00 ms

### Target assessment

| Target | Result |
|--------|--------|
| 40-unit avg ≤ 12 ms cloud | **NOT MET** (21.0 ms) |
| Regression byte-identical | **PASS** |

---

## Analysis

The overlap assert removal from the gameplay tick delivered the largest single gain (~8 ms). Marching grid queries reduced classifier volume (−29%) with modest movement savings. Allied dirty-flag skipping had **minimal impact** in massed combat because most allied pairs move every tick during engagement.

Remaining ~20 ms at 40 units is dominated by:

1. **Allied separation** (~7.7 ms) — O(n²) grid pairs when all units share 1–2 cells
2. **Movement** (~10.2 ms) — routing/rally enemy scans + engagement contact probes in dense combat
3. **Classification** (~5.3 ms) — residual pair checks on grid neighbors

Further micro-optimization within the gameplay tick is unlikely to reach 12 ms without architectural change.

---

## Escalation

Per TD directive item (6): **STOP optimizing.** See `docs/reports/WO-010c_escalation_proposal.md`.
