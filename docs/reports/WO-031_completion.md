# WO-031 Completion Report — Order System: Data Model & Headless Execution

**Status:** COMPLETE  
**Branch:** `cursor/wo-031-order-system-fd84`  
**Base:** main @ v0.2-phase2-sim (`1140540`)  
**TD green light:** 1A–7A with clarifications (flank offset default 100; attack_* terminal→hold; absolute_hold vs push; `unit_order_started`; R23–R25 only)

## Built

### Task 1 — Order data model + executor (R23/R24)
- Per-unit queue cap 3; primitives and triggers per schema.
- Headless `OrderExecutor` on `SimBattleCore` — pure no-op when no queues/horns.
- Absolute hold (2A): face-only gravity; no march/pursuit/drift; push shift lawful.
- Horn (1A): immediate queue abort → fighting withdrawal → own-edge retirement; ordered-retreat drain × Retreating Skill.
- Flank arc (3A): single lateral waypoint; `flank_arc_offset_m` default 100, per-params override.
- attack_* (4A): ignores routers; target rout/remove completes step → queue advances → exhausted = hold.

### Task 2 — Battle-type schema (R25)
- Structure only: `battle_type`, `deployment_zones`, `posture`, `victory_spec`.
- Documented in `/docs/ORDER_SCHEMA.md`. R23–R25 appended to DESIGN_RULINGS (not R26).

### Task 3 — Proof battles
| Scenario | Result (11 seeds) |
|----------|-------------------|
| S41 Hammer & Anvil | **11/11** flank/rear charge (typically `rear`, shock ~94) |
| S42 Cannae | **11/11** left/right/rear edges; enemy cohesion collapse |
| S43 Horn | **11/11** saved men; total_margin ≈708 strength |
| S44 Absolute vs Hold | **11/11** abs_disp=0; hold drifts ~20m |

### Task 4 — Order-state observability
- `EVENT,order_state,...` and `EVENT,order_started,...` only when queues/horn active (5A).
- S1 seed 1000 baseline: **byte-identical** (0 order events).

### Task 5 — Regression
- Suite Meta **PASS=78 FAIL=0 exit=0**
- GAMEPLAY_TICK p95=**31.834** ms (gate 50ms PASS; no optimization this WO)

## Files changed (primary)
- `docs/work_orders/WORK_ORDER_031.md`, `docs/ORDER_SCHEMA.md`, `docs/DESIGN_RULINGS_v1.2.md` (R23–R25)
- `docs/reports/WO-031_escalation.md`, `docs/reports/WO-031_completion.md`
- `scripts/orders/order_schema.gd`, `scripts/orders/order_executor.gd`
- `scripts/sim/sim_battle_core.gd`, `scripts/sim/sim_unit_proxy.gd`, `scripts/unit.gd`, `scripts/combat_resolver.gd`
- `data/combat_constants.json` (`flank_arc_offset_m`)
- `scripts/scenario_41.gd`–`44.gd`, `tests/scenario_41.tscn`–`44.tscn`
- `tests/scenario_wo010_autotest.gd` (EXPECTED_GREEN_PASS_COUNT=78)

## Tests

| criterion | result |
|-----------|--------|
| Order schema + executor; ambiguities escalated then green-lit | PASS |
| Battle-type schema documented; structure only | PASS |
| S41–S44 across 11 seeds with edge/shock/cascade evidence | PASS |
| Order-state visible in traces (EVENT) | PASS |
| S1–S40 byte-identical (S1_1000 verified) | PASS |
| Suite exit 0; meta reconciled | PASS — 78/0 |
| GAMEPLAY_TICK reported | PASS — p95=31.834 |

## Assumptions made
NONE (all prior ambiguities resolved by TD green light 1A–7A).

## Known issues
none
