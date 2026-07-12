# COMPLETION REPORT — WO-008

**Work order:** WO-008 — Edge-Based Contact: Flanks & Corners  
**Branch:** `cursor/wo-008-edge-contact-fd84`  
**Date:** 2026-07-12  
**TD ruling:** Per-channel edge multipliers (shift vs casualty) — spec change reversed in structure, revised in values

---

## Assumptions made

**NONE**

---

## Governance

Prior acceptance bands are **not** enforced on this run. Actuals delivered for TD band re-derivation. Any doc contradiction was escalated via TD ruling before implementation.

---

## Per-channel edge multipliers (implemented)

| Constant | Value | Channel |
|----------|-------|---------|
| `edge_mult_front` | 1.0 | front (both channels) |
| `edge_mult_side_shift` | 2.0 | shift morale (ground lost) |
| `edge_mult_rear_shift` | 3.0 | shift morale |
| `edge_mult_side_casualty` | 1.5 | casualty cohesion |
| `edge_mult_rear_casualty` | 2.0 | casualty cohesion |

Corner contacts length-weight blend **per channel** (`edge_shift_multiplier`, `edge_casualty_multiplier` in `classify_contact`). Head-on legacy path unchanged (no edge mult).

---

## Regression (Scenarios 1 & 2)

| Check | Result |
|-------|--------|
| S1 winner flips | **0** (11/11 seeds) |
| S1 combat drift | **0** (±0.15s) |
| S2 winner / combat / rout | **0** drift (11/11 seeds) |
| Determinism (core 8 cols, seed 12345) | **PASS** |

---

## Scenario 3 — LEFT flank (seed 1000, `FLANK_DELAY_SEC=9.5`)

| Metric | Actual |
|--------|--------|
| S1 reference combat | 68.2s |
| S3 combat | **22.0s** |
| Combat ratio (S3/S1) | **0.32** |
| Prior band | [0.45, 0.60] — **TD re-derive** |
| Blue `strength_at_rout` | **78.60%** |
| Blue edge drains | front=0, **left=50.3**, rear=12.5 |

**Note:** Allied overlap red_a/red_b detected at tick 837 during flank correction (faster rout with casualty mult). Overlap assertion **FAIL** — report to TD; timing not retuned per directive.

---

## Scenario 4 — Three-mode drain (seed 1000, 50 ticks)

| Mode | Drain/s | Spawn edge label |
|------|---------|------------------|
| FRONT | **3.155** | front |
| SIDE | **6.658** | left |
| CORNER | **3.163** | front+left |

### Decomposition (side vs front)

| Metric | Value |
|--------|-------|
| Observed side/front | **2.11×** |
| Spec shift mult (side/front) | **2.00×** |
| Spec casualty mult (side/front) | **1.50×** |
| Actual ÷ shift mult | **1.06×** |
| Actual ÷ casualty mult | **1.41×** |

### Corner ratios (actuals)

| Ratio | Value |
|-------|-------|
| corner/front | **1.00×** |
| corner/side | **0.48×** |

Prior strict-between ordering **not met** (corner ≈ front, side elevated by casualty channel). Delivered for TD band re-derivation; constants not retuned.

---

## Compass & overlap

| Check | Result |
|-------|--------|
| Compass 32/32 | **PASS** |
| S1 reflection overlap (seed 1000) | **PASS** |

---

## Files changed

| File | Change |
|------|--------|
| `data/combat_constants.json` | Four per-channel mult constants |
| `scripts/combat_resolver.gd` | `_edge_shift_multiplier_for_name`, `_edge_casualty_multiplier_for_name`, `_apply_casualty_drain_by_edges` |
| `scripts/edge_contact.gd` | Per-channel weighted blends in contact dict |
| `scripts/scenario_03.gd` | `FLANK_DELAY_SEC` restored to **9.5** |
| `tests/scenario_wo008_autotest.gd` | Report actuals; prior S3/S4 bands not enforced |
| `tests/wo001_smoke_test.gd` | New constant keys |

---

## Escalations (open)

1. **S3 ratio 0.32** — below prior [0.45, 0.60] band after casualty channel restore; TD re-derive band.
2. **S3 allied overlap** at tick 837 with 9.5s flank release — investigate vs casualty-mult pacing.
3. **S4 corner ordering** — corner ≈ front, side >> corner; TD re-derive strict-between band.
