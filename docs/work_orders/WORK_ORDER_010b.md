# WORK ORDER 010b — Performance Profile & Hot-Path Optimization

**Status:** Complete (performance target partially met; regression PASS)  
**Parent:** WO-010 (Gate 1 remediation)  
**TD Verdict:** Performance REJECTED on WO-010 → GREEN LIGHT for WO-010b

## Directive

1. **PROFILE FIRST** — instrument tick; report 40-unit subsystem breakdown before optimizing.
2. Optimize adhesion/classifier hot path: AABB early-outs, per-pair contact cache with dirty flags, capped binary search.
3. Keep spatial grid only if breakdown justifies it.
4. Targets: 40-unit avg ≤10 ms cloud; scaling closer to linear; regression byte-identical.

## Deliverables

- [x] `scripts/tick_profiler.gd` — subsystem timers + classifier counters
- [x] `scripts/contact_cache.gd` — per-tick directed contact cache
- [x] `tests/scenario_wo010b_profile.gd` — 4/20/40 breakdown harness
- [x] `tests/scenario_wo010b_wallclock.gd` — wall-clock harness (profiler off)
- [x] `docs/reports/WO-010b_completion.md` — before/after tables + escalation notes
- [x] Full `scenario_wo010_autotest.gd` byte-identical PASS

## Outcome

- 40-unit tick reduced ~40 ms → ~28 ms (−30%); classifier calls −71%.
- 10 ms cloud target **not met** — further work needs pair-set reduction in massed overlap/allied passes.
- Spatial grid **retained** (0.07 ms/tick).
