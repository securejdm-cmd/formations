# ESCALATION REPORT — WO-025 Task 2 (quality_of_day width)

**Work order:** WO-025 Quality of the Day  
**Branch:** `cursor/wo-025-quality-of-day-fd84`  
**Date:** 2026-07-16  
**Design authority:** DESIGN_RULINGS R21  

---

## Blocker

Pre-authorized selection rule requires **one** `quality_of_day_sigma` where all six bands hold (33 seeds, 1000–1032):

| Edge | Required win% |
|------|---------------|
| 0% | 50 ± 10 |
| 3% | 55–68 |
| 5% | 62–75 |
| 10% | 78–90 |
| 20% | 90–98 |
| 50% | ≥ 98 |

**No tested σ ∈ {0.02, 0.03, 0.04, 0.05, 0.06, 0.08, 0.10, 0.12, 0.15} satisfies all six.**

Full table: `docs/reports/evidence_wo025/qod_sweep.md` / `.csv`.

### Pattern

- **Low σ (0.02–0.05):** 0% cell enters 40–60 (Task 3 OK), but mid/high edges remain too cliff-like (3–20% overshoot the upper band; 20% often 100%).
- **Mid σ (0.06–0.08):** mid edges soften, but 10–20% undershoot and 50% can fall below 98%.
- **High σ (≥0.10):** noise swamps paper stats — 50% edge win% collapses (84.8% at 0.10; 75.8% at 0.15), violating maneuver-adjacent paper dominance.

Gaussian N(1,σ) alone cannot draw the R21 curve. Per R21 / WO-025: **supporting levers (slow wobble, rout-threshold variance) are TD decisions** — workshop must not add them.

---

## Options

- **A)** TD authorizes a supporting mechanism (slow wobble and/or rout-threshold variance) and a follow-on WO to combine with σ.
- **B)** TD relaxes one or more selection bands (state which) so a single σ can commit.
- **C)** TD picks a provisional σ for playtest (recommend **0.05**: 0%=45.5, 5%=72.7, 50%=100; mid bands still imperfect) knowing Task 2 remains open.

---

## Recommendation

**Option A** — the sweep shows the cliff is structural; more zero-mean width only trades one failure mode for another. Supporting persistent/low-frequency variance is the R21-documented next lever.

---

## Still delivered (not blocked)

- R21 appended; `quality_of_day` implemented (disabled by default = WO-024 no-op)
- 0% anomaly diagnosed (slot/RNG-order, not posture); with σ≥0.02 the 0% cell lands in 50±10
- S3 rebaseline (separate commit); suite exit 0 with feature off
- Maneuver boundary spot-check at σ=0.05: S3/S18/S21/S34/S36 hold with QoD ON

## AWAITING GREEN LIGHT — width / supporting levers only

## Links

- This escalation: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-025-quality-of-day-fd84/docs/reports/WO-025_escalation.md
- Sweep: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-025-quality-of-day-fd84/docs/reports/evidence_wo025/qod_sweep.md
- Completion: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-025-quality-of-day-fd84/docs/reports/WO-025_completion.md
- Previous: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-024-honest-numbers-fd84/docs/reports/WO-024_completion.md
