# WORK ORDER 010c — Gameplay-Path Performance Pass

**Status:** Complete — regression PASS; **12 ms target NOT MET** (escalation filed)  
**Parent:** WO-010b  
**TD Verdict:** WO-010b APPROVED as profiling exemplar; one targeted pass authorized

## Directive

1. No-overlap assertion → test-mode only (autotest + fast-mode)
2. MARCHING units → grid neighbor queries with reach-derived radius
3. Allied separation → skip pairs where neither unit moved (dirty flags)
4. Re-measure 4/20/40 profiler + wall-clock; target ≤12 ms @ 40 units
5. Full regression byte-identical
6. If target unmet → STOP optimizing; escalate with written proposal

## Deliverables

- [x] `_overlap_assert_enabled()` — `headless_mode && fast_sim_mode` gate
- [x] `_grid_units_within_radius_sorted()` + `_march_enemy_query_radius_px()`
- [x] `_capture_tick_start_positions()` / `_unit_moved_this_tick()` allied skip
- [x] Perf harnesses use gameplay path (`fast_sim_mode=false`)
- [x] Full regression PASS
- [x] Escalation proposal (`docs/reports/WO-010c_escalation_proposal.md`)
