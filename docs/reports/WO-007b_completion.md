# COMPLETION REPORT — WO-007b

**Work order:** WO-007b — K_dmg mini-sweep + commit (TD ruling on WO-007 sweep)  
**Branch:** `cursor/wo-007b-k-dmg-sweep-fd84`  
**Date:** 2026-07-11

---

## Committed constants (new project baseline)

| Constant | Previous | **New baseline** |
|----------|----------|------------------|
| `drain_per_meter_lost` | 0.8 | **0.8** (unchanged) |
| `drain_per_strength_pct_lost` | 1.5 | **2.5** |
| `k_dmg` | 0.004 | **0.0025** |

**All future acceptance tables and comparisons should baseline against these values** unless a later work order explicitly supersedes them.

---

## K_dmg sweep matrix (drains fixed at 0.8 / 2.5)

| k_dmg | mean S1 combat | mean S2 combat | mean S2 strength_at_rout | S1 winner Δ | S2 winner Δ |
|-------|----------------|----------------|--------------------------|-------------|-------------|
| 0.0020 | 90.7s | 50.5s | 68.06 | 1 | 0 |
| **0.0025** | **73.1s** | **41.5s** | **67.35** | **0** | **0** |
| 0.0030 | 61.0s | 35.2s | 66.80 | 0 | 0 |

Winner changes vs pre-WO-007b baseline (`k_dmg=0.004`, `drain_strength=1.5`).

**Selection rule applied:** All three cells keep S2 rout within 55–80%. Nearest S1 mean to 80s → **`k_dmg=0.0025`** (73.1s, |Δ|=6.9s). Committed per pre-authorized TD rule.

---

## Post-commit 11-seed baseline tables

### Scenario 1 (mean combat **73.1s**)

| Seed | Winner | Combat |
|------|--------|--------|
| 1000 | red_1 | 68.2s |
| 1001 | red_1 | 72.8s |
| 1002 | blue_1 | 68.0s |
| 1003 | blue_1 | 80.2s |
| 1004 | red_1 | 81.5s |
| 1005 | red_1 | 66.4s |
| 1006 | red_1 | 66.2s |
| 1007 | red_1 | 80.4s |
| 1008 | red_1 | 73.2s |
| 1009 | red_1 | 79.2s |
| 12345 | blue_1 | 68.2s |

### Scenario 2 (mean combat **41.5s**, mean strength_at_rout **67.34%**)

| Seed | Winner | Combat | strength_at_rout |
|------|--------|--------|------------------|
| 1000 | red_1 | 41.6s | 67.39 |
| 1001 | red_1 | 41.4s | 67.39 |
| 1002 | red_1 | 41.6s | 67.38 |
| 1003 | red_1 | 41.4s | 67.36 |
| 1004 | red_1 | 41.6s | 67.33 |
| 1005 | red_1 | 41.2s | 67.38 |
| 1006 | red_1 | 41.4s | 67.34 |
| 1007 | red_1 | 41.6s | 67.33 |
| 1008 | red_1 | 41.4s | 67.33 |
| 1009 | red_1 | 41.4s | 67.33 |
| 12345 | red_1 | 41.6s | 67.31 |

push60 wins **11/11**. S2 rout band **67.3–67.4%** (within 55–80% design target).

---

## Changes vs prior baselines

| Metric | WO-005/007 (old) | WO-007b (new) |
|--------|------------------|---------------|
| S1 mean combat | ~81.3s | **73.1s** |
| S2 mean combat | ~44.3s | **41.5s** |
| S2 mean strength_at_rout | ~46.5% | **67.3%** |
| S1 winner flips (vs old) | — | 0 at selected k_dmg |
| S2 winner flips (vs old) | — | 0 |

---

## Files changed

| File | Change |
|------|--------|
| `data/combat_constants.json` | `k_dmg=0.0025`, `drain_per_strength_pct_lost=2.5` |
| `tests/scenario_wo007b_autotest.gd` | K_dmg sweep harness |
| `tests/scenario_baseline_capture.gd` | Post-commit baseline capture |
| `docs/reports/WO-007b_completion.md` | This report |

---

## Assumptions made

**NONE**

---

## Known issues

- S1 per-seed combat spans 66–82s (mean 73.1s); guardrail “nearest 80s” met at mean level — individual seeds still vary.
- Designer hand-confirm items from prior WOs remain open.
