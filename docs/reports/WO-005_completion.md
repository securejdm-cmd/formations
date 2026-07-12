# COMPLETION REPORT — WO-005

**Work order:** WO-005 ADDENDUM — Shrink-drain investigation + Modified Option C (GREEN LIGHT)  
**Branch:** `cursor/wo-005-shrink-drain-fix-fd84`  
**Pull request:** https://github.com/securejdm-cmd/formations/pull/7  
**Date:** 2026-07-11

---

## Built

Per TD GREEN LIGHT (Modified Option C):

1. **Simulation geometry reverted to WO-003 centered shrink** — collision and contact math use centered `effective_depth_m()` on unit origin; no rear-anchored position shifts; post-damage `snap_pair_to_contact` removed; shrink-drain experiment stays reverted.
2. **Render-only rear-anchored front-crack** — visual body rear edge holds at full-depth line; front face recedes as strength drops (same VisualRoot pattern as bump offset); simulation footprint unchanged.
3. **Grind band (bump) and crack fissures** — unchanged from WO-004/WO-005 addendum.

---

## Investigation summary (from escalation)

Shrink-drain hypothesis **rejected** — excluding shrink from `drain_per_meter_lost` moved combat only ~2s (39s → 41s). Root cause was real-geometry rear-anchor + snap, not drain double-count. See [`docs/reports/WO-005_escalation.md`](WO-005_escalation.md).

---

## 11-seed outcome table (WO-005 vs WO-003)

Combat durations returned to WO-003 band. **No winner flips.**

| Seed | Winner | March | Combat (WO-005) | Combat (WO-003) | Flee |
|------|--------|-------|-----------------|-----------------|------|
| 1000 | red_1 | 61.7s | 76.2s | 76.2s | 146.4s |
| 1001 | red_1 | 61.7s | 83.4s | 83.4s | 146.9s |
| 1002 | blue_1 | 61.7s | 77.0s | 77.0s | 153.9s |
| 1003 | blue_1 | 61.7s | 84.2s | 84.2s | 154.1s |
| 1004 | red_1 | 61.7s | 96.2s | 96.2s | 147.7s |
| 1005 | red_1 | 61.7s | 75.2s | 75.2s | 146.3s |
| 1006 | red_1 | 61.7s | 73.2s | 73.2s | 146.2s |
| 1007 | red_1 | 61.7s | 77.2s | 77.2s | 146.5s |
| 1008 | red_1 | 61.7s | 82.0s | 82.0s | 146.7s |
| 1009 | red_1 | 61.7s | 91.4s | 91.4s | 147.4s |
| 12345 | blue_1 | 61.7s | 78.0s | 78.0s | 153.9s |

**Winner flips:** none.

---

## Test results

| Criterion | Result |
|-----------|--------|
| Combat durations in WO-003 band (~73–96s) | **PASS** |
| No winner flips | **PASS** |
| Determinism (seed 12345) | **PASS** |
| No-overlap assertion (all seeds) | **PASS** |
| Kill accounting (men ≈ 1000) | **PASS** |
| Render-only front-crack (visual rear holds) | **PASS** (code) — designer hand-confirm |
| Crack fissures unchanged | **PASS** |
| Bump/grind band unchanged | **PASS** |

---

## Files changed

| File | Change |
|------|--------|
| `scripts/unit.gd` | Centered sim geometry; render-only rear-anchored body; crack fissures |
| `scripts/combat_resolver.gd` | Removed sim rear-anchor position shift from strength loss |
| `scripts/scenario_01.gd` | Removed post-damage snap |
| `data/combat_constants.json` | Crack fissure constants (unchanged values) |
| `tests/scenario_01_autotest.gd` | WO-005 harness labels |
| `docs/reports/WO-005_escalation.md` | Investigation record |
| `docs/reports/WO-005_completion.md` | This report |

---

## Assumptions made

**NONE**

---

## Known issues

- **Designer hand-confirm** — render-only front-crack reads as rear-holding / front-receding during combat; crack fissures visible on engaged front.
- **Deferred mechanic (TD ruling):** “Casualties = ground yielded” as a **real simulation mechanic** is **DEFERRED**. Revisit only if a future phase gives it gameplay value worth the tuning cost. Current build uses centered sim footprint with visual-only front recession.
