# WO-012 Completion Report — Sim Core Consolidation

**Status:** COMPLETE  
**Branch:** `cursor/wo-012-sim-core-consolidation-fd84`  
**Prerequisite:** WO-011 merged; required before Phase 2 mechanics.

## Summary

`SimBattleCore` is now the **single authoritative combat implementation**. Headless fast mode and realtime threaded mode both execute that core; Scenario01’s legacy inline combat path (~648 lines) was deleted after byte-identical certification. Canonical combat libraries (`CombatResolver`, `EdgeContact`, `FormationGeometry`, `ContactCache`) accept `Variant` unit parameters and are shared by the core and scenarios.

## Architecture (end state)

| Layer | Role |
|-------|------|
| `SimBattleCore` | Sole tick/combat/grid/victory implementation |
| `SimUnitProxy` | Plain unit mirror; stable proxy reuse + partner sync to `Unit` nodes |
| `SimThreadController` | Worker thread + double-buffer snapshots (unchanged semantics) |
| `Scenario01` | Thin orchestration: capture → core tick → apply → event hooks |
| `CombatResolver` / `EdgeContact` / `FormationGeometry` / `ContactCache` | One Variant-typed combat library set (no sim duplicates) |

## File-level deletion accounting (duplicate combat removed)

| File | Approx. lines | Notes |
|------|---------------|-------|
| `scripts/sim/sim_combat_resolver.gd` | 659 | Deleted — was Variant copy of `combat_resolver.gd` |
| `scripts/sim/sim_edge_contact.gd` | 397 | Deleted — was Variant copy of `edge_contact.gd` |
| `scripts/sim/sim_formation_geometry.gd` | 108 | Deleted — was Variant copy of `formation_geometry.gd` |
| `scripts/sim/sim_contact_cache.gd` | 35 | Deleted — was Variant copy of `contact_cache.gd` |
| `scripts/sim/sim_combat_dispatch.gd` | 83 | Deleted — facade to sim copies |
| `scripts/sim/fix_variant_inference.py` | 70 | Deleted — one-shot migration helper |
| `scripts/scenario_01.gd` (combat body) | **648** | Removed duplicate grid/movement/combat/victory logic; replaced with thin `_sim_core` wrappers |

**Net:** six sim combat files removed; Scenario01 combat implementation eliminated in favor of delegation.

## WO-011 report amendment (TD directive)

**Measured 40-unit threaded p95 sim-thread tick (cloud VM, seed 1000, `perf_40` autotest):**

| Metric | Value |
|--------|-------|
| **p95_tick_ms** | **28.163** |
| avg_tick_ms | 14.003 |
| max_tick_ms | 68.729 |
| worker ticks sampled | 2038 |

Gate: p95 ≤ 50 ms — **PASS**.

## Certification (byte-identical — no drift)

```
[WO-010] Fast-mode certification PASS (seed 12345 trace byte-identical)
[WO-011] Threaded certification PASS (seed 12345 trace byte-identical)
tests/wo011_trace_diff.gd → TRACE MATCH (627 lines)
```

Full `scenario_wo010_autotest.gd` run (cloud): S1–S8, determinism, S3–S7, Perf40 PASS; S2 rout metrics restored after post-apply event hook fix (`rout_strength=67.29` seed 1000).

## Key integration fixes

1. **Partner sync:** `SimUnitProxy.apply_to_unit()` now syncs contact partners to `Unit` nodes (required for fast-mode capture each tick).
2. **Stable proxies:** `capture_from_units()` reuses proxy objects across per-phase syncs (child scenario custom tick pipelines).
3. **Scenario hooks:** `_on_first_contact` / `_on_first_rout` dispatched after core→unit apply so Scenario02/03 overrides see live `Unit` state.

## Constraints honored

- No behavior changes intended — traces byte-identical vs WO-011 baseline.
- No constants changes.
- No new gameplay features.
- Exactly **one** combat tick implementation (`SimBattleCore`).
