# ESCALATION REPORT — WO-024 Task 2 S3 gravity A/B

**Work order:** WO-024 Honest Numbers (Task 2 regression clause)  
**Branch:** `cursor/wo-024-honest-numbers-fd84`  
**Date:** 2026-07-15  
**Design authority:** DAMAGE_AND_CATEGORIES_v1.1 §5 (surface-gap EngageRadius); WO-024 Task 2

---

## Blocker

WO-024 requires S1/S2/S3 gravity A/B (`engage_radius_m` 4.0 vs 0.0) to remain **byte-identical**, or else escalate with the delta — do not rebaseline.

After fixing engagement gravity to measure **surface gap** (not center distance):

| Scenario | Identical? | Notes |
|----------|------------|-------|
| S1 | **yes** | combat 81.6s / winner blue_1 / ticks 2961 |
| S2 | **yes** | combat 61.2s / winner red_1 / ticks 2658 |
| S3 | **no** | winner & combat time identical; **519/739** TRACE lines differ |

S3 is a **flank** scenario (`red_b` delayed flanker). Working surface-gap gravity is no longer a no-op once the flanker enters the defender's front-arc engage window — tiny facing/position drift begins (~t=72s, first diff `pos_y` −0.01 vs 0.00 on `red_a`), then compound through the rest of the trace.

Final outcomes still match:

| Metric | radius 4.0 | radius 0.0 |
|--------|------------|------------|
| winner | `red_b` | `red_b` |
| combat_sec | 21.5 | 21.5 |
| ticks | 2303 | 2303 |
| blue_a strength@rout | 76.23 | 76.28 |

Evidence: `docs/reports/evidence_wo024/gravity_ab.log`, `s3_grav_diff.log`.

The WO parenthetical ("head-on marchers are already square, so gravity should be a no-op") holds for **S1/S2**. It does **not** hold for S3 once gravity is actually competent — that appears to be a scenario-classification assumption conflict, not a defect in the surface-gap measurement itself.

---

## Options

- **A)** Accept S3 A/B non-identity as expected with working gravity; keep S1/S2 byte-identical as the head-on lock; document S3 as "gravity-sensitive flank scenario" (no rebaseline of S3 golden numbers beyond what's already soft-gated).
- **B)** Change S3's A/B criterion from byte-identical traces to outcome-identical (winner + combat_sec ±ε), and treat trace drift as allowed.
- **C)** Force gravity off for units that are already on a scripted head-on march destination until first contact (narrower gravity) — **would be a behavior change beyond the stated surface-gap defect fix**; not recommended without TD design.

---

## Recommendation

**Option A** — S1/S2 already prove head-on gravity is a no-op. S3's delta is the first evidence that **working** Sec-5 gravity affects a scripted flank; escalating rather than papering over is correct.

---

## AWAITING GREEN LIGHT — S3 A/B lock only

Surface-gap gravity fix, S33 square-up, flank analytic, S34 pin, GAMEPLAY_TICK, and sensitivity curve remain completed under the main completion report. No S3 rebaseline applied.

## Links

- This escalation: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-024-honest-numbers-fd84/docs/reports/WO-024_escalation.md
- Completion report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-024-honest-numbers-fd84/docs/reports/WO-024_completion.md
- S3 diff log: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-024-honest-numbers-fd84/docs/reports/evidence_wo024/s3_grav_diff.log
- Previous report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-023-gate2-blockers-fd84/docs/reports/WO-023_completion.md
