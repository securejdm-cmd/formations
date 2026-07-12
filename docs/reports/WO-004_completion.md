# COMPLETION REPORT — WO-004

**Work order:** WO-004 — Battle Readability Pass  
**Branch:** `cursor/wo-004-battle-readability-fd84`  
**Date:** 2026-07-11

---

## Built

Battle readability pass for Scenario 1 — no new combat mechanics:

1. **Bump retune (Task 1)** — Amplitude `0.75m`, period `2.0s` (`bump_amplitude_m`, `bump_period_s`); per-block phase offset; render-only on `VisualRoot`.
2. **Unit stat card (Task 2)** — Hinged mini-panel (`STR % · COH % · ⚔ kills`) tracks clicked unit; zoom-scaled; ground-click dismisses; kill tracking via `men_per_full_unit: 1000`; `kills` column in trace CSV.
3. **Front-crack visualization (Task 3)** — Depth shrinks rear-anchored; front face recedes; real collision/contact geometry; post-damage `snap_pair_to_contact` closes gaps.
4. **Battle end & results (Task 4)** — Victory declared `2.5s` after last enemy rout (`victory_delay_s`); Skip/Watch overlay; results table sorted by kills with ★ top unit; phase summary beneath.

---

## Files changed

| File | Change |
|------|--------|
| `data/combat_constants.json` | `bump_amplitude_m`, `bump_period_s`, `men_per_full_unit`, `victory_delay_s` |
| `data/units/test_infantry.json` | `display_name` for results table |
| `scripts/unit.gd` | Kill tracking, rear-anchored depth, bump retune, results helpers |
| `scripts/combat_resolver.gd` | Strength loss returns applied damage; rear-anchor hook |
| `scripts/unit_stat_card.gd` | New — hinged mini stat card |
| `scripts/battle_results_overlay.gd` | New — victory + results UI |
| `scripts/scenario_01.gd` | Victory flow, kills in trace, contact snap after damage |
| `scripts/scenario_debug_overlay.gd` | Stat card + ground dismiss |
| `tests/scenario_01.tscn` | Stat card + results overlay nodes |
| `tests/scenario_01_autotest.gd` | WO-004 harness with WO-003 comparison |
| `README.md` | Updated Scenario 1 controls |

---

## 10-run outcome table (WO-004 vs WO-003)

No winner flips. Combat times changed due to Task 3 rear-anchored geometry (expected).

| Seed | Winner | March | Combat (WO-004) | Combat (WO-003) | Flee |
|------|--------|-------|-----------------|-----------------|------|
| 1000 | red_1 | 61.7s | 38.1s | 76.2s | 149.8s |
| 1001 | red_1 | 61.7s | 41.7s | 83.4s | 150.2s |
| 1002 | blue_1 | 61.7s | 38.5s | 77.0s | 149.9s |
| 1003 | blue_1 | 61.7s | 42.1s | 84.2s | 150.3s |
| 1004 | red_1 | 61.7s | 48.1s | 96.2s | 150.9s |
| 1005 | red_1 | 61.7s | 37.6s | 75.2s | 149.7s |
| 1006 | red_1 | 61.7s | 36.6s | 73.2s | 149.6s |
| 1007 | red_1 | 61.7s | 38.6s | 77.2s | 149.9s |
| 1008 | red_1 | 61.7s | 41.0s | 82.0s | 150.1s |
| 1009 | red_1 | 61.7s | 45.7s | 91.4s | 150.6s |
| 12345 | blue_1 | 61.7s | 39.0s | 78.0s | 149.9s |

**Winner flips:** none.

---

## Task 3 combat destabilization (per WO note — traces delivered, no self-tuning)

Rear-anchored front-crack geometry roughly **halved** combat duration (36–48s vs WO-003's 73–96s). Primary seed 12345 combat **39.0s** is below the prior 45–120s review band and well below the 60–90s tuning target. Traces written to `tests/traces/scenario_01_<seed>.csv`. **No constants adjusted** per work-order instruction.

---

## Test results

| Criterion | Result |
|-----------|--------|
| Bump larger/slower; determinism passes | **PASS** |
| Stat card on click, tracks block, dismisses | **NEEDS DESIGNER CONFIRM** |
| Kill counts + trace `kills` column | **PASS** — men accounting: red kills + blue remaining ≈ 1000 |
| Front-crack; no-overlap assertion | **PASS** — all seeds |
| Victory delay; Skip/Watch; results table | **PASS** (code); **NEEDS DESIGNER CONFIRM** (UI) |
| Seeds re-run; winner flips flagged | **PASS** — no flips |
| Determinism (seed 12345) | **PASS** |

---

## Trace excerpt (seed 12345, with kills column)

```
time_sec,unit_id,strength,cohesion,kills,pos_x,pos_y,state
62.0,red_1,99.4907,99.2270,5,-14.85,0.00,marching
62.0,blue_1,99.6153,99.4230,4,15.10,0.00,marching
```

---

## Assumptions made

**NONE**

---

## Known issues

- **Designer hand-confirm** needed for stat card readability at min/max zoom and bump animation visibility.
- **Combat duration destabilized** by Task 3 geometry (see table above) — TD review required for whether rear-anchor snap behavior needs refinement in a follow-up WO; no tuning applied here.
