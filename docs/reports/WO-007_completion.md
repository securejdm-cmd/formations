# COMPLETION REPORT — WO-007

**Work order:** WO-007 — Direction Independence + Rout-Band Tuning Sweep  
**Branch:** `cursor/wo-007-direction-independence-fd84`  
**Date:** 2026-07-11

---

## Built

### Task A — Direction-independence fix

**Root cause (plain English):** Routed units fled toward a **fixed map direction based on team color** (`red` always fled left, `blue` always fled right). In mirrored battles, teams swap sides but kept the same flee direction — so the loser ran **toward** the winner instead of off the map. That caused late-combat overlaps and broke reflection symmetry. Combat/contact/push math was already facing-relative; only the rout flee vector was world-axis biased.

**Fix:** `Unit._flee_direction()` now returns `-facing.normalized()` — flee backward along the unit's engagement axis, independent of team or map side.

**Reflection Test** (seeds 1000–1004): **5/5 PASS**
- Per-unit `strength`, `cohesion`, `kills`, `state` traces identical (unit-keyed)
- `pos_x` reflected about map center (`normal + mirror ≈ 0`, tolerance ±0.05 px)
- Zero overlap failures in normal **and** mirrored runs

**Symmetry standard documented:** `docs/SIMULATION_SYMMETRY.md` (TD ruling: per-unit RNG wobble accepted; unit-keyed reflection required).

### Task B — Rout-band tuning sweep (data only)

12-cell grid over `drain_per_meter_lost` × `drain_per_strength_pct_lost`. Constants file **unchanged**; overrides applied in-memory during autotest only.

---

## Post-fix 11-seed tables vs prior work orders

### Scenario 1 — no changes vs WO-005

| Seed | Winner | Combat (post-fix) | WO-005 | Change |
|------|--------|-------------------|--------|--------|
| 1000 | red_1 | 76.2s | 76.2s | none |
| 1001 | red_1 | 83.4s | 83.4s | none |
| 1002 | blue_1 | 77.0s | 77.0s | none |
| 1003 | blue_1 | 84.2s | 84.2s | none |
| 1004 | red_1 | 96.2s | 96.2s | none |
| 1005 | red_1 | 75.2s | 75.2s | none |
| 1006 | red_1 | 73.2s | 73.2s | none |
| 1007 | red_1 | 77.2s | 77.2s | none |
| 1008 | red_1 | 82.0s | 82.0s | none |
| 1009 | red_1 | 91.4s | 91.4s | none |
| 12345 | blue_1 | 78.0s | 78.0s | none |

**Winner flips:** none. Fix affects mirrored rout geometry only; standard Scenario 1 spawn positions produce identical flee directions as before.

### Scenario 2 — no changes vs WO-006

| Seed | Winner | Combat | strength_at_rout | vs WO-006 |
|------|--------|--------|------------------|-----------|
| 1000–12345 | red_1 (11/11) | 44.2–44.6s | 46.38–46.55 | all match |

---

## Rout-band sweep matrix

Baseline post-fix defaults: `drain_per_meter_lost=0.8`, `drain_per_strength_pct_lost=1.5` → mean S2 rout **46.49%**, mean S2 combat **44.3s**, mean S1 combat **81.3s**.

| drain_meter | drain_strength% | mean S2 rout% | mean S2 combat | mean S1 combat | S1 winner Δ | S2 winner Δ |
|-------------|-----------------|---------------|----------------|----------------|-------------|-------------|
| 0.8 | 1.5 | 46.49 | 44.3s | 81.3s | 0 | 0 |
| 0.8 | 2.0 | 58.46 | 33.6s | 57.9s | 1 | 0 |
| 0.8 | 2.5 | 66.08 | 27.0s | 45.1s | 1 | 0 |
| 1.2 | 1.5 | 49.07 | 41.7s | 78.2s | 0 | 0 |
| 1.2 | 2.0 | 59.98 | 32.2s | 56.5s | 1 | 0 |
| 1.2 | 2.5 | 67.07 | 26.1s | 44.3s | 1 | 0 |
| 1.6 | 1.5 | 51.37 | 39.5s | 74.8s | 1 | 0 |
| 1.6 | 2.0 | 61.31 | 30.9s | 55.2s | 1 | 0 |
| 1.6 | 2.5 | 67.98 | 25.2s | 43.7s | 1 | 0 |
| 2.0 | 1.5 | 53.42 | 37.5s | 72.5s | 1 | 0 |
| 2.0 | 2.0 | 62.59 | 29.7s | 54.0s | 1 | 0 |
| 2.0 | 2.5 | 68.83 | 24.4s | 43.0s | 1 | 0 |

**Reading for TD:** Raising `drain_per_strength_pct_lost` moves mean `strength_at_rout` toward the 60–75% design band but shortens both scenarios sharply. Cells with `drain_strength ≥ 2.0` land near target rout % (58–69%) while pulling Scenario 1 mean combat below the 60–90s guardrail. No sweep cell holds S1 near 81s **and** S2 rout near 65% simultaneously — tradeoff is explicit in the matrix.

Winner changes vs post-fix baseline: S2 stable (0 flips in all cells); S1 flips 1 seed when `drain_strength ≥ 2.0` or `drain_meter ≥ 1.6` with `drain_strength 1.5`.

---

## Test results

| Criterion | Result |
|-----------|--------|
| Reflection Test (5 seeds, unit-keyed + reflected positions + zero overlaps) | **PASS** |
| Root cause explained in report | **PASS** |
| Post-fix 11-seed tables S1 + S2 | **PASS** (no drift vs WO-005/WO-006) |
| Sweep matrix (12 cells) | **PASS** |
| `combat_constants.json` untouched | **PASS** |
| Determinism post-fix | **PASS** |
| Symmetry standard in `/docs` | **PASS** (`docs/SIMULATION_SYMMETRY.md`) |

**State tolerance:** exact string match on trace `state` column; no mismatches observed post-fix.

---

## Files changed

| File | Change |
|------|--------|
| `scripts/unit.gd` | Flee direction: team-based → `-facing` |
| `scripts/constants_service.gd` | Runtime `set_constant` / `reload_from_file` for sweep harness |
| `tests/scenario_wo007_autotest.gd` | Reflection Test + post-fix tables + sweep |
| `docs/SIMULATION_SYMMETRY.md` | TD symmetry standard |
| `docs/reports/WO-007_completion.md` | This report |

---

## Assumptions made

**NONE**

---

## Known issues

- Designer hand-confirm items from prior WOs remain open.
- Rout-band tuning values not committed — awaiting TD selection from sweep matrix.
- Per-unit RNG stream design: mirror winners may match normal winners by team color; documented as accepted in `docs/SIMULATION_SYMMETRY.md`.
